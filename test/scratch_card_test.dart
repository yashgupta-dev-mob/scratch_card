import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scratch_card_plus/scratch_card_plus.dart';

const _cardKey = Key('card');

Widget _app(Widget card) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: Center(child: card),
    ),
  );
}

/// Records every callback in order. Consecutive progress events collapse
/// into one entry.
class _Recorder {
  final List<String> events = [];
  final List<double> progress = [];

  void add(String name) {
    if (name == 'progress' && events.isNotEmpty && events.last == 'progress') {
      return;
    }
    events.add(name);
  }

  ScratchCard<T> card<T>({
    ScratchCardController? controller,
    WidgetBuilder? rewardChild,
    RewardWidgetBuilder<T>? rewardBuilder,
    Future<T> Function()? onFetchReward,
    bool isScratched = false,
    CelebrationType celebrationType = CelebrationType.confettiAndRays,
    void Function(Object, StackTrace)? onRewardError,
  }) {
    return ScratchCard<T>(
      key: _cardKey,
      controller: controller,
      showIdleShimmer: false,
      showScratchHint: false,
      enableHaptics: false,
      isScratched: isScratched,
      celebrationType: celebrationType,
      rewardChild: rewardChild ?? (_) => const Text('₹50 Cashback'),
      rewardBuilder: rewardBuilder,
      onFetchReward: onFetchReward,
      onRewardError: onRewardError,
      onTap: () => add('tap'),
      onOpened: () => add('opened'),
      onScratchStart: () => add('scratchStart'),
      onScratchProgress: (p) {
        progress.add(p);
        add('progress');
      },
      onThresholdReached: () => add('threshold'),
      onRevealed: () => add('revealed'),
      onCelebrationComplete: () => add('celebrationComplete'),
      onClosed: () => add('closed'),
    );
  }
}

/// Drags horizontal rows across the expanded card until the cover is gone
/// or [maxRows] rows have been scratched.
Future<void> _scratch(WidgetTester tester, {int maxRows = 9}) async {
  final finder = find.byType(Scratcher);
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  for (var row = 0; row < maxRows; row++) {
    final scratcher = finder.evaluate();
    if (scratcher.isEmpty) break;
    final state = tester.state<ScratcherState>(finder);
    if (state.thresholdReached) break;
    final y = rect.top + 20 + row * 40.0;
    final gesture = await tester.startGesture(Offset(rect.left + 4, y));
    for (var x = rect.left + 4; x <= rect.right - 4; x += 24) {
      await gesture.moveTo(Offset(x, y));
    }
    await gesture.up();
    await tester.pump();
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_cardKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping opens the full-screen view: onTap then onOpened',
      (tester) async {
    final r = _Recorder();
    await tester.pumpWidget(_app(r.card<Object?>()));
    expect(find.byType(Scratcher), findsNothing);

    await _open(tester);

    expect(r.events, ['tap', 'opened']);
    expect(find.byType(Scratcher), findsOneWidget);
    expect(find.text('SCRATCH HERE'), findsOneWidget);
    // The expanded card is larger than the collapsed one.
    expect(tester.getSize(find.byType(Scratcher)).width, greaterThan(300));
  });

  testWidgets('full flow fires every callback once, in order', (tester) async {
    final r = _Recorder();
    final controller = ScratchCardController();
    addTearDown(controller.dispose);
    final statuses = <ScratchCardStatus>[];
    controller.addListener(() {
      if (statuses.isEmpty || statuses.last != controller.status) {
        statuses.add(controller.status);
      }
    });

    await tester.pumpWidget(_app(r.card<Object?>(controller: controller)));
    await _open(tester);
    await _scratch(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ConfettiBurst), findsNothing, reason: 'finished');
    expect(find.text('₹50 Cashback'), findsOneWidget);
    expect(controller.isRevealed, isTrue);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(r.events, [
      'tap',
      'opened',
      'scratchStart',
      'progress',
      'threshold',
      'revealed',
      'celebrationComplete',
      'closed',
    ]);
    expect(r.progress.first, greaterThan(0));
    expect(r.progress.last, greaterThanOrEqualTo(0.35));
    for (var i = 1; i < r.progress.length; i++) {
      expect(r.progress[i], greaterThanOrEqualTo(r.progress[i - 1]));
    }
    expect(statuses, [
      ScratchCardStatus.opening,
      ScratchCardStatus.opened,
      ScratchCardStatus.scratching,
      ScratchCardStatus.revealing,
      ScratchCardStatus.revealed,
      ScratchCardStatus.closing,
      ScratchCardStatus.closed,
    ]);

    // The collapsed card now shows the reward instead of the cover.
    expect(find.byType(ScratchCardCover), findsNothing);
    expect(find.text('₹50 Cashback'), findsOneWidget);
  });

  testWidgets('celebration plays when the reward is revealed', (tester) async {
    final r = _Recorder();
    await tester.pumpWidget(_app(r.card<Object?>()));
    await _open(tester);
    await _scratch(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(find.byType(SunburstRays), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(r.events, contains('celebrationComplete'));
  });

  testWidgets('scratch input is ignored after the threshold', (tester) async {
    final r = _Recorder();
    await tester.pumpWidget(_app(r.card<Object?>()));
    await _open(tester);
    await _scratch(tester);
    final countAtThreshold = r.progress.length;

    // Keep dragging over where the card is while the cover fades out.
    final center = tester.getCenter(find.byType(Scratcher));
    await tester.dragFrom(center - const Offset(150, 0), const Offset(300, 0));
    await tester.pump();

    expect(r.progress.length, countAtThreshold);
    expect(r.events.where((e) => e == 'threshold').length, 1);
    expect(r.events.where((e) => e == 'closed'), isEmpty,
        reason: 'dragging over the card must not hit the scrim');
    await tester.pumpAndSettle();
  });

  testWidgets('controller.reveal() opens and reveals; reset() restores',
      (tester) async {
    final r = _Recorder();
    final controller = ScratchCardController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(r.card<Object?>(controller: controller)));

    unawaited(controller.reveal());
    await tester.pumpAndSettle();

    expect(controller.isRevealed, isTrue);
    expect(controller.status, ScratchCardStatus.revealed);
    expect(find.text('₹50 Cashback'), findsOneWidget);
    expect(r.events, ['opened', 'revealed', 'celebrationComplete']);

    controller.reset();
    await tester.pumpAndSettle();
    expect(controller.isRevealed, isFalse);
    expect(controller.progress, 0);
    expect(controller.status, ScratchCardStatus.opened);
    expect(find.byType(Scratcher), findsOneWidget);

    unawaited(controller.close());
    await tester.pumpAndSettle();
    expect(controller.status, ScratchCardStatus.closed);
    expect(find.byType(ScratchCardCover), findsOneWidget);

    controller.reset();
    await tester.pump();
    expect(controller.status, ScratchCardStatus.idle);
  });

  testWidgets('isScratched shows the reward immediately', (tester) async {
    final r = _Recorder();
    await tester.pumpWidget(
      _app(
        r.card<Object?>(
          isScratched: true,
          rewardChild: (_) => const Text('10% OFF'),
        ),
      ),
    );

    expect(find.text('10% OFF'), findsOneWidget);
    expect(find.byType(ScratchCardCover), findsNothing);

    await _open(tester);
    expect(find.byType(Scratcher), findsNothing);
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(r.events, ['tap', 'opened']);
  });

  testWidgets('async reward: loading, then success', (tester) async {
    final r = _Recorder();
    final completer = Completer<String>();
    var fetches = 0;
    await tester.pumpWidget(
      _app(
        r.card<String>(
          onFetchReward: () {
            fetches++;
            return completer.future;
          },
          rewardBuilder: (context, reward) => Text('Won $reward'),
        ),
      ),
    );

    await tester.tap(find.byKey(_cardKey));
    await tester.pump();
    expect(fetches, 1, reason: 'fetch starts as soon as the card opens');
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _scratch(tester);
    expect(r.events, contains('threshold'));
    expect(r.events, isNot(contains('revealed')),
        reason: 'waits for the reward before revealing');

    completer.complete('₹100');
    await tester.pumpAndSettle();

    expect(find.text('Won ₹100'), findsOneWidget);
    expect(r.events, containsAllInOrder(['threshold', 'revealed']));
    expect(fetches, 1);
  });

  testWidgets('async reward: error, then retry succeeds', (tester) async {
    final r = _Recorder();
    var attempts = 0;
    final errors = <Object>[];
    await tester.pumpWidget(
      _app(
        r.card<String>(
          onFetchReward: () async {
            attempts++;
            if (attempts == 1) throw StateError('offline');
            return 'Free delivery';
          },
          rewardBuilder: (context, reward) => Text(reward),
          onRewardError: (error, _) => errors.add(error),
        ),
      ),
    );

    await _open(tester);
    expect(errors, hasLength(1));

    await _scratch(tester);
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong.'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(r.events, isNot(contains('revealed')));

    await tester.tap(find.text('Tap to retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Free delivery'), findsOneWidget);
    expect(r.events, containsAllInOrder(['threshold', 'revealed']));
    expect(r.events.last, 'celebrationComplete');
  });

  testWidgets('scrim tap closes and fires onClosed', (tester) async {
    final r = _Recorder();
    await tester.pumpWidget(_app(r.card<Object?>()));
    await _open(tester);

    await tester.tapAt(const Offset(10, 590));
    await tester.pumpAndSettle();

    expect(r.events, ['tap', 'opened', 'closed']);
    expect(find.byType(Scratcher), findsNothing);
  });

  testWidgets('no callbacks fire after the card is disposed', (tester) async {
    final r = _Recorder();
    await tester.pumpWidget(_app(r.card<Object?>()));
    await _open(tester);
    await _scratch(tester);
    final before = List<String>.of(r.events);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 5));

    expect(r.events, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed card matches the design', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ScratchCard<Object?>(showIdleShimmer: false),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(_cardKey),
      matchesGoldenFile('goldens/collapsed_card.png'),
    );
  });
}
