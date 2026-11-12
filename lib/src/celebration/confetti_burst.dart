import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'confetti_painter.dart';

/// A one-shot confetti burst that starts as soon as it's inserted into the tree.
///
/// Give it the whole screen (for example with `Positioned.fill`). It ignores
/// pointers. Insert it with a new [Key] to play it again.
class ConfettiBurst extends StatefulWidget {
  /// Creates a confetti burst.
  const ConfettiBurst({
    super.key,
    this.particleCount = 120,
    this.colors = defaultColors,
    this.duration = const Duration(milliseconds: 2500),
    this.origin = Alignment.center,
    this.gravity = 1100,
    this.seed,
    this.onComplete,
  }) : assert(particleCount >= 0);

  /// Gold, orange, pink, teal, purple and white.
  static const List<Color> defaultColors = [
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF4F8B),
    Color(0xFF1DE9B6),
    Color(0xFF9C27B0),
    Colors.white,
  ];

  /// Number of pieces.
  final int particleCount;

  /// Colours to pick from.
  final List<Color> colors;

  /// Length of the burst, including the fade-out.
  final Duration duration;

  /// Where the burst starts, relative to this widget's size.
  final Alignment origin;

  /// Downward acceleration, px/s².
  final double gravity;

  /// Seed for repeatable bursts (for example in golden tests).
  final int? seed;

  /// Called once the burst has finished.
  final VoidCallback? onComplete;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    final random = math.Random(widget.seed);
    _particles = List<ConfettiParticle>.generate(
      widget.particleCount,
      (_) => ConfettiParticle.random(random, widget.colors),
      growable: false,
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: ConfettiPainter(
            particles: _particles,
            progress: _controller,
            duration: widget.duration,
            origin: widget.origin,
            gravity: widget.gravity,
          ),
        ),
      ),
    );
  }
}
