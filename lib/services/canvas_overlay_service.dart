import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/canvas_models.dart';

/// State for the drawable canvas overlay: placed images, freehand strokes, and
/// the undo/redo timeline spanning both.
///
/// Follows the app's global-singleton-plus-[ChangeNotifier] pattern — it is
/// constructed in `main.dart` and read via provider, like the other services.
/// It deliberately knows nothing about the server; the screen owns broadcasting
/// so the service stays testable and the overlay works with the server stopped.
class CanvasOverlayService extends ChangeNotifier {
  static const int _maxUndoStack = 50;

  /// Points closer together than this (normalised) are dropped while drawing.
  /// A finger emits events far faster than the stroke actually changes shape.
  static const double _minPointDistance = 0.002;

  /// Ramer–Douglas–Peucker tolerance applied once a stroke is committed.
  static const double _simplifyTolerance = 0.0015;

  final List<CanvasImage> _images = [];
  final List<CanvasStroke> _strokes = [];
  final List<CanvasCommand> _undoStack = [];
  final List<CanvasCommand> _redoStack = [];

  CanvasStroke? _liveStroke;
  String? _selectedImageId;
  CanvasImage? _dragStartGeometry;

  DrawTool _tool = DrawTool.pen;
  Color _color = const Color(0xFFFF3B30);
  double _strokeWidth = 0.006;
  int _idCounter = 0;

  List<CanvasImage> get images => List.unmodifiable(_images);
  List<CanvasStroke> get strokes => List.unmodifiable(_strokes);

  /// The in-progress stroke, painted on a separate layer so committed strokes
  /// aren't repainted on every pointer move.
  CanvasStroke? get liveStroke => _liveStroke;

  DrawTool get tool => _tool;
  Color get color => _color;
  double get strokeWidth => _strokeWidth;
  String? get selectedImageId => _selectedImageId;
  CanvasImage? get selectedImage {
    final id = _selectedImageId;
    if (id == null) return null;
    for (final image in _images) {
      if (image.id == id) return image;
    }
    return null;
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isEmpty => _images.isEmpty && _strokes.isEmpty;

  String _nextId(String prefix) => '$prefix${_idCounter++}';

  // ---------------------------------------------------------------- tools

  void setTool(DrawTool tool) {
    if (_tool == tool) return;
    _tool = tool;
    // Selection handles are chrome for manipulating images; drop them as soon
    // as the user picks up a drawing tool so they can't be drawn around.
    _selectedImageId = null;
    notifyListeners();
  }

  void setColor(Color color) {
    _color = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width.clamp(0.002, 0.04);
    notifyListeners();
  }

  // -------------------------------------------------------------- drawing

  void startStroke(Offset normalised) {
    final mode = _tool == DrawTool.highlighter
        ? StrokeMode.highlighter
        : StrokeMode.pen;
    _liveStroke = CanvasStroke(
      id: _nextId('s'),
      points: [normalised.dx, normalised.dy],
      // ignore: deprecated_member_use — .value is still the ARGB int accessor.
      color: _color.value,
      width: _tool == DrawTool.highlighter ? _strokeWidth * 3 : _strokeWidth,
      mode: mode,
    );
    notifyListeners();
  }

  /// Returns true if the point was actually appended, so the caller knows
  /// whether it is worth streaming an update to connected displays.
  bool extendStroke(Offset normalised) {
    final stroke = _liveStroke;
    if (stroke == null) return false;

    final last = stroke.offsetAt(stroke.pointCount - 1);
    if ((normalised - last).distance < _minPointDistance) return false;

    stroke.points.addAll([normalised.dx, normalised.dy]);
    notifyListeners();
    return true;
  }

  /// Commits the live stroke. Returns the simplified stroke, or null if the
  /// gesture was too short to be a real mark (a stray tap).
  CanvasStroke? endStroke() {
    final stroke = _liveStroke;
    _liveStroke = null;
    if (stroke == null) return null;

    if (stroke.pointCount < 2) {
      // A single tap becomes a dot: duplicate the point so the painter has a
      // segment to draw, otherwise the user taps and nothing appears.
      stroke.points.addAll([stroke.xAt(0), stroke.yAt(0)]);
    }

    final simplified = stroke.copyWith(
      points: _simplify(stroke.points, _simplifyTolerance),
    );
    _strokes.add(simplified);
    _pushCommand(
      CanvasCommand(type: CanvasCommandType.addStroke, strokes: [simplified]),
    );
    notifyListeners();
    return simplified;
  }

  /// Stroke eraser: removes whole strokes intersecting [normalised]. Erasing is
  /// a list removal rather than pixel compositing, which keeps strokes as the
  /// single source of truth — so it survives a resize repaint and undoes as one
  /// step. Returns true if anything was removed.
  bool eraseAt(Offset normalised, double radius) {
    final removed = <CanvasStroke>[];
    final indices = <int>[];

    for (var i = _strokes.length - 1; i >= 0; i--) {
      if (_strokeHitTest(_strokes[i], normalised, radius)) {
        indices.insert(0, i);
        removed.insert(0, _strokes[i]);
      }
    }
    if (removed.isEmpty) return false;

    for (final index in indices.reversed) {
      _strokes.removeAt(index);
    }
    _pushCommand(
      CanvasCommand(
        type: CanvasCommandType.eraseStrokes,
        strokes: removed,
        indices: indices,
      ),
    );
    notifyListeners();
    return true;
  }

  // --------------------------------------------------------------- images

  /// Places an image centred on the canvas, sized to fit within 60% of it while
  /// preserving [aspectRatio] (width/height of the source in *canvas* units).
  CanvasImage addImage(String path, {double aspectRatio = 1.0}) {
    const maxExtent = 0.6;
    // The canvas is 16:9, so a square source must be narrower in normalised x
    // than in y to avoid arriving pre-stretched.
    final canvasRelative = aspectRatio / kCanvasAspectRatio;
    var w = maxExtent;
    var h = w / canvasRelative;
    if (h > maxExtent) {
      h = maxExtent;
      w = h * canvasRelative;
    }

    final image = CanvasImage(
      id: _nextId('i'),
      path: path,
      x: (1 - w) / 2,
      y: (1 - h) / 2,
      w: w,
      h: h,
    );
    _images.add(image);
    _selectedImageId = image.id;
    _pushCommand(
      CanvasCommand(type: CanvasCommandType.addImage, images: [image]),
    );
    notifyListeners();
    return image;
  }

  /// Topmost image containing [normalised], or null. Iterates back-to-front so
  /// the visually-topmost image wins a tap.
  CanvasImage? imageAt(Offset normalised) {
    for (var i = _images.length - 1; i >= 0; i--) {
      if (_images[i].contains(normalised)) return _images[i];
    }
    return null;
  }

  void selectImage(String? id) {
    if (_selectedImageId == id) return;
    _selectedImageId = id;
    notifyListeners();
  }

  /// Records geometry at drag start so the whole drag collapses into a single
  /// undo entry instead of one per pointer move.
  void beginTransform() {
    _dragStartGeometry = selectedImage;
  }

  void updateTransform({double? x, double? y, double? w, double? h}) {
    final current = selectedImage;
    if (current == null) return;
    final index = _images.indexWhere((i) => i.id == current.id);
    if (index == -1) return;

    // Keep images from being resized to nothing or dragged fully off-canvas.
    final newW = (w ?? current.w).clamp(0.05, 4.0);
    final newH = (h ?? current.h).clamp(0.05, 4.0);
    _images[index] = current.copyWith(
      x: (x ?? current.x).clamp(-newW + 0.05, 0.95),
      y: (y ?? current.y).clamp(-newH + 0.05, 0.95),
      w: newW,
      h: newH,
    );
    notifyListeners();
  }

  /// Returns true if the transform actually changed anything worth broadcasting.
  bool endTransform() {
    final before = _dragStartGeometry;
    _dragStartGeometry = null;
    final after = selectedImage;
    if (before == null || after == null || before.id != after.id) return false;
    if (before.x == after.x &&
        before.y == after.y &&
        before.w == after.w &&
        before.h == after.h) {
      return false;
    }

    _pushCommand(
      CanvasCommand(
        type: CanvasCommandType.transformImage,
        before: before,
        after: after,
      ),
    );
    return true;
  }

  void deleteSelectedImage() {
    final image = selectedImage;
    if (image == null) return;
    final index = _images.indexWhere((i) => i.id == image.id);
    if (index == -1) return;

    _images.removeAt(index);
    _selectedImageId = null;
    _pushCommand(
      CanvasCommand(
        type: CanvasCommandType.deleteImage,
        images: [image],
        indices: [index],
      ),
    );
    notifyListeners();
  }

  void bringSelectedToFront() {
    final image = selectedImage;
    if (image == null) return;
    final index = _images.indexWhere((i) => i.id == image.id);
    if (index == -1 || index == _images.length - 1) return;

    _images.removeAt(index);
    _images.add(image);
    // Z-order changes are intentionally not undoable — they are trivially
    // reversible by hand and would otherwise clutter the timeline.
    notifyListeners();
  }

  // ------------------------------------------------------- undo / redo

  void _pushCommand(CanvasCommand command) {
    _undoStack.add(command);
    if (_undoStack.length > _maxUndoStack) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final command = _undoStack.removeLast();

    switch (command.type) {
      case CanvasCommandType.addStroke:
        _strokes.removeWhere((s) => s.id == command.strokes.first.id);
      case CanvasCommandType.addImage:
        _images.removeWhere((i) => i.id == command.images.first.id);
        if (_selectedImageId == command.images.first.id) {
          _selectedImageId = null;
        }
      case CanvasCommandType.transformImage:
        _replaceImage(command.before!);
      case CanvasCommandType.deleteImage:
        _images.insert(
          command.indices.first.clamp(0, _images.length),
          command.images.first,
        );
      case CanvasCommandType.eraseStrokes:
        for (var i = 0; i < command.strokes.length; i++) {
          _strokes.insert(
            command.indices[i].clamp(0, _strokes.length),
            command.strokes[i],
          );
        }
      case CanvasCommandType.clear:
        _images.addAll(command.images);
        _strokes.addAll(command.strokes);
    }

    _redoStack.add(command);
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final command = _redoStack.removeLast();

    switch (command.type) {
      case CanvasCommandType.addStroke:
        _strokes.add(command.strokes.first);
      case CanvasCommandType.addImage:
        _images.add(command.images.first);
      case CanvasCommandType.transformImage:
        _replaceImage(command.after!);
      case CanvasCommandType.deleteImage:
        _images.removeWhere((i) => i.id == command.images.first.id);
      case CanvasCommandType.eraseStrokes:
        final ids = command.strokes.map((s) => s.id).toSet();
        _strokes.removeWhere((s) => ids.contains(s.id));
      case CanvasCommandType.clear:
        _images.clear();
        _strokes.clear();
        _selectedImageId = null;
    }

    _undoStack.add(command);
    notifyListeners();
  }

  void _replaceImage(CanvasImage image) {
    final index = _images.indexWhere((i) => i.id == image.id);
    if (index != -1) _images[index] = image;
  }

  void clear() {
    if (isEmpty) return;
    _pushCommand(
      CanvasCommand(
        type: CanvasCommandType.clear,
        images: List.of(_images),
        strokes: List.of(_strokes),
      ),
    );
    _images.clear();
    _strokes.clear();
    _liveStroke = null;
    _selectedImageId = null;
    notifyListeners();
  }

  /// Wipes everything including history — used when leaving the canvas screen
  /// so a new service doesn't inherit a stale timeline.
  void reset() {
    _images.clear();
    _strokes.clear();
    _undoStack.clear();
    _redoStack.clear();
    _liveStroke = null;
    _selectedImageId = null;
    notifyListeners();
  }

  // ------------------------------------------------------------- payload

  /// The wire format consumed by `index.html` and the in-app presenter.
  ///
  /// [includeLive] appends the in-progress stroke so displays can follow the
  /// line as it is being drawn. Selection state is deliberately excluded —
  /// handles are controller-only chrome the congregation must never see.
  Map<String, dynamic> toPayload({bool includeLive = false}) {
    final all = [
      ..._strokes,
      if (includeLive && _liveStroke != null && _liveStroke!.pointCount > 1)
        _liveStroke!,
    ];
    return {
      'aspect': kCanvasAspectRatio,
      'images': _images.map((i) => i.toJson()).toList(),
      'strokes': all.map((s) => s.toJson()).toList(),
    };
  }

  // -------------------------------------------------------------- helpers

  /// Distance from [point] to any segment of [stroke], within [radius].
  bool _strokeHitTest(CanvasStroke stroke, Offset point, double radius) {
    final threshold = radius + stroke.width / 2;
    for (var i = 0; i < stroke.pointCount - 1; i++) {
      if (_distanceToSegment(
            point,
            stroke.offsetAt(i),
            stroke.offsetAt(i + 1),
          ) <
          threshold) {
        return true;
      }
    }
    // A dot-stroke has a single distinct point; test it directly.
    return stroke.pointCount == 1 &&
        (point - stroke.offsetAt(0)).distance < threshold;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return (p - a).distance;

    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }

  /// Ramer–Douglas–Peucker. A finished stroke typically drops 60–80% of its
  /// points with no visible change, which keeps the broadcast payload small.
  List<double> _simplify(List<double> points, double tolerance) {
    final count = points.length ~/ 2;
    if (count < 3) return List.of(points);

    final keep = List<bool>.filled(count, false);
    keep[0] = true;
    keep[count - 1] = true;
    _rdp(points, 0, count - 1, tolerance, keep);

    final result = <double>[];
    for (var i = 0; i < count; i++) {
      if (keep[i]) result.addAll([points[i * 2], points[i * 2 + 1]]);
    }
    return result;
  }

  void _rdp(
    List<double> points,
    int first,
    int last,
    double tolerance,
    List<bool> keep,
  ) {
    if (last <= first + 1) return;

    final a = Offset(points[first * 2], points[first * 2 + 1]);
    final b = Offset(points[last * 2], points[last * 2 + 1]);

    var maxDistance = 0.0;
    var index = first;
    for (var i = first + 1; i < last; i++) {
      final distance = _distanceToSegment(
        Offset(points[i * 2], points[i * 2 + 1]),
        a,
        b,
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }

    if (maxDistance > tolerance) {
      keep[index] = true;
      _rdp(points, first, index, tolerance, keep);
      _rdp(points, index, last, tolerance, keep);
    }
  }

  /// Largest square-ish canvas of [kCanvasAspectRatio] fitting inside [size].
  /// Letterboxing the controller means the user draws in a box shaped exactly
  /// like the projector, so normalised coordinates never stretch.
  static Rect letterbox(Size size) {
    final width = math.min(size.width, size.height * kCanvasAspectRatio);
    final height = width / kCanvasAspectRatio;
    return Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
  }
}
