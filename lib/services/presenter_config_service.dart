import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PresenterConfigService extends ChangeNotifier {
  static const String _keyBgColor = 'presenter_bg_color';
  static const String _keyFgColor = 'presenter_fg_color';
  static const String _keyFontSize = 'presenter_font_size';
  static const String _keyFont = 'presenter_font';

  // Default values
  String _bgColor = 'default';
  String _fgColor = 'default';
  double _fontSize = 60;
  String _font = 'default';

  String get bgColor => _bgColor;
  String get fgColor => _fgColor;
  double get fontSize => _fontSize;
  String get font => _font;

  // Helper getters for UI
  Color? get bgColorValue =>
      _bgColor == 'default' ? null : _parseColor(_bgColor);
  Color? get fgColorValue =>
      _fgColor == 'default' ? null : _parseColor(_fgColor);

  PresenterConfigService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _bgColor = prefs.getString(_keyBgColor) ?? 'default';
    _fgColor = prefs.getString(_keyFgColor) ?? 'default';
    _fontSize = prefs.getDouble(_keyFontSize) ?? _fontSize;
    _font = prefs.getString(_keyFont) ?? 'default';
    notifyListeners();
  }

  Future<void> setBgColor(String color) async {
    _bgColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBgColor, color);
    notifyListeners();
  }

  Future<void> setFgColor(String color) async {
    _fgColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFgColor, color);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, size);
    notifyListeners();
  }

  Future<void> setFont(String font) async {
    _font = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFont, font);
    notifyListeners();
  }

  // Get config map for WebSocket message
  Map<String, dynamic> getConfig() {
    return {
      'bg': _bgColor,
      'fg': _fgColor,
      'fontSize': _fontSize == 48 ? 'default' : _fontSize,
      'font': _font,
    };
  }

  Color? _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      try {
        return Color(
          int.parse(colorString.substring(1), radix: 16) + 0xFF000000,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}
