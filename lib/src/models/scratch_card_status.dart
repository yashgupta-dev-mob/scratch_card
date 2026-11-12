/// The lifecycle stages a scratch card moves through.
///
/// A typical session goes:
/// [idle] → [opening] → [opened] → [scratching] → [revealing] → [revealed]
/// → [closing] → [closed].
enum ScratchCardStatus {
  /// The collapsed card is waiting to be tapped.
  idle,

  /// The card is flying from its spot in the layout to full screen.
  opening,

  /// The expanded card is on screen and nothing has been scratched yet.
  opened,

  /// The user has started scratching the cover.
  scratching,

  /// The reveal threshold was crossed (or `reveal()` was called) and the
  /// cover is being cleared. The reward may still be loading.
  revealing,

  /// The reward is fully visible.
  revealed,

  /// The expanded view is animating back to the collapsed card.
  closing,

  /// The expanded view has been dismissed.
  closed,
}
