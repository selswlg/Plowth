import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import 'study_repository.dart';

class InsightScreen extends StatefulWidget {
  const InsightScreen({super.key, required this.refreshSeed});

  final int refreshSeed;

  @override
  State<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends State<InsightScreen> {
  late final StudyRepository _repository;
  late Future<InsightSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _repository = StudyRepository();
    _snapshotFuture = _repository.getInsightSnapshot();
  }

  @override
  void didUpdateWidget(covariant InsightScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      setState(() {
        _snapshotFuture = _repository.getInsightSnapshot();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Insight', style: AppTypography.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Read your learning signals',
                        style: AppTypography.displayMedium,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _snapshotFuture = _repository.getInsightSnapshot();
                    });
                  },
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: FutureBuilder<InsightSnapshot>(
                future: _snapshotFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _InsightStatus(
                      message: 'Loading review analytics...',
                    );
                  }

                  if (snapshot.hasError) {
                    final message =
                        snapshot.error is StudyException
                            ? (snapshot.error as StudyException).message
                            : 'Insight data is unavailable right now.';
                    return _InsightMessage(
                      icon: Icons.error_outline_rounded,
                      title: 'Insight unavailable',
                      message: message,
                    );
                  }

                  final data = snapshot.data;
                  if (data == null) {
                    return const _InsightMessage(
                      icon: Icons.insights_rounded,
                      title: 'No insight yet',
                      message:
                          'Finish a review session to generate analytics and coaching guidance.',
                    );
                  }

                  return _InsightContent(snapshot: data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightContent extends StatelessWidget {
  const _InsightContent({required this.snapshot});

  final InsightSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final overview = snapshot.overview;

    return ListView(
      children: [
        _CoachCard(snapshot: snapshot),
        const SizedBox(height: AppSpacing.lg),
        _CognitiveUpdatePanel(
          initialConcept:
              snapshot.focusTopic ??
              (snapshot.weakConcepts.isEmpty
                  ? null
                  : snapshot.weakConcepts.first.conceptName),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Today', style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricCard(
              label: 'Due Today',
              value: '${overview.totalDueToday}',
              tone: AppColors.primary,
            ),
            _MetricCard(
              label: 'Completed',
              value: '${overview.completedToday}',
              tone: AppColors.accent,
            ),
            _MetricCard(
              label: 'Accuracy',
              value:
                  overview.accuracyToday == null
                      ? '--'
                      : '${(overview.accuracyToday! * 100).round()}%',
              tone: AppColors.ratingGood,
            ),
            _MetricCard(
              label: 'Memory',
              value: '${(overview.memoryStrength * 100).round()}%',
              tone: AppColors.ratingHard,
            ),
            _MetricCard(
              label: 'Streak',
              value: '${overview.streakDays}d',
              tone: AppColors.ratingEasy,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Weak Concepts', style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (snapshot.weakConcepts.isEmpty)
          const _EmptyInsightCard(
            message:
                'No weak concepts detected yet. Review data will start surfacing patterns here.',
          )
        else
          ...snapshot.weakConcepts.map(
            (concept) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _WeakConceptCard(concept: concept),
            ),
          ),
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.snapshot});

  final InsightSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.glow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.coachTitle,
            style: AppTypography.headlineLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            snapshot.coachMessage,
            style: AppTypography.bodyLarge.copyWith(color: Colors.white),
          ),
          if (snapshot.focusTopic != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                'Focus: ${snapshot.focusTopic}',
                style: AppTypography.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CognitiveUpdatePanel extends StatefulWidget {
  const _CognitiveUpdatePanel({required this.initialConcept});

  final String? initialConcept;

  @override
  State<_CognitiveUpdatePanel> createState() => _CognitiveUpdatePanelState();
}

class _CognitiveUpdatePanelState extends State<_CognitiveUpdatePanel> {
  final StudyRepository _repository = StudyRepository();
  late final TextEditingController _conceptController;
  final TextEditingController _evidenceController = TextEditingController();

  bool _isPreviewing = false;
  String? _applyingCardId;
  String? _message;
  String? _error;
  List<CognitiveUpdateMatch> _matches = const [];

  @override
  void initState() {
    super.initState();
    _conceptController = TextEditingController(
      text: widget.initialConcept ?? '',
    );
  }

  @override
  void dispose() {
    _conceptController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    final conceptName = _conceptController.text.trim();
    final evidence = _evidenceController.text.trim();
    if (conceptName.length < 2) {
      setState(() {
        _error = 'Add a concept name to compare.';
        _message = null;
      });
      return;
    }

    setState(() {
      _isPreviewing = true;
      _error = null;
      _message = null;
      _matches = const [];
    });

    try {
      final matches = await _repository.previewCognitiveUpdate(
        conceptName: conceptName,
        description: evidence,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreviewing = false;
        _matches = matches;
        if (matches.isEmpty) {
          _message = 'No related concepts found yet.';
        }
      });
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreviewing = false;
        _error = error.message;
      });
    }
  }

  Future<void> _apply(CognitiveUpdateMatch match) async {
    final evidence = _evidenceController.text.trim();
    final candidate = match.cards.isEmpty ? null : match.cards.first;
    if (candidate == null) {
      setState(() {
        _error = 'No card is available for this concept yet.';
        _message = null;
      });
      return;
    }
    if (evidence.length < 3) {
      setState(() {
        _error = 'Add evidence before updating a card.';
        _message = null;
      });
      return;
    }

    setState(() {
      _applyingCardId = candidate.cardId;
      _error = null;
      _message = null;
    });

    try {
      await _repository.applyCognitiveUpdate(
        cardId: candidate.cardId,
        newEvidence: evidence,
        sourceConceptName: _conceptController.text.trim(),
        action: match.suggestedAction,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _applyingCardId = null;
        _message = 'Card enriched. The update is stored in its history.';
      });
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _applyingCardId = null;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text('Cognitive Update', style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Compare new evidence with existing concepts before adding another duplicate card.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _conceptController,
            decoration: const InputDecoration(hintText: 'Concept name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _evidenceController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'New evidence or correction',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPreviewing ? null : _preview,
              child: Text(_isPreviewing ? 'Checking...' : 'Find Updates'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.accentRed,
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_message!, style: AppTypography.bodyMedium),
          ],
          for (final match in _matches) ...[
            const SizedBox(height: AppSpacing.md),
            _CognitiveUpdateMatchCard(
              match: match,
              applyingCardId: _applyingCardId,
              onApply: () => _apply(match),
            ),
          ],
        ],
      ),
    );
  }
}

class _CognitiveUpdateMatchCard extends StatelessWidget {
  const _CognitiveUpdateMatchCard({
    required this.match,
    required this.applyingCardId,
    required this.onApply,
  });

  final CognitiveUpdateMatch match;
  final String? applyingCardId;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final candidate = match.cards.isEmpty ? null : match.cards.first;
    final isApplying = candidate != null && applyingCardId == candidate.cardId;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(match.conceptName, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${(match.similarity * 100).round()}% match - ${match.suggestedAction}',
            style: AppTypography.bodySmall,
          ),
          if (candidate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(candidate.question, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(candidate.answerExcerpt, style: AppTypography.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: isApplying ? null : onApply,
              child: Text(isApplying ? 'Updating...' : 'Add Evidence'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTypography.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}

class _WeakConceptCard extends StatelessWidget {
  const _WeakConceptCard({required this.concept});

  final WeakConceptInsight concept;

  @override
  Widget build(BuildContext context) {
    final recency =
        concept.lastFailedAt == null
            ? 'No recent miss'
            : _formatRecency(concept.lastFailedAt!);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.accentOrange,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(concept.conceptName, style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Failure score ${concept.failureCount} - $recency',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRecency(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    }
    final minutes = difference.inMinutes <= 0 ? 1 : difference.inMinutes;
    return '${minutes}m ago';
  }
}

class _InsightStatus extends StatelessWidget {
  const _InsightStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _InsightMessage extends StatelessWidget {
  const _InsightMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInsightCard extends StatelessWidget {
  const _EmptyInsightCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: AppTypography.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
