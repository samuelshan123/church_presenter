import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../models/canvas_models.dart';
import '../../../../services/canvas_overlay_service.dart';
import '../../../../services/image_compression_service.dart';
import '../../../../services/server_service.dart';
import '../widgets/canvas_painters.dart';
import '../widgets/canvas_toolbar.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/app_icon.dart';

/// Which part of a selected image the current drag is manipulating.
enum _DragMode {
  none,
  move,
  resizeTopLeft,
  resizeTopRight,
  resizeBottomLeft,
  resizeBottomRight,
}

/// The drawable canvas: place images, draw over them, erase, undo, and broadcast
/// the result to every connected display.
///
/// Coordinates are normalised in [CanvasOverlayService]; this screen owns the
/// pixel↔normalised conversion via a letterboxed [Rect] matching the display's
/// aspect ratio, so what the user draws is exactly what the projector shows.
class CanvasScreen extends StatefulWidget {
  final ServerService serverService;

  const CanvasScreen({super.key, required this.serverService});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  /// Broadcast cadence while a stroke is in progress. A finger emits pointer
  /// events at 60–120Hz; sending each one floods the socket for no visible
  /// gain, so points are batched and flushed at ~30Hz.
  static const Duration _streamInterval = Duration(milliseconds: 33);

  final CanvasOverlayService _canvas = CanvasOverlayService();
  final ImageCompressionService _compressor = ImageCompressionService();

  Timer? _streamTimer;
  bool _pendingStream = false;
  bool _isLive = false;

  _DragMode _dragMode = _DragMode.none;
  Rect _canvasRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _canvas.addListener(_onCanvasChanged);
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _canvas.removeListener(_onCanvasChanged);
    // Leaving the screen must not leave a drawing stuck on the projector.
    if (_isLive) widget.serverService.sendOverlay(null);
    _canvas.dispose();
    super.dispose();
  }

  void _onCanvasChanged() => setState(() {});

  // ------------------------------------------------------------ broadcast

  /// Push the current canvas to displays. [live] includes the in-progress
  /// stroke so the audience follows the line as it is drawn.
  void _broadcast({bool live = false}) {
    if (!_isLive) return;
    widget.serverService.sendOverlay(_canvas.toPayload(includeLive: live));
  }

  /// Coalesces high-frequency updates onto a timer rather than sending per
  /// pointer event.
  void _scheduleStream() {
    if (!_isLive) return;
    _pendingStream = true;
    _streamTimer ??= Timer.periodic(_streamInterval, (_) {
      if (!_pendingStream) return;
      _pendingStream = false;
      _broadcast(live: true);
    });
  }

  void _stopStreaming() {
    _streamTimer?.cancel();
    _streamTimer = null;
    _pendingStream = false;
  }

  void _toggleLive() {
    if (!widget.serverService.isRunning) {
      _showSnack('Start the server first to present the canvas.');
      return;
    }
    setState(() => _isLive = !_isLive);
    if (_isLive) {
      _broadcast();
    } else {
      _stopStreaming();
      widget.serverService.sendOverlay(null);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------- gestures

  /// Pixel → normalised, relative to the letterboxed canvas.
  Offset _normalise(Offset local) => Offset(
    (local.dx - _canvasRect.left) / _canvasRect.width,
    (local.dy - _canvasRect.top) / _canvasRect.height,
  );

  bool _withinCanvas(Offset local) => _canvasRect.contains(local);

  void _onPointerDown(PointerDownEvent event) {
    final local = event.localPosition;
    if (!_withinCanvas(local)) return;
    final point = _normalise(local);

    switch (_canvas.tool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _canvas.startStroke(point);
      case DrawTool.eraser:
        if (_canvas.eraseAt(point, _eraserRadius)) _scheduleStream();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final local = event.localPosition;
    final point = _normalise(local);

    switch (_canvas.tool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        if (_canvas.extendStroke(point)) _scheduleStream();
      case DrawTool.eraser:
        if (_canvas.eraseAt(point, _eraserRadius)) _scheduleStream();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    switch (_canvas.tool) {
      case DrawTool.pen:
      case DrawTool.highlighter:
        _canvas.endStroke();
        _stopStreaming();
        _broadcast();
      case DrawTool.eraser:
        _stopStreaming();
        _broadcast();
    }
  }

  /// Eraser radius in normalised units, matched to a comfortable finger target.
  double get _eraserRadius => 0.02;

  // --------------------------------------------------- image manipulation

  void _onSelectDown(DragStartDetails details) {
    final local = details.localPosition;
    if (!_withinCanvas(local)) return;
    final point = _normalise(local);

    // Handles first: they extend outside the image bounds, and a corner grab
    // must win over a body drag where the two overlap.
    final selected = _canvas.selectedImage;
    if (selected != null) {
      final mode = _handleAt(selected, local);
      if (mode != _DragMode.none) {
        _dragMode = mode;
        _canvas.beginTransform();
        return;
      }
    }

    final hit = _canvas.imageAt(point);
    _canvas.selectImage(hit?.id);
    if (hit != null) {
      _dragMode = _DragMode.move;
      _canvas.beginTransform();
    } else {
      _dragMode = _DragMode.none;
    }
  }

  /// Which corner handle (if any) sits under [local]. Uses a fixed pixel radius
  /// so handles stay grabbable on small images.
  _DragMode _handleAt(CanvasImage image, Offset local) {
    final rect = image.toRect(_canvasRect.size).shift(_canvasRect.topLeft);
    const modes = [
      _DragMode.resizeTopLeft,
      _DragMode.resizeTopRight,
      _DragMode.resizeBottomLeft,
      _DragMode.resizeBottomRight,
    ];
    final positions = SelectionPainter.handlePositions(rect);

    for (var i = 0; i < positions.length; i++) {
      if ((local - positions[i]).distance <=
          SelectionPainter.handleRadius * 2) {
        return modes[i];
      }
    }
    return _DragMode.none;
  }

  void _onSelectUpdate(DragUpdateDetails details) {
    final image = _canvas.selectedImage;
    if (image == null || _dragMode == _DragMode.none) return;

    final dx = details.delta.dx / _canvasRect.width;
    final dy = details.delta.dy / _canvasRect.height;

    switch (_dragMode) {
      case _DragMode.move:
        _canvas.updateTransform(x: image.x + dx, y: image.y + dy);
      case _DragMode.resizeBottomRight:
        _canvas.updateTransform(w: image.w + dx, h: image.h + dy);
      case _DragMode.resizeBottomLeft:
        _canvas.updateTransform(
          x: image.x + dx,
          w: image.w - dx,
          h: image.h + dy,
        );
      case _DragMode.resizeTopRight:
        _canvas.updateTransform(
          y: image.y + dy,
          w: image.w + dx,
          h: image.h - dy,
        );
      case _DragMode.resizeTopLeft:
        _canvas.updateTransform(
          x: image.x + dx,
          y: image.y + dy,
          w: image.w - dx,
          h: image.h - dy,
        );
      case _DragMode.none:
        break;
    }
    _scheduleStream();
  }

  void _onSelectEnd(DragEndDetails details) {
    _dragMode = _DragMode.none;
    _stopStreaming();
    // Commit as one undo entry for the whole drag, then send final geometry.
    if (_canvas.endTransform()) _broadcast();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Downscale before use: every connected display fetches this file over the
    // LAN, so a full-resolution phone photo would be re-sent to each of them.
    final file = await _compressor.compress(
      File(picked.path),
      subdirectory: 'canvas_images',
    );

    // Resolve the source aspect ratio before placing, so the image arrives
    // correctly proportioned instead of being squashed into a default box.
    final decoded = await decodeImageFromList(await file.readAsBytes());
    final aspect = decoded.width / decoded.height;

    if (!mounted) return;
    _canvas.setTool(DrawTool.pen);
    _canvas.addImage(file.path, aspectRatio: aspect);
    setState(() => _selecting = true);
    _broadcast();
  }

  /// True when the user is manipulating images rather than drawing.
  bool _selecting = false;

  void _setSelecting(bool value) {
    setState(() => _selecting = value);
    if (!value) _canvas.selectImage(null);
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChangeNotifierProvider.value(
      value: _canvas,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Canvas'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _toggleLive,
                icon: AppIcon(
                  _isLive
                      ? HugeIcons.strokeRoundedMonitorDot
                      : HugeIcons.strokeRoundedComputerScreenShare,
                  size: 18,
                ),
                label: Text(_isLive ? 'Live' : 'Present'),
                style: FilledButton.styleFrom(
                  backgroundColor: _isLive ? colorScheme.primary : null,
                  foregroundColor: _isLive ? colorScheme.onPrimary : null,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    // Letterbox to the display aspect ratio so the user draws
                    // inside a box shaped exactly like the projector output.
                    _canvasRect = CanvasOverlayService.letterbox(size);
                    return _buildCanvas();
                  },
                ),
              ),
            ),
            CanvasToolbar(
              canvas: _canvas,
              selecting: _selecting,
              onSelectingChanged: _setSelecting,
              onAddImage: _pickImage,
              onChanged: _broadcast,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final content = Stack(
      children: [
        // Black canvas body — matches what the display shows behind the strokes.
        Positioned.fromRect(
          rect: _canvasRect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ),

        // Images, painted bottom-up in list order.
        for (final image in _canvas.images)
          Positioned.fromRect(
            rect: image.toRect(_canvasRect.size).shift(_canvasRect.topLeft),
            child: Image.file(
              File(image.path),
              fit: BoxFit.fill,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.white12,
                child: Center(
                  child: AppIcon(
                    HugeIcons.strokeRoundedAlbumNotFound01,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),

        // Committed strokes. Isolated behind a RepaintBoundary so the live
        // stroke above can repaint every frame without redrawing all history.
        Positioned.fromRect(
          rect: _canvasRect,
          child: RepaintBoundary(
            child: CustomPaint(
              size: _canvasRect.size,
              painter: StrokePainter(_canvas.strokes),
            ),
          ),
        ),

        Positioned.fromRect(
          rect: _canvasRect,
          child: CustomPaint(
            size: _canvasRect.size,
            painter: LiveStrokePainter(_canvas.liveStroke),
          ),
        ),

        // Selection chrome — controller only, never broadcast.
        if (_selecting)
          Positioned.fromRect(
            rect: _canvasRect,
            child: CustomPaint(
              size: _canvasRect.size,
              painter: SelectionPainter(
                image: _canvas.selectedImage,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );

    // Two distinct input modes: GestureDetector for image manipulation (it
    // needs drag semantics), and a raw Listener for drawing — Listener skips
    // the gesture arena, so strokes start on contact with no recognition delay.
    if (_selecting) {
      return GestureDetector(
        onPanStart: _onSelectDown,
        onPanUpdate: _onSelectUpdate,
        onPanEnd: _onSelectEnd,
        child: content,
      );
    }

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: content,
    );
  }
}
