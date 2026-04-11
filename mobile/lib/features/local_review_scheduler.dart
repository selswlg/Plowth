import 'dart:math' as math;

class LocalScheduleInput {
  const LocalScheduleInput({
    required this.reps,
    required this.lapses,
    required this.state,
    required this.stability,
    required this.difficulty,
    required this.lastReviewAt,
    required this.rating,
    required this.responseTimeMs,
    required this.seedDifficulty,
    required this.now,
  });

  final int? reps;
  final int? lapses;
  final String? state;
  final double? stability;
  final double? difficulty;
  final DateTime? lastReviewAt;
  final String rating;
  final int? responseTimeMs;
  final int seedDifficulty;
  final DateTime now;
}

class LocalScheduleUpdate {
  const LocalScheduleUpdate({
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.reps,
    required this.lapses,
    required this.state,
    required this.nextReviewAt,
    required this.lastReviewAt,
  });

  final double stability;
  final double difficulty;
  final double retrievability;
  final int reps;
  final int lapses;
  final String state;
  final DateTime nextReviewAt;
  final DateTime lastReviewAt;
}

LocalScheduleUpdate calculateLocalSchedule(LocalScheduleInput input) {
  final previousReps = input.reps ?? 0;
  final previousLapses = input.lapses ?? 0;
  final previousState = input.state ?? 'new';
  final previousStability =
      input.stability != null && input.stability! > 0
          ? input.stability!
          : math.max(0.25, input.seedDifficulty * 0.35);
  final previousDifficulty =
      input.difficulty != null && input.difficulty! > 0
          ? input.difficulty!
          : (input.seedDifficulty + 3).toDouble();

  var elapsedDays = 0.0;
  if (input.lastReviewAt != null) {
    final elapsedSeconds = math.max(
      0.0,
      input.now.difference(input.lastReviewAt!).inMilliseconds / 1000,
    );
    elapsedDays = elapsedSeconds / 86400;
  }

  final retrievability =
      input.lastReviewAt == null
          ? 1.0
          : math.exp(-elapsedDays / math.max(previousStability, 0.1));

  var responseFactor = 1.0;
  if (input.responseTimeMs != null) {
    if (input.responseTimeMs! <= 3500) {
      responseFactor = 1.1;
    } else if (input.responseTimeMs! >= 15000) {
      responseFactor = 0.88;
    } else if (input.responseTimeMs! >= 10000) {
      responseFactor = 0.95;
    }
  }

  var difficultyDelta = switch (input.rating) {
    'again' => 1.1,
    'hard' => 0.35,
    'good' => -0.15,
    'easy' => -0.45,
    _ => -0.15,
  };
  if (input.responseTimeMs != null && input.responseTimeMs! >= 12000) {
    difficultyDelta += 0.2;
  }

  final nextDifficulty = _clamp(
    previousDifficulty + difficultyDelta,
    1.0,
    10.0,
  );
  final nextReps = previousReps + 1;
  final nextLapses = previousLapses + (input.rating == 'again' ? 1 : 0);

  late final double nextStability;
  late final Duration interval;
  late final String nextState;

  if (input.rating == 'again') {
    nextStability = _clamp(previousStability * 0.35 * responseFactor, 0.08, 3);
    interval = Duration(minutes: previousReps == 0 ? 10 : 30);
    nextState = previousReps > 0 ? 'relearning' : 'learning';
  } else {
    final growth = switch (input.rating) {
      'hard' => 0.9,
      'good' => 1.35,
      'easy' => 1.8,
      _ => 1.35,
    };
    final recallFactor = math.max(0.7, 1.3 - (1.0 - retrievability));
    final difficultyFactor = math.max(0.65, 1.2 - nextDifficulty / 12);
    nextStability = _clamp(
      previousStability *
          growth *
          recallFactor *
          difficultyFactor *
          responseFactor,
      0.2,
      365,
    );

    if (previousReps == 0) {
      interval = switch (input.rating) {
        'hard' => const Duration(hours: 8),
        'easy' => const Duration(days: 3),
        _ => const Duration(days: 1),
      };
    } else {
      final intervalDays = switch (input.rating) {
        'hard' => math.max(0.35, nextStability * 0.6),
        'easy' => math.max(2.0, nextStability * 1.5),
        _ => math.max(1.0, nextStability),
      };
      interval = Duration(
        milliseconds: (intervalDays * const Duration(days: 1).inMilliseconds)
            .round(),
      );
    }

    var computedState = nextReps < 2 ? 'learning' : 'review';
    if (previousState == 'relearning' &&
        (input.rating == 'good' || input.rating == 'easy')) {
      computedState = 'review';
    }
    nextState = computedState;
  }

  return LocalScheduleUpdate(
    stability: nextStability,
    difficulty: nextDifficulty,
    retrievability: _clamp(retrievability, 0.0, 1.0),
    reps: nextReps,
    lapses: nextLapses,
    state: nextState,
    nextReviewAt: input.now.add(interval),
    lastReviewAt: input.now,
  );
}

double _clamp(double value, double minimum, double maximum) {
  return math.max(minimum, math.min(maximum, value));
}
