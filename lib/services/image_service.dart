import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

enum ImageDisplayMode {
  cover('Cover (Fill Screen)'),
  contain('Fit (Original Ratio)'),
  fill('Stretch (Fill)'),
  original('Original Size');

  final String label;
  const ImageDisplayMode(this.label);
}

class ImageService extends ChangeNotifier {
  static const String _keyDisplayMode = 'image_display_mode';
  static const String _keyZoomLevel = 'image_zoom_level';

  final List<String> _images = [];
  String? _currentImagePath;
  ImageDisplayMode _displayMode = ImageDisplayMode.contain;
  double _zoomLevel = 1.0;

  List<String> get images => List.unmodifiable(_images);
  String? get currentImagePath => _currentImagePath;
  bool get hasCurrentImage => _currentImagePath != null;
  ImageDisplayMode get displayMode => _displayMode;
  double get zoomLevel => _zoomLevel;

  ImageService() {
    _loadImages();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_keyDisplayMode) ?? 1; // default to contain
    _displayMode = ImageDisplayMode.values[modeIndex];
    _zoomLevel = prefs.getDouble(_keyZoomLevel) ?? 1.0;
    notifyListeners();
  }

  Future<void> _loadImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(
        path.join(appDir.path, 'presentation_images'),
      );

      if (await imagesDir.exists()) {
        final files = imagesDir.listSync();
        _images.clear();
        for (var file in files) {
          if (file is File && _isImageFile(file.path)) {
            _images.add(file.path);
          }
        }
        _images.sort((a, b) => b.compareTo(a)); // Most recent first
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error loading images: $e');
    }
  }

  bool _isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
  }

  Future<String?> addImage(File imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(
        path.join(appDir.path, 'presentation_images'),
      );

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          'image_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final savedPath = path.join(imagesDir.path, fileName);

      await imageFile.copy(savedPath);
      _images.insert(0, savedPath);
      notifyListeners();

      return savedPath;
    } catch (e) {
      print('❌ Error adding image: $e');
      return null;
    }
  }

  Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
      _images.remove(imagePath);
      if (_currentImagePath == imagePath) {
        _currentImagePath = null;
      }
      notifyListeners();
    } catch (e) {
      print('❌ Error deleting image: $e');
    }
  }

  void setCurrentImage(String? imagePath) {
    _currentImagePath = imagePath;
    notifyListeners();
  }

  void clearCurrentImage() {
    _currentImagePath = null;
    notifyListeners();
  }

  Future<void> setDisplayMode(ImageDisplayMode mode) async {
    _displayMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDisplayMode, mode.index);
    notifyListeners();
  }

  Future<void> setZoomLevel(double zoom) async {
    _zoomLevel = zoom.clamp(0.5, 3.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyZoomLevel, _zoomLevel);
    notifyListeners();
  }

  void zoomIn() {
    setZoomLevel(_zoomLevel + 0.1);
  }

  void zoomOut() {
    setZoomLevel(_zoomLevel - 0.1);
  }

  void resetZoom() {
    setZoomLevel(1.0);
  }

  Map<String, dynamic> getImageConfig() {
    return {'displayMode': _displayMode.name, 'zoomLevel': _zoomLevel};
  }
}
