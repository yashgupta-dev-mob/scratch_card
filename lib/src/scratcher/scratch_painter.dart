import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The user's scratch strokes, as a [Listenable] so only the paint step
/// reruns when they change. No widget rebuilds are needed.
///
/// Only the strokes added since the last bake are kept as vectors. Older
/// strokes are flattened into a mask image by [RenderScratchLayer], so the
/// cost of painting a frame stays flat however long the user scratches.
class ScratchPath extends ChangeNotifier {
  Path _path = Path();
  final List<Offset> _dots = <Offset>[];
  int _pendingSegments = 0;
  Offset? _penPosition;
  int _generation = 0;
  bool _hasAny = false;

  /// Strokes added since the last bake.
  Path get path => _path;

  /// Start points of strokes added since the last bake, painted as filled
  /// circles so a single tap also clears a round spot.
  List<Offset> get dots => _dots;

  /// Number of segments and dots added since the last bake.
  int get pendingCount => _pendingSegments + _dots.length;

  /// Whether there are strokes that haven't been baked yet.
  bool get hasPending => pendingCount > 0;

  /// Whether anything has been scratched (baked or not).
  bool get isEmpty => !_hasAny;

  /// Bumped by [clear]. A baked mask from an older generation is stale.
  int get generation => _generation;

  /// Starts a new stroke at [point].
  void moveTo(Offset point) {
    _path.moveTo(point.dx, point.dy);
    _dots.add(point);
    _penPosition = point;
    _hasAny = true;
    notifyListeners();
  }

  /// Extends the current stroke to [point].
  void lineTo(Offset point) {
    _path.lineTo(point.dx, point.dy);
    _pendingSegments++;
    _penPosition = point;
    _hasAny = true;
    notifyListeners();
  }

  /// Removes all strokes.
  void clear() {
    _path = Path();
    _dots.clear();
    _pendingSegments = 0;
    _penPosition = null;
    _hasAny = false;
    _generation++;
    notifyListeners();
  }

  /// Drops the pending strokes after they were baked into the mask. The
  /// current stroke continues from the pen position, so the next [lineTo]
  /// stays connected. Doesn't notify: it's called during paint.
  void _markBaked() {
    _path = Path();
    final pen = _penPosition;
    if (pen != null) _path.moveTo(pen.dx, pen.dy);
    _dots.clear();
    _pendingSegments = 0;
  }
}

/// Paints [child] and then erases the [scratchPath] out of it with
/// [BlendMode.clear], inside a single `saveLayer`.
///
/// The child must not create compositing layers (no `Opacity`,
/// `RepaintBoundary`, platform views, etc.). Gradients, text, icons,
/// decorations, custom painters and `SnapshotWidget` are fine.
class ScratchLayer extends SingleChildRenderObjectWidget {
  /// Creates a scratch layer.
  const ScratchLayer({
    super.key,
    required this.scratchPath,
    required this.brushSize,
    super.child,
  });

  /// The strokes to erase.
  final ScratchPath scratchPath;

  /// Stroke width of the eraser.
  final double brushSize;

  @override
  RenderScratchLayer createRenderObject(BuildContext context) =>
      RenderScratchLayer(
        scratchPath: scratchPath,
        brushSize: brushSize,
        devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderScratchLayer renderObject,
  ) {
    renderObject
      ..scratchPath = scratchPath
      ..brushSize = brushSize
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
  }
}

/// Render object behind [ScratchLayer].
class RenderScratchLayer extends RenderProxyBox {
  /// Creates the render object.
  RenderScratchLayer({
    required this._scratchPath,
    required this._brushSize,
    this._devicePixelRatio = 1,
  });

  /// Pending segments before they are flattened into the mask. Low enough
  /// that the vector path stays cheap to tessellate, high enough that baking
  /// (one offscreen draw) happens only every few frames.
  static const int bakeThreshold = 48;

  ScratchPath _scratchPath;

  /// The strokes to erase.
  ScratchPath get scratchPath => _scratchPath;
  set scratchPath(ScratchPath value) {
    if (identical(value, _scratchPath)) return;
    if (attached) {
      _scratchPath.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _scratchPath = value;
    _disposeMask();
    markNeedsPaint();
  }

  double _brushSize;

  /// Stroke width of the eraser.
  double get brushSize => _brushSize;
  set brushSize(double value) {
    if (value == _brushSize) return;
    _brushSize = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  /// Resolution of the baked mask, in physical pixels per logical pixel.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    // The old mask is still correct, just at another resolution; it is
    // stretched until the next bake replaces it.
    markNeedsPaint();
  }

  /// Everything erased before the pending strokes, as an alpha mask in
  /// physical pixels. Opaque where the cover has been scratched away.
  ui.Image? _mask;
  int _maskGeneration = -1;

  bool _warnedAboutCompositing = false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scratchPath.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scratchPath.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _disposeMask();
    super.dispose();
  }

  void _disposeMask() {
    _mask?.dispose();
    _mask = null;
    _maskGeneration = -1;
  }

  Paint _strokePaint(BlendMode blendMode) => Paint()
    ..blendMode = blendMode
    ..style = PaintingStyle.stroke
    ..strokeWidth = _brushSize
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _dotPaint(BlendMode blendMode) => Paint()
    ..blendMode = blendMode
    ..style = PaintingStyle.fill;

  void _drawPending(Canvas canvas, BlendMode blendMode) {
    if (_scratchPath._pendingSegments > 0) {
      canvas.drawPath(_scratchPath.path, _strokePaint(blendMode));
    }
    final dot = _dotPaint(blendMode);
    for (final point in _scratchPath.dots) {
      canvas.drawCircle(point, _brushSize / 2, dot);
    }
  }

  /// Flattens the previous mask plus the pending strokes into a new mask.
  void _bake() {
    final width = (size.width * _devicePixelRatio).ceil();
    final height = (size.height * _devicePixelRatio).ceil();
    if (width <= 0 || height <= 0) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final previous = _mask;
    if (previous != null) {
      canvas.drawImageRect(
        previous,
        Rect.fromLTWH(
          0,
          0,
          previous.width.toDouble(),
          previous.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint(),
      );
    }
    canvas.scale(_devicePixelRatio);
    _drawPending(canvas, BlendMode.srcOver);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();

    previous?.dispose();
    _mask = image;
    _maskGeneration = _scratchPath.generation;
    _scratchPath._markBaked();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    if (child.needsCompositing) {
      // A composited child paints into its own layer, which can't be erased
      // from here. Fall back to painting it untouched.
      assert(() {
        if (!_warnedAboutCompositing) {
          _warnedAboutCompositing = true;
          debugPrint(
            'ScratchLayer: the cover widget needs compositing (it contains '
            'Opacity, RepaintBoundary, a platform view or similar), so it '
            'cannot be scratched. Remove those widgets from the cover.',
          );
        }
        return true;
      }());
      context.paintChild(child, offset);
      return;
    }

    if (_maskGeneration != _scratchPath.generation) _disposeMask();
    final mask = _mask;

    // Nothing scratched yet: no need for an offscreen layer at all.
    if (mask == null && !_scratchPath.hasPending) {
      context.paintChild(child, offset);
      return;
    }

    final bounds = offset & size;
    final canvas = context.canvas;
    canvas.saveLayer(bounds, Paint());
    context.paintChild(child, offset);
    assert(identical(canvas, context.canvas));

    if (mask != null) {
      // Erase everything baked so far in one textured draw.
      canvas.drawImageRect(
        mask,
        Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
        bounds,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..filterQuality = FilterQuality.low,
      );
    }
    if (_scratchPath.hasPending) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      _drawPending(canvas, BlendMode.clear);
      canvas.restore();
    }
    canvas.restore();

    if (_scratchPath.pendingCount >= bakeThreshold) _bake();
  }
}
