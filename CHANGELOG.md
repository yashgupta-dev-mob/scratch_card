## 0.1.0

* First release.
* `ScratchCard` with the orange "Order reward" design, an idle shimmer and press feedback.
* Tap to open: a Hero flight to a full-screen view over a blurred scrim.
* Scratch layer built on `saveLayer` + `BlendMode.clear`, with grid-based progress tracking.
* Auto-reveal after `revealThreshold` (35% by default), with an elastic reward pop and haptics.
* Confetti burst and sunburst rays, or a custom `celebrationBuilder`. Reduced motion is respected.
* Async rewards through `onFetchReward`, with loading, error and retry states.
* `ScratchCardController` with `open`, `reveal`, `close` and `reset`.
* Callbacks: `onTap`, `onOpened`, `onScratchStart`, `onScratchProgress`, `onThresholdReached`, `onRevealed`, `onCelebrationComplete`, `onClosed`, `onStatusChanged`, `onRewardError`.
* Building blocks exported for standalone use: `Scratcher`, `ScratchCardCover`, `ConfettiBurst`, `SunburstRays` and `ScratchProgressTracker`.
