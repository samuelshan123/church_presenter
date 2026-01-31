import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

enum DisplayType {
  fullscreen('Fullscreen'),
  portrait('Portrait'),
  landscape('Landscape');

  final String label;
  const DisplayType(this.label);
}

class BackgroundService extends ChangeNotifier {
  static const String _keyImagePath = 'background_image_path';
  static const String _keyDisplayType = 'background_display_type';

  String? _imagePath;
  DisplayType _displayType = DisplayType.fullscreen;

  String? get imagePath => _imagePath;
  DisplayType get displayType => _displayType;
  bool get hasImage => _imagePath != null && _imagePath!.isNotEmpty;

  BackgroundService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _imagePath = prefs.getString(_keyImagePath);
    final displayTypeIndex = prefs.getInt(_keyDisplayType) ?? 0;
    _displayType = DisplayType.values[displayTypeIndex];
    notifyListeners();
  }

  Future<String?> saveImage(File imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backgroundsDir = Directory(path.join(appDir.path, 'backgrounds'));

      if (!await backgroundsDir.exists()) {
        await backgroundsDir.create(recursive: true);
      }

      final fileName =
          'background_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final savedPath = path.join(backgroundsDir.path, fileName);

      await imageFile.copy(savedPath);

      // Delete old image if exists
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        final oldFile = File(_imagePath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      _imagePath = savedPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyImagePath, savedPath);
      notifyListeners();

      return savedPath;
    } catch (e) {
      print('❌ Error saving background image: $e');
      return null;
    }
  }

  Future<void> clearImage() async {
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      final file = File(_imagePath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          print('❌ Error deleting background image: $e');
        }
      }
    }

    _imagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyImagePath);
    notifyListeners();
  }

  Future<void> setDisplayType(DisplayType type) async {
    _displayType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDisplayType, type.index);
    notifyListeners();
  }

  Map<String, dynamic> getBackgroundConfig() {
    return {'imagePath': _imagePath, 'displayType': _displayType.name};
  }
}
