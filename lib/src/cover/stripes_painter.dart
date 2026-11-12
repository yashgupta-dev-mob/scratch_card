import 'package:flutter/rendering.dart';

/// Paints thin 45° diagonal stripes across the whole canvas.
class StripesPainter extends CustomPainter {
  /// Creates a stripes painter.
  const StripesPainter({
    required this.color,
    this.stripeWidth = 10,
    this.gap = 10,
  });

  /// Stripe colour (usually white at a low opacity).
  final Color color;

  /// Width of each stripe.
  final double stripeWidth;

  /// Horizontal gap between stripes.
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0 || stripeWidth <= 0 || size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;
    final step = stripeWidth + gap;
    final reach = size.height + 2 * stripeWidth;
    for (double x = -size.height - stripeWidth;
        x < size.width + stripeWidth;
        x += step) {
      canvas.drawLine(
        Offset(x, size.height + stripeWidth),
        Offset(x + reach, -stripeWidth),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StripesPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.stripeWidth != stripeWidth ||
      oldDelegate.gap != gap;
}
