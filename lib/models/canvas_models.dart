import 'dart:ui';

/// Canvas overlay data model.
///
/// Every coordinate in this file is **normalised**: `0.0`–`1.0` as a fraction of
/// the canvas width/height rather than a pixel value. The controller may be a
/// phone and the display a 4K projector, so pixels are meaningless across the
/// wire — the receiver multiplies by its own canvas size on replay. Stroke width
/// is normalised against width alone so line weight scales with the surface too.
///
/// The controller draw surface is letterboxed to [kCanvasAspectRatio] so the
/// user always draws inside a box shaped exactly like what the audience sees.
/// Without that, a 4:3 controller drawing on a 16:9 display would stretch.
const double kCanvasAspectRatio = 16 / 9;

enum DrawTool { pen, highlighter, eraser }

/// How a stroke is composited. The eraser is a *data* operation (it removes
/// whole strokes from the list) rather than a pixel operation, so it survives
/// repaints on resize and undoes cleanly. See [CanvasOverlayService.eraseAt].
enum StrokeMode {
  pen,
  highlighter;

  static StrokeMode fromName(String? name) =>
      StrokeMode.values.firstWhere((m) => m.name == name, orElse: () => pen);
}

/// A single freehand stroke, stored as a flat `[x1,y1,x2,y2,...]` list. Flat
/// doubles rather than point objects roughly halves the JSON payload, which
/// matters because strokes are broadcast while the finger is still moving.
class CanvasStroke {
  final String id;
  final List<double> points;
  final int color;
  final double width;
  final StrokeMode mode;

  const CanvasStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
    required this.mode,
  });

  CanvasStroke copyWith({List<double>? points}) => CanvasStroke(
    id: id,
    points: points ?? this.points,
    color: color,
    width: width,
    mode: mode,
  );

  int get pointCount => points.length ~/ 2;
  double xAt(int i) => points[i * 2];
  double yAt(int i) => points[i * 2 + 1];
  Offset offsetAt(int i) => Offset(points[i * 2], points[i * 2 + 1]);

  /// Hex `#rrggbb` — the HTML client wants a CSS colour, not an ARGB int.
  String get cssColor =>
      '#${(color & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';

  double get opacity =>
      mode == StrokeMode.highlighter ? 0.4 : ((color >> 24) & 0xFF) / 255.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': points,
    'color': cssColor,
    'width': width,
    'mode': mode.name,
    'opacity': opacity,
  };

  factory CanvasStroke.fromJson(Map<String, dynamic> json) => CanvasStroke(
    id: json['id'] as String,
    points: (json['points'] as List).map((e) => (e as num).toDouble()).toList(),
    color: json['argb'] as int? ?? 0xFFFFFFFF,
    width: (json['width'] as num).toDouble(),
    mode: StrokeMode.fromName(json['mode'] as String?),
  );
}

/// An image placed on the canvas. Geometry is normalised like strokes.
///
/// [path] is the controller's local file path; it is never readable by the
/// browser, so [toJson] emits a `/api/image/<encoded>` URL that the existing
/// shelf route already serves. Keeping the raw path out of the payload also
/// avoids leaking the device's directory layout to every display client.
class CanvasImage {
  final String id;
  final String path;
  final double x;
  final double y;
  final double w;
  final double h;

  const CanvasImage({
    required this.id,
    required this.path,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  CanvasImage copyWith({double? x, double? y, double? w, double? h}) =>
      CanvasImage(
        id: id,
        path: path,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
      );

  Rect toRect(Size size) => Rect.fromLTWH(
    x * size.width,
    y * size.height,
    w * size.width,
    h * size.height,
  );

  bool contains(Offset normalised) =>
      normalised.dx >= x &&
      normalised.dx <= x + w &&
      normalised.dy >= y &&
      normalised.dy <= y + h;

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': '/api/image/${Uri.encodeComponent(path)}',
    'x': x,
    'y': y,
    'w': w,
    'h': h,
  };
}

/// A reversible edit. Undo/redo spans strokes *and* images in one interleaved
/// timeline, so "pop the last stroke" is not enough — each command carries the
/// state needed to invert it. Drags are coalesced into a single [transformImage]
/// on pointer-up rather than one command per move event.
enum CanvasCommandType {
  addStroke,
  addImage,
  transformImage,
  deleteImage,
  eraseStrokes,
  clear,
}

class CanvasCommand {
  final CanvasCommandType type;

  /// Objects removed by this command, kept so undo can restore them.
  final List<CanvasStroke> strokes;
  final List<CanvasImage> images;

  /// Index each removed object occupied, so undo restores z-order exactly.
  final List<int> indices;

  /// Geometry before/after for [CanvasCommandType.transformImage].
  final CanvasImage? before;
  final CanvasImage? after;

  const CanvasCommand({
    required this.type,
    this.strokes = const [],
    this.images = const [],
    this.indices = const [],
    this.before,
    this.after,
  });
}
