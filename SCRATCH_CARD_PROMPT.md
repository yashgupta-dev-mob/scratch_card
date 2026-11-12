# Prompt: Build the `scratch_card` Flutter package

You are working in an existing, freshly scaffolded Flutter **package** project named `scratch_card` (only `lib/scratch_card.dart` exists so far; Dart SDK `^3.13.4`). Build a production-quality, reusable scratch-card package with:

1. A compact reward card (design below).
2. Tap the card → it animates from its place in the layout to a large, full-screen presentation.
3. Scratching with a finger. After only a **little** scratching (default 35%), the rest of the cover clears by itself and the reward appears.
4. A celebration animation when the reward appears.
5. A full set of **callbacks** and a **controller**, so the host app can drive and observe every stage.

Don't add any third-party dependencies. Build the scratch layer, the confetti and all animations with the Flutter SDK only (`CustomPainter`, `AnimationController`, `PageRouteBuilder`, `Hero`, `BackdropFilter`, `HapticFeedback`).

---

## 1. Visual design of the collapsed card (match this exactly)

Reference: a small, rounded, orange reward tile.

- **Shape:** rounded rectangle, corner radius `20`, default size about `180 × 170` logical px (configurable). Soft drop shadow (`Colors.orange.withOpacity(0.35)`, blur 16, offset `(0, 6)`).
- **Background:** linear gradient from top-left to bottom-right, about `#FFB547` → `#F7931E` → `#F57C00`.
- **Texture:** thin **diagonal stripes** at 45° across the whole card, white at about 8–10% opacity, about 10px wide with about 10px gaps. Draw them with a `CustomPainter` clipped to the rounded rect, not with an image asset.
- **Icon badge:** centered near the top. A circle about `56px` across with a white fill at about 25% opacity and a 1.5px white border at about 50% opacity. Inside it, a white gift icon (`Icons.card_giftcard_rounded` or `Icons.redeem_rounded`), size about 28.
- **Title:** `"Order reward"` (configurable), white, `FontWeight.w700`, size about 18, centered, 12px below the badge. Use the app's font (the reference looks like Poppins). Don't bundle a font.
- **Pill label:** `"TAP TO SCRATCH"` (configurable), white, `FontWeight.w600`, size about 12, `letterSpacing: 1.2`, all caps. It sits in a stadium-shaped pill with a white fill at about 20% opacity and padding `h:14, v:6`, 10px below the title.
- **Idle hint animation (optional, on by default):** a slow shimmer or gloss sweep across the card every about 3s, and/or a gentle pulse on the pill, to invite a tap.
- **Press feedback:** scale to `0.96` on tap-down and spring back on release.

Expose all colours, texts, the icon and the sizes through a `ScratchCardStyle` object with sensible defaults that reproduce this look, so the package can be themed.

---

## 2. Interaction flow and states

Model the card as a state machine and expose it:

```dart
enum ScratchCardStatus { idle, opening, opened, scratching, revealing, revealed, closing, closed }
```

### 2.1 Tap → expand to full screen
- Tapping the collapsed card pushes a transparent full-screen route (`PageRouteBuilder(opaque: false)`).
- The card **flies from its exact on-screen position** to the centre of the screen with a `Hero` (unique tag per card) and grows to the expanded size. Default: `min(screenWidth − 48, 360)` square, configurable through `expandedSize`. Duration about 450ms, curve `Curves.easeOutBack` or similar spring.
- At the same time, the background fades to a dark scrim (`Colors.black` at about 60% opacity) with a `BackdropFilter` blur (sigma about 8).
- In the expanded state, the card shows the same cover design scaled up, but the pill text changes to `"SCRATCH HERE"` (configurable), and a small hint animates over it (for example a finger or coin icon swiping back and forth) until the user starts scratching.
- Show a close (✕) button in the top-right of the screen. Tapping the scrim or pressing system back also closes, unless `barrierDismissible: false`.
- On close, the card flies back to its original spot through the reverse Hero animation.

### 2.2 Scratching
- The scratch layer is the cover design described above. Underneath it is the **reward widget**, built by the host app through a builder.
- Implementation: paint the cover inside `canvas.saveLayer`, then draw the user's scratch path with `BlendMode.clear` and a round stroke (`brushSize`, default 40). Store the touch points in a `ChangeNotifier`/`Listenable` that the painter listens to (`CustomPainter(repaint: ...)`). **Don't call `setState` on every pointer move.** Wrap the layer in a `RepaintBoundary`.
- Use `GestureDetector` with `onPanStart/Update/End`, or a `Listener`. Ignore points outside the card bounds. Keep the scratch inside the rounded-rect clip.
- **Progress calculation:** split the card into a grid (for example 30×30 cells). Mark a cell as scratched when a brush circle covers its centre. Progress = scratched cells / total cells. This approach is cheap and doesn't need pixel readback. Throttle progress callbacks to about 60Hz at most.
- Light haptic tick (`HapticFeedback.selectionClick`) on scratch start. Optionally add a subtle tick every 10% of progress, controlled by the `enableHaptics` flag.

### 2.3 Auto-reveal after a little scratching
- When progress reaches `revealThreshold` (default `0.35`, configurable from `0.05` to `1.0`), **stop accepting scratch input** and auto-reveal:
  - The remaining cover fades out and slightly scales up (opacity 1→0, scale 1→1.08, about 400ms). Optionally it dissolves in particles.
  - The reward content scales in with an elastic bounce (0.6→1.0, `Curves.elasticOut`, about 700ms).
  - `HapticFeedback.mediumImpact()`.
- The reveal can also be triggered programmatically through the controller (`controller.reveal()`).

### 2.4 Celebration
- As soon as the reveal starts, play a **confetti burst** over the full screen. Paint it with a `CustomPainter` driven by one `AnimationController`. Don't use a package.
  - About 120 particles (configurable) burst outward and upward from the card centre. Use gravity, random rotation and spin, a mix of rectangles and circles, and a configurable colour list (default: gold, orange, pink, teal, purple, white).
  - Duration about 2.5s. Particles fade out at the end. Run it inside a `RepaintBoundary` and keep it at 60fps on mid-range devices.
- Also add a soft radial glow or "sunburst" of rotating rays behind the reward card for the length of the celebration.
- `celebrationType` options: `confetti` (default), `confettiAndRays`, `none`. Also accept a `celebrationBuilder` so hosts can plug in Lottie or Rive themselves.
- Respect `MediaQuery.disableAnimations`: if reduced motion is on, skip the confetti and use simple fades.

### 2.5 Already-scratched cards
- If `isScratched: true` (the reward was already claimed earlier, for example from the backend), the collapsed card shows the **reward view** directly instead of the cover. Tapping it may still open the expanded view, without scratch or confetti. Make this configurable.

---

## 3. Callbacks (required)

Every callback is optional. Each fires exactly once per transition, at the moments described here:

```dart
typedef ScratchProgressCallback = void Function(double progress); // 0.0 – 1.0

ScratchCard(
  // lifecycle
  VoidCallback? onTap,                       // collapsed card tapped (before expanding)
  VoidCallback? onOpened,                    // expand animation finished
  VoidCallback? onScratchStart,              // first touch on the cover
  ScratchProgressCallback? onScratchProgress,// throttled progress updates
  VoidCallback? onThresholdReached,          // threshold crossed, auto-reveal starting
  VoidCallback? onRevealed,                  // reveal animation finished, reward fully visible
  VoidCallback? onCelebrationComplete,       // confetti finished
  VoidCallback? onClosed,                    // expanded view dismissed (by any means)
  ValueChanged<ScratchCardStatus>? onStatusChanged, // fires for every state change

  // async reward (optional but important)
  Future<T> Function()? onFetchReward,       // called when the card opens; result passed to rewardBuilder
  void Function(Object error, StackTrace st)? onRewardError,
  ...
)
```

### Async reward flow
- If `onFetchReward` is given, call it **as soon as the card opens**, so the network request runs while the user scratches.
- Until it resolves, the area under the cover shows `rewardLoadingBuilder` (default: a small spinner).
- If the threshold is reached before the future resolves, keep the cover in the "revealing" state with a shimmer until the data arrives, then reveal and celebrate.
- On error, call `onRewardError`, show `rewardErrorBuilder` (default: "Something went wrong. Tap to retry."), and skip the celebration.
- The generic type `T` flows into `Widget Function(BuildContext, T reward) rewardBuilder`. If there is no `onFetchReward`, use the simpler `WidgetBuilder rewardChild`.

---

## 4. Controller

```dart
class ScratchCardController extends ChangeNotifier {
  ScratchCardStatus get status;
  double get progress;
  Future<void> open();      // programmatically expand
  Future<void> reveal();    // skip scratching and reveal now (with celebration)
  Future<void> close();     // collapse back
  void reset();             // restore the cover, progress = 0, status = idle
}
```

The controller is optional. If none is passed, the widget creates and disposes its own. Dispose every `AnimationController` and listener correctly.

---

## 5. Public API (target shape)

```dart
ScratchCard<T>(
  key: ...,
  controller: ScratchCardController?,
  style: ScratchCardStyle(              // all visual tokens from section 1
    width: 180, height: 170,
    borderRadius: 20,
    gradientColors: [...],
    stripeColor: Colors.white.withOpacity(0.09),
    icon: Icons.card_giftcard_rounded,
    title: 'Order reward',
    collapsedLabel: 'TAP TO SCRATCH',
    expandedLabel: 'SCRATCH HERE',
    titleStyle: ..., labelStyle: ...,
  ),
  coverBuilder: WidgetBuilder?,         // fully replace the cover design if needed
  rewardChild: WidgetBuilder?,          // static reward
  rewardBuilder: Widget Function(BuildContext, T)?,
  rewardLoadingBuilder: WidgetBuilder?,
  rewardErrorBuilder: Widget Function(BuildContext, Object error, VoidCallback retry)?,
  expandedSize: Size?,
  brushSize: 40,
  revealThreshold: 0.35,
  isScratched: false,
  barrierDismissible: true,
  enableHaptics: true,
  showIdleShimmer: true,
  showScratchHint: true,
  celebrationType: CelebrationType.confettiAndRays,
  confettiColors: [...],
  confettiParticleCount: 120,
  celebrationBuilder: WidgetBuilder?,
  heroTag: Object?,                     // default: unique per instance
  // + all callbacks from section 3
)
```

Also export the building blocks so they can be used on their own: `ScratchCardCover`, `Scratcher` (the raw scratch layer with its own `onProgress` and `onThreshold`), and `ConfettiBurst`.

---

## 6. File structure

```
lib/
  scratch_card.dart                 // public exports only
  src/
    scratch_card_widget.dart        // collapsed card + tap + Hero
    scratch_card_route.dart         // full-screen transparent route, scrim, blur, close btn
    scratch_card_expanded.dart      // expanded card: scratcher + reward + celebration
    scratcher/
      scratcher.dart                // gesture + layer widget
      scratch_painter.dart          // saveLayer + BlendMode.clear painter
      scratch_progress.dart         // grid-based progress tracker
    cover/
      scratch_card_cover.dart       // gradient + stripes + badge + title + pill
      stripes_painter.dart
      shimmer.dart
    celebration/
      confetti_burst.dart
      confetti_painter.dart
      sunburst_rays.dart
    controller/scratch_card_controller.dart
    models/scratch_card_status.dart
    models/scratch_card_style.dart
example/
  lib/main.dart                     // demo app (see section 7)
test/
  ...                               // see section 8
```

---

## 7. Example app

Create `example/` as a runnable Flutter app that depends on the package with `path: ../`. It shows:
- A 2-column grid of 6 scratch cards on a light background, like a rewards screen. Mix in:
  - a static reward ("₹50 Cashback" with a coin icon),
  - an async reward using `onFetchReward` with a 1.5s `Future.delayed`,
  - one that fails, to demo the error and retry states,
  - one that is already scratched (`isScratched: true`),
  - one with a custom purple/blue `ScratchCardStyle`.
- An on-screen event log (a scrollable list at the bottom) that prints every callback as it fires, so the whole callback sequence can be checked by eye.
- A toolbar button that calls `controller.reveal()` and `controller.reset()` on the first card.

---

## 8. Tests

- Unit test the grid progress tracker. Hand-built strokes should produce the expected coverage, and the threshold should fire exactly once.
- Widget tests:
  - Tapping the card pushes the route and fires `onTap`, then `onOpened`.
  - Simulated drags (`tester.dragFrom`) over enough of the card fire `onScratchStart`, increasing `onScratchProgress`, then `onThresholdReached` and `onRevealed`, in that order.
  - Input is ignored after the threshold.
  - `controller.reveal()` and `controller.reset()` work.
  - `isScratched: true` shows the reward immediately.
  - The async reward shows the loading, then success, or the error and retry.
  - Closing fires `onClosed`, and no callback fires after dispose.
- Golden test for the collapsed card, to check it matches the design.

---

## 9. Quality bar

- `flutter analyze` is clean with `flutter_lints`. All public APIs have dartdoc comments.
- No dropped frames while scratching: only the painter repaints, through a `Listenable`, not the widget tree.
- Works on Android, iOS and web, in portrait and landscape. The expanded size adapts to the screen and the safe area.
- Accessibility: wrap the card in `Semantics` (label "Order reward, scratch card, tap to open"). In the expanded view, add a semantic "Reveal reward" action that calls `reveal()` for screen-reader users.
- Update `README.md` with a GIF placeholder, quick start, all parameters, the callback order diagram, and the controller usage. Update `CHANGELOG.md` and `pubspec.yaml` (description, version `0.1.0`).

## 10. Acceptance criteria

1. The collapsed card looks like the reference: orange gradient, diagonal stripes, gift badge, "Order reward", "TAP TO SCRATCH" pill.
2. Tapping it smoothly animates the card from its position to a large, centred, full-screen presentation over a blurred dark scrim.
3. Scratching clears the cover under the finger. At about 35% (configurable), the rest disappears by itself and the reward bounces in.
4. Confetti (and rays) play when the reward appears.
5. Every callback fires once, in this order: `onTap → onOpened → onScratchStart → onScratchProgress* → onThresholdReached → onRevealed → onCelebrationComplete → onClosed`.
6. The example app runs, and its event log shows that sequence.
7. All tests pass.
