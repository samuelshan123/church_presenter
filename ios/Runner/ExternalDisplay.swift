import Flutter
import UIKit
import WebKit

/// Second-screen output for HDMI adapters and AirPlay.
///
/// When a TV is attached, iOS creates a scene for it (see the external
/// display roles in Info.plist). Instead of mirroring the controller UI, that
/// scene shows the built-in display page (`assets/presenter/web/index.html`)
/// full-screen. That is the same stateless page any browser display uses, so
/// the TV renders songs, Bible, images and canvas identically with no second
/// renderer to maintain.
enum ExternalDisplayBridge {
  private static var channel: FlutterMethodChannel?
  private(set) static var isConnected = false

  /// Exposes connect/disconnect events to Dart (`ExternalDisplayService`).
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "church_presenter/external_display",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isConnected":
        result(isConnected)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  static func setConnected(_ connected: Bool) {
    guard connected != isConnected else { return }
    isConnected = connected
    channel?.invokeMethod(connected ? "connected" : "disconnected", arguments: nil)
  }
}

/// Scene delegate for the external display roles declared in Info.plist.
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = ExternalDisplayViewController()
    window.isHidden = false
    self.window = window
    ExternalDisplayBridge.setConnected(true)
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    window = nil
    ExternalDisplayBridge.setConnected(false)
  }
}

/// Full-screen web view of the local display page. While the presenter
/// server isn't running it shows a waiting screen and retries, so plugging
/// the TV in before tapping "Start Presenter" just works.
final class ExternalDisplayViewController: UIViewController, WKNavigationDelegate {
  private static let displayURL = URL(string: "http://127.0.0.1:8901/")!
  private static let retryInterval: TimeInterval = 2

  private lazy var webView: WKWebView = {
    let configuration = WKWebViewConfiguration()
    configuration.mediaTypesRequiringUserActionForPlayback = []
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .black
    webView.scrollView.backgroundColor = .black
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.navigationDelegate = self
    return webView
  }()

  private var retryTimer: Timer?
  private var isShowingWaitingScreen = false

  override func loadView() {
    view = webView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    loadDisplayPage()
  }

  override var prefersHomeIndicatorAutoHidden: Bool { true }

  deinit {
    retryTimer?.invalidate()
  }

  private func loadDisplayPage() {
    webView.load(
      URLRequest(
        url: Self.displayURL,
        cachePolicy: .reloadIgnoringLocalCacheData,
        timeoutInterval: 3
      )
    )
  }

  private func handleLoadFailure() {
    // A failed load leaves the previous page on screen, so the waiting page
    // only needs drawing once — after that just keep retrying behind it.
    if !isShowingWaitingScreen {
      isShowingWaitingScreen = true
      webView.loadHTMLString(Self.waitingPageHTML, baseURL: nil)
    }
    retryTimer?.invalidate()
    retryTimer = Timer.scheduledTimer(withTimeInterval: Self.retryInterval, repeats: false) {
      [weak self] _ in
      self?.loadDisplayPage()
    }
  }

  // MARK: WKNavigationDelegate

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if webView.url?.host == Self.displayURL.host {
      isShowingWaitingScreen = false
      retryTimer?.invalidate()
    }
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    handleLoadFailure()
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    handleLoadFailure()
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    loadDisplayPage()
  }

  private static let waitingPageHTML = """
    <!DOCTYPE html>
    <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
    <style>
      html,body{margin:0;height:100%;background:#000;color:#fff;
        font-family:-apple-system,system-ui,sans-serif;display:flex;
        align-items:center;justify-content:center;text-align:center}
      h1{font-size:5vw;font-weight:600;margin:0 0 1.5vw}
      p{font-size:2.4vw;color:#9a9a9a;margin:0}
    </style></head>
    <body><div><h1>Church Presenter</h1>
    <p>Tap “Start Presenter” on your device to show slides here.</p></div></body></html>
    """
}
