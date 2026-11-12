import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scratch_card_style.dart';
import 'shimmer.dart';
import 'stripes_painter.dart';

/// The scratchable cover: an orange gradient with diagonal stripes, a gift
/// badge, a title and a pill label.
///
/// The content scales with the available size. At [ScratchCardStyle.width] ×
/// [ScratchCardStyle.height] it matches the collapsed design exactly, and at
/// the expanded size everything grows proportionally.
///
/// The cover paints directly into its parent's canvas and doesn't create
/// compositing layers, which is what lets the scratcher erase it.
///
/// With [cache] on (the default), the static artwork (gradient, stripes,
/// badge and text) is rasterized once into an image and redrawn as a single
/// textured quad. The shimmer is painted on top of that image, so animating
/// it never re-rasterizes the artwork.
class ScratchCardCover extends StatelessWidget {
  /// Creates a cover.
  const ScratchCardCover({
    super.key,
    this.style = const ScratchCardStyle(),
    this.label,
    this.shimmer,
    this.shimmerSweepPortion = 0.35,
    this.cache = true,
  });

  /// Shared, always-on controller. Never disposed: it lives as long as the
  /// app and holds no resources of its own.
  static final SnapshotController _snapshotOn =
      SnapshotController(allowSnapshotting: true);

  /// Visual tokens.
  final ScratchCardStyle style;

  /// Pill text. Defaults to [ScratchCardStyle.collapsedLabel].
  final String? label;

  /// When non-null, drives a gloss sweep across the cover.
  final Animation<double>? shimmer;

  /// See [ShimmerPainter.sweepPortion].
  final double shimmerSweepPortion;

  /// Whether to cache the static artwork as an image. Turn it off while the
  /// size animates every frame (for example in a hero flight), where a new
  /// snapshot per frame would cost more than painting directly.
  final bool cache;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.hasBoundedWidth ? constraints.maxWidth : style.width;
        final h =
            constraints.hasBoundedHeight ? constraints.maxHeight : style.height;
        final s = math
            .min(w / style.width, h / style.height)
            .clamp(0.5, 2.4)
            .toDouble();
        final colors = switch (style.gradientColors.length) {
          0 => const [Color(0xFFFFB547), Color(0xFFF57C00)],
          1 => [style.gradientColors.first, style.gradientColors.first],
          _ => style.gradientColors,
        };

        final resolvedLabel = label ?? style.collapsedLabel;
        Widget artwork = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: style.gradientBegin,
              end: style.gradientEnd,
            ),
          ),
          child: CustomPaint(
            painter: StripesPainter(
              color: style.stripeColor,
              stripeWidth: style.stripeWidth * s,
              gap: style.stripeGap * s,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(10 * s),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _CoverContent(
                    style: style,
                    label: resolvedLabel,
                    scale: s,
                  ),
                ),
              ),
            ),
          ),
        );

        if (cache) {
          // A new key (style or label changed) gives a fresh render object and
          // therefore a fresh snapshot. Size changes re-snapshot via autoresize.
          artwork = SnapshotWidget(
            key: ValueKey<(ScratchCardStyle, String)>((style, resolvedLabel)),
            controller: _snapshotOn,
            mode: SnapshotMode.permissive,
            autoresize: true,
            child: artwork,
          );
        }

        return SizedBox(
          width: w,
          height: h,
          // Always wrapped, so toggling the shimmer keeps the tree shape (and
          // the cached snapshot) intact.
          child: CustomPaint(
            foregroundPainter: shimmer == null
                ? null
                : ShimmerPainter(
                    animation: shimmer!,
                    sweepPortion: shimmerSweepPortion,
                  ),
            child: artwork,
          ),
        );
      },
    );
  }
}

class _CoverContent extends StatelessWidget {
  const _CoverContent({
    required this.style,
    required this.label,
    required this.scale,
  });

  final ScratchCardStyle style;
  final String label;
  final double scale;

  TextStyle _scaled(TextStyle base, double fallbackSize) =>
      base.copyWith(fontSize: (base.fontSize ?? fallbackSize) * scale);

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: style.badgeSize * s,
          height: style.badgeSize * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: style.badgeColor,
            border: Border.all(
              color: style.badgeBorderColor,
              width: style.badgeBorderWidth * s,
            ),
          ),
          child: Icon(
            style.icon,
            size: style.iconSize * s,
            color: style.iconColor,
          ),
        ),
        SizedBox(height: 12 * s),
        Text(
          style.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: _scaled(style.titleStyle, 18),
        ),
        SizedBox(height: 10 * s),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
          decoration: BoxDecoration(
            color: style.pillColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: _scaled(style.labelStyle, 12),
          ),
        ),
      ],
    );
  }
}
