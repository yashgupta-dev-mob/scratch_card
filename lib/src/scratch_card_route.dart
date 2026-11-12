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
}
