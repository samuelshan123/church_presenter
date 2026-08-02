# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Church Presenter — a multiplatform Flutter app (Android/iOS/macOS/Windows/Linux) for presenting song lyrics, Bible verses, and images to a congregation. The controlling device runs an embedded HTTP/WebSocket server; a separate display (browser, projector laptop, etc.) connects to it and renders whatever the controller broadcasts.

This project uses FVM — Flutter SDK version is pinned in `.fvmrc` (currently 3.41.4). Prefix Flutter/Dart commands with `fvm` (e.g. `fvm flutter run`) if the FVM-managed SDK differs from the globally active one.

## Common commands

```bash
fvm flutter pub get                 # install dependencies
fvm flutter run                     # run on a connected device/simulator
fvm flutter run -d macos            # run on a specific platform
fvm flutter analyze                 # static analysis (uses analysis_options.yaml -> flutter_lints)
fvm flutter test                    # run tests (no test/ directory exists yet)
fvm flutter test test/some_test.dart --plain-name "test name"   # run a single test
fvm flutter build apk / ios / macos / web   # platform builds
```

There is no CI config and no test suite currently in the repo — verify changes by running the app rather than relying on `flutter test`.

## Architecture

### Global singleton services, not DI

`lib/main.dart` constructs a handful of app-lifetime singleton services at the top level (`globalPresenterConfig`, `globalBackgroundService`, `globalImageService`, `globalSongSyncController`, `globalServerService`) and wires them into a `MultiProvider`. Screens read them via `context.watch/read<T>()` (provider package) or by receiving them directly as constructor args from `HomeScreen`. There is no separate DI container — new cross-cutting state should follow this same global-singleton-plus-ChangeNotifier pattern rather than introducing a new state-management approach.

### Broadcast/presenter system (the core feature)

- `ServerService` (`lib/services/server_service.dart`) runs a `shelf`-based HTTP server on port 8901 with a `/api/ws` WebSocket endpoint. Any number of display clients can connect. It also serves `GET /` (the display page), `/api/background`, and `/api/image/<path>` (arbitrary local file paths read off disk and streamed to displays).
- Controller screens call `serverService.sendMessage(content, messageType, metadata)` to broadcast. `messageType` is one of `'text'`, `'image'`, or `'bible'`; `metadata` carries type-specific fields (e.g. `imagePath`, `book`).
- Every broadcast payload has the same shape — `config` (presenter colors/font/size), `background`, `imageConfig`, `type`, `content`, `metadata`, `overlay` — so the display client is fully stateless and just re-renders whatever it receives, including on initial connect. `ServerService` caches the last-sent values and replays them to any client that connects or reconnects mid-service.
- `overlay` is the canvas layer and is tracked *separately* from `type`/`content`: drawing over a verse must not clobber the verse underneath. `sendOverlay()` deliberately skips `notifyListeners()` and logging because it fires at ~30Hz while a stroke is in progress.
- `assets/presenter/web/index.html` is the reference display client: a static HTML/JS page served at `/` by the same shelf server and also usable standalone in any browser pointed at the controller's LAN IP. When changing the WebSocket message contract, update both `ServerService` (producer) and `index.html` (consumer) together — plus `lib/views/features/presenter/screens/presenter_screen.dart` and `present_image_screen.dart`, the in-app Flutter equivalents of the same renderer.
- The server binds `anyIPv4`, so it is reachable on every interface — but most of those addresses are useless to the congregation's display. `_ipScore`/`_rankIps` rank interfaces so a real LAN adapter on a private range sorts first, and VPN tunnels, Tailscale's CGNAT range, VM bridges, AirDrop, and cellular sort last. Nothing is dropped; the UI surfaces the top pick and hides the rest. Fixing "the URL doesn't work" bugs usually means adjusting these prefix lists, not the server itself.
- `WakelockPlus` is enabled while the server runs so the controlling device's screen doesn't sleep mid-service.

### Canvas overlay

`CanvasOverlayService` (`lib/services/canvas_overlay_service.dart`) backs a drawable annotation layer over the live slide — freehand strokes plus placed/resizable images, with a shared undo/redo timeline.

- **All coordinates are normalised 0–1**, never pixels, so the controller and every display render identically at any resolution. The controller letterboxes its drawing area to `kCanvasAspectRatio` (`letterbox()`) so normalised coordinates never stretch.
- Erasing removes whole strokes from a list rather than compositing pixels — strokes stay the single source of truth, so an erase survives a resize repaint and undoes as one step.
- Strokes are decimated while drawing (`_minPointDistance`) and simplified with Ramer–Douglas–Peucker on commit, which is what keeps the broadcast payload small enough to stream live.
- The service knows nothing about `ServerService` — the screen owns broadcasting. Keep it that way: it means the overlay works with the server stopped.
- `toPayload()` is the wire format; selection handles are excluded on purpose since they are controller-only chrome the congregation must never see.

### Images

Picked images go through `ImageCompressionService` before being stored or served. Every connected display fetches these over LAN, so the resolution cap (`_maxDimension`) matters far more than encoder quality. Compression is best-effort by design — it returns the *original* file when it would skip, fail, or produce a larger result, so callers can treat the result as "the file to use" without null handling. Never let it block presenting.

### Persistence: SQLite (structured data) + SharedPreferences (settings)

- `DatabaseHelper` (`lib/db/database_helper.dart`) is a singleton wrapping `sqflite`. Schema is managed via `onCreate`/`onUpgrade` with a manually incremented `version` (currently 5) — when changing schema, add an `if (oldVersion < N)` branch in `_upgradeDB` rather than editing existing migration steps, and bump `version`. Existing installs never re-run `onCreate`, so any table added there needs a matching migration branch.
- Tables: `songs`, `song_lists`, `list_songs` (many-to-many join), `bible_verse_history`, plus the sync tables below.
- Simple user preferences (presenter colors/fonts, background image path/display type, theme) live in `SharedPreferences` via each respective `ChangeNotifier` service, not in SQLite.

### Song sync (CDN import pipeline)

Tamil Christian song lyrics are pulled from a static CDN (`SongSyncService`, `lib/services/song_sync_service.dart`) rather than a normal REST API:
- A master index (`sync_song_index` table) maps remote song IDs to titles and "buckets" (`bucket = floor(id / 50)`).
- Full lyrics live in per-bucket blobs at `/caches/{sha256(bucketNumber)}.cs.song`, each a gzip+base64-encoded JSON map keyed by `id % 50`.
- `SongSyncController` (`lib/controllers/song_sync_controller.dart`) orchestrates: fetch index → diff against local `sync_song_detail` → compute only the missing buckets → fetch and upsert, exposing progress via `SyncStatus`/`SyncStats` for the UI. Sync is resumable/idempotent — only missing songs are re-fetched, and only the `sync_meta.last_synced_at` timestamp is written on a fully successful run.
- These CDN-synced songs are read-only reference content, separate from user-authored songs in the `songs` table.

### Web song import (scraping, separate from CDN sync)

`WebSearchService` (`lib/services/web_search_service.dart`) is a second, independent import path: it scrapes DuckDuckGo's HTML endpoint, unwraps the `uddg` redirect parameter, then tries an ordered list of CSS selectors against each result page to extract lyrics. Expect this to be brittle — it depends on third-party markup. `searchTitles()` returns immediately for the UI; `fetchLyrics()` pulls a single page on demand. `_cleanLyrics`/`_isValidLyrics` truncate at known site boilerplate and reject junk; when a site starts leaking navigation text into imports, extend those stop-word lists.

### Presenting songs

Song content is free-form text split into slides by `parseSongSections()` (`lib/views/features/songs/utils/song_section_parser.dart`): blank-line-delimited, falling back to per-line splitting when there are no blank lines. `stripEnglishOnlyLinesIfTamil()` drops ASCII-only lines when the content contains Tamil — web-scraped lyrics routinely interleave a transliteration the congregation doesn't want projected. `SectionBroadcastController` handles stepping through those sections and pushing each to `ServerService`.

### Bible content

Each Bible book is a separate bundled asset (`assets/bible/<BookName>.json`), listed individually in `pubspec.yaml`'s `flutter.assets`. `BibleService` lazily loads and caches per-book JSON on first access rather than loading the whole Bible at startup — when adding new translations/books, follow the same per-book-file convention and remember to register the new asset path in `pubspec.yaml`.

### Feature module layout

`lib/views/features/<feature>/screens/`, `.../widgets/`, and `.../utils/` group UI by feature (bible, songs, backgrounds, presenter, present-image, canvas). Shared cross-feature widgets live in `lib/views/widgets/`. Services in `lib/services/` are the state/logic layer; screens should stay thin and delegate to services rather than holding business logic directly.

### UI conventions

- Theming is centralised in `main.dart`: Material 3, a `deepPurple` seeded `ColorScheme`, and Poppins via `google_fonts`. In particular `_buildInputDecorationTheme` styles every input — don't set per-field `border`/`filled`/`fillColor` on a `TextField`, or it will drift from the rest of the app.
- Icons come from the `hugeicons` package rather than Material icons.
