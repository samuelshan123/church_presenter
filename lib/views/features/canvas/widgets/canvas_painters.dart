import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../../../models/canvas_models.dart';

/// Paints strokes from normalised coordinates onto [size].
///
/// Split from the image layer and the live-stroke layer so a [RepaintBoundary]
/// can sit between them: while a stroke is in progress only the live layer
/// repaints, not the whole accumulated drawing.
class StrokePainter extends CustomPainter {
  final List<CanvasStroke> strokes;

  const StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      paintStroke(canvas, size, stroke);
    }
  }

  /// Draws one stroke as a smooth curve.
  ///
  /// Uses [Path.quadraticBezierTo] through segment midpoints rather than
  /// straight `lineTo` segments — with `lineTo` the polyline reads as visibly
  /// jagged and faceted at projector scale.
  static void paintStroke(Canvas canvas, Size size, CanvasStroke stroke) {
    if (stroke.pointCount == 0) return;

    final paint = Paint()
      ..color = Color(stroke.color).withValues(alpha: stroke.opacity)
      ..strokeWidth = stroke.width * size.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Highlighter multiplies so overlapping passes darken like real ink rather
    // than washing out to a flat block.
    if (stroke.mode == StrokeMode.highlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    Offset scaled(int i) =>
        Offset(stroke.xAt(i) * size.width, stroke.yAt(i) * size.height);

    if (stroke.pointCount == 1) {
      canvas.drawPoints(PointMode.points, [scaled(0)], paint);
      return;
    }

    final path = Path()..moveTo(scaled(0).dx, scaled(0).dy);
    if (stroke.pointCount == 2) {
      path.lineTo(scaled(1).dx, scaled(1).dy);
    } else {
      for (var i = 1; i < stroke.pointCount - 1; i++) {
        final current = scaled(i);
        final next = scaled(i + 1);
        final midpoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          midpoint.dx,
          midpoint.dy,
        );
      }
      final last = scaled(stroke.pointCount - 1);
      path.lineTo(last.dx, last.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(StrokePainter oldDelegate) =>
      oldDelegate.strokes.length != strokes.length ||
      !identical(oldDelegate.strokes, strokes);
}

/// Paints the single in-progress stroke.
class LiveStrokePainter extends CustomPainter {
  final CanvasStroke? stroke;
  final int pointCount;

  LiveStrokePainter(this.stroke) : pointCount = stroke?.pointCount ?? 0;

  @override
  void paint(Canvas canvas, Size size) {
    final current = stroke;
    if (current != null) StrokePainter.paintStroke(canvas, size, current);
  }

  @override
  bool shouldRepaint(LiveStrokePainter oldDelegate) =>
      oldDelegate.stroke?.id != stroke?.id ||
      oldDelegate.pointCount != pointCount;
}

/// Selection handles for the image being manipulated.
///
/// Controller-only chrome — this is never part of the broadcast payload, so the
/// congregation never sees the outline or the grab handles.
class SelectionPainter extends CustomPainter {
  final CanvasImage? image;
  final Color color;

  /// Handles keep a minimum touch target regardless of image size, otherwise a
  /// small image becomes impossible to grab on a phone. Must match the hit
  /// radius used by the gesture layer.
  static const double handleRadius = 11;

  const SelectionPainter({required this.image, required this.color});

  static List<Offset> handlePositions(Rect rect) => [
    rect.topLeft,
    rect.topRight,
    rect.bottomLeft,
    rect.bottomRight,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final current = image;
    if (current == null) return;

    final rect = current.toRect(size);
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final fill = Paint()..color = Colors.white;
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final position in handlePositions(rect)) {
      canvas.drawCircle(position, handleRadius, fill);
      canvas.drawCircle(position, handleRadius, border);
    }
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) =>
      oldDelegate.image?.id != image?.id ||
      oldDelegate.image?.x != image?.x ||
      oldDelegate.image?.y != image?.y ||
      oldDelegate.image?.w != image?.w ||
      oldDelegate.image?.h != image?.h;
}
