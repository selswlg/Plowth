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
      setState(() {
        _snapshotFuture = _loadSnapshot();
      });
    }
  }

  Future<_HomeSnapshot> _loadSnapshot() async {
    try {
      final queue = await _repository.getReviewQueue(limit: 200);
      final summary = await _repository.getTodaySummary();
      return _HomeSnapshot(
        dueCount: queue.length,
        completedCount: summary.totalCards,
        accuracyRate: summary.accuracyRate,
      );
    } on StudyException {
      return const _HomeSnapshot(
        dueCount: null,
        completedCount: null,
        accuracyRate: null,
      );
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
                    'Build your first review loop',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next Step', style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  const _EmptyStateCard(
                    icon: Icons.library_books_rounded,
                    message:
                        'Phase 2 is live: capture source text, inspect generated cards, then move into the review loop.',
                  ),
                ],
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

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.dueCount,
    required this.completedCount,
    required this.accuracyRate,
  });

  final int? dueCount;
  final int? completedCount;
  final double? accuracyRate;
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
