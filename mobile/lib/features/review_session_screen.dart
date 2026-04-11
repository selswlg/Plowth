import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import 'study_repository.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.refreshSeed,
    required this.onCaptureRequested,
  });

  final int refreshSeed;
  final VoidCallback onCaptureRequested;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final StudyRepository _repository = StudyRepository();
  final Random _random = Random();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showAnswer = false;
  String? _errorMessage;
  GenerationJob? _activeGenerationJob;
  List<ReviewQueueItem> _queue = const [];
  List<_ReviewResult> _results = const [];
  DateTime? _cardShownAt;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void didUpdateWidget(covariant ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _loadQueue();
    }
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeGenerationJob = null;
      _showAnswer = false;
    });

    try {
      final queue = await _repository.getReviewQueue(limit: 50);
      final activeGenerationJob =
          queue.isEmpty
              ? await _repository.getLatestActiveGenerationJob()
              : null;
      if (!mounted) {
        return;
      }
      setState(() {
        _queue = queue;
        _activeGenerationJob = activeGenerationJob;
        _results = const [];
        _currentIndex = 0;
        _cardShownAt = queue.isEmpty ? null : DateTime.now();
        _isLoading = false;
      });
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _submitRating(String rating) async {
    if (_isSubmitting || _currentIndex >= _queue.length) {
      return;
    }

    final card = _queue[_currentIndex];
    final startedAt = _cardShownAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(startedAt);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await _repository.submitReview(
        card: card,
        rating: rating,
        responseTimeMs: max(500, elapsed.inMilliseconds),
        clientId:
            'rvw-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}',
      );

      if (!mounted) {
        return;
      }

      final nextResults = [
        ..._results,
        _ReviewResult(
          rating: response.rating,
          responseTimeMs: response.responseTimeMs,
        ),
      ];

      if (_currentIndex + 1 >= _queue.length) {
        setState(() {
          _results = nextResults;
          _showAnswer = false;
          _isSubmitting = false;
          _currentIndex = _queue.length;
          _cardShownAt = null;
        });
        return;
      }

      setState(() {
        _results = nextResults;
        _currentIndex += 1;
        _showAnswer = false;
        _isSubmitting = false;
        _cardShownAt = DateTime.now();
      });
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _openTutorSheet({
    required ReviewQueueItem card,
    required String requestType,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder:
          (context) => _TutorSheet(
            repository: _repository,
            card: card,
            initialRequestType: requestType,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewComplete = _queue.isNotEmpty && _currentIndex >= _queue.length;

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
                      Text('Review', style: AppTypography.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Run today\'s recall loop',
                        style: AppTypography.displayMedium,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isSubmitting ? null : _loadQueue,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isLoading)
              const Expanded(
                child: _ReviewStatus(message: 'Loading review queue...'),
              )
            else if (_errorMessage != null)
              Expanded(
                child: _ReviewMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'Queue unavailable',
                  message: _errorMessage!,
                  primaryLabel: 'Retry',
                  onPrimaryTap: _loadQueue,
                ),
              )
            else if (_queue.isEmpty)
              Expanded(
                child: _ReviewMessage(
                  icon:
                      _activeGenerationJob == null
                          ? Icons.auto_stories_outlined
                          : Icons.hourglass_top_rounded,
                  title:
                      _activeGenerationJob == null
                          ? 'No cards due'
                          : 'Cards are preparing',
                  message:
                      _activeGenerationJob == null
                          ? 'Generate a review set from Capture or come back when the next cards are due.'
                          : 'Your latest material is still being processed. Refresh in a moment.',
                  primaryLabel:
                      _activeGenerationJob == null ? 'Open Capture' : 'Refresh',
                  onPrimaryTap:
                      _activeGenerationJob == null
                          ? widget.onCaptureRequested
                          : _loadQueue,
                ),
              )
            else if (reviewComplete)
              Expanded(
                child: _ReviewSummary(
                  results: _results,
                  onReviewAgain: _loadQueue,
                  onCaptureRequested: widget.onCaptureRequested,
                ),
              )
            else
              Expanded(child: _buildSessionCard(_queue[_currentIndex])),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(ReviewQueueItem card) {
    final progressLabel = '${_currentIndex + 1} / ${_queue.length}';
    final domainHint = card.tags?['domain_hint']?.toString();
    final cardLabel = [
      if (domainHint != null && domainHint.isNotEmpty) domainHint.toUpperCase(),
      card.cardType.toUpperCase(),
      card.state,
    ].join(' - ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(progressLabel, style: AppTypography.labelLarge),
            const Spacer(),
            Text(
              card.sourceTitle ?? 'Untitled source',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _queue.length,
            minHeight: 6,
            backgroundColor: AppColors.surfaceLight,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: GestureDetector(
            onTap:
                _showAnswer
                    ? null
                    : () {
                      setState(() {
                        _showAnswer = true;
                      });
                    },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.medium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      cardLabel,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('Question', style: AppTypography.labelSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(card.question, style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState:
                        _showAnswer
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                    firstChild: Text(
                      'Tap to reveal the answer and rate your recall.',
                      style: AppTypography.bodyMedium,
                    ),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Answer', style: AppTypography.labelSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Text(card.answer, style: AppTypography.bodyLarge),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Reps ${card.reps} - Lapses ${card.lapses}',
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _TutorActionBar(
                          enabled: !_isSubmitting,
                          onExplain:
                              () => _openTutorSheet(
                                card: card,
                                requestType: 'explain',
                              ),
                          onExample:
                              () => _openTutorSheet(
                                card: card,
                                requestType: 'example',
                              ),
                          onRelated:
                              () => _openTutorSheet(
                                card: card,
                                requestType: 'related',
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_errorMessage != null) ...[
          _ReviewBanner(message: _errorMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _RatingButton(
              label: 'Again',
              color: AppColors.ratingAgain,
              enabled: _showAnswer && !_isSubmitting,
              onTap: () => _submitRating('again'),
            ),
            _RatingButton(
              label: 'Hard',
              color: AppColors.ratingHard,
              enabled: _showAnswer && !_isSubmitting,
              onTap: () => _submitRating('hard'),
            ),
            _RatingButton(
              label: 'Good',
              color: AppColors.ratingGood,
              enabled: _showAnswer && !_isSubmitting,
              onTap: () => _submitRating('good'),
            ),
            _RatingButton(
              label: 'Easy',
              color: AppColors.ratingEasy,
              enabled: _showAnswer && !_isSubmitting,
              onTap: () => _submitRating('easy'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.results,
    required this.onReviewAgain,
    required this.onCaptureRequested,
  });

  final List<_ReviewResult> results;
  final VoidCallback onReviewAgain;
  final VoidCallback onCaptureRequested;

  @override
  Widget build(BuildContext context) {
    final total = results.length;
    final againCount =
        results.where((result) => result.rating == 'again').length;
    final hardCount = results.where((result) => result.rating == 'hard').length;
    final goodCount = results.where((result) => result.rating == 'good').length;
    final easyCount = results.where((result) => result.rating == 'easy').length;
    final avgResponseTime =
        total == 0
            ? 0
            : results
                    .map((result) => result.responseTimeMs)
                    .reduce((left, right) => left + right) ~/
                total;
    final accuracy =
        total == 0 ? 0 : ((goodCount + easyCount) / total * 100).round();

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
          Text('Session Complete', style: AppTypography.displayMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$total cards reviewed with $accuracy% strong recall.',
            style: AppTypography.bodyLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _SummaryTile(label: 'Again', value: '$againCount'),
              _SummaryTile(label: 'Hard', value: '$hardCount'),
              _SummaryTile(label: 'Good', value: '$goodCount'),
              _SummaryTile(label: 'Easy', value: '$easyCount'),
              _SummaryTile(label: 'Avg ms', value: '$avgResponseTime'),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCaptureRequested,
                  child: const Text('Capture More'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: onReviewAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                  ),
                  child: const Text('Refresh Queue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.headlineLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: enabled ? 1 : 0.32),
          foregroundColor: Colors.white,
        ),
        child: Text(label),
      ),
    );
  }
}

class _TutorActionBar extends StatelessWidget {
  const _TutorActionBar({
    required this.enabled,
    required this.onExplain,
    required this.onExample,
    required this.onRelated,
  });

  final bool enabled;
  final VoidCallback onExplain;
  final VoidCallback onExample;
  final VoidCallback onRelated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tutor', style: AppTypography.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _TutorActionButton(
              label: 'Explain',
              enabled: enabled,
              onTap: onExplain,
            ),
            _TutorActionButton(
              label: 'Example',
              enabled: enabled,
              onTap: onExample,
            ),
            _TutorActionButton(
              label: 'Related',
              enabled: enabled,
              onTap: onRelated,
            ),
          ],
        ),
      ],
    );
  }
}

class _TutorActionButton extends StatelessWidget {
  const _TutorActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: enabled ? 0.45 : 0.18),
        ),
      ),
      child: Text(label),
    );
  }
}

class _TutorSheet extends StatefulWidget {
  const _TutorSheet({
    required this.repository,
    required this.card,
    required this.initialRequestType,
  });

  final StudyRepository repository;
  final ReviewQueueItem card;
  final String initialRequestType;

  @override
  State<_TutorSheet> createState() => _TutorSheetState();
}

class _TutorSheetState extends State<_TutorSheet> {
  late String _requestType;
  TutorCardResponse? _response;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestType = widget.initialRequestType;
    _loadResponse();
  }

  Future<void> _loadResponse() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _response = null;
    });

    try {
      final response = await widget.repository.getTutorResponse(
        cardId: widget.card.id,
        requestType: _requestType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _response = response;
        _isLoading = false;
      });
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  void _changeRequestType(String value) {
    if (_requestType == value) {
      return;
    }
    setState(() {
      _requestType = value;
    });
    _loadResponse();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          bottomPadding + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Tutor', style: AppTypography.headlineMedium),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(widget.card.question, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'explain', label: Text('Explain')),
                ButtonSegment(value: 'example', label: Text('Example')),
                ButtonSegment(value: 'related', label: Text('Related')),
              ],
              selected: {_requestType},
              onSelectionChanged: (selection) {
                _changeRequestType(selection.first);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.62,
              ),
              child: SingleChildScrollView(child: _buildBody()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _TutorFeedbackCard(
        icon: Icons.error_outline_rounded,
        title: 'Tutor unavailable',
        message: _errorMessage!,
      );
    }

    if (_response == null) {
      return const _TutorFeedbackCard(
        icon: Icons.school_outlined,
        title: 'No tutor response',
        message: 'The tutor did not return any content for this card.',
      );
    }

    return _TutorResponseView(response: _response!);
  }
}

class _TutorResponseView extends StatelessWidget {
  const _TutorResponseView({required this.response});

  final TutorCardResponse response;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            response.cached ? 'Cached tutor response' : 'Fresh tutor response',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(response.title, style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(response.content, style: AppTypography.bodyLarge),
        if (response.bullets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Highlights', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final bullet in response.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(bullet, style: AppTypography.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
        if (response.relatedConcepts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Related Concepts', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children:
                response.relatedConcepts
                    .map(
                      (concept) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(concept, style: AppTypography.bodySmall),
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }
}

class _TutorFeedbackCard extends StatelessWidget {
  const _TutorFeedbackCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.message});

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

class _ReviewMessage extends StatelessWidget {
  const _ReviewMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimaryTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;

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
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onPrimaryTap, child: Text(primaryLabel)),
          ],
        ),
      ),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}

class _ReviewResult {
  const _ReviewResult({required this.rating, required this.responseTimeMs});

  final String rating;
  final int responseTimeMs;
}
