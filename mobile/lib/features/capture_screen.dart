import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import 'study_repository.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.onStartReview});

  final VoidCallback onStartReview;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final StudyRepository _repository = StudyRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  GenerationJob? _job;
  SourceMaterial? _source;
  List<StudyCard> _cards = const [];

  @override
  void initState() {
    super.initState();
    _resumeActiveGeneration();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _generateCards() async {
    if (_job != null &&
        (_job!.status == 'pending' || _job!.status == 'running') &&
        _source != null) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
      await _pollGeneration(
        SourceGenerationResult(
          sourceId: _source!.id,
          jobId: _job!.id,
          status: _job!.status,
        ),
      );
      return;
    }

    final content = _contentController.text.trim();
    if (content.length < 30) {
      setState(() {
        _errorMessage =
            'Add at least a short paragraph so the generator has enough context.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _job = null;
      _source = null;
      _cards = const [];
    });

    try {
      final result = await _repository.createTextSource(
        title: _titleController.text,
        rawContent: content,
      );

      await _pollGeneration(result);
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

  Future<void> _resumeActiveGeneration() async {
    try {
      final job = await _repository.getLatestActiveGenerationJob();
      if (job == null || job.sourceId == null) {
        return;
      }

      final source = await _repository.getSource(job.sourceId!);
      if (!mounted) {
        return;
      }

      if (_titleController.text.trim().isEmpty) {
        _titleController.text = source.title ?? '';
      }
      if (_contentController.text.trim().isEmpty && source.rawContent != null) {
        _contentController.text = source.rawContent!;
      }

      setState(() {
        _job = job;
        _source = source;
        _isSubmitting = true;
      });

      await _pollGeneration(
        SourceGenerationResult(
          sourceId: source.id,
          jobId: job.id,
          status: job.status,
        ),
      );
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

  Future<void> _pollGeneration(SourceGenerationResult result) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final source = await _repository.getSource(result.sourceId);
      final job =
          result.jobId == null ? null : await _repository.getJob(result.jobId!);

      if (!mounted) {
        return;
      }

      setState(() {
        _source = source;
        _job = job;
      });

      final generationFailed =
          source.status == 'error' || job?.status == 'failed';
      if (generationFailed) {
        throw StudyException(
          job?.errorMessage ??
              source.errorMessage ??
              'Card generation failed unexpectedly.',
        );
      }

      final generationDone =
          source.status == 'done' || job?.status == 'completed';
      if (generationDone) {
        final cards = await _repository.getCards(sourceId: result.sourceId);
        if (!mounted) {
          return;
        }
        _titleController.text = source.title ?? _titleController.text;
        _contentController.text = source.rawContent ?? _contentController.text;
        setState(() {
          _cards = cards;
          _source = source;
          _job = job;
          _isSubmitting = false;
        });
        return;
      }

      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _errorMessage =
          'Generation is still running. Resume polling instead of creating a duplicate source.';
    });
  }

  Future<void> _editCard(StudyCard card) async {
    final draft = await _showCardEditor(card);
    if (draft == null) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final updated = await _repository.updateCard(
        cardId: card.id,
        question: draft.question,
        answer: draft.answer,
        difficulty: draft.difficulty,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _cards = [
          for (final existing in _cards)
            if (existing.id == updated.id) updated else existing,
        ];
      });
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    }
  }

  Future<_CardDraft?> _showCardEditor(StudyCard card) {
    final questionController = TextEditingController(text: card.question);
    final answerController = TextEditingController(text: card.answer);
    var difficulty = card.difficulty;

    return showModalBottomSheet<_CardDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Card', style: AppTypography.headlineMedium),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: questionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Question',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: answerController,
                        maxLines: 5,
                        decoration: const InputDecoration(labelText: 'Answer'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Difficulty', style: AppTypography.labelLarge),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1')),
                          ButtonSegment(value: 2, label: Text('2')),
                          ButtonSegment(value: 3, label: Text('3')),
                          ButtonSegment(value: 4, label: Text('4')),
                          ButtonSegment(value: 5, label: Text('5')),
                        ],
                        selected: {difficulty},
                        onSelectionChanged: (selection) {
                          setSheetState(() {
                            difficulty = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(
                              _CardDraft(
                                question: questionController.text,
                                answer: answerController.text,
                                difficulty: difficulty,
                              ),
                            );
                          },
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  List<String> _qualityWarnings(StudyCard card) {
    final warnings = <String>[];
    if (card.question.trim().length < 18) {
      warnings.add('Question is terse');
    }
    if (card.answer.trim().length < 32) {
      warnings.add('Answer needs more context');
    }
    if (card.difficulty >= 5) {
      warnings.add('High difficulty');
    }
    return warnings;
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
                  Text('Capture', style: AppTypography.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Turn raw notes into a review set',
                    style: AppTypography.displayMedium,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(child: _buildComposerCard()),
          ),
          if (_source != null || _job != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _buildStatusCard()),
            ),
          if (_errorMessage != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _InlineMessage(
                  color: AppColors.accentRed,
                  icon: Icons.error_outline_rounded,
                  message: _errorMessage!,
                ),
              ),
            ),
          if (_cards.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Generated Cards',
                          style: AppTypography.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onStartReview,
                        child: const Text('Start Review'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Review and tighten the wording before you study.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final card in _cards)
                    _PreviewCard(
                      card: card,
                      warnings: _qualityWarnings(card),
                      onTap: () => _editCard(card),
                    ),
                ],
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  Widget _buildComposerCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Material', style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Paste notes, lecture snippets, or a concept summary. The Phase 2 pipeline will chunk it, create concepts, and draft cards.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Optional topic label',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _contentController,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Paste the material you want to turn into cards.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _generateCards,
              child: Text(
                _isSubmitting
                    ? 'Generating Cards...'
                    : (_job != null &&
                        (_job!.status == 'pending' ||
                            _job!.status == 'running'))
                    ? 'Resume Generation'
                    : 'Generate Review Set',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final sourceStatus = _source?.status ?? 'analyzing';
    final jobStatus = _job?.status ?? 'pending';
    final cardCount = _source?.metadata?['card_count'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _cards.isEmpty ? 'Analyzing material' : 'Generation complete',
                  style: AppTypography.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Source: $sourceStatus  •  Job: $jobStatus',
            style: AppTypography.bodyMedium,
          ),
          if (cardCount != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$cardCount cards drafted from this source.',
              style: AppTypography.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.card,
    required this.warnings,
    required this.onTap,
  });

  final StudyCard card;
  final List<String> warnings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.cardType.toUpperCase(),
                      style: AppTypography.labelSmall,
                    ),
                  ),
                  Text(
                    'D${card.difficulty}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(card.question, style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(card.answer, style: AppTypography.bodyMedium),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children:
                      warnings
                          .map(
                            (warning) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentOrange.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Text(
                                warning,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.accentOrange,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.color,
    required this.icon,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}

class _CardDraft {
  const _CardDraft({
    required this.question,
    required this.answer,
    required this.difficulty,
  });

  final String question;
  final String answer;
  final int difficulty;
}
