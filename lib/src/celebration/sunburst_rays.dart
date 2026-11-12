import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A soft radial glow with slowly rotating light rays. It fades in, holds,
/// then fades out over [duration]. It starts as soon as it's inserted into
/// the tree and ignores pointers.
class SunburstRays extends StatefulWidget {
  /// Creates a sunburst.
  const SunburstRays({
    super.key,
    this.duration = const Duration(milliseconds: 2500),
    this.color = const Color(0xFFFFD54F),
    this.rayCount = 14,
    this.radius,
    this.center = Alignment.center,
    this.onComplete,
  }) : assert(rayCount > 0);

  /// Total length, including the fade in and out.
  final Duration duration;

  /// Colour of the glow and rays.
  final Color color;

  /// Number of rays.
  final int rayCount;

  /// Ray length. Defaults to 60% of the shortest side.
  final double? radius;

  /// Centre of the burst within this widget.
  final Alignment center;

  /// Called once the animation has finished.
  final VoidCallback? onComplete;

  @override
  State<SunburstRays> createState() => _SunburstRaysState();
}

class _SunburstRaysState extends State<SunburstRays>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _SunburstImageCache _cache = _SunburstImageCache();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onComplete?.call();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SunburstPainter(
            progress: _controller,
            color: widget.color,
            rayCount: widget.rayCount,
            radius: widget.radius,
            center: widget.center,
            cache: _cache,
            devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
          ),
        ),
      ),
    );
  }
}

/// Holds the pre-rendered glow + rays so each frame is one rotated,
/// faded textured quad instead of two large gradient fills.
class _SunburstImageCache {
  ui.Image? image;
  double? radius;
  Color? color;
  int? rayCount;
  double? pixelRatio;

  void dispose() {
    image?.dispose();
    image = null;
  }
}

class _SunburstPainter extends CustomPainter {
  _SunburstPainter({
    required this.progress,
    required this.color,
    required this.rayCount,
    required this.radius,
    required this.center,
    required this.cache,
    required this.devicePixelRatio,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final int rayCount;
  final double? radius;
  final Alignment center;
  final _SunburstImageCache cache;
  final double devicePixelRatio;

  /// The glow is soft, so half resolution is visually identical.
  static const double _resolution = 0.5;

  /// Renders the sunburst at full opacity, centred in a 2r × 2r image.
  ui.Image _render(double r, double pixelRatio) {
    final side = (2 * r * pixelRatio).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    final c = Offset(r, r);

    canvas.drawCircle(
      c,
      r * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.75)),
    );

    final half = math.pi / rayCount * 0.45;
    final path = Path();
    for (var i = 0; i < rayCount; i++) {
      final a = i * 2 * math.pi / rayCount;
      path
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - half), c.dy + r * math.sin(a - half))
        ..lineTo(c.dx + r * math.cos(a + half), c.dy + r * math.sin(a + half))
        ..close();
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final picture = recorder.endRecording();
    final image = picture.toImageSync(side, side);
    picture.dispose();
    return image;
  }

  ui.Image _imageFor(double r) {
    final pixelRatio = devicePixelRatio * _resolution;
    final cached = cache.image;
    if (cached != null &&
        cache.radius == r &&
        cache.color == color &&
        cache.rayCount == rayCount &&
        cache.pixelRatio == pixelRatio) {
      return cached;
    }
    cache.dispose();
    cache
      ..image = _render(r, pixelRatio)
      ..radius = r
      ..color = color
      ..rayCount = rayCount
      ..pixelRatio = pixelRatio;
    return cache.image!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final v = progress.value;
    if (v <= 0 || v >= 1 || size.isEmpty) return;
    final opacity = v < 0.15
        ? v / 0.15
        : v > 0.6
            ? ((1 - v) / 0.4).clamp(0.0, 1.0)
            : 1.0;
    if (opacity <= 0) return;

    final c = center.alongSize(size);
    final r = radius ?? size.shortestSide * 0.6;
    final image = _imageFor(r);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(v * 0.9);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(center: Offset.zero, radius: r),
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, opacity)
        ..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunburstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.rayCount != rayCount ||
      oldDelegate.radius != radius ||
      oldDelegate.center != center ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
