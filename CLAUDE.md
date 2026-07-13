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

- `ServerService` (`lib/services/server_service.dart`) runs a `shelf`-based HTTP server on port 8901 with a `/api/ws` WebSocket endpoint. Any number of display clients can connect.
- Controller screens call `serverService.sendMessage(content, messageType, metadata)` to broadcast. `messageType` is one of `'text'`, `'image'`, or `'bible'`; `metadata` carries type-specific fields (e.g. `imagePath`, `book`).
- Every broadcast payload bundles the current `presenterConfig` (colors/font/size), `backgroundService` config, and `imageService` config alongside `type`/`content`/`metadata` — the display client is fully stateless and just re-renders whatever it receives, including on initial connect.
- `assets/presenter/web/index.html` is the reference display client: a static HTML/JS page served at `/` by the same shelf server and also usable standalone in any browser pointed at the controller's LAN IP. When changing the WebSocket message contract, update both `ServerService` (producer) and `index.html` (consumer) together — plus `lib/views/features/presenter/screens/presenter_screen.dart` and `present_image_screen.dart`, the in-app Flutter equivalents of the same renderer.
- `WakelockPlus` is enabled while the server runs so the controlling device's screen doesn't sleep mid-service.

### Persistence: SQLite (structured data) + SharedPreferences (settings)

- `DatabaseHelper` (`lib/db/database_helper.dart`) is a singleton wrapping `sqflite`. Schema is managed via `onCreate`/`onUpgrade` with a manually incremented `version` — when changing schema, add an `if (oldVersion < N)` branch in `_upgradeDB` rather than editing existing migration steps, and bump `version`.
- Tables: `songs`, `song_lists`, `list_songs` (many-to-many join), `bible_verse_history`, plus the sync tables below.
- Simple user preferences (presenter colors/fonts, background image path/display type, theme) live in `SharedPreferences` via each respective `ChangeNotifier` service, not in SQLite.

### Song sync (CDN import pipeline)

Tamil Christian song lyrics are pulled from a static CDN (`SongSyncService`, `lib/services/song_sync_service.dart`) rather than a normal REST API:
- A master index (`sync_song_index` table) maps remote song IDs to titles and "buckets" (`bucket = floor(id / 50)`).
- Full lyrics live in per-bucket blobs at `/caches/{sha256(bucketNumber)}.cs.song`, each a gzip+base64-encoded JSON map keyed by `id % 50`.
- `SongSyncController` (`lib/controllers/song_sync_controller.dart`) orchestrates: fetch index → diff against local `sync_song_detail` → compute only the missing buckets → fetch and upsert, exposing progress via `SyncStatus`/`SyncStats` for the UI. Sync is resumable/idempotent — only missing songs are re-fetched, and only the `sync_meta.last_synced_at` timestamp is written on a fully successful run.
- These CDN-synced songs are read-only reference content, separate from user-authored songs in the `songs` table.

### Bible content

Each Bible book is a separate bundled asset (`assets/bible/<BookName>.json`), listed individually in `pubspec.yaml`'s `flutter.assets`. `BibleService` lazily loads and caches per-book JSON on first access rather than loading the whole Bible at startup — when adding new translations/books, follow the same per-book-file convention and remember to register the new asset path in `pubspec.yaml`.

### Feature module layout

`lib/views/features/<feature>/screens/` and `.../widgets/` group UI by feature (bible, songs, backgrounds, presenter, present-image). Shared cross-feature widgets live in `lib/views/widgets/`. Services in `lib/services/` are the state/logic layer; screens should stay thin and delegate to services rather than holding business logic directly.
