import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'presenter_config_service.dart';
import 'background_service.dart';
import 'image_service.dart';

class ServerService extends ChangeNotifier {
  final PresenterConfigService presenterConfig;
  final BackgroundService backgroundService;
  final ImageService imageService;
  HttpServer? _server;
  String? _deviceIp;
  List<(String, String)> _deviceIps = []; // (interfaceName, address)
  String? _currentMessage;
  String _currentMessageType = 'text';
  Map<dynamic, dynamic>? _currentMetadata;

  /// Drawable canvas layer, rendered *above* whatever `type`/`content` is
  /// showing. Held separately so drawing over a verse or an image never
  /// clobbers the underlying content. Null means no overlay is active.
  Map<String, dynamic>? _currentOverlay;
  bool _isRunning = false;
  final int port = 8901;
  final List<WebSocketChannel> _connectedClients = [];

  ServerService({
    required this.presenterConfig,
    required this.backgroundService,
    required this.imageService,
  });

  bool get isRunning => _isRunning;
  String? get deviceIp => _deviceIp;
  String? get currentMessage => _currentMessage;
  String get serverUrl => 'http://$_deviceIp:$port';
  List<String> get serverUrls =>
      _deviceIps.map((e) => 'http://${e.$2}:$port').toList();
  /// Ranked best-first: the first entry is the address other devices on the
  /// same network are most likely able to reach. [isRecommended] marks entries
  /// that are genuine physical LAN adapters on a private-router range.
  List<({String label, String url, bool isRecommended})>
  get serverUrlsWithLabels => _deviceIps
      .map(
        (e) => (
          label: e.$1,
          url: 'http://${e.$2}:$port',
          isRecommended: _ipScore(e) == 0,
        ),
      )
      .toList();
  int get connectedClientsCount => _connectedClients.length;

  /// Service Handler
  Handler get handler {
    final router = shelf_router.Router();

    // WebSocket endpoint
    router.get(
      '/api/ws',
      webSocketHandler((WebSocketChannel socket, String? protocol) {
        _connectedClients.add(socket);
        print(
          '✅ WebSocket client connected. Total: ${_connectedClients.length}',
        );

        // Send current state on connection. This replays the *actual* current
        // type/metadata/overlay rather than assuming text, so a display that
        // reconnects mid-service restores the live slide and any drawing on it
        // instead of dropping back to a blank text screen.
        var initialPayload = {
          'config': presenterConfig.getConfig(),
          'background': backgroundService.getBackgroundConfig(),
          'imageConfig': imageService.getImageConfig(),
          'type': _currentMessageType,
          'content': _currentMessage ?? '',
          'metadata': _currentMetadata ?? {},
          'overlay': _currentOverlay,
        };
        socket.sink.add(jsonEncode(initialPayload));

        // Remove client on disconnect
        socket.stream.listen(
          (_) {},
          onDone: () {
            _connectedClients.remove(socket);
            print(
              '👋 Client disconnected. Remaining: ${_connectedClients.length}',
            );
            notifyListeners();
          },
          onError: (_) {
            _connectedClients.remove(socket);
            notifyListeners();
          },
        );
      }),
    );

    // Serve index.html
    router.get('/', (Request request) async {
      try {
        final html = await rootBundle.loadString(
          'assets/presenter/web/index.html',
        );
        return Response.ok(
          html,
          headers: {
            'Content-Type': 'text/html',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
          },
        );
      } catch (e) {
        print('❌ Error loading index.html: $e');
        return Response.internalServerError(body: 'Error loading page: $e');
      }
    });

    // Serve background image
    router.get('/api/background', (Request request) async {
      try {
        if (backgroundService.hasImage) {
          final file = File(backgroundService.imagePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final extension = backgroundService.imagePath!
                .split('.')
                .last
                .toLowerCase();
            final contentType = _getImageContentType(extension);
            return Response.ok(bytes, headers: {'Content-Type': contentType});
          }
        }
        return Response.notFound('No background image');
      } catch (e) {
        print('❌ Error serving background: $e');
        return Response.internalServerError(body: 'Error loading background');
      }
    });

    // Serve content image
    router.get('/api/image/<imagePath|.*>', (
      Request request,
      String imagePath,
    ) async {
      try {
        final decodedPath = Uri.decodeComponent(imagePath);
        final file = File(decodedPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final extension = decodedPath.split('.').last.toLowerCase();
          final contentType = _getImageContentType(extension);
          return Response.ok(bytes, headers: {'Content-Type': contentType});
        }
        return Response.notFound('Image not found');
      } catch (e) {
        print('❌ Error serving content image: $e');
        return Response.internalServerError(body: 'Error loading image');
      }
    });

    router.all('/<ignored|.*>', (Request request) {
      return Response.notFound('Not Found');
    });

    return router;
  }

  /// Start Server
  Future<bool> startServer() async {
    try {
      _deviceIps = _rankIps(await _getAllLocalIps());
      _deviceIp = _deviceIps.isNotEmpty ? _deviceIps.first.$2 : 'Unknown';
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      _isRunning = true;

      // Enable wakelock to keep server running when screen is off
      await WakelockPlus.enable();
      print('🔒 Wakelock enabled - server will stay active');

      notifyListeners();
      print('✅ Server running on http://$_deviceIp:$port');
      return true;
    } catch (e) {
      print('❌ Error starting server: $e');
      return false;
    }
  }

  /// Stop Server
  Future<void> stopServer() async {
    if (_server != null) {
      // Disable wakelock
      await WakelockPlus.disable();
      print('🔓 Wakelock disabled');

      // Close all WebSocket connections
      for (var client in List<WebSocketChannel>.from(_connectedClients)) {
        try {
          await client.sink.close();
        } catch (e) {
          print('❌ Error closing client: $e');
        }
      }
      _connectedClients.clear();

      await _server!.close(force: true);
      _server = null;
      _isRunning = false;
      _currentMessage = null;
      _currentOverlay = null;
      _deviceIps = <(String, String)>[];
      _deviceIp = null;
      notifyListeners();
      print('🛑 Server stopped');
    }
  }

  /// Broadcast Message to all connected clients
  void sendMessage(
    String message,
    String messageType,
    Map<dynamic, dynamic>? metadata,
  ) {
    _currentMessage = message;
    _currentMessageType = messageType;
    _currentMetadata = metadata;
    _broadcast(message, messageType, metadata);
  }

  /// Re-broadcast current state with fresh background/config (e.g. after background settings change)
  void broadcastCurrentState() {
    _broadcast(_currentMessage ?? '', _currentMessageType, _currentMetadata);
  }

  /// Broadcast the drawable canvas layer without disturbing the content beneath
  /// it. Pass null to remove the overlay entirely.
  ///
  /// This is called at up to ~30Hz while a stroke is in progress, so it skips
  /// the `notifyListeners()`/logging that [_broadcast] does — rebuilding every
  /// listening widget on each point would stutter the controller's own canvas.
  void sendOverlay(Map<String, dynamic>? overlay) {
    _currentOverlay = overlay;
    if (_connectedClients.isEmpty) return;

    final data = jsonEncode({
      'config': presenterConfig.getConfig(),
      'background': backgroundService.getBackgroundConfig(),
      'imageConfig': imageService.getImageConfig(),
      'type': _currentMessageType,
      'content': _currentMessage ?? '',
      'metadata': _currentMetadata,
      'overlay': overlay,
    });

    for (final client in List<WebSocketChannel>.from(_connectedClients)) {
      try {
        client.sink.add(data);
      } catch (e) {
        print('❌ Error sending overlay to client: $e');
        _connectedClients.remove(client);
      }
    }
  }

  void _broadcast(
    String message,
    String messageType,
    Map<dynamic, dynamic>? metadata,
  ) {
    var payload = {
      'config': presenterConfig.getConfig(),
      'background': backgroundService.getBackgroundConfig(),
      'imageConfig': imageService.getImageConfig(),
      'type': messageType,
      'content': message,
      'metadata': metadata,
      'overlay': _currentOverlay,
    };
    final data = jsonEncode(payload);

    for (final client in List<WebSocketChannel>.from(_connectedClients)) {
      try {
        client.sink.add(data);
      } catch (e) {
        print('❌ Error sending to client: $e');
        _connectedClients.remove(client);
      }
    }

    notifyListeners();
    print('📤 Broadcast to ${_connectedClients.length} clients: $message');
  }

  /// Interface name prefixes that are real physical LAN adapters. Devices on
  /// the same Wi-Fi/router can reach these; everything else is virtual.
  static const _physicalPrefixes = [
    'en', // macOS / iOS ethernet + Wi-Fi
    'wlan', // Android / Linux Wi-Fi
    'eth', // Linux ethernet
    'wi-fi', // Windows
    'ethernet', // Windows
  ];

  /// Mobile data. Physical and often on a private range, but nobody on the
  /// church Wi-Fi can route to it — always rank below a real LAN adapter.
  static const _cellularPrefixes = ['rmnet', 'pdp_ip', 'ccmni'];

  /// Interface name prefixes that are virtual: VPN tunnels, VM/container
  /// bridges, AirDrop/AWDL, and Apple-internal adapters. The server does listen
  /// on these, but other devices on the LAN have no route to them.
  static const _virtualPrefixes = [
    'utun', 'tun', 'tap', 'ppp', 'ipsec', // VPN tunnels
    'bridge', 'vboxnet', 'vmnet', 'docker', 'veth', // VMs / containers
    'awdl', 'llw', // AirDrop / AWDL
    'ap', 'anpi', // hotspot / Apple internal
  ];

  /// Score an interface+address pair — lower sorts first. The top-ranked
  /// address is the one most likely reachable by every device on the network.
  int _ipScore((String, String) entry) {
    final name = entry.$1.toLowerCase();
    final addr = entry.$2;

    // Tailscale and other CGNAT-range addresses look like ordinary IPs but are
    // only reachable from inside the same tunnel — rank them with the virtuals.
    final isCgnat = _isInCgnatRange(addr);
    final isVirtual =
        isCgnat || _virtualPrefixes.any((p) => name.startsWith(p));
    final isCellular =
        !isVirtual && _cellularPrefixes.any((p) => name.startsWith(p));
    final isPhysical =
        !isVirtual &&
        !isCellular &&
        _physicalPrefixes.any((p) => name.startsWith(p));

    if (isPhysical && _isPrivateLan(addr)) return 0; // ideal: real LAN adapter
    if (isPhysical) return 1; // physical, unusual range
    if (!isVirtual && !isCellular && _isPrivateLan(addr)) return 2; // unknown
    if (!isVirtual && !isCellular) return 3; // unknown name and range
    if (isCellular) return 4; // mobile data — not on the local network
    return 5; // VPN / VM / AirDrop
  }

  /// True for the private ranges a home/church router hands out.
  bool _isPrivateLan(String addr) {
    final parts = addr.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.contains(null)) return false;
    final a = parts[0]!, b = parts[1]!;
    if (a == 192 && b == 168) return true;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }

  /// 100.64.0.0/10 — carrier-grade NAT, used by Tailscale.
  bool _isInCgnatRange(String addr) {
    final parts = addr.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.contains(null)) return false;
    return parts[0] == 100 && parts[1]! >= 64 && parts[1]! <= 127;
  }

  /// Order addresses so the most publicly-reachable one is first. Nothing is
  /// dropped — the UI shows the top pick and tucks the rest behind an expander,
  /// so an unusual setup never leaves the user with no URL at all.
  List<(String, String)> _rankIps(List<(String, String)> ips) {
    final ranked = [...ips];
    ranked.sort((a, b) {
      final byScore = _ipScore(a).compareTo(_ipScore(b));
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
    return ranked;
  }

  /// Get all local non-loopback IPv4 addresses with their interface names
  Future<List<(String, String)>> _getAllLocalIps() async {
    final ips = <(String, String)>[];
    for (var interface in await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
    )) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          ips.add((interface.name, addr.address));
        }
      }
    }
    return ips;
  }

  /// Get image content type from extension
  String _getImageContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}
