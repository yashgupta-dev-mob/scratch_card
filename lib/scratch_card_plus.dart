/// A reward scratch card for Flutter.
///
/// Tap the card to open it full screen. Scratch a little and the rest of the
/// cover clears itself, the reward pops in and confetti plays. Every stage is
/// reported through callbacks and can be driven with a
/// [ScratchCardController].
library;

export 'src/celebration/confetti_burst.dart' show ConfettiBurst;
export 'src/celebration/sunburst_rays.dart' show SunburstRays;
export 'src/cover/scratch_card_cover.dart' show ScratchCardCover;
export 'src/models/celebration_type.dart';
export 'src/models/scratch_card_status.dart';
export 'src/models/scratch_card_style.dart';
export 'src/scratch_card_widget.dart'
    show
        CelebrationWidgetBuilder,
        RewardErrorWidgetBuilder,
        RewardWidgetBuilder,
        ScratchCard,
        ScratchCardController,
        ScratchCoverBuilder,
        ScratchProgressCallback;
export 'src/scratcher/scratch_progress.dart' show ScratchProgressTracker;
export 'src/scratcher/scratcher.dart' show Scratcher, ScratcherState;
