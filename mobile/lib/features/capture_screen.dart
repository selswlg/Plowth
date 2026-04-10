import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import 'study_repository.dart';

enum _CaptureMode { text, csv, link, pdf }

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.onCaptureSubmitted});

  final VoidCallback onCaptureSubmitted;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final StudyRepository _repository = StudyRepository();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  _CaptureMode _mode = _CaptureMode.text;
  bool _isSubmitting = false;
  bool _isPreviewing = false;
  String? _errorMessage;
  SourceGenerationResult? _latestSubmission;
  CsvImportResult? _latestCsvImport;

  String? _csvFileName;
  Uint8List? _csvBytes;
  CsvPreview? _csvPreview;
  int? _questionColumn;
  int? _answerColumn;
  Set<int> _tagColumns = <int>{};

  bool get _isBusy => _isSubmitting || _isPreviewing;

  @override
  void dispose() {
    _urlController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _generateCards() async {
    final content = _contentController.text.trim();
    if (content.length < 30) {
      setState(() {
        _errorMessage =
            'Add at least a short paragraph so there is enough context.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _latestCsvImport = null;
    });

    try {
      final result = await _repository.createTextSource(rawContent: content);
      if (!mounted) {
        return;
      }

      _contentController.clear();
      setState(() {
        _isSubmitting = false;
        _latestSubmission = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Material received. Track progress from Home.'),
        ),
      );
      widget.onCaptureSubmitted();
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

  Future<void> _submitLink() async {
    final url = _urlController.text.trim();
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a full http:// or https:// URL.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _latestCsvImport = null;
    });

    try {
      final result = await _repository.createLinkSource(url: url);
      if (!mounted) {
        return;
      }

      _urlController.clear();
      setState(() {
        _isSubmitting = false;
        _latestSubmission = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link received. Track progress from Home.'),
        ),
      );
      widget.onCaptureSubmitted();
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

  Future<void> _pickPdfFile() async {
    setState(() {
      _isPreviewing = true;
      _errorMessage = null;
      _latestSubmission = null;
      _latestCsvImport = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null) {
        if (mounted) {
          setState(() => _isPreviewing = false);
        }
        return;
      }

      final pickedFile = result.files.single;
      final bytes = pickedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPreviewing = false;
          _errorMessage = 'The selected PDF file could not be read.';
        });
        return;
      }

      setState(() {
        _isPreviewing = false;
        _isSubmitting = true;
      });

      final upload = await _repository.createPdfSource(
        fileName: pickedFile.name,
        bytes: bytes,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _latestSubmission = upload;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF received. Track progress from Home.'),
        ),
      );
      widget.onCaptureSubmitted();
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreviewing = false;
        _isSubmitting = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreviewing = false;
        _isSubmitting = false;
        _errorMessage = 'PDF file selection failed unexpectedly.';
      });
    }
  }

  Future<void> _pickCsvFile() async {
    setState(() {
      _isPreviewing = true;
      _errorMessage = null;
      _latestSubmission = null;
      _latestCsvImport = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (result == null) {
        if (mounted) {
          setState(() => _isPreviewing = false);
        }
        return;
      }

      final pickedFile = result.files.single;
      final bytes = pickedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPreviewing = false;
          _errorMessage = 'The selected CSV file could not be read.';
        });
        return;
      }

      final preview = await _repository.previewCsvFile(
        fileName: pickedFile.name,
        bytes: bytes,
      );
      if (!mounted) {
        return;
      }

      final questionColumn = _guessColumn(preview.columns, const [
        'question',
        'term',
        'front',
        'prompt',
      ], fallback: 0);
      final answerColumn = _guessColumn(
        preview.columns,
        const ['answer', 'definition', 'back', 'response'],
        fallback: preview.columns.length > 1 ? 1 : 0,
        avoid: questionColumn,
      );

      setState(() {
        _isPreviewing = false;
        _csvFileName = pickedFile.name;
        _csvBytes = bytes;
        _csvPreview = preview;
        _questionColumn = questionColumn;
        _answerColumn = answerColumn;
        _tagColumns = <int>{};
      });
    } on StudyException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreviewing = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreviewing = false;
        _errorMessage = 'CSV file selection failed unexpectedly.';
      });
    }
  }

  Future<void> _importCsvCards() async {
    final fileName = _csvFileName;
    final bytes = _csvBytes;
    final questionColumn = _questionColumn;
    final answerColumn = _answerColumn;
    if (fileName == null ||
        bytes == null ||
        questionColumn == null ||
        answerColumn == null) {
      setState(() {
        _errorMessage = 'Choose a CSV file and map the required columns first.';
      });
      return;
    }
    if (questionColumn == answerColumn) {
      setState(() {
        _errorMessage = 'Question and answer must use different columns.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _repository.importCsvFile(
        fileName: fileName,
        bytes: bytes,
        questionColumn: questionColumn,
        answerColumn: answerColumn,
        tagColumns: _tagColumns.toList()..sort(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _latestCsvImport = result;
        _csvFileName = null;
        _csvBytes = null;
        _csvPreview = null;
        _questionColumn = null;
        _answerColumn = null;
        _tagColumns = <int>{};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV cards are ready. Start from Home.')),
      );
      widget.onCaptureSubmitted();
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

  int _guessColumn(
    List<String> columns,
    List<String> keywords, {
    required int fallback,
    int? avoid,
  }) {
    for (var index = 0; index < columns.length; index += 1) {
      if (index == avoid) {
        continue;
      }
      final lower = columns[index].toLowerCase();
      if (keywords.any(lower.contains)) {
        return index;
      }
    }

    if (fallback >= 0 && fallback < columns.length && fallback != avoid) {
      return fallback;
    }
    for (var index = 0; index < columns.length; index += 1) {
      if (index != avoid) {
        return index;
      }
    }
    return 0;
  }

  void _setMode(_CaptureMode mode) {
    if (_isBusy) {
      return;
    }
    setState(() {
      _mode = mode;
      _errorMessage = null;
    });
  }

  void _setQuestionColumn(int? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _questionColumn = value;
      _tagColumns.remove(value);
    });
  }

  void _setAnswerColumn(int? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _answerColumn = value;
      _tagColumns.remove(value);
    });
  }

  void _toggleTagColumn(int index, bool selected) {
    setState(() {
      if (selected) {
        _tagColumns.add(index);
      } else {
        _tagColumns.remove(index);
      }
    });
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
                    'Add material for your next review set',
                    style: AppTypography.displayMedium,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: _ModeSelector(
                selectedMode: _mode,
                isBusy: _isBusy,
                onModeChanged: _setMode,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(child: _buildComposerCard()),
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
          if (_latestSubmission != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              sliver: const SliverToBoxAdapter(child: _QueuedMaterialCard()),
            ),
          if (_latestCsvImport != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _CsvImportCompleteCard(result: _latestCsvImport!),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  Widget _buildComposerCard() {
    return switch (_mode) {
      _CaptureMode.text => _buildTextComposerCard(),
      _CaptureMode.csv => _buildCsvComposerCard(),
      _CaptureMode.link => _buildLinkComposerCard(),
      _CaptureMode.pdf => _buildPdfComposerCard(),
    };
  }

  Widget _buildTextComposerCard() {
    return _CapturePanel(
      title: 'Learning material',
      description:
          'Paste notes, lecture excerpts, or a short concept summary. Cards will be prepared in the background.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _contentController,
            maxLines: 12,
            minLines: 8,
            decoration: const InputDecoration(
              hintText:
                  'Paste the material you want to study. A title will be created automatically.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBusy ? null : _generateCards,
              child: Text(_isSubmitting ? 'Sending...' : 'Make Cards'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCsvComposerCard() {
    final preview = _csvPreview;
    return _CapturePanel(
      title: 'CSV import',
      description:
          'Choose a CSV, confirm the question and answer columns, then import each row as a card.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _pickCsvFile,
              icon:
                  _isPreviewing
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.upload_file_rounded),
              label: Text(_isPreviewing ? 'Reading CSV...' : 'Choose CSV File'),
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _csvFileName ?? 'Selected CSV',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${preview.rowCount} rows detected. Previewing up to 5 rows.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _CsvPreviewTable(preview: preview),
            const SizedBox(height: AppSpacing.lg),
            _ColumnDropdown(
              label: 'Question column',
              columns: preview.columns,
              value: _questionColumn,
              onChanged: _isBusy ? null : _setQuestionColumn,
            ),
            const SizedBox(height: AppSpacing.md),
            _ColumnDropdown(
              label: 'Answer column',
              columns: preview.columns,
              value: _answerColumn,
              onChanged: _isBusy ? null : _setAnswerColumn,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Tag columns', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Optional columns will be stored as card tags.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var index = 0; index < preview.columns.length; index += 1)
                  FilterChip(
                    label: Text(preview.columns[index]),
                    selected: _tagColumns.contains(index),
                    onSelected:
                        _isBusy ||
                                index == _questionColumn ||
                                index == _answerColumn
                            ? null
                            : (selected) => _toggleTagColumn(index, selected),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isBusy ? null : _importCsvCards,
                child: Text(_isSubmitting ? 'Importing...' : 'Import Cards'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkComposerCard() {
    return _CapturePanel(
      title: 'Link capture',
      description:
          'Paste a public article, guide, or documentation URL. Readable text will be extracted before cards are prepared.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://example.com/article',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBusy ? null : _submitLink,
              child: Text(_isSubmitting ? 'Sending...' : 'Make Cards'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfComposerCard() {
    return _CapturePanel(
      title: 'PDF upload',
      description:
          'Choose a text-based PDF. Selectable text will be extracted before cards are prepared.',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isBusy ? null : _pickPdfFile,
          icon:
              _isPreviewing || _isSubmitting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.picture_as_pdf_rounded),
          label: Text(
            _isSubmitting
                ? 'Uploading PDF...'
                : _isPreviewing
                ? 'Reading PDF...'
                : 'Choose PDF File',
          ),
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.selectedMode,
    required this.isBusy,
    required this.onModeChanged,
  });

  final _CaptureMode selectedMode;
  final bool isBusy;
  final ValueChanged<_CaptureMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: itemWidth,
              child: _ModeButton(
                label: 'Text',
                icon: Icons.notes_rounded,
                selected: selectedMode == _CaptureMode.text,
                onTap: isBusy ? null : () => onModeChanged(_CaptureMode.text),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _ModeButton(
                label: 'CSV',
                icon: Icons.table_chart_rounded,
                selected: selectedMode == _CaptureMode.csv,
                onTap: isBusy ? null : () => onModeChanged(_CaptureMode.csv),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _ModeButton(
                label: 'Link',
                icon: Icons.link_rounded,
                selected: selectedMode == _CaptureMode.link,
                onTap: isBusy ? null : () => onModeChanged(_CaptureMode.link),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _ModeButton(
                label: 'PDF',
                icon: Icons.picture_as_pdf_rounded,
                selected: selectedMode == _CaptureMode.pdf,
                onTap: isBusy ? null : () => onModeChanged(_CaptureMode.pdf),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.surfaceCard;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(
          color: selected ? AppColors.primaryLight : AppColors.border,
        ),
      ),
    );
  }
}

class _CapturePanel extends StatelessWidget {
  const _CapturePanel({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Text(title, style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(description, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ColumnDropdown extends StatelessWidget {
  const _ColumnDropdown({
    required this.label,
    required this.columns,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> columns;
  final int? value;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var index = 0; index < columns.length; index += 1)
          DropdownMenuItem(value: index, child: Text(columns[index])),
      ],
      onChanged: onChanged,
    );
  }
}

class _CsvPreviewTable extends StatelessWidget {
  const _CsvPreviewTable({required this.preview});

  final CsvPreview preview;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          columns: [
            for (final column in preview.columns)
              DataColumn(label: Text(column, style: AppTypography.labelSmall)),
          ],
          rows: [
            for (final row in preview.sampleRows)
              DataRow(
                cells: [
                  for (final column in preview.columns)
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          _truncateCell(row[column] ?? ''),
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _truncateCell(String value) {
    if (value.length <= 48) {
      return value;
    }
    return '${value.substring(0, 45)}...';
  }
}

class _QueuedMaterialCard extends StatelessWidget {
  const _QueuedMaterialCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cards are being prepared',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'You can leave this screen. Home will show the latest progress.',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CsvImportCompleteCard extends StatelessWidget {
  const _CsvImportCompleteCard({required this.result});

  final CsvImportResult result;

  @override
  Widget build(BuildContext context) {
    final skippedText =
        result.skippedCount == 0 ? '' : ' ${result.skippedCount} rows skipped.';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.ratingGood),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CSV cards are ready', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${result.cardCount} cards imported from ${result.rowCount} rows.$skippedText',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
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
