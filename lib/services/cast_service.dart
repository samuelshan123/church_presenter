import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../config/cast_config.dart';
import 'server_service.dart';

/// Google Cast (Chromecast / Google TV) output.
///
/// The Chromecast runs the same display page as every browser display
/// (`index.html?mode=cast`, see [kCastReceiverUrl]), but it is served over
/// HTTPS and so may not open the controller's plain-HTTP WebSocket or image
/// URLs. Instead this service relays each payload over the Cast message
/// channel ([kCastNamespace]):
///
/// * `state` — the exact payload WebSocket displays get, with local image
///   paths swapped for asset ids;
/// * `asset` — an image, downscaled for a TV and base64-encoded, sent once per
///   session;
/// * `part` — any message over the Cast size limit, split into pieces the
///   receiver joins back together.
///
/// Like [CanvasOverlayService], the server knows nothing about casting: this
/// service subscribes to [ServerService] payloads.
class CastService extends ChangeNotifier {
  CastService({required ServerService serverService})
    : _serverService = serverService;

  final ServerService _serverService;

  /// The Cast SDK caps one message at 64 KiB; leave room for its envelope.
  static const int _maxMessageBytes = 60000;

  /// TVs are 1080p (some 4K, but the Chromecast UI layer renders at 1080p),
  /// so anything bigger only slows the transfer.
  static const int _assetMaxDimension = 1920;
  static const int _assetQuality = 82;

  bool _initialised = false;
  StreamSubscription<GoogleCastSession?>? _sessionSubscription;
  StreamSubscription<GoogleCastMessage>? _messageSubscription;
  GoogleCastSession? _session;

  /// Asset ids the current receiver already holds.
  final Set<String> _sentAssets = {};
  int _nextPartId = 0;

  Map<String, dynamic>? _pendingPayload;
  bool _sending = false;

  /// Casting needs the native Cast SDK (Android / iOS) and a registered
  /// receiver ([isCastConfigured]). On desktop, Chrome's own "Cast tab" can
  /// cast the browser display page instead.
  bool get isAvailable =>
      isCastConfigured && !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  GoogleCastConnectState get connectionState =>
      _session?.connectionState ?? GoogleCastConnectState.disconnected;
  bool get isConnected => connectionState == GoogleCastConnectState.connected;
  bool get isConnecting => connectionState == GoogleCastConnectState.connecting;

  /// The TV's name, e.g. "Living Room TV", while connected or connecting.
  String? get deviceName => _session?.device?.friendlyName;

  Stream<List<GoogleCastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  List<GoogleCastDevice> get devices =>
      GoogleCastDiscoveryManager.instance.devices;

  /// Sets up the Cast SDK. Safe to call more than once; a no-op where casting
  /// is unavailable.
  Future<void> initialise() async {
    if (_initialised || !isAvailable) return;
    _initialised = true;

    final GoogleCastOptions options = Platform.isIOS
        ? IOSGoogleCastOptions(
            GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(
              kCastReceiverAppId,
            ),
            stopCastingOnAppTerminated: true,
          )
        : GoogleCastOptionsAndroid(
            appId: kCastReceiverAppId,
            stopCastingOnAppTerminated: true,
          );

    try {
      await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
      await GoogleCastSessionManager.instance.addMessageChannel(kCastNamespace);
    } catch (e) {
      debugPrint('Cast unavailable: $e');
      return;
    }

    _sessionSubscription = GoogleCastSessionManager
        .instance
        .currentSessionStream
        .listen(_onSessionChanged);
    _messageSubscription = GoogleCastSessionManager.instance.messageStream
        .where((m) => m.namespace == kCastNamespace)
        .listen(_onReceiverMessage);
  }

  Future<void> startDiscovery() async {
    if (!_initialised) return;
    await GoogleCastDiscoveryManager.instance.startDiscovery(activeScan: true);
  }

  Future<void> stopDiscovery() async {
    if (!_initialised) return;
    await GoogleCastDiscoveryManager.instance.stopDiscovery();
  }

  Future<bool> connect(GoogleCastDevice device) async {
    if (!_initialised) return false;
    return GoogleCastSessionManager.instance.startSessionWithDevice(device);
  }

  Future<void> disconnect() async {
    if (!_initialised) return;
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
  }

  void _onSessionChanged(GoogleCastSession? session) {
    final wasConnected = isConnected;
    _session = session;
    final nowConnected = isConnected;

    if (nowConnected && !wasConnected) {
      _onConnected();
    } else if (!nowConnected && wasConnected) {
      _onDisconnected();
    }
    notifyListeners();
  }

  Future<void> _onConnected() async {
    _sentAssets.clear();
    _serverService.addPayloadListener(_queuePayload);
    // Screens only broadcast while the presenter is running, so casting
    // switches it on — just like plugging in an HDMI screen does.
    if (!_serverService.isRunning) {
      await _serverService.startServer();
    }
    _queuePayload(_serverService.currentPayload);
  }

  void _onDisconnected() {
    _serverService.removePayloadListener(_queuePayload);
    _pendingPayload = null;
    _sentAssets.clear();
  }

  /// The receiver says "ready" whenever its page (re)loads, having lost its
  /// asset cache: resend everything.
  void _onReceiverMessage(GoogleCastMessage message) {
    try {
      final data = jsonDecode(message.message);
      if (data is Map && data['kind'] == 'ready' && isConnected) {
        _sentAssets.clear();
        _queuePayload(_serverService.currentPayload);
      }
    } catch (_) {
      // Ignore anything that isn't ours.
    }
  }

  /// Keeps only the newest payload while a send is in flight, so a burst
  /// (live canvas drawing at ~30Hz) collapses to what the TV can keep up with
  /// instead of queueing stale frames.
  void _queuePayload(Map<String, dynamic> payload) {
    if (!isConnected) return;
    _pendingPayload = payload;
    if (!_sending) _drain();
  }

  Future<void> _drain() async {
    _sending = true;
    try {
      while (_pendingPayload != null && isConnected) {
        final payload = _pendingPayload!;
        _pendingPayload = null;
        await _sendPayload(payload);
      }
    } catch (e) {
      debugPrint('Cast send failed: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> _sendPayload(Map<String, dynamic> payload) async {
    // A JSON round trip gives a deep, mutable copy we can rewrite safely.
    final state = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;

    final metadata = state['metadata'];
    if (state['type'] == 'image' &&
        metadata is Map &&
        metadata['imagePath'] is String) {
      metadata['imageAsset'] = await _ensureAsset(
        metadata['imagePath'] as String,
      );
    }

    final background = state['background'];
    if (background is Map && background['imagePath'] is String) {
      background['imageAsset'] = await _ensureAsset(
        background['imagePath'] as String,
      );
    }

    final overlay = state['overlay'];
    if (overlay is Map && overlay['images'] is List) {
      for (final image in overlay['images'] as List) {
        final url = image is Map ? image['url'] : null;
        if (url is String && url.startsWith('/api/image/')) {
          final path = Uri.decodeComponent(url.substring('/api/image/'.length));
          final id = await _ensureAsset(path);
          if (id != null) image['url'] = 'asset:$id';
        }
      }
    }

    await _sendJson({'kind': 'state', 'data': state});
  }

  /// Sends the image at [path] unless the receiver already has it, returning
  /// its asset id (or null if the file can't be read).
  Future<String?> _ensureAsset(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    final id = sha1
        .convert(
          utf8.encode('$path|${stat.size}|${stat.modified.toIso8601String()}'),
        )
        .toString()
        .substring(0, 16);
    if (_sentAssets.contains(id)) return id;

    final isPng = path.toLowerCase().endsWith('.png');
    Uint8List? bytes;
    try {
      // Same approach as ImageCompressionService: min* caps the long edge.
      bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: _assetMaxDimension,
        minHeight: _assetMaxDimension,
        quality: _assetQuality,
        // PNG keeps transparency for canvas stickers and logos.
        format: isPng ? CompressFormat.png : CompressFormat.jpeg,
      );
    } catch (e) {
      debugPrint('Cast image downscale failed, sending original: $e');
    }
    bytes ??= await file.readAsBytes();

    final sent = await _sendJson({
      'kind': 'asset',
      'id': id,
      'mime': isPng ? 'image/png' : 'image/jpeg',
      'data': base64Encode(bytes),
    });
    if (sent) _sentAssets.add(id);
    return id;
  }

  /// Sends [message], splitting it into `part` messages when it is over the
  /// Cast size limit. Returns false once the session is gone.
  Future<bool> _sendJson(Map<String, dynamic> message) async {
    final text = jsonEncode(message);
    if (utf8.encode(text).length <= _maxMessageBytes) {
      return _send(text);
    }

    // Tamil text is three bytes per character in UTF-8; base64 is one.
    final isAscii = text.codeUnits.every((c) => c < 128);
    final chunkChars = isAscii ? _maxMessageBytes - 200 : 16000;
    final count = (text.length / chunkChars).ceil();
    final id = _nextPartId++;
    for (var index = 0; index < count; index++) {
      final start = index * chunkChars;
      final end = (start + chunkChars).clamp(0, text.length);
      final ok = await _send(
        jsonEncode({
          'kind': 'part',
          'id': id,
          'index': index,
          'count': count,
          'text': text.substring(start, end),
        }),
      );
      if (!ok) return false;
    }
    return true;
  }

  Future<bool> _send(String text) async {
    if (!isConnected) return false;
    try {
      return await GoogleCastSessionManager.instance.sendMessage(
        kCastNamespace,
        text,
      );
    } catch (e) {
      debugPrint('Cast message failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _messageSubscription?.cancel();
    _serverService.removePayloadListener(_queuePayload);
    super.dispose();
  }
}
