/// Google Cast (Chromecast / Google TV) settings.
///
/// Casting uses a *custom* receiver: the display page
/// (`assets/presenter/web/index.html`) hosted over HTTPS and opened on the
/// Chromecast with `?mode=cast`. It is registered in the Google Cast SDK
/// Developer Console (https://cast.google.com/publish), which issues the
/// application ID below.
///
/// Until that ID is filled in, [isCastConfigured] is false and the app hides
/// its Cast button. When the ID changes, also update the `_<ID>._googlecast._tcp`
/// entry under `NSBonjourServices` in `ios/Runner/Info.plist`.
library;

/// Application ID from the Cast Developer Console, e.g. `'A1B2C3D4'`.
const String kCastReceiverAppId = '';

/// Where the receiver page is hosted (GitHub Pages, published by
/// `.github/workflows/cast-receiver.yml`). Register exactly this URL in the
/// Cast Developer Console.
const String kCastReceiverUrl =
    'https://samuelshan123.github.io/church_presenter/?mode=cast';

/// Custom message channel between the app and the receiver page. Must match
/// `CAST_NAMESPACE` in `index.html`.
const String kCastNamespace = 'urn:x-cast:com.churchpresenter.display';

bool get isCastConfigured => kCastReceiverAppId.isNotEmpty;
