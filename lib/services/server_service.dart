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
  String? _currentMessage;
  bool _isRunning = false;
  final int port = 8080;
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

        // Send current state on connection (including background)
        var initialPayload = {
          'config': presenterConfig.getConfig(),
          'background': backgroundService.getBackgroundConfig(),
          'type': 'text',
          'content': _currentMessage ?? 'Welcome',
          'metadata': {},
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
      _deviceIp = await _getLocalIp();
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
    var payload = {
      'config': presenterConfig.getConfig(),
      'background': backgroundService.getBackgroundConfig(),
      'imageConfig': imageService.getImageConfig(),
      'type': messageType,
      'content': message,
      'metadata': metadata,
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

  /// Get Local IP
  Future<String> _getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return 'Unknown';
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
