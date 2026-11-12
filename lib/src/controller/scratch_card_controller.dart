part of '../scratch_card_widget.dart';

/// Drives a [ScratchCard] from code and reports its state.
///
/// Attach one controller to at most one card. If you create it, you also
/// dispose it.
///
/// ```dart
/// final controller = ScratchCardController();
/// ScratchCard(controller: controller, rewardChild: ...);
/// await controller.reveal(); // opens the card and reveals it with a celebration
/// controller.reset();        // brings the cover back
/// ```
class ScratchCardController extends ChangeNotifier {
  /// Creates a controller.
  ScratchCardController();

  ScratchCardStatus _status = ScratchCardStatus.idle;
  double _progress = 0;
  bool _isRevealed = false;
  _ScratchCardState<dynamic>? _host;

  /// Current stage of the card.
  ScratchCardStatus get status => _status;

  /// Scratched share of the cover, from 0.0 to 1.0 (1.0 once revealed).
  double get progress => _progress;

  /// Whether the reward has been revealed (or the card started scratched).
  bool get isRevealed => _isRevealed;

  /// Whether this controller is attached to a mounted [ScratchCard].
  bool get isAttached => _host != null;

  /// Whether the full-screen view is currently showing.
  bool get isOpen => _host?._route != null;

  /// Opens the full-screen view. Completes when the open animation ends.
  Future<void> open() => _host?._open() ?? Future<void>.value();

  /// Skips scratching and reveals the reward now, with the celebration. Opens
  /// the card first if needed. Doesn't fire `onThresholdReached`.
  Future<void> reveal() => _host?._reveal() ?? Future<void>.value();

  /// Closes the full-screen view. Completes when the close animation ends.
  Future<void> close() => _host?._close() ?? Future<void>.value();

  /// Restores the cover, sets progress to 0 and the status to
  /// [ScratchCardStatus.idle] (or [ScratchCardStatus.opened] if the card is
  /// open). A fetched reward is fetched again on the next open.
  void reset() {
    final host = _host;
    if (host != null) {
      host._reset();
      return;
    }
    _status = ScratchCardStatus.idle;
    _progress = 0;
    _isRevealed = false;
    notifyListeners();
  }

  void _attach(_ScratchCardState<dynamic> host) {
    assert(
      _host == null || identical(_host, host),
      'A ScratchCardController can only be attached to one ScratchCard at a '
      'time.',
    );
    _host = host;
  }

  void _detach(_ScratchCardState<dynamic> host) {
    if (identical(_host, host)) _host = null;
  }

  void _notify() => notifyListeners();
}
