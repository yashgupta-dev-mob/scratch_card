part of 'scratch_card_widget.dart';

/// A transparent full-screen route that hosts the expanded card. The card
/// flies in through a [Hero] shared with the collapsed card.
class _ScratchCardRoute<T> extends PageRouteBuilder<void> {
  _ScratchCardRoute({required _ScratchCardState<T> host})
      : super(
          opaque: false,
          barrierDismissible: false,
          maintainState: true,
          transitionDuration: host.widget.style.openDuration,
          reverseTransitionDuration: host.widget.style.openDuration,
          pageBuilder: (context, animation, secondaryAnimation) =>
              _ScratchCardExpandedPage<T>(
            host: host,
            routeAnimation: animation,
          ),
        );

  /// Marks the page entry as covering everything below it, so the overlay
  /// stops painting the routes underneath (they stay alive and laid out,
  /// because they keep their state).
  ///
  /// Only valid while the expanded view paints a fully opaque backdrop. Must
  /// not be called during build: the overlay rebuilds in response.
  void setCoversBelow(bool value) {
    if (overlayEntries.isEmpty) return;
    final page = overlayEntries.last;
    if (page.opaque != value) page.opaque = value;
  }
}
