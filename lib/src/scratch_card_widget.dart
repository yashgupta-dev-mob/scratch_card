import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'celebration/confetti_burst.dart';
import 'celebration/sunburst_rays.dart';
import 'cover/scratch_card_cover.dart';
import 'models/celebration_type.dart';
import 'models/scratch_card_status.dart';
import 'models/scratch_card_style.dart';
import 'scratcher/scratcher.dart';

part 'controller/scratch_card_controller.dart';
part 'scratch_card_expanded.dart';
part 'scratch_card_route.dart';

/// Called with the scratched share of the card, from 0.0 to 1.0.
typedef ScratchProgressCallback = void Function(double progress);

/// Builds the reward from a value returned by `onFetchReward`.
typedef RewardWidgetBuilder<T> = Widget Function(
  BuildContext context,
  T reward,
);

/// Builds the view shown when `onFetchReward` fails.
/// Calling [retry] fetches again.
typedef RewardErrorWidgetBuilder = Widget Function(
  BuildContext context,
  Object error,
  VoidCallback retry,
);

/// Builds a custom celebration (for example a Lottie or Rive animation).
/// Call [onComplete] when it has finished.
typedef CelebrationWidgetBuilder = Widget Function(
  BuildContext context,
  VoidCallback onComplete,
);

/// Builds a custom cover. [expanded] is true in the full-screen view.
///
/// The cover must not contain compositing widgets (`Opacity`,
/// `RepaintBoundary`, platform views, …), or it can't be scratched.
typedef ScratchCoverBuilder = Widget Function(
  BuildContext context,
  bool expanded,
);

/// A reward card that opens to full screen on tap and is revealed by
/// scratching.
///
/// After a little scratching ([revealThreshold], 35% by default), the rest of
/// the cover clears automatically, the reward pops in and a celebration plays.
///
/// Callbacks fire in this order:
/// [onTap] → [onOpened] → [onScratchStart] → [onScratchProgress]… →
/// [onThresholdReached] → [onRevealed] → [onCelebrationComplete] → [onClosed].
///
/// Set [T] to the type returned by [onFetchReward] to get it in
/// [rewardBuilder]. For a fixed reward, use [rewardChild] instead.
class ScratchCard<T> extends StatefulWidget {
  /// Creates a scratch card.
  const ScratchCard({
    super.key,
    this.controller,
    this.style = const ScratchCardStyle(),
    this.coverBuilder,
    this.rewardChild,
    this.rewardBuilder,
    this.rewardLoadingBuilder,
    this.rewardErrorBuilder,
    this.initialReward,
    this.onFetchReward,
    this.expandedSize,
    this.brushSize = 40,
    this.revealThreshold = 0.35,
    this.isScratched = false,
    this.openWhenScratched = true,
    this.barrierDismissible = true,
    this.enableHaptics = true,
    this.showIdleShimmer = true,
    this.showScratchHint = true,
    this.celebrationType = CelebrationType.confettiAndRays,
    this.confettiColors = ConfettiBurst.defaultColors,
    this.confettiParticleCount = 120,
    this.celebrationDuration = const Duration(milliseconds: 2500),
    this.celebrationBuilder,
    this.heroTag,
    this.semanticLabel,
    this.onTap,
    this.onOpened,
    this.onScratchStart,
    this.onScratchProgress,
    this.onThresholdReached,
    this.onRevealed,
    this.onCelebrationComplete,
    this.onClosed,
    this.onStatusChanged,
    this.onRewardError,
  })  : assert(revealThreshold >= 0.05 && revealThreshold <= 1.0),
        assert(brushSize > 0),
        assert(confettiParticleCount >= 0);

  /// Drives the card from code: open, reveal, close or reset it. Optional.
  final ScratchCardController? controller;

  /// Visual tokens for the cover and the expanded view.
  final ScratchCardStyle style;

  /// Replaces the built-in cover design entirely.
  final ScratchCoverBuilder? coverBuilder;

  /// A fixed reward. Used when there's no [onFetchReward], or when
  /// [rewardBuilder] is null.
  final WidgetBuilder? rewardChild;

  /// Builds the reward from the value returned by [onFetchReward], or from
  /// [initialReward].
  final RewardWidgetBuilder<T>? rewardBuilder;

  /// Shown under the cover while [onFetchReward] is pending.
  /// Defaults to a small spinner.
  final WidgetBuilder? rewardLoadingBuilder;

  /// Shown when [onFetchReward] fails. Defaults to
  /// "Something went wrong. Tap to retry."
  final RewardErrorWidgetBuilder? rewardErrorBuilder;

  /// A reward that is already known, so no fetch is needed. Useful with
  /// [isScratched].
  final T? initialReward;

  /// Loads the reward. It's called as soon as the card opens, so the request
  /// runs while the user scratches. The result goes to [rewardBuilder].
  final Future<T> Function()? onFetchReward;

  /// Size of the card in the full-screen view. Defaults to a square of
  /// `min(screenWidth − 48, 360)`. It is shrunk to fit small screens.
  final Size? expandedSize;

  /// Width of the scratch stroke.
  final double brushSize;

  /// Scratched share (0.05–1.0) at which the rest of the cover clears itself.
  final double revealThreshold;

  /// The reward was already claimed: the card shows it right away, with no
  /// cover, scratching or celebration.
  final bool isScratched;

  /// Whether tapping an already-scratched card still opens the full-screen view.
  final bool openWhenScratched;

  /// Whether tapping the scrim or pressing system back closes the expanded
  /// view. The close button always works.
  final bool barrierDismissible;

  /// Whether to play haptic feedback.
  final bool enableHaptics;

  /// Whether to play a gloss sweep across the collapsed card every few seconds.
  final bool showIdleShimmer;

  /// Whether to animate a swiping-finger hint on the expanded card until
  /// scratching starts.
  final bool showScratchHint;

  /// The built-in celebration. Ignored when [celebrationBuilder] is set.
  final CelebrationType celebrationType;

  /// Confetti colours.
  final List<Color> confettiColors;

  /// Number of confetti pieces.
  final int confettiParticleCount;

  /// Length of the built-in celebration.
  final Duration celebrationDuration;

  /// Replaces the built-in celebration.
  final CelebrationWidgetBuilder? celebrationBuilder;

  /// Hero tag linking the collapsed and expanded card. Defaults to a unique
  /// tag per card.
  final Object? heroTag;

  /// Screen-reader label of the collapsed card.
  final String? semanticLabel;

  /// The collapsed card was tapped (fires before it expands).
  final VoidCallback? onTap;

  /// The expand animation has finished.
  final VoidCallback? onOpened;

  /// The first touch landed on the cover.
  final VoidCallback? onScratchStart;

  /// The scratched share changed. Throttled to about 60 calls per second.
  final ScratchProgressCallback? onScratchProgress;

  /// The user scratched past [revealThreshold] and the auto-reveal is
  /// starting. Doesn't fire for `controller.reveal()`.
  final VoidCallback? onThresholdReached;

  /// The reveal animation has finished and the reward is fully visible.
  final VoidCallback? onRevealed;

  /// The celebration has finished. It always fires after [onRevealed].
  final VoidCallback? onCelebrationComplete;

  /// The expanded view was dismissed (by close button, scrim, back or
  /// controller).
  final VoidCallback? onClosed;

  /// Fires for every [ScratchCardStatus] change.
  final ValueChanged<ScratchCardStatus>? onStatusChanged;

  /// [onFetchReward] threw.
  final void Function(Object error, StackTrace stackTrace)? onRewardError;

  @override
  State<ScratchCard<T>> createState() => _ScratchCardState<T>();
}

enum _RewardStatus { none, loading, success, error }

@immutable
class _RewardSnapshot<T> {
  const _RewardSnapshot._(this.status, [this.data, this.error]);
  const _RewardSnapshot.none() : this._(_RewardStatus.none);
  const _RewardSnapshot.loading() : this._(_RewardStatus.loading);
  const _RewardSnapshot.success(T? data) : this._(_RewardStatus.success, data);
  const _RewardSnapshot.error(Object error)
      : this._(_RewardStatus.error, null, error);

  final _RewardStatus status;
  final T? data;
  final Object? error;
}

class _ScratchCardState<T> extends State<ScratchCard<T>>
    with SingleTickerProviderStateMixin {
  ScratchCardController? _ownController;
  late ScratchCardController _controller;
  late final ValueNotifier<_RewardSnapshot<T>> _reward;
  late final AnimationController _idleShimmer;
  final Object _defaultHeroTag = Object();

  _ScratchCardRoute<T>? _route;
  _ScratchCardExpandedPageState<T>? _expanded;
  Completer<void>? _openCompleter;
  Completer<void>? _closeCompleter;
  ScratchCardStatus? _statusBeforeClosing;

  bool _pressed = false;
  bool _reduceMotion = false;
  bool _lastRevealed = false;
  int _fetchGeneration = 0;

  /// The gloss sweep runs for [_idleSweep], then nothing is drawn for
  /// [_idlePause]. The pause is a timer, not a running animation, so the card
  /// schedules no frames while the gloss is off screen.
  static const Duration _idleSweep = Duration(milliseconds: 1050);
  static const Duration _idlePause = Duration(milliseconds: 1950);
  Timer? _idlePauseTimer;
  bool _idleShimmerOn = false;

  /// Whether the route showing this card is the top route. When another
  /// route covers it (including this card's own expanded view), the idle
  /// shimmer stops so it doesn't keep the whole screen repainting underneath.
  bool _routeIsCurrent = true;

  /// The route this card lives in. Its page is snapshotted for the blurred
  /// scrim behind the expanded view.
  ModalRoute<Object?>? _hostRoute;

  Object get _heroTag => widget.heroTag ?? _defaultHeroTag;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    if (widget.isScratched) _markScratchedSilently();
    _lastRevealed = _controller.isRevealed;
    _reward = ValueNotifier<_RewardSnapshot<T>>(_freshReward(useInitial: true));
    _idleShimmer = AnimationController(vsync: this, duration: _idleSweep)
      ..addStatusListener(_onIdleShimmerStatus);
    if (_controller.isRevealed) _ensureRewardFetched();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _hostRoute = ModalRoute.of(context);
    _syncIdleShimmer();
  }

  @override
  void didUpdateWidget(ScratchCard<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachController();
      _attachController(widget.controller);
      if (widget.isScratched) _markScratchedSilently();
      _lastRevealed = _controller.isRevealed;
    } else if (!oldWidget.isScratched &&
        widget.isScratched &&
        !_controller.isRevealed) {
      _markScratchedSilently();
      _lastRevealed = true;
      _ensureRewardFetched();
    }
    _syncIdleShimmer();
  }

  @override
  void dispose() {
    final route = _route;
    route?.animation?.removeStatusListener(_handleRouteStatus);
    if (route != null && route.isActive) {
      final navigator = route.navigator;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) navigator?.removeRoute(route);
      });
    }
    _route = null;
    _completeOpen();
    _completeClose();
    _detachController();
    _reward.dispose();
    _idlePauseTimer?.cancel();
    _idleShimmer.dispose();
    super.dispose();
  }

  void _attachController(ScratchCardController? external) {
    if (external == null) {
      _ownController = ScratchCardController();
    }
    _controller = external ?? _ownController!;
    _controller._attach(this);
    _controller.addListener(_onControllerChanged);
  }

  void _detachController() {
    _controller.removeListener(_onControllerChanged);
    _controller._detach(this);
    _ownController?.dispose();
    _ownController = null;
  }

  void _markScratchedSilently() {
    _controller._isRevealed = true;
    _controller._progress = 1;
    if (_controller._status == ScratchCardStatus.idle) {
      _controller._status = ScratchCardStatus.revealed;
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final revealed = _controller.isRevealed;
    if (revealed != _lastRevealed) {
      _lastRevealed = revealed;
      setState(() {});
      _syncIdleShimmer();
    }
  }

  /// Starts or stops the idle shimmer. Callers rebuild afterwards (or are
  /// about to), since [build] only passes the animation while it is on.
  void _syncIdleShimmer() {
    final run = widget.showIdleShimmer &&
        !_reduceMotion &&
        !_controller.isRevealed &&
        _routeIsCurrent &&
        _route == null;
    if (run == _idleShimmerOn) return;
    _idleShimmerOn = run;
    if (run) {
      _runIdleCycle();
    } else {
      _idlePauseTimer?.cancel();
      _idlePauseTimer = null;
      _idleShimmer.stop();
      _idleShimmer.value = 0; // Paints nothing.
    }
  }

  static int get _idleCycleMs =>
      (_idleSweep + _idlePause).inMilliseconds;

  /// Position in the shared shimmer cycle. Every card uses the same wall
  /// clock, so all sweeps on screen land in the same frames and the app is
  /// idle (no frames at all) between them.
  static int _idlePhaseMs() =>
      DateTime.now().millisecondsSinceEpoch % _idleCycleMs;

  /// Joins the shared cycle: sweeps now if the cycle is mid-sweep, otherwise
  /// waits for the next sweep without scheduling frames.
  void _runIdleCycle() {
    _idlePauseTimer?.cancel();
    _idlePauseTimer = null;
    if (!mounted || !_idleShimmerOn) return;
    final phase = _idlePhaseMs();
    final sweepMs = _idleSweep.inMilliseconds;
    if (phase < sweepMs) {
      _idleShimmer.forward(from: phase / sweepMs);
    } else {
      _waitForNextSweep(_idleCycleMs - phase);
    }
  }

  void _waitForNextSweep(int ms) {
    _idlePauseTimer?.cancel();
    _idlePauseTimer = Timer(Duration(milliseconds: ms), () {
      _idlePauseTimer = null;
      if (!mounted || !_idleShimmerOn) return;
      _idleShimmer.forward(from: 0);
    });
  }

  void _onIdleShimmerStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_idleShimmerOn) return;
    // Wait for the start of the next shared cycle. If the sweep finished a
    // little early, this still lands on the next cycle, never mid-sweep.
    _waitForNextSweep(_idleCycleMs - _idlePhaseMs());
  }

  // ---------------------------------------------------------------------------
  // Status + callbacks
  // ---------------------------------------------------------------------------

  void _setStatus(ScratchCardStatus status) {
    if (_controller._status == status) return;
    _controller._status = status;
    _controller._notify();
    if (mounted) widget.onStatusChanged?.call(status);
  }

  void _handleScratchStart() {
    if (!mounted) return;
    _setStatus(ScratchCardStatus.scratching);
    widget.onScratchStart?.call();
  }

  void _handleProgress(double progress) {
    if (!mounted) return;
    _controller._progress = progress;
    _controller._notify();
    widget.onScratchProgress?.call(progress);
  }

  void _handleThresholdReached({required bool fireCallback}) {
    if (!mounted) return;
    _setStatus(ScratchCardStatus.revealing);
    if (fireCallback) widget.onThresholdReached?.call();
  }

  void _handleRevealed() {
    if (!mounted) return;
    _controller._isRevealed = true;
    _controller._progress = 1;
    _setStatus(ScratchCardStatus.revealed);
    _controller._notify();
    widget.onRevealed?.call();
  }

  void _handleCelebrationComplete() {
    if (!mounted) return;
    widget.onCelebrationComplete?.call();
  }

  // ---------------------------------------------------------------------------
  // Reward loading
  // ---------------------------------------------------------------------------

  _RewardSnapshot<T> _freshReward({required bool useInitial}) {
    if (widget.onFetchReward == null) {
      return _RewardSnapshot<T>.success(widget.initialReward);
    }
    if (useInitial && widget.initialReward != null) {
      return _RewardSnapshot<T>.success(widget.initialReward);
    }
    return _RewardSnapshot<T>.none();
  }

  void _ensureRewardFetched() {
    if (widget.onFetchReward == null) return;
    final status = _reward.value.status;
    if (status == _RewardStatus.none || status == _RewardStatus.error) {
      _fetchReward();
    }
  }

  void _retryFetch() {
    _fetchReward();
  }

  Future<void> _fetchReward() async {
    final fetch = widget.onFetchReward;
    if (fetch == null) return;
    final generation = ++_fetchGeneration;
    _reward.value = _RewardSnapshot<T>.loading();
    try {
      final result = await fetch();
      if (!mounted || generation != _fetchGeneration) return;
      _reward.value = _RewardSnapshot<T>.success(result);
    } catch (error, stackTrace) {
      if (!mounted || generation != _fetchGeneration) return;
      _reward.value = _RewardSnapshot<T>.error(error);
      widget.onRewardError?.call(error, stackTrace);
    }
  }

  // ---------------------------------------------------------------------------
  // Open / close / reveal / reset
  // ---------------------------------------------------------------------------

  void _handleTap() {
    if (_route != null) return;
    widget.onTap?.call();
    if (!mounted) return;
    if (_controller.isRevealed && !widget.openWhenScratched) return;
    _open();
  }

  Future<void> _open() {
    if (!mounted) return Future<void>.value();
    if (_route != null) {
      return _openCompleter?.future ?? Future<void>.value();
    }
    final navigator = Navigator.of(context);
    final completer = _openCompleter = Completer<void>();
    _setStatus(ScratchCardStatus.opening);
    _ensureRewardFetched();
    final route = _route = _ScratchCardRoute<T>(host: this);
    _syncIdleShimmer();
    navigator.push(route);
    route.animation!.addStatusListener(_handleRouteStatus);
    return completer.future;
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (!mounted) return;
    switch (status) {
      case AnimationStatus.completed:
        if (_controller.status == ScratchCardStatus.opening) {
          _setStatus(
            _controller.isRevealed
                ? ScratchCardStatus.revealed
                : ScratchCardStatus.opened,
          );
          widget.onOpened?.call();
        } else if (_controller.status == ScratchCardStatus.closing) {
          // A pop was cancelled (for example a predictive back gesture).
          _setStatus(_statusBeforeClosing ?? ScratchCardStatus.opened);
        }
        _completeOpen();
      case AnimationStatus.reverse:
        if (_controller.status != ScratchCardStatus.closing) {
          _statusBeforeClosing = _controller.status;
        }
        _setStatus(ScratchCardStatus.closing);
        _completeOpen();
      case AnimationStatus.dismissed:
        _handleRouteDismissed();
      case AnimationStatus.forward:
        break;
    }
  }

  void _handleRouteDismissed() {
    final route = _route;
    if (route == null) return;
    route.animation?.removeStatusListener(_handleRouteStatus);
    _route = null;
    _expanded = null;
    _completeOpen();
    if (mounted) _syncIdleShimmer();
    if (!mounted) {
      _completeClose();
      return;
    }
    if (!_controller.isRevealed) {
      _controller._progress = 0;
      if (_reward.value.status == _RewardStatus.error) {
        _reward.value = _freshReward(useInitial: false);
      }
    }
    _setStatus(ScratchCardStatus.closed);
    widget.onClosed?.call();
    _completeClose();
    if (mounted) setState(() {});
  }

  /// Called by the expanded page when it is disposed. If the route was
  /// removed without a dismiss animation, finish closing here.
  void _onExpandedDisposed(_ScratchCardExpandedPageState<T> page) {
    if (_expanded == page) _expanded = null;
    final route = _route;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_route == route && !route.isActive) _handleRouteDismissed();
    });
  }

  void _completeOpen() {
    final completer = _openCompleter;
    _openCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _completeClose() {
    final completer = _closeCompleter;
    _closeCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<void> _close() {
    final route = _route;
    if (route == null) return Future<void>.value();
    final completer = _closeCompleter ??= Completer<void>();
    if (_controller.status == ScratchCardStatus.closing) {
      return completer.future;
    }
    final navigator = route.navigator;
    if (navigator == null) {
      _handleRouteDismissed();
    } else if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
    return completer.future;
  }

  Future<void> _reveal() async {
    if (!mounted || _controller.isRevealed) return;
    if (_route == null) {
      await _open();
    } else if (_openCompleter != null) {
      await _openCompleter!.future;
    }
    if (!mounted) return;
    _expanded?._revealProgrammatically();
  }

  void _reset() {
    if (!mounted) return;
    _fetchGeneration++;
    _reward.value = _freshReward(useInitial: false);
    _controller._progress = 0;
    _controller._isRevealed = false;
    final expanded = _expanded;
    if (_route != null && expanded != null) {
      expanded._resetFromHost();
      _ensureRewardFetched();
      _setStatus(ScratchCardStatus.opened);
    } else {
      _setStatus(ScratchCardStatus.idle);
    }
    _controller._notify();
    _lastRevealed = false;
    setState(() {});
    _syncIdleShimmer();
  }

  // ---------------------------------------------------------------------------
  // Shared building blocks (also used by the route and hero shuttle)
  // ---------------------------------------------------------------------------

  Size _resolveExpandedSize(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final maxW = math.max(120.0, screen.width - 48);
    final maxH = math.max(120.0, screen.height - padding.vertical - 160);
    final requested = widget.expandedSize;
    if (requested != null && !requested.isEmpty) {
      final scale = math.min(
        1.0,
        math.min(maxW / requested.width, maxH / requested.height),
      );
      return requested * scale;
    }
    return Size.square(math.min(360.0, math.min(maxW, maxH)));
  }

  Widget _buildCover(
    BuildContext context, {
    required bool expanded,
    Animation<double>? shimmer,
    double shimmerSweepPortion = 0.35,
    bool cache = true,
  }) {
    final builder = widget.coverBuilder;
    if (builder != null) return builder(context, expanded);
    return ScratchCardCover(
      style: widget.style,
      label: expanded ? widget.style.expandedLabel : widget.style.collapsedLabel,
      shimmer: shimmer,
      shimmerSweepPortion: shimmerSweepPortion,
      cache: cache,
    );
  }

  Widget _buildRewardContent(BuildContext context, _RewardSnapshot<T> snap) {
    switch (snap.status) {
      case _RewardStatus.none:
      case _RewardStatus.loading:
        return widget.rewardLoadingBuilder?.call(context) ??
            _DefaultRewardLoading(color: _accentColor);
      case _RewardStatus.error:
        return widget.rewardErrorBuilder
                ?.call(context, snap.error!, _retryFetch) ??
            _DefaultRewardError(onRetry: _retryFetch);
      case _RewardStatus.success:
        final builder = widget.rewardBuilder;
        final data = snap.data;
        if (builder != null && data is T) return builder(context, data);
        return widget.rewardChild?.call(context) ??
            _DefaultReward(color: _accentColor);
    }
  }

  Color get _accentColor => widget.style.gradientColors.isEmpty
      ? const Color(0xFFF7931E)
      : widget.style.gradientColors[widget.style.gradientColors.length ~/ 2];

  /// The reward at its natural (expanded) size.
  Widget _buildRewardSurface(BuildContext context) {
    return ColoredBox(
      color: widget.style.rewardBackgroundColor,
      child: SizedBox.expand(
        child: Center(
          child: ValueListenableBuilder<_RewardSnapshot<T>>(
            valueListenable: _reward,
            builder: (context, snap, _) => _buildRewardContent(context, snap),
          ),
        ),
      ),
    );
  }

  /// The reward laid out at the expanded size and scaled down to fit, so it
  /// looks the same in the collapsed card, the hero flight and full screen.
  Widget _buildScaledReward(BuildContext context, Size expandedSize) {
    return ColoredBox(
      color: widget.style.rewardBackgroundColor,
      child: FittedBox(
        child: SizedBox.fromSize(
          size: expandedSize,
          child: _buildRewardSurface(context),
        ),
      ),
    );
  }

  RectTween _createRectTween(Rect? begin, Rect? end) {
    return _CardRectTween(
      begin: begin,
      end: end,
      isOpening: () =>
          _route?.animation?.status != AnimationStatus.reverse,
    );
  }

  Widget _buildShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final style = widget.style;
    final expandedSize = _resolveExpandedSize(flightContext);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value.clamp(0.0, 1.0);
          return _CardFace(
            style: style,
            radius: ui.lerpDouble(
              style.borderRadius,
              style.expandedBorderRadius,
              t,
            )!,
            elevation: t,
            child: _controller.isRevealed
                ? _buildScaledReward(context, expandedSize)
                // The size changes every frame of the flight, so caching
                // would re-rasterize every frame. Paint directly instead.
                : _buildCover(context, expanded: t > 0.5, cache: false),
          );
        },
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final revealed = _controller.isRevealed;

    final Widget content = revealed
        ? _buildScaledReward(context, _resolveExpandedSize(context))
        : _buildCover(
            context,
            expanded: false,
            // Always attached: when stopped its value is 0 and it paints
            // nothing, so starting/stopping needs no rebuild.
            shimmer: widget.showIdleShimmer ? _idleShimmer : null,
            // The controller only runs for the sweep itself; the pause
            // between sweeps is a timer.
            shimmerSweepPortion: 1,
          );

    final card = Hero(
      tag: _heroTag,
      createRectTween: _createRectTween,
      flightShuttleBuilder: _buildShuttle,
      child: _CardFace(
        style: style,
        radius: style.borderRadius,
        elevation: 0,
        child: RepaintBoundary(child: content),
      ),
    );

    final label = widget.semanticLabel ??
        (revealed
            ? '${style.title}, scratch card, reward revealed'
            : '${style.title}, scratch card, tap to open');

    return Semantics(
      button: true,
      label: label,
      onTap: _handleTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: Duration(milliseconds: _pressed ? 100 : 260),
          curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
          child: SizedBox(width: style.width, height: style.height, child: card),
        ),
      ),
    );
  }
}

/// Rect tween for the hero flight. It overshoots slightly when opening, for a
/// springy feel, and follows a straight path when closing.
class _CardRectTween extends RectTween {
  _CardRectTween({super.begin, super.end, required this.isOpening});

  final bool Function() isOpening;

  static const Curve _openCurve = Cubic(0.34, 1.3, 0.64, 1);

  @override
  Rect? lerp(double t) =>
      super.lerp(isOpening() ? _openCurve.transform(t) : t);
}

/// Rounded, shadowed card shell shared by the collapsed card, the hero
/// shuttle and the expanded card.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.style,
    required this.radius,
    required this.elevation,
    required this.child,
  });

  final ScratchCardStyle style;
  final double radius;

  /// 0 = collapsed shadow, 1 = expanded shadow.
  final double elevation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: style.shadowColor,
            blurRadius: style.shadowBlurRadius * (1 + 0.8 * elevation),
            offset: style.shadowOffset * (1 + 0.6 * elevation),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}

class _DefaultReward extends StatelessWidget {
  const _DefaultReward({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.celebration_rounded, size: 72, color: color),
        const SizedBox(height: 16),
        const Text(
          'Reward unlocked!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D2D2D),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _DefaultRewardLoading extends StatelessWidget {
  const _DefaultRewardLoading({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CircularProgressIndicator(strokeWidth: 3, color: color),
    );
  }
}

class _DefaultRewardError extends StatelessWidget {
  const _DefaultRewardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Something went wrong. Tap to retry.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Color(0xFFE53935),
              ),
              SizedBox(height: 12),
              Text(
                'Something went wrong.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D2D),
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Tap to retry',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF57C00),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
