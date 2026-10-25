import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'server_service.dart';

/// Tracks a TV attached by HDMI / USB-C adapter or AirPlay.
///
/// The native side (`ios/Runner/ExternalDisplay.swift`,
/// `android/.../ExternalDisplayController.kt`) puts the built-in display page
/// full-screen on that screen; this service just mirrors its state into Dart
/// and starts the presenter server when a screen appears, so the TV shows
/// slides without the operator having to tap "Start Presenter" first.
///
/// Platforms without the native side (desktop, web) simply never connect.
class ExternalDisplayService extends ChangeNotifier {
  ExternalDisplayService({required ServerService serverService})
    : _serverService = serverService {
    _channel.setMethodCallHandler(_handleCall);
    _queryInitialState();
  }

  static const MethodChannel _channel = MethodChannel(
    'church_presenter/external_display',
  );

  final ServerService _serverService;
  bool _isConnected = false;

  /// Whether a TV is currently showing the live display.
  bool get isConnected => _isConnected;

  Future<void> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'connected':
        _setConnected(true);
      case 'disconnected':
        _setConnected(false);
    }
  }

  // The TV may already be attached when the app launches, before Dart was
  // listening for the "connected" event.
  Future<void> _queryInitialState() async {
    try {
      final connected = await _channel.invokeMethod<bool>('isConnected');
      _setConnected(connected ?? false);
    } on MissingPluginException {
      // No native second-screen support on this platform.
    }
  }

  void _setConnected(bool connected) {
    if (connected == _isConnected) return;
    _isConnected = connected;
    notifyListeners();
    if (connected && !_serverService.isRunning) {
      _serverService.startServer();
    }
  }
}
