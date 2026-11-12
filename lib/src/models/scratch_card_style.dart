import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Visual tokens for a scratch card.
///
/// The defaults reproduce the orange "Order reward" card: an orange gradient
/// with faint diagonal stripes, a gift icon in a translucent circle, a bold
/// title and a "TAP TO SCRATCH" pill.
@immutable
class ScratchCardStyle {
  /// Creates a style. Every value has a default matching the reference design.
  const ScratchCardStyle({
    this.width = 180,
    this.height = 170,
    this.borderRadius = 20,
    this.expandedBorderRadius = 28,
    this.gradientColors = const [
      Color(0xFFFFB547),
      Color(0xFFF7931E),
      Color(0xFFF57C00),
    ],
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
    this.stripeColor = const Color(0x17FFFFFF),
    this.stripeWidth = 10,
    this.stripeGap = 10,
    this.icon = Icons.card_giftcard_rounded,
    this.iconColor = Colors.white,
    this.iconSize = 28,
    this.badgeSize = 56,
    this.badgeColor = const Color(0x40FFFFFF),
    this.badgeBorderColor = const Color(0x80FFFFFF),
    this.badgeBorderWidth = 1.5,
    this.title = 'Order reward',
    this.collapsedLabel = 'TAP TO SCRATCH',
    this.expandedLabel = 'SCRATCH HERE',
    this.titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.2,
      decoration: TextDecoration.none,
    ),
    this.labelStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      height: 1.2,
      decoration: TextDecoration.none,
    ),
    this.pillColor = const Color(0x33FFFFFF),
    this.shadowColor = const Color(0x59FF9800),
    this.shadowBlurRadius = 16,
    this.shadowOffset = const Offset(0, 6),
    this.rewardBackgroundColor = Colors.white,
    this.scrimColor = const Color(0x99000000),
    this.scrimBlurSigma = 8,
    this.expandedHintText = 'Scratch the card to reveal your reward',
    this.expandedHintStyle = const TextStyle(
      color: Color(0xE6FFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.none,
    ),
    this.openDuration = const Duration(milliseconds: 450),
  });

  /// Preferred width of the collapsed card. Tight parent constraints win.
  final double width;

  /// Preferred height of the collapsed card. Tight parent constraints win.
  final double height;

  /// Corner radius of the collapsed card.
  final double borderRadius;

  /// Corner radius of the expanded card.
  final double expandedBorderRadius;

  /// Cover gradient colours (at least two).
  final List<Color> gradientColors;

  /// Start of the cover gradient.
  final AlignmentGeometry gradientBegin;

  /// End of the cover gradient.
  final AlignmentGeometry gradientEnd;

  /// Colour of the diagonal stripes. Use a transparent colour to hide them.
  final Color stripeColor;

  /// Width of each stripe at the collapsed size.
  final double stripeWidth;

  /// Gap between stripes at the collapsed size.
  final double stripeGap;

  /// Icon shown in the badge.
  final IconData icon;

  /// Colour of [icon].
  final Color iconColor;

  /// Size of [icon] at the collapsed size.
  final double iconSize;

  /// Diameter of the circular badge at the collapsed size.
  final double badgeSize;

  /// Fill of the circular badge.
  final Color badgeColor;

  /// Border colour of the circular badge.
  final Color badgeBorderColor;

  /// Border width of the circular badge.
  final double badgeBorderWidth;

  /// Title under the badge, e.g. "Order reward".
  final String title;

  /// Pill text on the collapsed card.
  final String collapsedLabel;

  /// Pill text on the expanded card.
  final String expandedLabel;

  /// Title text style at the collapsed size (scaled up when expanded).
  final TextStyle titleStyle;

  /// Pill text style at the collapsed size (scaled up when expanded).
  final TextStyle labelStyle;

  /// Fill of the pill behind the label.
  final Color pillColor;

  /// Colour of the card's drop shadow.
  final Color shadowColor;

  /// Blur radius of the card's drop shadow.
  final double shadowBlurRadius;

  /// Offset of the card's drop shadow.
  final Offset shadowOffset;

  /// Background behind the reward content.
  final Color rewardBackgroundColor;

  /// Colour of the full-screen scrim behind the expanded card.
  final Color scrimColor;

  /// Blur sigma applied behind the scrim.
  final double scrimBlurSigma;

  /// Helper text under the expanded card before the reveal. `null` hides it.
  final String? expandedHintText;

  /// Style of [expandedHintText].
  final TextStyle expandedHintStyle;

  /// Duration of the open and close animation.
  final Duration openDuration;

  /// Returns a copy with the given fields replaced.
  ScratchCardStyle copyWith({
    double? width,
    double? height,
    double? borderRadius,
    double? expandedBorderRadius,
    List<Color>? gradientColors,
    AlignmentGeometry? gradientBegin,
    AlignmentGeometry? gradientEnd,
    Color? stripeColor,
    double? stripeWidth,
    double? stripeGap,
    IconData? icon,
    Color? iconColor,
    double? iconSize,
    double? badgeSize,
    Color? badgeColor,
    Color? badgeBorderColor,
    double? badgeBorderWidth,
    String? title,
    String? collapsedLabel,
    String? expandedLabel,
    TextStyle? titleStyle,
    TextStyle? labelStyle,
    Color? pillColor,
    Color? shadowColor,
    double? shadowBlurRadius,
    Offset? shadowOffset,
    Color? rewardBackgroundColor,
    Color? scrimColor,
    double? scrimBlurSigma,
    String? expandedHintText,
    TextStyle? expandedHintStyle,
    Duration? openDuration,
  }) {
    return ScratchCardStyle(
      width: width ?? this.width,
      height: height ?? this.height,
      borderRadius: borderRadius ?? this.borderRadius,
      expandedBorderRadius: expandedBorderRadius ?? this.expandedBorderRadius,
      gradientColors: gradientColors ?? this.gradientColors,
      gradientBegin: gradientBegin ?? this.gradientBegin,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      stripeColor: stripeColor ?? this.stripeColor,
      stripeWidth: stripeWidth ?? this.stripeWidth,
      stripeGap: stripeGap ?? this.stripeGap,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      iconSize: iconSize ?? this.iconSize,
      badgeSize: badgeSize ?? this.badgeSize,
      badgeColor: badgeColor ?? this.badgeColor,
      badgeBorderColor: badgeBorderColor ?? this.badgeBorderColor,
      badgeBorderWidth: badgeBorderWidth ?? this.badgeBorderWidth,
      title: title ?? this.title,
      collapsedLabel: collapsedLabel ?? this.collapsedLabel,
      expandedLabel: expandedLabel ?? this.expandedLabel,
      titleStyle: titleStyle ?? this.titleStyle,
      labelStyle: labelStyle ?? this.labelStyle,
      pillColor: pillColor ?? this.pillColor,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      rewardBackgroundColor:
          rewardBackgroundColor ?? this.rewardBackgroundColor,
      scrimColor: scrimColor ?? this.scrimColor,
      scrimBlurSigma: scrimBlurSigma ?? this.scrimBlurSigma,
      expandedHintText: expandedHintText ?? this.expandedHintText,
      expandedHintStyle: expandedHintStyle ?? this.expandedHintStyle,
      openDuration: openDuration ?? this.openDuration,
    );
  }

  // Value equality lets the cover keep its cached raster when a parent
  // rebuilds with an equal (but not identical) style.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScratchCardStyle &&
        other.width == width &&
        other.height == height &&
        other.borderRadius == borderRadius &&
        other.expandedBorderRadius == expandedBorderRadius &&
        listEquals(other.gradientColors, gradientColors) &&
        other.gradientBegin == gradientBegin &&
        other.gradientEnd == gradientEnd &&
        other.stripeColor == stripeColor &&
        other.stripeWidth == stripeWidth &&
        other.stripeGap == stripeGap &&
        other.icon == icon &&
        other.iconColor == iconColor &&
        other.iconSize == iconSize &&
        other.badgeSize == badgeSize &&
        other.badgeColor == badgeColor &&
        other.badgeBorderColor == badgeBorderColor &&
        other.badgeBorderWidth == badgeBorderWidth &&
        other.title == title &&
        other.collapsedLabel == collapsedLabel &&
        other.expandedLabel == expandedLabel &&
        other.titleStyle == titleStyle &&
        other.labelStyle == labelStyle &&
        other.pillColor == pillColor &&
        other.shadowColor == shadowColor &&
        other.shadowBlurRadius == shadowBlurRadius &&
        other.shadowOffset == shadowOffset &&
        other.rewardBackgroundColor == rewardBackgroundColor &&
        other.scrimColor == scrimColor &&
        other.scrimBlurSigma == scrimBlurSigma &&
        other.expandedHintText == expandedHintText &&
        other.expandedHintStyle == expandedHintStyle &&
        other.openDuration == openDuration;
  }

  @override
  int get hashCode => Object.hashAll([
        width,
        height,
        borderRadius,
        expandedBorderRadius,
        Object.hashAll(gradientColors),
        gradientBegin,
        gradientEnd,
        stripeColor,
        stripeWidth,
        stripeGap,
        icon,
        iconColor,
        iconSize,
        badgeSize,
        badgeColor,
        badgeBorderColor,
        badgeBorderWidth,
        title,
        collapsedLabel,
        expandedLabel,
        titleStyle,
        labelStyle,
        pillColor,
        shadowColor,
        shadowBlurRadius,
        shadowOffset,
        rewardBackgroundColor,
        scrimColor,
        scrimBlurSigma,
        expandedHintText,
        expandedHintStyle,
        openDuration,
      ]);
}
