import 'package:flutter_test/flutter_test.dart';

import 'package:plowth_app/features/study_repository.dart';

void main() {
  group('TutorCardResponse', () {
    test('parses tutor payload fields', () {
      final response = TutorCardResponse.fromJson({
        'card_id': 'card-1',
        'request_type': 'explain',
        'title': 'Why ATP matters',
        'content': 'ATP stores usable cellular energy.',
        'bullets': ['Source: Biology Unit 2', 'Difficulty: 3/5'],
        'related_concepts': ['Mitochondria', 'Metabolism'],
        'cached': true,
        'generated_at': '2026-04-09T10:00:00Z',
        'expires_at': '2026-04-10T10:00:00Z',
      });

      expect(response.cardId, 'card-1');
      expect(response.requestType, 'explain');
      expect(response.title, 'Why ATP matters');
      expect(response.bullets, ['Source: Biology Unit 2', 'Difficulty: 3/5']);
      expect(response.relatedConcepts, ['Mitochondria', 'Metabolism']);
      expect(response.cached, isTrue);
    });
  });

  group('CSV import models', () {
    test('CsvPreview parses columns and sample rows', () {
      final preview = CsvPreview.fromJson({
        'columns': ['Term', 'Definition', 'Deck'],
        'sample_rows': [
          {
            'Term': 'Osmosis',
            'Definition': 'Water movement across a membrane',
            'Deck': 'Biology',
          },
        ],
        'row_count': 12,
      });

      expect(preview.columns, ['Term', 'Definition', 'Deck']);
      expect(preview.sampleRows.first['Term'], 'Osmosis');
      expect(preview.rowCount, 12);
    });

    test('CsvImportResult parses import counts', () {
      final result = CsvImportResult.fromJson({
        'source_id': 'source-1',
        'title': 'biology_cards',
        'status': 'done',
        'card_count': 10,
        'skipped_count': 2,
        'row_count': 12,
        'columns': ['Term', 'Definition'],
      });

      expect(result.sourceId, 'source-1');
      expect(result.title, 'biology_cards');
      expect(result.cardCount, 10);
      expect(result.skippedCount, 2);
      expect(result.rowCount, 12);
      expect(result.columns, ['Term', 'Definition']);
    });
  });

  group('Card metadata models', () {
    test('ReviewQueueItem parses domain tags', () {
      final item = ReviewQueueItem.fromJson({
        'id': 'card-1',
        'source_id': 'source-1',
        'source_title': 'Code Notes',
        'question': 'What does calculateSchedule do?',
        'answer': 'It computes the next review time.',
        'card_type': 'definition',
        'difficulty': 3,
        'tags': {'domain_hint': 'code', 'domain_subtype': 'implementation'},
        'state': 'new',
        'reps': 0,
        'lapses': 0,
      });

      expect(item.tags?['domain_hint'], 'code');
      expect(item.tags?['domain_subtype'], 'implementation');
    });
  });

  group('Cognitive update models', () {
    test('CognitiveUpdateMatch parses candidate cards', () {
      final match = CognitiveUpdateMatch.fromJson({
        'concept_id': 'concept-1',
        'concept_name': 'Cellular respiration',
        'similarity': 0.42,
        'suggested_action': 'keep_separate',
        'cards': [
          {
            'card_id': 'card-1',
            'question': 'What is cellular respiration?',
            'answer_excerpt': 'Cells convert glucose into ATP.',
          },
        ],
      });

      expect(match.conceptName, 'Cellular respiration');
      expect(match.similarity, 0.42);
      expect(match.cards.first.cardId, 'card-1');
    });
  });
}
