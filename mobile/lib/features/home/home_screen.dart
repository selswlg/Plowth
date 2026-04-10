import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../study_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.learningGoalLabel,
    required this.onStartReview,
    required this.onAddMaterial,
    required this.refreshSeed,
  });

  final String learningGoalLabel;
  final VoidCallback onStartReview;
  final VoidCallback onAddMaterial;
  final int refreshSeed;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final StudyRepository _repository;
  late Future<_HomeSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _repository = StudyRepository();
    _snapshotFuture = _loadSnapshot();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _refreshSnapshot();
    }
  }

  void _refreshSnapshot() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<_HomeSnapshot> _loadSnapshot() async {
    int? dueCount;
    int? completedCount;
    double? accuracyRate;

    try {
      final queue = await _repository.getReviewQueue(limit: 200);
      final summary = await _repository.getTodaySummary();
      dueCount = queue.length;
      completedCount = summary.totalCards;
      accuracyRate = summary.accuracyRate;
    } on StudyException {
      dueCount = null;
      completedCount = null;
      accuracyRate = null;
    }

    final generation = await _loadGenerationSnapshot();
    return _HomeSnapshot(
      dueCount: dueCount,
      completedCount: completedCount,
      accuracyRate: accuracyRate,
      generation: generation,
    );
  }

  Future<_GenerationSnapshot?> _loadGenerationSnapshot() async {
    try {
      final job = await _repository.getLatestGenerationJob();
      if (job == null) {
        return null;
      }

      SourceMaterial? source;
      if (job.sourceId != null) {
        source = await _repository.getSource(job.sourceId!);
      }
      return _GenerationSnapshot(job: job, source: source);
    } on StudyException {
      return null;
    }
  }

  Future<void> _retryGeneration(String jobId) async {
    try {
      await _repository.retryJob(jobId);
      _refreshSnapshot();
    } on StudyException {
      _refreshSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session Ready', style: AppTypography.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Build your next review loop',
                    style: AppTypography.displayMedium,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<_HomeSnapshot>(
                future: _snapshotFuture,
                builder: (context, snapshot) {
                  return _TodaySummaryCard(
                    learningGoalLabel: widget.learningGoalLabel,
                    snapshot: snapshot.data,
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Actions', style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.refresh_rounded,
                          label: 'Start Review',
                          color: AppColors.primary,
                          onTap: widget.onStartReview,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.add_rounded,
                          label: 'Add Material',
                          color: AppColors.accent,
                          onTap: widget.onAddMaterial,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<_HomeSnapshot>(
                future: _snapshotFuture,
                builder: (context, snapshot) {
                  final generation = snapshot.data?.generation;
                  if (generation == null) {
                    return const _EmptyStateCard(
                      icon: Icons.library_books_rounded,
                      message:
                          'Add material to prepare cards, then start a focused review pass.',
                    );
                  }

                  return _GenerationStatusCard(
                    generation: generation,
                    onRefresh: _refreshSnapshot,
                    onStartReview: widget.onStartReview,
                    onAddMaterial: widget.onAddMaterial,
                    onRetry: () => _retryGeneration(generation.job.id),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.learningGoalLabel,
    required this.snapshot,
  });

  final String learningGoalLabel;
  final _HomeSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final dueValue = snapshot?.dueCount?.toString() ?? '--';
    final doneValue = snapshot?.completedCount?.toString() ?? '--';
    final accuracyValue =
        snapshot?.accuracyRate == null
            ? '--'
            : '${(snapshot!.accuracyRate! * 100).round()}%';

    final dueCount = snapshot?.dueCount ?? 0;
    final completedCount = snapshot?.completedCount ?? 0;
    final progressBase = dueCount + completedCount;
    final progress = progressBase == 0 ? 0.0 : completedCount / progressBase;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.glow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  learningGoalLabel,
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'Guest Mode',
                  style: AppTypography.labelSmall.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _SummaryMetric(value: dueValue, label: 'Due'),
              const SizedBox(width: AppSpacing.xl),
              _SummaryMetric(value: doneValue, label: 'Done'),
              const SizedBox(width: AppSpacing.xl),
              _SummaryMetric(value: accuracyValue, label: 'Accuracy'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationStatusCard extends StatelessWidget {
  const _GenerationStatusCard({
    required this.generation,
    required this.onRefresh,
    required this.onStartReview,
    required this.onAddMaterial,
    required this.onRetry,
  });

  final _GenerationSnapshot generation;
  final VoidCallback onRefresh;
  final VoidCallback onStartReview;
  final VoidCallback onAddMaterial;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isActive = generation.isActive;
    final isFailed = generation.isFailed;
    final isDone = generation.isDone;
    final title = generation.source?.title ?? 'Recent material';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GenerationIcon(isActive: isActive, isFailed: isFailed),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusTitle, style: AppTypography.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(title, style: AppTypography.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_summaryText, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (isDone)
                ElevatedButton(
                  onPressed: onStartReview,
                  child: const Text('Start Review'),
                ),
              if (isFailed)
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
              OutlinedButton(
                onPressed: onRefresh,
                child: const Text('Refresh'),
              ),
              if (!isActive)
                OutlinedButton(
                  onPressed: onAddMaterial,
                  child: const Text('Add More'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String get _statusTitle {
    if (generation.isFailed) {
      return 'Needs another pass';
    }
    if (generation.isDone) {
      return 'Cards ready';
    }
    return 'Preparing cards';
  }

  String get _summaryText {
    if (generation.isFailed) {
      return generation.job.errorMessage ??
          generation.source?.errorMessage ??
          'Something went wrong while preparing cards.';
    }

    final cardCount = generation.cardCount;
    final conceptCount = generation.conceptCount;
    if (generation.isDone && cardCount != null) {
      final conceptLabel =
          conceptCount == null ? '' : ' from $conceptCount concepts';
      return '$cardCount cards prepared$conceptLabel.';
    }

    return 'You can keep studying while the material is processed.';
  }
}

class _GenerationIcon extends StatelessWidget {
  const _GenerationIcon({required this.isActive, required this.isFailed});

  final bool isActive;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    return Icon(
      isFailed ? Icons.error_outline_rounded : Icons.check_circle_rounded,
      color: isFailed ? AppColors.accentRed : AppColors.ratingGood,
      size: 32,
    );
  }
}

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.dueCount,
    required this.completedCount,
    required this.accuracyRate,
    required this.generation,
  });

  final int? dueCount;
  final int? completedCount;
  final double? accuracyRate;
  final _GenerationSnapshot? generation;
}

class _GenerationSnapshot {
  const _GenerationSnapshot({required this.job, required this.source});

  final GenerationJob job;
  final SourceMaterial? source;

  bool get isActive => job.status == 'pending' || job.status == 'running';
  bool get isDone => job.status == 'completed' || source?.status == 'done';
  bool get isFailed => job.status == 'failed' || source?.status == 'error';

  int? get cardCount => _metadataInt('card_count');
  int? get conceptCount => _metadataInt('concept_count');

  int? _metadataInt(String key) {
    final value = source?.metadata?[key] ?? job.resultSummary?[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.displayLarge.copyWith(
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.labelLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
