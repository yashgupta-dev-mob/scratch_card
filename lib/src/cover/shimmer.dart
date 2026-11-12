import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

/// Paints a diagonal gloss band that sweeps across the canvas.
///
/// The band sweeps while [animation] is between 0 and [sweepPortion], and
/// nothing is drawn for the rest of the cycle. With a repeating animation and
/// `sweepPortion: 0.35`, the gloss passes about once per cycle with a pause
/// in between. Use `sweepPortion: 1` for a continuous shimmer.
class ShimmerPainter extends CustomPainter {
  /// Creates a shimmer painter that repaints whenever [animation] ticks.
  ShimmerPainter({
    required this.animation,
    this.sweepPortion = 0.35,
    this.color = const Color(0x47FFFFFF),
  }) : super(repaint: animation);

  /// Drives the sweep. Expected to run from 0 to 1, usually repeating.
  final Animation<double> animation;

  /// Fraction of each cycle during which the band is visible.
  final double sweepPortion;

  /// Peak colour of the gloss band.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final v = animation.value;
    // At 0 (stopped/reset) and from sweepPortion on, the band is off the card.
    if (size.isEmpty || sweepPortion <= 0 || v <= 0 || v >= sweepPortion) {
      return;
    }
    final p = Curves.easeInOut.transform((v / sweepPortion).clamp(0.0, 1.0));
    final bandWidth = size.width * 0.35;
    final cx = lerpDouble(-bandWidth, size.width + bandWidth, p)!;
    final diag = size.longestSide * 1.5;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(cx, size.height / 2);
    canvas.rotate(0.35);
    final rect = Rect.fromLTWH(-bandWidth / 2, -diag, bandWidth, diag * 2);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShimmerPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.sweepPortion != sweepPortion ||
      oldDelegate.color != color;
}
