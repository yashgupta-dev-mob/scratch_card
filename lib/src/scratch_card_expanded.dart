part of 'scratch_card_widget.dart';

/// The full-screen view: blurred scrim, the large card (reward underneath and
/// a scratchable cover on top), a scratch hint, a close button and the
/// celebration.
class _ScratchCardExpandedPage<T> extends StatefulWidget {
  const _ScratchCardExpandedPage({
    required this.host,
    required this.routeAnimation,
  });

  final _ScratchCardState<T> host;
  final Animation<double> routeAnimation;

  @override
  State<_ScratchCardExpandedPage<T>> createState() =>
      _ScratchCardExpandedPageState<T>();
}

class _ScratchCardExpandedPageState<T>
    extends State<_ScratchCardExpandedPage<T>> with TickerProviderStateMixin {
  _ScratchCardState<T> get host => widget.host;
  ScratchCard<T> get config => host.widget;

  /// Fades and lifts the remaining cover away.
  late final AnimationController _coverController;
  late final Animation<double> _coverOpacity;
  late final Animation<double> _coverScale;

  /// Pops the reward in.
  late final AnimationController _popController;
  late final Animation<double> _popScale;

  /// Swipe hint loop.
  late final AnimationController _hintController;

  /// Shimmer while waiting for the reward to load after the threshold.
  late final AnimationController _waitController;

  GlobalKey<ScratcherState> _scratcherKey = GlobalKey<ScratcherState>();

  /// The page under this route, captured once and blurred once. Drawing it
  /// is a single textured quad, whereas a live [BackdropFilter] re-blurs the
  /// whole screen on every frame (every scratch move, every confetti frame).
  /// Null until captured, or if capturing failed: then the live blur is used.
  ui.Image? _backdrop;
  Size? _backdropSize;

  /// Capturing failed: use the live blur instead.
  bool _backdropFailed = false;

  /// Fades the snapshot in when it arrives, a few frames after opening, so
  /// it doesn't pop in at the route's current opacity.
  late final AnimationController _backdropFade;

  /// Whether the snapshot covers the whole screen at full opacity, as of
  /// the last build.
  bool _snapshotFits = false;

  /// Whether this route currently tells the overlay to skip painting the
  /// page below. See [_syncCoverBelow].
  bool _coveringBelow = false;

  /// Resolution of the captured backdrop relative to the screen. The blur
  /// hides the lost detail, and a quarter-size image is 16× cheaper to blur.
  static const double _backdropScale = 0.25;

  bool _reduceMotion = false;
  bool _scratchStarted = false;
  bool _thresholdReached = false;
  bool _coverRemoved = false;
  bool _waiting = false;
  bool _popStarted = false;
  bool _revealed = false;
  bool _celebrating = false;
  bool _celebrationDone = false;
  bool _celebrationReported = false;
  int _celebrationId = 0;

  @override
  void initState() {
    super.initState();
    host._expanded = this;

    _coverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _coverRemoved = true);
        }
      });
    final coverCurve =
        CurvedAnimation(parent: _coverController, curve: Curves.easeOut);
    _coverOpacity = Tween<double>(begin: 1, end: 0).animate(coverCurve);
    _coverScale = Tween<double>(begin: 1, end: 1.08).animate(coverCurve);

    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onPopComplete();
      });
    _popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 1)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_popController);

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _waitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    host._reward.addListener(_onRewardChanged);

    if (host._controller.isRevealed) {
      // Opened an already-scratched card: show the reward, no cover, no party.
      _scratchStarted = true;
      _thresholdReached = true;
      _coverRemoved = true;
      _popStarted = true;
      _revealed = true;
      _celebrationDone = true;
      _celebrationReported = true;
    }

    _backdropFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addStatusListener(_onCoverInputsChanged);
    widget.routeAnimation.addStatusListener(_onCoverInputsChanged);
    if (config.style.scrimBlurSigma > 0) _captureBackdrop();
  }

  void _onCoverInputsChanged(AnimationStatus _) => _syncCoverBelow();

  /// Once the card is fully open and the blurred snapshot is fully opaque,
  /// the page underneath is invisible, yet it would still be painted every
  /// frame (every scratch move, every confetti frame). Marking this route
  /// as covering lets the overlay skip it entirely. As soon as closing
  /// starts, the page is painted again so the close animation reveals it.
  void _syncCoverBelow() {
    if (!mounted) return;
    final route = host._route;
    final hostRoute = host._hostRoute;
    final want = route != null &&
        _snapshotFits &&
        widget.routeAnimation.status == AnimationStatus.completed &&
        _backdropFade.status == AnimationStatus.completed &&
        // A route that doesn't keep its state would be disposed while
        // covered, taking the collapsed card (this view's host) with it.
        hostRoute != null &&
        hostRoute.opaque &&
        hostRoute.maintainState;
    if (want == _coveringBelow) return;
    _coveringBelow = want;
    route?.setCoversBelow(want);
  }

  /// Snapshots the host's page and blurs it once.
  Future<void> _captureBackdrop() async {
    // Two frames: the first builds this route and starts the hero flight,
    // the second hides the source card. Capturing after that keeps the
    // collapsed card out of the background, as with the live blur.
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted || !host.mounted) return;

    final boundary = host._hostRoute?.subtreeContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
      setState(() => _backdropFailed = true);
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sigma = config.style.scrimBlurSigma * dpr * _backdropScale;

    ui.Image? raw;
    try {
      raw = await boundary.toImage(pixelRatio: dpr * _backdropScale);
      if (!mounted) return;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImage(
        raw,
        Offset.zero,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
      );
      final picture = recorder.endRecording();
      final blurred = await picture.toImage(raw.width, raw.height);
      picture.dispose();
      if (!mounted) {
        blurred.dispose();
        return;
      }
      setState(() {
        _backdrop = blurred;
        _backdropSize = boundary.size;
      });
      if (_reduceMotion) {
        _backdropFade.value = 1;
      } else {
        _backdropFade.forward();
      }
    } catch (_) {
      // The page couldn't be captured (for example it was mid-paint or holds
      // a platform view). Use the live blur.
      if (mounted) setState(() => _backdropFailed = true);
    } finally {
      raw?.dispose();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncHint();
  }

  @override
  void dispose() {
    widget.routeAnimation.removeStatusListener(_onCoverInputsChanged);
    host._reward.removeListener(_onRewardChanged);
    host._onExpandedDisposed(this);
    _coverController.dispose();
    _popController.dispose();
    _hintController.dispose();
    _waitController.dispose();
    _backdropFade.dispose();
    _backdrop?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Reveal flow
  // ---------------------------------------------------------------------------

  void _syncHint() {
    final show = config.showScratchHint &&
        !_reduceMotion &&
        !_scratchStarted &&
        !_thresholdReached;
    if (show) {
      if (!_hintController.isAnimating) _hintController.repeat();
    } else if (_hintController.isAnimating) {
      _hintController.stop();
    }
  }

  void _onScratchStart() {
    if (!mounted) return;
    setState(() => _scratchStarted = true);
    _syncHint();
    host._handleScratchStart();
  }

  void _onProgress(double progress) => host._handleProgress(progress);

  void _onThreshold() => _beginReveal(userTriggered: true);

  void _revealProgrammatically() => _beginReveal(userTriggered: false);

  void _beginReveal({required bool userTriggered}) {
    if (!mounted || _thresholdReached) return;
    setState(() {
      _thresholdReached = true;
      _scratchStarted = true;
    });
    _syncHint();
    host._handleThresholdReached(fireCallback: userTriggered);
    _advanceReveal();
  }

  /// Moves the reveal forward based on the reward's loading state.
  void _advanceReveal() {
    if (!mounted || !_thresholdReached || _popStarted) return;
    switch (host._reward.value.status) {
      case _RewardStatus.success:
        _stopWaiting();
        _removeCover();
        _startPop();
      case _RewardStatus.error:
        _stopWaiting();
        _removeCover();
      case _RewardStatus.loading:
        _startWaiting();
      case _RewardStatus.none:
        _startWaiting();
        host._ensureRewardFetched();
    }
  }

  void _onRewardChanged() {
    if (!mounted) return;
    setState(() {});
    _advanceReveal();
  }

  void _startWaiting() {
    if (_waiting || _coverRemoved) return;
    setState(() => _waiting = true);
    if (!_reduceMotion) _waitController.repeat();
  }

  void _stopWaiting() {
    if (!_waiting) return;
    _waitController.stop();
    setState(() => _waiting = false);
  }

  void _removeCover() {
    if (_coverRemoved || _coverController.isAnimating) return;
    if (_coverController.status == AnimationStatus.completed) return;
    _coverController.forward();
  }

  void _startPop() {
    if (_popStarted) return;
    _popStarted = true;
    if (config.enableHaptics) HapticFeedback.mediumImpact();
    _startCelebration();
    _popController.forward(from: 0);
  }

  void _onPopComplete() {
    if (!mounted || _revealed) return;
    setState(() => _revealed = true);
    host._handleRevealed();
    _maybeReportCelebration();
  }

  void _startCelebration() {
    final hasBuilder = config.celebrationBuilder != null;
    if (_reduceMotion ||
        (!hasBuilder && config.celebrationType == CelebrationType.none)) {
      _celebrationDone = true;
      return;
    }
    setState(() {
      _celebrating = true;
      _celebrationDone = false;
      _celebrationId++;
    });
  }

  void _completeCelebration(int id) {
    // Deferred so a custom builder may call onComplete synchronously.
    scheduleMicrotask(() {
      if (!mounted || id != _celebrationId || _celebrationDone) return;
      setState(() {
        _celebrationDone = true;
        _celebrating = false;
      });
      _maybeReportCelebration();
    });
  }

  void _maybeReportCelebration() {
    if (_revealed && _celebrationDone && !_celebrationReported) {
      _celebrationReported = true;
      host._handleCelebrationComplete();
    }
  }

  void _resetFromHost() {
    if (!mounted) return;
    _coverController.reset();
    _popController.reset();
    _waitController.stop();
    setState(() {
      _scratcherKey = GlobalKey<ScratcherState>();
      _scratchStarted = false;
      _thresholdReached = false;
      _coverRemoved = false;
      _waiting = false;
      _popStarted = false;
      _revealed = false;
      _celebrating = false;
      _celebrationDone = false;
      _celebrationReported = false;
      _celebrationId++;
    });
    _syncHint();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final style = config.style;
    final size = host._resolveExpandedSize(context);
    final route = widget.routeAnimation;
    final dismissible = config.barrierDismissible;
    final showRays = _celebrating &&
        config.celebrationBuilder == null &&
        config.celebrationType == CelebrationType.confettiAndRays;

    return PopScope(
      canPop: dismissible,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screen = constraints.biggest;
            final centerY = screen.height / 2;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Scrim with blur.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: dismissible ? () => host._close() : null,
                  child: _buildScrim(screen),
                ),

                // Rotating rays behind the card.
                if (showRays)
                  FadeTransition(
                    opacity: route,
                    child: SunburstRays(
                      key: ValueKey<int>(_celebrationId),
                      duration: config.celebrationDuration,
                      radius: size.longestSide * 0.95,
                    ),
                  ),

                // The card.
                Center(child: _buildCard(context, size)),

                // Helper text under the card.
                if (style.expandedHintText != null)
                  Positioned(
                    left: 24,
                    right: 24,
                    top: centerY + size.height / 2 + 28,
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: route,
                        child: AnimatedOpacity(
                          opacity: _thresholdReached ? 0 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            style.expandedHintText!,
                            textAlign: TextAlign.center,
                            style: style.expandedHintStyle,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Celebration over everything.
                if (_celebrating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: route,
                        child: _buildCelebration(context),
                      ),
                    ),
                  ),

                // Close button.
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: FadeTransition(
                        opacity: route,
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => host._close(),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                          ),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScrim(Size screen) {
    final style = config.style;
    final route = widget.routeAnimation;
    final tint = AnimatedBuilder(
      animation: route,
      builder: (context, _) {
        final t = route.value.clamp(0.0, 1.0);
        return ColoredBox(
          color: style.scrimColor.withValues(alpha: style.scrimColor.a * t),
        );
      },
    );

    final backdrop = _backdrop;
    final backdropSize = _backdropSize;
    final snapshotFits = backdrop != null &&
        backdropSize != null &&
        (backdropSize.width - screen.width).abs() < 1 &&
        (backdropSize.height - screen.height).abs() < 1;
    if (snapshotFits != _snapshotFits) {
      _snapshotFits = snapshotFits;
      // Changing overlay opacity rebuilds the overlay, so not during build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncCoverBelow());
    }
    if (snapshotFits) {
      // The pre-blurred page fades in over the sharp one. RawImage applies
      // the opacity in its own draw call, so no extra layer is created.
      return Stack(
        fit: StackFit.expand,
        children: [
          RawImage(
            image: backdrop,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            opacity: AnimationMin<double>(route, _backdropFade),
          ),
          tint,
        ],
      );
    }

    // Still capturing (the first few frames): tint only. The blur fades in
    // as soon as the snapshot is ready, which is cheaper than a live blur.
    final screenChanged = backdrop != null && !snapshotFits;
    if (!_backdropFailed && !screenChanged && style.scrimBlurSigma > 0) {
      return tint;
    }

    // Capturing failed or the screen was resized: the live blur.
    return AnimatedBuilder(
      animation: route,
      builder: (context, child) {
        final t = route.value.clamp(0.0, 1.0);
        final sigma = style.scrimBlurSigma * t;
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
      child: tint,
    );
  }

  Widget _buildCard(BuildContext context, Size size) {
    final style = config.style;
    final card = Hero(
      tag: host._heroTag,
      createRectTween: host._createRectTween,
      flightShuttleBuilder: host._buildShuttle,
      child: SizedBox.fromSize(
        size: size,
        child: _CardFace(
          style: style,
          radius: style.expandedBorderRadius,
          elevation: 1,
          child: _buildCardBody(context),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: _revealed
          ? '${style.title}, reward revealed'
          : '${style.title}, scratch card. Scratch to reveal your reward.',
      customSemanticsActions: _thresholdReached
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              const CustomSemanticsAction(label: 'Reveal reward'):
                  _revealProgrammatically,
            },
      child: card,
    );
  }

  Widget _buildCardBody(BuildContext context) {
    final Animation<double> popScale =
        _reduceMotion ? const AlwaysStoppedAnimation<double>(1) : _popScale;

    return Stack(
      fit: StackFit.expand,
      children: [
        ScaleTransition(
          scale: popScale,
          child: host._buildRewardSurface(context),
        ),
        if (!_coverRemoved) _buildCoverLayer(context),
        if (config.showScratchHint && !_scratchStarted && !_reduceMotion)
          IgnorePointer(child: _ScratchHint(animation: _hintController)),
      ],
    );
  }

  Widget _buildCoverLayer(BuildContext context) {
    final cover = host._buildCover(
      context,
      expanded: true,
      shimmer: _waiting && !_reduceMotion ? _waitController : null,
      shimmerSweepPortion: 1,
    );

    return FadeTransition(
      opacity: _coverOpacity,
      child: ScaleTransition(
        scale: _coverScale,
        child: IgnorePointer(
          ignoring: _thresholdReached,
          child: RepaintBoundary(
            child: Scratcher(
              key: _scratcherKey,
              brushSize: config.brushSize,
              threshold: config.revealThreshold,
              enabled: !_thresholdReached,
              enableHaptics: config.enableHaptics,
              onScratchStart: _onScratchStart,
              onProgress: _onProgress,
              onThreshold: _onThreshold,
              child: cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebration(BuildContext context) {
    final id = _celebrationId;
    final builder = config.celebrationBuilder;
    if (builder != null) {
      return KeyedSubtree(
        key: ValueKey<int>(id),
        child: builder(context, () => _completeCelebration(id)),
      );
    }
    return ConfettiBurst(
      key: ValueKey<int>(id),
      particleCount: config.confettiParticleCount,
      colors: config.confettiColors,
      duration: config.celebrationDuration,
      onComplete: () => _completeCelebration(id),
    );
  }
}

/// A finger icon swiping back and forth over the cover.
///
/// The icon and its blurred shadow are rasterized once; each frame only
/// moves that image with a paint-only translation (no layout, no re-blur).
class _ScratchHint extends StatelessWidget {
  const _ScratchHint({required this.animation});

  final Animation<double> animation;

  static const double _iconSize = 44;

  /// Room around the icon so the shadow blur isn't clipped by the snapshot.
  static const double _box = _iconSize + 32;

  static final SnapshotController _snapshotOn =
      SnapshotController(allowSnapshotting: true);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Align(
          alignment: Alignment.topLeft,
          child: AnimatedBuilder(
            animation: animation,
            child: SnapshotWidget(
              controller: _snapshotOn,
              mode: SnapshotMode.permissive,
              child: const SizedBox.square(
                dimension: _box,
                child: Center(
                  child: Icon(
                    Icons.touch_app_rounded,
                    size: _iconSize,
                    color: Colors.white,
                    shadows: [
                      Shadow(blurRadius: 10, color: Color(0x55000000)),
                    ],
                  ),
                ),
              ),
            ),
            builder: (context, child) {
              final v = animation.value;
              // Same path as Align(Alignment(x, y)) on the 44px icon.
              final x = math.sin(v * 2 * math.pi) * 0.45;
              final y = 0.62 + math.cos(v * 4 * math.pi) * 0.05;
              final cx = (x + 1) / 2 * (size.width - _iconSize) + _iconSize / 2;
              final cy =
                  (y + 1) / 2 * (size.height - _iconSize) + _iconSize / 2;
              return Transform.translate(
                offset: Offset(cx - _box / 2, cy - _box / 2),
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}
