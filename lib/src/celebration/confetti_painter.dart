import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Shape of a confetti piece.
enum ConfettiShape {
  /// A small rectangle.
  rect,

  /// A round dot.
  circle,

  /// A long, thin strip.
  strip,
}

/// One confetti piece. Its motion is a closed-form function of time, so
/// painting any frame is O(particles) with no per-frame state.
class ConfettiParticle {
  /// Creates a particle.
  const ConfettiParticle({
    required this.vx,
    required this.vy,
    required this.drag,
    required this.size,
    required this.aspect,
    required this.rotation,
    required this.spin,
    required this.flipSpeed,
    required this.flipPhase,
    required this.wobbleAmp,
    required this.wobbleFreq,
    required this.wobblePhase,
    required this.color,
    required this.shape,
  });

  /// Creates a random particle that bursts mostly upward.
  factory ConfettiParticle.random(math.Random random, List<Color> colors) {
    final upward = random.nextDouble() < 0.8;
    final angle = upward
        ? -math.pi / 2 + (random.nextDouble() * 2 - 1) * 1.1
        : random.nextDouble() * math.pi * 2;
    final speed = 450 + random.nextDouble() * 1050;
    final roll = random.nextDouble();
    final shape = roll < 0.5
        ? ConfettiShape.rect
        : roll < 0.8
            ? ConfettiShape.circle
            : ConfettiShape.strip;
    return ConfettiParticle(
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed,
      drag: 1.4 + random.nextDouble() * 1.2,
      size: 6 + random.nextDouble() * 6,
      aspect: shape == ConfettiShape.strip ? 2.6 : 0.5 + random.nextDouble() * 0.6,
      rotation: random.nextDouble() * math.pi * 2,
      spin: (random.nextDouble() * 2 - 1) * 10,
      flipSpeed: 4 + random.nextDouble() * 8,
      flipPhase: random.nextDouble() * math.pi * 2,
      wobbleAmp: 4 + random.nextDouble() * 14,
      wobbleFreq: 2 + random.nextDouble() * 5,
      wobblePhase: random.nextDouble() * math.pi * 2,
      color: colors.isEmpty
          ? const Color(0xFFFFC107)
          : colors[random.nextInt(colors.length)],
      shape: shape,
    );
  }

  /// Initial horizontal velocity, px/s.
  final double vx;

  /// Initial vertical velocity, px/s (negative is up).
  final double vy;

  /// Linear air drag coefficient, 1/s.
  final double drag;

  /// Base size, px.
  final double size;

  /// Height ÷ width.
  final double aspect;

  /// Initial rotation, radians.
  final double rotation;

  /// Rotation speed, radians/s.
  final double spin;

  /// Speed of the 3D "flip" (vertical squash), radians/s.
  final double flipSpeed;

  /// Phase of the flip.
  final double flipPhase;

  /// Side-to-side flutter amplitude, px.
  final double wobbleAmp;

  /// Side-to-side flutter frequency, radians/s.
  final double wobbleFreq;

  /// Phase of the flutter.
  final double wobblePhase;

  /// Colour.
  final Color color;

  /// Shape.
  final ConfettiShape shape;
}

/// Paints a list of [ConfettiParticle]s at the time given by [progress].
class ConfettiPainter extends CustomPainter {
  /// Creates a confetti painter.
  ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.duration,
    this.origin = Alignment.center,
    this.gravity = 1100,
  }) : super(repaint: progress);

  /// The particles to paint.
  final List<ConfettiParticle> particles;

  /// Runs from 0 to 1 over [duration].
  final Animation<double> progress;

  /// Total burst duration.
  final Duration duration;

  /// Burst origin within the canvas.
  final Alignment origin;

  /// Downward acceleration, px/s².
  final double gravity;

  /// Sides of the polygon that stands in for a round dot. At confetti sizes
  /// (a few pixels) an octagon is indistinguishable from a circle.
  static const int _circleSides = 8;

  /// Unit octagon, computed once.
  static final List<double> _circleCos = List<double>.generate(
    _circleSides,
    (i) => math.cos(i * 2 * math.pi / _circleSides),
  );
  static final List<double> _circleSin = List<double>.generate(
    _circleSides,
    (i) => math.sin(i * 2 * math.pi / _circleSides),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final v = progress.value;
    if (v <= 0 || v >= 1 || size.isEmpty) return;
    final fade = v < 0.7 ? 1.0 : (1 - (v - 0.7) / 0.3).clamp(0.0, 1.0);
    if (fade <= 0) return;

    final t = v * duration.inMicroseconds / Duration.microsecondsPerSecond;
    final o = origin.alongSize(size);

    // Every particle goes into one triangle list, drawn with a single
    // drawVertices call. One draw per particle (with save/transform/restore
    // around it) is far more expensive on the raster thread and the GPU.
    const maxVertsPerParticle = _circleSides * 3;
    final positions = Float32List(particles.length * maxVertsPerParticle * 2);
    final colors = Int32List(particles.length * maxVertsPerParticle);
    var pi = 0; // Index into positions (2 per vertex).
    var ci = 0; // Index into colors (1 per vertex).

    for (final p in particles) {
      final k = p.drag;
      final e = (1 - math.exp(-k * t)) / k;
      final x = o.dx +
          p.vx * e +
          p.wobbleAmp * math.sin(p.wobbleFreq * t + p.wobblePhase);
      final y = o.dy + p.vy * e + gravity / k * (t - e);
      if (y > size.height + 40 || x < -40 || x > size.width + 40) continue;

      // Local point (lx, ly) → canvas: scale(1, flip), rotate, translate.
      final angle = p.rotation + p.spin * t;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final flip = math.cos(p.flipSpeed * t + p.flipPhase);
      final color = p.color.withValues(alpha: p.color.a * fade).toARGB32();

      void vertex(double lx, double ly) {
        final fy = ly * flip;
        positions[pi++] = x + cos * lx - sin * fy;
        positions[pi++] = y + sin * lx + cos * fy;
        colors[ci++] = color;
      }

      void quad(double hw, double hh) {
        vertex(-hw, -hh);
        vertex(hw, -hh);
        vertex(hw, hh);
        vertex(-hw, -hh);
        vertex(hw, hh);
        vertex(-hw, hh);
      }

      switch (p.shape) {
        case ConfettiShape.rect:
          quad(p.size / 2, p.size * p.aspect / 2);
        case ConfettiShape.strip:
          // The 1.5px corner radius is invisible at this size.
          quad(p.size * 0.45 / 2, p.size * p.aspect / 2);
        case ConfettiShape.circle:
          final r = p.size * 0.4;
          for (var i = 0; i < _circleSides; i++) {
            final j = (i + 1) % _circleSides;
            vertex(0, 0);
            vertex(r * _circleCos[i], r * _circleSin[i]);
            vertex(r * _circleCos[j], r * _circleSin[j]);
          }
      }
    }

    if (ci == 0) return;
    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(positions, 0, pi),
      colors: Int32List.sublistView(colors, 0, ci),
    );
    // BlendMode.dst: use the per-vertex colours as they are.
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.progress != progress ||
      oldDelegate.origin != origin ||
      oldDelegate.gravity != gravity ||
      oldDelegate.duration != duration;
}
