import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scratch_card_plus/scratch_card_plus.dart';

void main() {
  group('ScratchProgressTracker', () {
    test('starts at zero', () {
      final tracker = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      );
      expect(tracker.progress, 0);
      expect(tracker.totalCells, 900);
    });

    test('a single point covers roughly the brush circle area', () {
      final tracker = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      );
      tracker.addPoint(const Offset(150, 150));
      // Circle area / cell area = π·20² / 10² ≈ 12.6 cells.
      expect(tracker.scratchedCells, inInclusiveRange(9, 16));
    });

    test('a full-width stroke covers its band', () {
      final tracker = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      );
      tracker.addSegment(const Offset(0, 150), const Offset(300, 150));
      // A 40px band of a 300px card is about 13%.
      expect(tracker.progress, closeTo(40 / 300, 0.03));
    });

    test('segments are interpolated, so fast swipes still count', () {
      final sparse = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      )
        ..addPoint(const Offset(0, 150))
        ..addPoint(const Offset(300, 150));
      final segment = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      )..addSegment(const Offset(0, 150), const Offset(300, 150));
      expect(segment.progress, greaterThan(sparse.progress * 3));
    });

    test('scratching the same spot twice does not double count', () {
      final tracker = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      );
      tracker.addPoint(const Offset(100, 100));
      final once = tracker.scratchedCells;
      tracker.addPoint(const Offset(100, 100));
      expect(tracker.scratchedCells, once);
    });

    test('covering everything reaches 1.0', () {
      final tracker = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      );
      for (double y = 0; y <= 300; y += 20) {
        tracker.addSegment(Offset(0, y), Offset(300, y));
      }
      expect(tracker.progress, 1.0);
    });

    test('points outside the surface are ignored', () {
      final tracker = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      );
      tracker.addPoint(const Offset(-500, -500));
      tracker.addPoint(const Offset(900, 900));
      expect(tracker.progress, 0);
    });

    test('reset clears progress', () {
      final tracker = ScratchProgressTracker(
        size: const Size(300, 300),
        brushRadius: 20,
      )..addSegment(const Offset(0, 150), const Offset(300, 150));
      tracker.reset();
      expect(tracker.progress, 0);
    });
  });

  group('Scratcher', () {
    testWidgets('threshold fires exactly once and later input is ignored',
        (tester) async {
      var thresholdCalls = 0;
      var starts = 0;
      final progress = <double>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Scratcher(
                threshold: 0.3,
                enableHaptics: false,
                onScratchStart: () => starts++,
                onProgress: progress.add,
                onThreshold: () => thresholdCalls++,
                child: const ColoredBox(color: Color(0xFFFF9800)),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byType(Scratcher));
      for (var row = 0; row < 8; row++) {
        final y = rect.top + 20 + row * 40.0;
        await tester.dragFrom(
          Offset(rect.left + 2, y),
          Offset(rect.width - 4, 0),
        );
        await tester.pump();
      }

      expect(starts, 1);
      expect(thresholdCalls, 1);
      expect(progress, isNotEmpty);
      expect(progress.last, greaterThanOrEqualTo(0.3));
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
      final state = tester.state<ScratcherState>(find.byType(Scratcher));
      final frozen = state.progress;
      expect(state.thresholdReached, isTrue);
      expect(frozen, lessThan(0.6), reason: 'input stops at the threshold');
    });
  });
}
