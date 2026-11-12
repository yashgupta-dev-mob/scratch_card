# scratch_card

A reward scratch card for Flutter. Tap the card and it flies to full screen. Scratch a little and the rest of the cover clears by itself, the reward pops in and confetti plays. Every stage is reported through a callback.

<!-- Add a demo GIF here: ![demo](doc/demo.gif) -->

Built with the Flutter SDK only. It has no third-party dependencies.

## Features

- **Ready-made design:** an orange gradient, faint diagonal stripes, a gift badge, an "Order reward" title and a "TAP TO SCRATCH" pill. Everything can be themed through `ScratchCardStyle`.
- **Full-screen open:** a Hero flight from the card's spot to a large centred card, over a blurred dark scrim. Closing reverses the flight.
- **Smooth scratching:** only the painter repaints on each pointer move. Nothing is rebuilt.
- **Auto-reveal:** once `revealThreshold` (35% by default) is scratched, the cover fades away and the reward pops in with an elastic bounce.
- **Celebration:** confetti plus rotating light rays, or your own Lottie or Rive animation through `celebrationBuilder`.
- **Async rewards:** `onFetchReward` starts when the card opens, with loading, error and retry states.
- **Controller:** `open()`, `reveal()`, `close()` and `reset()`.
- **Accessibility:** semantics labels, a screen-reader "Reveal reward" action, reduced-motion support and haptics.

## Quick start

```dart
import 'package:scratch_card/scratch_card.dart';

ScratchCard(
  rewardChild: (context) => const Text('₹50 Cashback'),
  onRevealed: () => claimReward(),
)
```

### Reward from your backend

```dart
ScratchCard<Reward>(
  onFetchReward: () => api.fetchReward(orderId),      // starts when the card opens
  rewardBuilder: (context, reward) => RewardView(reward),
  onRewardError: (error, stack) => log(error),
  onRevealed: () => api.markClaimed(orderId),
)
```

If the user scratches past the threshold before the request finishes, the cover keeps shimmering until the reward arrives, then reveals it. If the request fails, the error view (with "Tap to retry") replaces the cover, and there is no celebration.

### Already-claimed cards

```dart
ScratchCard(isScratched: true, rewardChild: (_) => const Text('10% OFF'))
```

## Callback order

```
onTap ─► onOpened ─► onScratchStart ─► onScratchProgress… ─► onThresholdReached
      ─► onRevealed ─► onCelebrationComplete ─► onClosed
```

| Callback | When it fires |
| --- | --- |
| `onTap` | The collapsed card was tapped, before it expands. |
| `onOpened` | The expand animation has finished. |
| `onScratchStart` | The first touch landed on the cover. |
| `onScratchProgress(double)` | The scratched share (0.0–1.0) changed. Throttled to about 60 calls per second. |
| `onThresholdReached` | The user crossed `revealThreshold` and the auto-reveal is starting. Not fired for `controller.reveal()`. |
| `onRevealed` | The reward is fully visible. **Claim the reward here.** |
| `onCelebrationComplete` | The celebration has finished. Always fires after `onRevealed`. |
| `onClosed` | The expanded view was dismissed (close button, scrim, back or controller). |
| `onStatusChanged(ScratchCardStatus)` | Every status change. |
| `onRewardError(error, stack)` | `onFetchReward` threw. |

Statuses: `idle → opening → opened → scratching → revealing → revealed → closing → closed`.

No callback fires after the card is disposed.

## Controller

```dart
final controller = ScratchCardController();

ScratchCard(controller: controller, rewardChild: ...);

await controller.open();    // expand
await controller.reveal();  // skip scratching: open if needed, reveal and celebrate
await controller.close();   // collapse
controller.reset();         // bring the cover back, progress = 0

controller.status;      // ScratchCardStatus
controller.progress;    // 0.0–1.0
controller.isRevealed;
controller.isOpen;
```

`ScratchCardController` is a `ChangeNotifier`, so you can listen to it. Dispose it when you're done.

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `controller` | `null` | Optional `ScratchCardController`. |
| `style` | `ScratchCardStyle()` | Colours, texts, icon, sizes, radii, scrim and open duration. |
| `coverBuilder` | `null` | Replaces the cover. It must not contain `Opacity`, `RepaintBoundary` or platform views, or it can't be scratched. |
| `rewardChild` | `null` | A fixed reward. |
| `rewardBuilder` | `null` | Builds the reward from the value `onFetchReward` returns. |
| `rewardLoadingBuilder` | spinner | Shown while the reward loads. |
| `rewardErrorBuilder` | "Something went wrong. Tap to retry." | Shown on failure. Gets a `retry` callback. |
| `initialReward` | `null` | An already-known reward, so no fetch is needed. |
| `onFetchReward` | `null` | Loads the reward when the card opens. |
| `expandedSize` | `min(screenWidth − 48, 360)` square | Size of the full-screen card. Shrunk to fit small screens. |
| `brushSize` | `40` | Scratch stroke width. |
| `revealThreshold` | `0.35` | Share (0.05–1.0) to scratch before the auto-reveal. |
| `isScratched` | `false` | Show the reward immediately. |
| `openWhenScratched` | `true` | Whether a scratched card can still open full screen. |
| `barrierDismissible` | `true` | Whether a scrim tap or system back closes the view. The close button always works. |
| `enableHaptics` | `true` | Haptic ticks while scratching and a bump on reveal. |
| `showIdleShimmer` | `true` | A gloss sweep across the collapsed card every 3 seconds. |
| `showScratchHint` | `true` | An animated finger on the expanded card until the user scratches. |
| `celebrationType` | `confettiAndRays` | `confetti`, `confettiAndRays` or `none`. |
| `confettiColors` | gold, orange, pink, teal, purple, white | Confetti colours. |
| `confettiParticleCount` | `120` | Number of confetti pieces. |
| `celebrationDuration` | `2.5s` | Length of the built-in celebration. |
| `celebrationBuilder` | `null` | `(context, onComplete) => Widget`. Plug in Lottie or Rive here and call `onComplete` when it ends. |
| `heroTag` | unique per card | Hero tag for the open and close flight. |
| `semanticLabel` | "<title>, scratch card, tap to open" | Screen-reader label. |

The collapsed card uses `style.width × style.height` (180 × 170) when its parent allows it. When the parent forces a size, such as a grid cell, it fills that size and scales its content.

## Building blocks

These are exported for standalone use:

- `Scratcher`: a raw scratch layer with `onProgress`, `onThreshold` and `reset()` through a `GlobalKey<ScratcherState>`.
- `ScratchCardCover`: the default cover design.
- `ConfettiBurst` and `SunburstRays`: one-shot celebration widgets.
- `ScratchProgressTracker`: the grid-based coverage estimator.

## Example

`example/` is a rewards screen with six cards: static, async, failing then retrying, already claimed, purple theme and no celebration. It has a live log that prints every callback, and toolbar buttons that call `reveal()` and `reset()`.

```sh
cd example
flutter run
```
