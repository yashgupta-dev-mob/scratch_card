import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'scratch_painter.dart';
import 'scratch_progress.dart';

/// A raw scratch layer: drag a finger over [child] to erase it.
///
/// Usable without `ScratchCard`. Put whatever should be revealed *behind*
/// this widget (for example in a `Stack`), and pass the cover as [child].
///
/// The cover must not create compositing layers. See [ScratchLayer].
class Scratcher extends StatefulWidget {
  /// Creates a scratcher.
  const Scratcher({
    super.key,
    required this.child,
    this.brushSize = 40,
    this.threshold,
    this.enabled = true,
    this.gridSize = 30,
    this.enableHaptics = true,
    this.progressInterval = const Duration(milliseconds: 16),
    this.onScratchStart,
    this.onProgress,
    this.onThreshold,
    this.onScratchEnd,
  })  : assert(brushSize > 0),
        assert(threshold == null || (threshold >= 0 && threshold <= 1));

  /// The cover that gets scratched away.
  final Widget child;

  /// Stroke width of the eraser.
  final double brushSize;

  /// Progress (0.0–1.0) at which [onThreshold] fires once. After that, input
  /// is ignored. `null` means never.
  final double? threshold;

  /// Whether pointer input is accepted.
  final bool enabled;

  /// Resolution of the progress grid. See [ScratchProgressTracker].
  final int gridSize;

  /// Plays a light haptic tick on the first touch and every 10% of progress.
  final bool enableHaptics;

  /// Minimum time between two [onProgress] calls.
  final Duration progressInterval;

  /// Called on the first touch.
  final VoidCallback? onScratchStart;

  /// Called with the scratched share (0.0–1.0), throttled by
  /// [progressInterval].
  final ValueChanged<double>? onProgress;

  /// Called once when progress reaches [threshold].
  final VoidCallback? onThreshold;

  /// Called when a finger lifts.
  final VoidCallback? onScratchEnd;

  @override
  State<Scratcher> createState() => ScratcherState();
}

/// State for [Scratcher]. Reach it with a `GlobalKey<ScratcherState>` to call
/// [reset] or read [progress].
class ScratcherState extends State<Scratcher> {
  final ScratchPath _path = ScratchPath();
  final Stopwatch _clock = Stopwatch()..start();
  ScratchProgressTracker? _tracker;
  int? _activePointer;
  Offset? _last;
  bool _started = false;
  bool _thresholdReached = false;
  Duration? _lastEmit;
  double _lastEmittedProgress = -1;
  int _lastHapticStep = 0;

  /// Scratched share, 0.0–1.0.
  double get progress => _tracker?.progress ?? 0;

  /// Whether [Scratcher.threshold] has been reached.
  bool get thresholdReached => _thresholdReached;

  /// Restores the full cover and clears progress.
  void reset() {
    _path.clear();
    _tracker?.reset();
    _activePointer = null;
    _last = null;
    _started = false;
    _thresholdReached = false;
    _lastEmit = null;
    _lastEmittedProgress = -1;
    _lastHapticStep = 0;
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  ScratchProgressTracker? _ensureTracker() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return null;
    final tracker = _tracker;
    if (tracker == null ||
        tracker.size != box.size ||
        tracker.brushRadius != widget.brushSize / 2 ||
        tracker.gridSize != widget.gridSize) {
      _path.clear();
      return _tracker = ScratchProgressTracker(
        size: box.size,
        brushRadius: widget.brushSize / 2,
        gridSize: widget.gridSize,
      );
    }
    return tracker;
  }

  void _handleDown(PointerDownEvent event) {
    if (!widget.enabled || _thresholdReached || _activePointer != null) return;
    if (_ensureTracker() == null) return;
    _activePointer = event.pointer;
    _last = null;
    if (!_started) {
      _started = true;
      if (widget.enableHaptics) HapticFeedback.selectionClick();
      widget.onScratchStart?.call();
      if (!mounted) return;
    }
    _addPoint(event.localPosition);
  }

  void _handleMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    if (!widget.enabled || _thresholdReached) return;
    _addPoint(event.localPosition);
  }

  void _handleUp(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _last = null;
    _emitProgress(force: true);
    widget.onScratchEnd?.call();
  }

  void _addPoint(Offset point) {
    final tracker = _tracker;
    if (tracker == null) return;
    if (!(Offset.zero & tracker.size).contains(point)) {
      // Leaving the card breaks the stroke. Re-entering starts a new one.
      _last = null;
      return;
    }
    final last = _last;
    if (last == null) {
      _path.moveTo(point);
      tracker.addPoint(point);
    } else {
      _path.lineTo(point);
      tracker.addSegment(last, point);
    }
    _last = point;
    _afterProgressChanged();
  }

  void _afterProgressChanged() {
    final value = progress;
    final threshold = widget.threshold;
    final crossed = threshold != null && value >= threshold;

    _emitProgress(force: crossed);

    final step = (value * 10).floor();
    if (step > _lastHapticStep) {
      _lastHapticStep = step;
      if (widget.enableHaptics && !crossed) HapticFeedback.selectionClick();
    }

    if (crossed && !_thresholdReached) {
      _thresholdReached = true;
      _activePointer = null;
      _last = null;
      widget.onThreshold?.call();
    }
  }

  void _emitProgress({bool force = false}) {
    if (_thresholdReached) return;
    final value = progress;
    if (value == _lastEmittedProgress) return;
    final now = _clock.elapsed;
    final lastEmit = _lastEmit;
    if (!force &&
        lastEmit != null &&
        now - lastEmit < widget.progressInterval) {
      return;
    }
    _lastEmit = now;
    _lastEmittedProgress = value;
    widget.onProgress?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: _handleUp,
      child: ScratchLayer(
        scratchPath: _path,
        brushSize: widget.brushSize,
        child: widget.child,
      ),
    );
  }
}
