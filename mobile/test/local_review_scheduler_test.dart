import 'package:flutter_test/flutter_test.dart';

import 'package:plowth_app/features/local_review_scheduler.dart';

void main() {
  group('calculateLocalSchedule', () {
    test('again keeps the card in a short relearning interval', () {
      final now = DateTime.utc(2026, 4, 11, 12, 0);
      final update = calculateLocalSchedule(
        LocalScheduleInput(
          reps: 3,
          lapses: 1,
          state: 'review',
          stability: 5,
          difficulty: 5,
          lastReviewAt: now.subtract(const Duration(days: 2)),
          rating: 'again',
          responseTimeMs: 9000,
          seedDifficulty: 3,
          now: now,
        ),
      );

      expect(update.state, 'relearning');
      expect(update.lapses, 2);
      expect(update.nextReviewAt.isBefore(now.add(const Duration(hours: 1))), isTrue);
    });

    test('easy pushes the next review further than good', () {
      final now = DateTime.utc(2026, 4, 11, 12, 0);
      final good = calculateLocalSchedule(
        LocalScheduleInput(
          reps: 4,
          lapses: 0,
          state: 'review',
          stability: 8,
          difficulty: 4,
          lastReviewAt: now.subtract(const Duration(days: 4)),
          rating: 'good',
          responseTimeMs: 2500,
          seedDifficulty: 3,
          now: now,
        ),
      );
      final easy = calculateLocalSchedule(
        LocalScheduleInput(
          reps: 4,
          lapses: 0,
          state: 'review',
          stability: 8,
          difficulty: 4,
          lastReviewAt: now.subtract(const Duration(days: 4)),
          rating: 'easy',
          responseTimeMs: 2500,
          seedDifficulty: 3,
          now: now,
        ),
      );

      expect(easy.nextReviewAt.isAfter(good.nextReviewAt), isTrue);
      expect(easy.stability, greaterThanOrEqualTo(good.stability));
    });
  });
}
