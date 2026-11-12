# scratch_card: Developer Guide

A reward scratch card for Flutter. The user taps a card, it flies to full screen, they scratch a little, the rest of the cover clears itself, the reward pops in and a celebration plays. Every stage is reported through a callback, so you know exactly when to claim the reward.

This guide covers:

1. [Why use this package](#1-why-use-this-package)
2. [Performance: what is optimised and how](#2-performance-what-is-optimised-and-how)
3. [Installation](#3-installation)
4. [Implementation recipes](#4-implementation-recipes)
5. [`ScratchCard` reference: every parameter](#5-scratchcard-reference-every-parameter)
6. [`ScratchCardStyle` reference: every field](#6-scratchcardstyle-reference-every-field)
7. [Controller, statuses and callback order](#7-controller-statuses-and-callback-order)
8. [Building blocks for custom UIs](#8-building-blocks-for-custom-uis)
9. [Keeping your integration fast](#9-keeping-your-integration-fast)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Why use this package

- **Complete reward flow out of the box:** a collapsed card, a hero flight to full screen, a blurred scrim, scratching, an auto-reveal, a reward "pop", confetti and light rays, and a close flight back.
- **No third-party dependencies:** it uses the Flutter SDK only.
- **Safe reward claiming:** `onRevealed` fires exactly once, when the reward is fully visible. No callback fires after the card is disposed.
- **Async rewards built in:** `onFetchReward` starts loading when the card opens, so the request runs while the user scratches. Loading, error and retry states are handled for you.
- **Fully themeable:** about 30 visual tokens in `ScratchCardStyle`, or replace the cover and celebration entirely.
- **Controllable from code:** `open()`, `reveal()`, `close()` and `reset()` through `ScratchCardController`.
- **Accessible:** semantics labels, a screen-reader "Reveal reward" action, reduced-motion support and haptics.
- **Optimised rendering:** the package is built to keep the raster thread under budget. See the next section.

---

## 2. Performance: what is optimised and how

Scratch cards are deceptively expensive. A full-screen blur, a cover that is erased pixel by pixel, a shimmer that never stops and 120 confetti pieces can easily push the **raster thread** past the 16 ms frame budget. Each technique below targets one of those costs.

### 2.1 Idle shimmer that doesn't keep the app busy

| Problem | A looping shimmer animation on every card asks for a new frame 60 times a second, forever. The gloss is only visible about a third of the time, so most of those frames draw nothing new. |
| --- | --- |
| **What the package does** | The animation runs only during the visible sweep (about 1 s). The pause between sweeps is a plain `Timer`, so **no frames are produced while waiting**. |
| | All cards share one wall-clock cycle, so every sweep on screen lands in the **same** frames instead of each card waking the app at a different time. |
| | The shimmer stops completely while another route covers the card (including the card's own full-screen view). |

### 2.2 Cover artwork cached as an image

| Problem | The cover (gradient, stripes, badge, title, pill) is dozens of drawing operations, re-rasterized on every frame, for every card. |
| --- | --- |
| **What the package does** | The static artwork is rasterized **once** into an image (`SnapshotWidget`) and redrawn as a single textured quad. The shimmer is painted on top of that image, so animating it never re-rasterizes the artwork. |
| | `ScratchCardStyle` has value equality, so a parent rebuild with an equal style keeps the cached image. |

### 2.3 Scratch strokes that don't get slower over time

| Problem | Erasing by redrawing the entire scratch path every frame means the cost **grows with every stroke**: the longer the user scratches, the slower it gets. |
| --- | --- |
| **What the package does** | Only the newest strokes are kept as vectors. Every 48 segments they are **baked into a mask image**, and older strokes are erased in one textured draw. The per-frame cost stays flat however long the user scratches. |
| | Before the first touch, no offscreen layer is used at all. |
| | Progress is measured on a 30 × 30 grid, without reading pixels back from the GPU. |
| | Pointer moves only repaint the scratch layer. No widgets are rebuilt. |

### 2.4 Background blur computed once, not every frame

| Problem | A `BackdropFilter` behind the open card re-blurs the **entire screen** on every frame: every scratch move, every confetti frame. This is usually the single most expensive thing in the flow. |
| --- | --- |
| **What the package does** | When the card opens, the page behind it is captured once at quarter resolution, blurred once, and faded in as a plain image. |
| | If capturing isn't possible (for example the page contains a platform view), it falls back to the live blur automatically. |

### 2.5 The page underneath is not drawn while the card is open

| Problem | The full-screen view is a transparent route, so Flutter keeps painting the whole page below it every frame, even though the blurred image covers it completely. In a real app that page can be heavy. |
| --- | --- |
| **What the package does** | Once the card is fully open and the blurred image is fully opaque, the route tells the overlay that it covers everything below. Flutter then **skips painting the page** (it stays alive and keeps its state). The moment closing starts, the page is painted again, so the close animation looks exactly the same. |
| | This only applies when the page under the card keeps its state (`maintainState`, the default for normal pages), so the card's own page can never be disposed while open. |

The cost of the open card is therefore **independent of how complex your page is**.

### 2.6 Cheap celebration

| Problem | Confetti drawn as one call per piece (with save/transform/restore around each) means 120+ draw calls per frame. The sunburst fills an area larger than the screen with two gradients every frame. |
| --- | --- |
| **What the package does** | All confetti is drawn in **one** `drawVertices` call per frame. |
| | The sunburst glow and rays are rendered once into an image at half resolution. Each frame only rotates and fades that image. |

### 2.7 Small things that add up

- The scratch-hint finger and its blurred shadow are cached as an image and moved with a paint-only transform (no layout, no re-blur per frame).
- `onScratchProgress` is throttled to about 60 calls per second.
- The hero flight paints the cover directly instead of re-caching it on every frame of the size animation.

### 2.8 Measured results

These were measured in **profile mode** on an Android emulator (Pixel-class, API 37), running the same scripted sequence before and after the optimisations. Figures are the **median raster time per frame** and the share of frames over 16 ms.

| Phase | Before | After |
| --- | --- | --- |
| Idle grid (11 cards, nothing touched) | 16.4 ms, 47% janky, 48 frames/s | **2.1 ms, 0% janky**, about 19 frames/s (only during sweeps) |
| Opening a card | 19.2 ms, 60% janky | **2.1 ms, 0% janky** |
| Scratching | 16.0 ms, 33% janky (worst frame 105 ms) | **2.7 ms**, 5% janky |
| Celebration | 21.3 ms, 56% janky | **about 2.5 ms**, 0% janky |
| Closing | 16.5 ms, 47% janky | **about 3 ms, 0% janky** |

> **Note on emulators:** the Android emulator sometimes holds the raster thread at about 16 ms per frame regardless of what is drawn, while it waits for a display buffer. In testing, the same near-empty animation measured 2.3 ms in one run and 16.3 ms in the next. If DevTools shows a flat ~16 ms raster line on an emulator, confirm on a **real device** before treating it as a package cost. Always profile with `flutter run --profile`, never in debug mode.

---

## 3. Installation

The package is local, so add it as a path dependency in your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  scratch_card:
    path: ../scratch_card   # path relative to your app's folder
```

Then run:

```sh
flutter pub get
```

And import it:

```dart
import 'package:scratch_card/scratch_card.dart';
```

> After adding the dependency, do a **hot restart** (or a full run). Hot reload doesn't pick up new packages.

---

## 4. Implementation recipes

### 4.1 Minimal card with a fixed reward

```dart
ScratchCard(
  rewardChild: (context) => const Text('₹50 Cashback'),
  onRevealed: () => wallet.credit(50), // claim here
)
```

### 4.2 Reward loaded from your backend

Set the type parameter to your reward model so `rewardBuilder` receives it typed.

```dart
ScratchCard<Reward>(
  onFetchReward: () => api.fetchReward(orderId), // starts when the card opens
  rewardBuilder: (context, reward) => RewardView(reward: reward),
  onRewardError: (error, stack) => logger.error(error, stack),
  onRevealed: () => api.markClaimed(orderId),
)
```

What happens in each case:

- **The request finishes before the threshold:** the reveal is instant.
- **The user crosses the threshold first:** the cover shimmers until the reward arrives, then reveals it.
- **The request fails:** the error view ("Something went wrong. Tap to retry.") replaces the cover, and there is no celebration. Closing and reopening fetches again.

### 4.3 Already-claimed card

```dart
ScratchCard<Reward>(
  isScratched: true,
  initialReward: claimedReward, // no fetch needed
  rewardBuilder: (context, reward) => RewardView(reward: reward),
)
```

Set `openWhenScratched: false` if tapping a claimed card should do nothing.

### 4.4 A grid or list of cards

Cards fill their cell when the parent gives a fixed size (grid cells), and use `style.width × style.height` (180 × 170) otherwise.

```dart
GridView.count(
  crossAxisCount: 2,
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
  childAspectRatio: 180 / 170,
  padding: const EdgeInsets.all(16),
  children: [
    for (final offer in offers)
      ScratchCard<Reward>(
        key: ValueKey(offer.id), // keeps each card's state stable
        isScratched: offer.claimed,
        initialReward: offer.claimed ? offer.reward : null,
        onFetchReward: () => api.scratch(offer.id),
        rewardBuilder: (context, reward) => RewardView(reward: reward),
        onRevealed: () => api.markClaimed(offer.id),
      ),
  ],
)
```

### 4.5 Driving the card from code

```dart
class _RewardsPageState extends State<RewardsPage> {
  final _controller = ScratchCardController();

  @override
  void dispose() {
    _controller.dispose(); // you created it, you dispose it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScratchCard(
          controller: _controller,
          rewardChild: (_) => const Text('Free delivery'),
        ),
        TextButton(
          onPressed: _controller.reveal, // open + reveal + celebrate
          child: const Text('Reveal for me'),
        ),
      ],
    );
  }
}
```

### 4.6 Theming

```dart
ScratchCard(
  style: const ScratchCardStyle(
    title: 'Festive reward',
    icon: Icons.auto_awesome_rounded,
    gradientColors: [Color(0xFF8E7BFF), Color(0xFF5B5BEA), Color(0xFF3949AB)],
    shadowColor: Color(0x593949AB),
    collapsedLabel: 'TAP TO OPEN',
    expandedLabel: 'SCRATCH ME',
  ),
  rewardChild: (_) => const Text('250 coins'),
)
```

> Use `const` styles (or keep one style instance) where you can. An equal style keeps the cached cover image. See [§9](#9-keeping-your-integration-fast).

### 4.7 Custom cover

```dart
ScratchCard(
  coverBuilder: (context, expanded) => DecoratedBox(
    decoration: const BoxDecoration(color: Colors.blueGrey),
    child: Center(child: Text(expanded ? 'Scratch here' : 'Tap to open')),
  ),
  rewardChild: (_) => const Text('10% OFF'),
)
```

**Rule:** the cover must not contain `Opacity`, `RepaintBoundary`, `ShaderMask`, platform views or other widgets that create their own compositing layer. Those can't be erased, and the cover will be drawn unscratchable (a warning is printed in debug mode).

### 4.8 Custom celebration (Lottie, Rive, ...)

```dart
ScratchCard(
  celebrationBuilder: (context, onComplete) => Lottie.asset(
    'assets/confetti.json',
    repeat: false,
    onLoaded: (composition) =>
        Future.delayed(composition.duration, onComplete),
  ),
  rewardChild: (_) => const Text('Jackpot!'),
)
```

Always call `onComplete`. `onCelebrationComplete` waits for it.

---

## 5. `ScratchCard` reference: every parameter

`ScratchCard<T>`: `T` is the type returned by `onFetchReward`. Use `ScratchCard<Object?>` (or omit `T`) for fixed rewards.

### 5.1 Reward content

| Parameter | Type | Default | What it does |
| --- | --- | --- | --- |
| `rewardChild` | `WidgetBuilder?` | `null` | A fixed reward. Used when there is no `onFetchReward`, or when `rewardBuilder` is null. |
| `rewardBuilder` | `RewardWidgetBuilder<T>?` | `null` | `(context, reward) => Widget`. Builds the reward from the value returned by `onFetchReward` (or `initialReward`). |
| `onFetchReward` | `Future<T> Function()?` | `null` | Loads the reward. Called as soon as the card **opens**, so it runs while the user scratches. |
| `initialReward` | `T?` | `null` | A reward that is already known, so no fetch is needed. Typically used with `isScratched`. |
| `rewardLoadingBuilder` | `WidgetBuilder?` | small spinner | Shown under the cover while `onFetchReward` is pending. |
| `rewardErrorBuilder` | `RewardErrorWidgetBuilder?` | "Something went wrong. Tap to retry." | `(context, error, retry) => Widget`. Shown when `onFetchReward` throws. Call `retry` to fetch again. |

If none of `rewardChild` / `rewardBuilder` is given, a default "Reward unlocked!" view is shown.

### 5.2 Behaviour

| Parameter | Type | Default | What it does |
| --- | --- | --- | --- |
| `controller` | `ScratchCardController?` | `null` | Drives the card from code and exposes its state. One controller per card. |
| `revealThreshold` | `double` | `0.35` | Share of the cover (0.05–1.0) the user must scratch before the rest clears automatically. Lower values are friendlier. 1.0 is very hard to reach with a finger. |
| `brushSize` | `double` | `40` | Width of the scratch stroke, in logical pixels. Bigger means a faster reveal. |
| `isScratched` | `bool` | `false` | The reward was already claimed: show it immediately, with no cover, no scratching and no celebration. |
| `openWhenScratched` | `bool` | `true` | Whether tapping an already-scratched card still opens the full-screen view. |
| `barrierDismissible` | `bool` | `true` | Whether tapping the dark scrim or pressing system back closes the full-screen view. The close (✕) button always works. |
| `expandedSize` | `Size?` | square of `min(360, screenWidth − 48)` | Size of the card in the full-screen view. It is shrunk automatically to fit small screens. |
| `enableHaptics` | `bool` | `true` | A light tick on the first touch and every 10% of progress, and a medium bump on reveal. |
| `showIdleShimmer` | `bool` | `true` | A gloss sweep across the collapsed card about every 3 seconds. Set `false` to make the idle screen fully static. |
| `showScratchHint` | `bool` | `true` | An animated finger on the expanded card until the user starts scratching. |
| `heroTag` | `Object?` | unique per card | Hero tag linking the collapsed and expanded card. Only set it if you need a specific tag. It must be unique on the screen. |
| `semanticLabel` | `String?` | `"<title>, scratch card, tap to open"` | Screen-reader label of the collapsed card. |

### 5.3 Celebration

| Parameter | Type | Default | What it does |
| --- | --- | --- | --- |
| `celebrationType` | `CelebrationType` | `confettiAndRays` | `confetti`, `confettiAndRays` or `none`. Ignored when `celebrationBuilder` is set. |
| `confettiColors` | `List<Color>` | gold, orange, pink, teal, purple, white | Colours picked at random for the confetti pieces. |
| `confettiParticleCount` | `int` | `120` | Number of confetti pieces (≥ 0). |
| `celebrationDuration` | `Duration` | `2.5 s` | Length of the built-in celebration. |
| `celebrationBuilder` | `CelebrationWidgetBuilder?` | `null` | `(context, onComplete) => Widget`. Replaces the built-in celebration (Lottie, Rive, ...). You must call `onComplete` when it ends. |

The celebration is skipped automatically when the system's reduce-motion setting is on.

### 5.4 Appearance

| Parameter | Type | Default | What it does |
| --- | --- | --- | --- |
| `style` | `ScratchCardStyle` | `ScratchCardStyle()` | All visual tokens: colours, texts, icon, sizes, radii, scrim and animation duration. See [§6](#6-scratchcardstyle-reference-every-field). |
| `coverBuilder` | `ScratchCoverBuilder?` | `null` | `(context, expanded) => Widget`. Replaces the built-in cover. `expanded` is `true` in the full-screen view. No compositing widgets inside (see [§4.7](#47-custom-cover)). |

### 5.5 Callbacks

| Callback | Signature | When it fires |
| --- | --- | --- |
| `onTap` | `VoidCallback` | The collapsed card was tapped, before it expands. |
| `onOpened` | `VoidCallback` | The open animation has finished. |
| `onScratchStart` | `VoidCallback` | The first touch landed on the cover. |
| `onScratchProgress` | `void Function(double progress)` | The scratched share (0.0–1.0) changed. Throttled to about 60 calls/s. |
| `onThresholdReached` | `VoidCallback` | The user crossed `revealThreshold` and the auto-reveal is starting. **Not** fired for `controller.reveal()`. |
| `onRevealed` | `VoidCallback` | The reward is fully visible. **Claim the reward here.** Fires once. |
| `onCelebrationComplete` | `VoidCallback` | The celebration has finished. Always after `onRevealed`. |
| `onClosed` | `VoidCallback` | The full-screen view was dismissed (close button, scrim, back or controller). |
| `onStatusChanged` | `ValueChanged<ScratchCardStatus>` | Every status change. See [§7.2](#72-statuses). |
| `onRewardError` | `void Function(Object error, StackTrace stack)` | `onFetchReward` threw. |

---

## 6. `ScratchCardStyle` reference: every field

All fields are optional. The defaults reproduce the orange "Order reward" design. Use `copyWith` to tweak one field of an existing style.

### 6.1 Size and shape

| Field | Default | What it does |
| --- | --- | --- |
| `width` | `180` | Preferred width of the collapsed card. A parent that forces a size (like a grid cell) wins. |
| `height` | `170` | Preferred height of the collapsed card. |
| `borderRadius` | `20` | Corner radius of the collapsed card. |
| `expandedBorderRadius` | `28` | Corner radius of the full-screen card. |

### 6.2 Cover background

| Field | Default | What it does |
| --- | --- | --- |
| `gradientColors` | `[#FFB547, #F7931E, #F57C00]` | Cover gradient (two or more colours). The middle colour is also used as the accent for the default loading spinner and reward icon. |
| `gradientBegin` | `Alignment.topLeft` | Where the gradient starts. |
| `gradientEnd` | `Alignment.bottomRight` | Where the gradient ends. |
| `stripeColor` | `#17FFFFFF` (white, 9%) | Colour of the diagonal stripes. Use a transparent colour to hide them. |
| `stripeWidth` | `10` | Width of each stripe at the collapsed size (scaled when expanded). |
| `stripeGap` | `10` | Gap between stripes at the collapsed size. |

### 6.3 Badge and icon

| Field | Default | What it does |
| --- | --- | --- |
| `icon` | `Icons.card_giftcard_rounded` | Icon inside the round badge. |
| `iconColor` | `Colors.white` | Icon colour. |
| `iconSize` | `28` | Icon size at the collapsed size. |
| `badgeSize` | `56` | Diameter of the round badge at the collapsed size. |
| `badgeColor` | `#40FFFFFF` | Badge fill. |
| `badgeBorderColor` | `#80FFFFFF` | Badge border colour. |
| `badgeBorderWidth` | `1.5` | Badge border width. |

### 6.4 Texts

| Field | Default | What it does |
| --- | --- | --- |
| `title` | `'Order reward'` | Title under the badge. Also used in screen-reader labels. |
| `collapsedLabel` | `'TAP TO SCRATCH'` | Pill text on the collapsed card. |
| `expandedLabel` | `'SCRATCH HERE'` | Pill text on the full-screen card. |
| `titleStyle` | white, 18, w700 | Title text style at the collapsed size (scaled up when expanded). |
| `labelStyle` | white, 12, w600, letter-spacing 1.2 | Pill text style at the collapsed size. |
| `pillColor` | `#33FFFFFF` | Fill behind the pill label. |
| `expandedHintText` | `'Scratch the card to reveal your reward'` | Helper text under the full-screen card before the reveal. `null` hides it. |
| `expandedHintStyle` | white 90%, 14, w500 | Style of `expandedHintText`. |

### 6.5 Shadow, reward and scrim

| Field | Default | What it does |
| --- | --- | --- |
| `shadowColor` | `#59FF9800` | Card drop-shadow colour. |
| `shadowBlurRadius` | `16` | Drop-shadow blur (grows a little when expanded). |
| `shadowOffset` | `Offset(0, 6)` | Drop-shadow offset. |
| `rewardBackgroundColor` | `Colors.white` | Background behind the reward content. |
| `scrimColor` | `#99000000` (black, 60%) | Colour of the full-screen scrim behind the open card. |
| `scrimBlurSigma` | `8` | Blur strength of the page behind the scrim. `0` disables the blur (and the snapshot work). |

### 6.6 Animation

| Field | Default | What it does |
| --- | --- | --- |
| `openDuration` | `450 ms` | Duration of the open and close flight. |

---

## 7. Controller, statuses and callback order

### 7.1 `ScratchCardController`

A `ChangeNotifier`, so you can `addListener` or use it with `ListenableBuilder`. Attach it to **one** card at a time, and dispose it if you created it.

| Member | What it does |
| --- | --- |
| `Future<void> open()` | Opens the full-screen view. Completes when the open animation ends. |
| `Future<void> reveal()` | Skips scratching: opens the card if needed, reveals the reward and plays the celebration. Doesn't fire `onThresholdReached`. |
| `Future<void> close()` | Closes the full-screen view. Completes when the close animation ends. |
| `void reset()` | Restores the cover and sets progress to 0. The status becomes `idle`, or `opened` if the card is open. A fetched reward is fetched again on the next open. |
| `ScratchCardStatus status` | The current stage. |
| `double progress` | Scratched share, 0.0–1.0 (1.0 once revealed). |
| `bool isRevealed` | Whether the reward has been revealed (or the card started scratched). |
| `bool isOpen` | Whether the full-screen view is showing. |
| `bool isAttached` | Whether the controller is attached to a mounted card. |

### 7.2 Statuses

`ScratchCardStatus`, in the order a typical session goes:

| Status | Meaning |
| --- | --- |
| `idle` | The collapsed card is waiting to be tapped. |
| `opening` | The card is flying to full screen. |
| `opened` | The full-screen card is showing and nothing has been scratched yet. |
| `scratching` | The user has started scratching. |
| `revealing` | The threshold was crossed (or `reveal()` was called) and the cover is clearing. The reward may still be loading. |
| `revealed` | The reward is fully visible. |
| `closing` | The full-screen view is animating back. |
| `closed` | The full-screen view has been dismissed. |

### 7.3 Callback order

```
onTap ─► onOpened ─► onScratchStart ─► onScratchProgress… ─► onThresholdReached
      ─► onRevealed ─► onCelebrationComplete ─► onClosed
```

- **Claim the reward in `onRevealed`.** It fires once, when the reward is actually visible.
- Don't claim in `onThresholdReached`: with an async reward, the reward may not have loaded yet.
- If the user closes the card before reaching the threshold, progress resets to 0 and the full cover is back the next time it opens.

---

## 8. Building blocks for custom UIs

These are exported for standalone use.

### `Scratcher`: a raw scratch layer

Put what should be revealed **behind** it (for example in a `Stack`) and pass the cover as `child`.

| Parameter | Default | What it does |
| --- | --- | --- |
| `child` | required | The cover that gets scratched away. No compositing widgets inside. |
| `brushSize` | `40` | Stroke width. |
| `threshold` | `null` | Progress (0.0–1.0) at which `onThreshold` fires once. After that, input is ignored. `null` means never. |
| `enabled` | `true` | Whether pointer input is accepted. |
| `gridSize` | `30` | Resolution of the progress grid (cells per side). |
| `enableHaptics` | `true` | A light tick on the first touch and every 10%. |
| `progressInterval` | `16 ms` | Minimum time between two `onProgress` calls. |
| `onScratchStart` | — | First touch. |
| `onProgress` | — | `(double progress)`, throttled. |
| `onThreshold` | — | `threshold` reached. |
| `onScratchEnd` | — | A finger lifted. |

Use a `GlobalKey<ScratcherState>` to call `reset()`, or to read `progress` and `thresholdReached`.

### `ScratchCardCover`: the default cover design

`style`, `label`, `shimmer` (an `Animation<double>` driving the gloss), `shimmerSweepPortion`, and `cache` (default `true`: cache the artwork as an image; turn it off only if the size animates every frame).

### `ConfettiBurst`: a one-shot confetti widget

`particleCount` (120), `colors`, `duration` (2.5 s), `origin` (`Alignment.center`), `gravity` (1100), `seed` (for repeatable bursts, for example in golden tests), `onComplete`. Insert it with a new `Key` to play it again.

### `SunburstRays`: a one-shot rotating glow

`duration` (2.5 s), `color` (`#FFD54F`), `rayCount` (14), `radius` (default 60% of the shortest side), `center`, `onComplete`.

### `ScratchProgressTracker`: the coverage estimator

`ScratchProgressTracker(size:, brushRadius:, gridSize: 30)`, with `addPoint`, `addSegment`, `progress`, `scratchedCells`, `totalCells` and `reset()`.

---

## 9. Keeping your integration fast

The package is optimised, but the code around it can still undo that. Check these points:

1. **Don't `setState` your whole page on every `onScratchProgress`.** It fires up to 60 times a second. If you show progress, rebuild only a small widget (a `ValueNotifier` with a `ValueListenableBuilder`), or react only to steps (every 10%).
2. **Use `const` or stable styles.** `style: const ScratchCardStyle(...)`, or a style stored in a field. An equal style keeps the cached cover. A new, different style per build forces a re-cache.
3. **Keep custom covers free of compositing widgets.** No `Opacity`, `RepaintBoundary`, `ShaderMask`, `BackdropFilter`, video or platform views inside `coverBuilder`.
4. **Keep reward widgets light.** The reward pops in with a scale animation. Avoid heavy blurs or large network images that decode during the reveal (pre-cache images with `precacheImage` if needed).
5. **Give cards in lists a stable `key`.** Each card keeps its own state, controller binding and cached images.
6. **Host cards in normal pages.** Pages that keep their state (the default for `MaterialPageRoute`) let the package skip painting them while a card is open.
7. **Set `showIdleShimmer: false`** on screens that must be fully static (for example long lists where battery matters most).
8. **Profile properly.** Use `flutter run --profile` on a **real device**. Debug mode is several times slower, and emulators can show a fake ~16 ms raster time (see [§2.8](#28-measured-results)).

---

## 10. Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| The cover can't be scratched. A debug message says "needs compositing". | `coverBuilder` contains `Opacity`, `RepaintBoundary` or similar. Remove it, or bake the effect into colours. |
| `onRevealed` never fires after scratching. | The reward is still loading (`onFetchReward` hasn't completed), or it failed. Check `onRewardError`. |
| The reveal happens too early or too late. | Tune `revealThreshold` (0.05–1.0) and `brushSize`. |
| The blurred background doesn't show updates while the card is open. | Expected: the background is captured once when the card opens (see [§2.4](#24-background-blur-computed-once-not-every-frame)). It updates again when the card closes. |
| "A ScratchCardController can only be attached to one ScratchCard". | Create one controller per card. |
| The raster graph shows a flat ~16 ms on the emulator. | An emulator display artifact. Verify on a real device in profile mode. |
| A newly added package isn't found after `pub get`. | Do a hot restart or a full run. Hot reload doesn't load new packages. |
