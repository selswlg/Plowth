import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import 'study_repository.dart';

class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, this.sourceId, this.sourceTitle});

  final String? sourceId;
  final String? sourceTitle;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  late final StudyRepository _repository;
  late Future<List<StudyCard>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _repository = StudyRepository();
    _cardsFuture = _loadCards();
  }

  Future<List<StudyCard>> _loadCards() {
    return _repository.getCards(sourceId: widget.sourceId);
  }

  void _refreshCards() {
    setState(() {
      _cardsFuture = _loadCards();
    });
  }

  Future<void> _openCardEditor(StudyCard card) async {
    final updated = await showModalBottomSheet<StudyCard>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder:
          (context) => _CardEditorSheet(repository: _repository, card: card),
    );

    if (updated != null && mounted) {
      _refreshCards();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Card saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.sourceTitle ?? 'Cards';

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Cards', style: AppTypography.headlineMedium),
      ),
      body: SafeArea(
        child: FutureBuilder<List<StudyCard>>(
          future: _cardsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _EditorMessage(
                icon: Icons.error_outline_rounded,
                title: 'Cards unavailable',
                message: 'Refresh after your session is connected.',
                actionLabel: 'Refresh',
                onAction: _refreshCards,
              );
            }

            final cards = snapshot.data ?? const <StudyCard>[];
            if (cards.isEmpty) {
              return _EditorMessage(
                icon: Icons.style_outlined,
                title: 'No cards ready',
                message: 'Generate cards from Capture before editing them.',
                actionLabel: 'Refresh',
                onAction: _refreshCards,
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _refreshCards(),
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
                          Text(title, style: AppTypography.displayMedium),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${cards.length} cards ready for tightening.',
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: cards.length,
                      separatorBuilder:
                          (context, index) =>
                              const SizedBox(height: AppSpacing.md),
                      itemBuilder:
                          (context, index) => _CardListItem(
                            card: cards[index],
                            onTap: () => _openCardEditor(cards[index]),
                          ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardListItem extends StatelessWidget {
  const _CardListItem({required this.card, required this.onTap});

  final StudyCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final domain = _formatDomain(card.domainHint);
    final subtype = card.domainSubtype;

    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _MetadataPill(label: domain),
                  _MetadataPill(label: card.cardType.toUpperCase()),
                  if (subtype != null && subtype.isNotEmpty)
                    _MetadataPill(label: subtype),
                  _MetadataPill(label: 'D${card.difficulty}'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(card.question, style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                card.answer,
                style: AppTypography.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Edit',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardEditorSheet extends StatefulWidget {
  const _CardEditorSheet({required this.repository, required this.card});

  final StudyRepository repository;
  final StudyCard card;

  @override
  State<_CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends State<_CardEditorSheet> {
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  late final TextEditingController _subtypeController;
  late final List<_DomainFieldSpec> _domainFieldSpecs;
  late final Map<String, TextEditingController> _domainControllers;
  late int _difficulty;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.card.question);
    _answerController = TextEditingController(text: widget.card.answer);
    _subtypeController = TextEditingController(
      text: widget.card.domainSubtype ?? '',
    );
    _difficulty = widget.card.difficulty.clamp(1, 5);
    _domainFieldSpecs = _DomainFieldSpec.forDomain(widget.card.domainHint);
    final existingFields = widget.card.domainFields;
    _domainControllers = {
      for (final spec in _domainFieldSpecs)
        spec.key: TextEditingController(text: existingFields[spec.key] ?? ''),
    };
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _subtypeController.dispose();
    for (final controller in _domainControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildTags() {
    final tags = Map<String, dynamic>.from(
      widget.card.tags ?? const <String, dynamic>{},
    );
    tags['domain_hint'] = widget.card.domainHint;

    final subtype = _subtypeController.text.trim();
    if (subtype.isEmpty) {
      tags.remove('domain_subtype');
    } else {
      tags['domain_subtype'] = subtype;
    }

    final rawExistingFields = tags['domain_fields'];
    final fields = <String, String>{
      if (rawExistingFields is Map)
        for (final entry in rawExistingFields.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
    };

    for (final spec in _domainFieldSpecs) {
      final value = _domainControllers[spec.key]?.text.trim() ?? '';
      if (value.isEmpty) {
        fields.remove(spec.key);
      } else {
        fields[spec.key] = value;
      }
    }

    if (fields.isEmpty) {
      tags.remove('domain_fields');
    } else {
      tags['domain_fields'] = fields;
    }

    return tags;
  }

  Future<void> _save() async {
    final question = _questionController.text.trim();
    final answer = _answerController.text.trim();

    if (question.length < 5 || answer.length < 3) {
      setState(() {
        _errorMessage = 'Question and answer need more detail.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.repository.updateCard(
        cardId: widget.card.id,
        question: question,
        answer: answer,
        difficulty: _difficulty,
        tags: _buildTags(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final domain = _formatDomain(widget.card.domainHint);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Card', style: AppTypography.headlineMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$domain guidance',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _questionController,
                maxLines: 3,
                minLines: 2,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _answerController,
                maxLines: 6,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(labelText: 'Answer'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Difficulty $_difficulty / 5',
                style: AppTypography.labelLarge,
              ),
              Slider(
                value: _difficulty.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$_difficulty',
                onChanged:
                    _isSaving
                        ? null
                        : (value) {
                          setState(() {
                            _difficulty = value.round();
                          });
                        },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _subtypeController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Domain focus',
                  hintText: 'implementation, vocabulary, exam trap',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Domain Notes', style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _domainHelperText(widget.card.domainHint),
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final spec in _domainFieldSpecs) ...[
                TextField(
                  controller: _domainControllers[spec.key],
                  enabled: !_isSaving,
                  maxLines: spec.maxLines,
                  minLines: spec.minLines,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: spec.label,
                    hintText: spec.hint,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_errorMessage != null) ...[
                _EditorBanner(message: _errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child:
                      _isSaving
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Save Card'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainFieldSpec {
  const _DomainFieldSpec({
    required this.key,
    required this.label,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 2,
  });

  final String key;
  final String label;
  final String hint;
  final int minLines;
  final int maxLines;

  static List<_DomainFieldSpec> forDomain(String domainHint) {
    switch (domainHint) {
      case 'code':
        return const [
          _DomainFieldSpec(
            key: 'implementation_note',
            label: 'Implementation note',
            hint: 'Function, API, or invariant to remember',
          ),
          _DomainFieldSpec(
            key: 'edge_case',
            label: 'Edge case',
            hint: 'Input or state that breaks weak answers',
          ),
          _DomainFieldSpec(
            key: 'snippet',
            label: 'Snippet',
            hint: 'Minimal code cue',
            minLines: 2,
            maxLines: 4,
          ),
        ];
      case 'language':
        return const [
          _DomainFieldSpec(
            key: 'grammar_note',
            label: 'Grammar point',
            hint: 'Pattern, conjugation, or word order',
          ),
          _DomainFieldSpec(
            key: 'example_sentence',
            label: 'Natural example',
            hint: 'A sentence worth repeating aloud',
          ),
          _DomainFieldSpec(
            key: 'translation_hint',
            label: 'Translation cue',
            hint: 'Native-language anchor or false friend',
          ),
        ];
      case 'exam':
        return const [
          _DomainFieldSpec(
            key: 'exam_trap',
            label: 'Exam trap',
            hint: 'The wording that causes mistakes',
          ),
          _DomainFieldSpec(
            key: 'memory_cue',
            label: 'Memory cue',
            hint: 'A short recall hook',
          ),
          _DomainFieldSpec(
            key: 'common_mistake',
            label: 'Common mistake',
            hint: 'The answer you should avoid',
          ),
        ];
      default:
        return const [
          _DomainFieldSpec(
            key: 'example',
            label: 'Example',
            hint: 'A concrete case that makes the answer easier',
          ),
          _DomainFieldSpec(
            key: 'contrast',
            label: 'Contrast',
            hint: 'Similar idea that should stay separate',
          ),
          _DomainFieldSpec(
            key: 'context',
            label: 'Context',
            hint: 'When this answer matters',
          ),
        ];
    }
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: AppColors.primaryLight),
      ),
    );
  }
}

class _EditorMessage extends StatelessWidget {
  const _EditorMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
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
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _EditorBanner extends StatelessWidget {
  const _EditorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.32)),
      ),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.accentRed),
      ),
    );
  }
}

String _formatDomain(String domainHint) {
  switch (domainHint) {
    case 'code':
      return 'Code';
    case 'language':
      return 'Language';
    case 'exam':
      return 'Exam';
    default:
      return 'General';
  }
}

String _domainHelperText(String domainHint) {
  switch (domainHint) {
    case 'code':
      return 'Keep the invariant, edge case, and minimal snippet close to the answer.';
    case 'language':
      return 'Keep grammar, natural usage, and translation cues separate.';
    case 'exam':
      return 'Keep traps and memory cues visible before the next review.';
    default:
      return 'Keep examples, contrasts, and context attached to the card.';
  }
}
