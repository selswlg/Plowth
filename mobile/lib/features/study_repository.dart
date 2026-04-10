import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';

class StudyException implements Exception {
  const StudyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SourceGenerationResult {
  const SourceGenerationResult({
    required this.sourceId,
    required this.jobId,
    required this.status,
  });

  final String sourceId;
  final String? jobId;
  final String status;

  factory SourceGenerationResult.fromJson(Map<String, dynamic> json) {
    return SourceGenerationResult(
      sourceId: json['id'] as String,
      jobId: json['job_id'] as String?,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class CsvPreview {
  const CsvPreview({
    required this.columns,
    required this.sampleRows,
    required this.rowCount,
  });

  final List<String> columns;
  final List<Map<String, String>> sampleRows;
  final int rowCount;

  factory CsvPreview.fromJson(Map<String, dynamic> json) {
    return CsvPreview(
      columns:
          ((json['columns'] as List?) ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      sampleRows:
          ((json['sample_rows'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (row) => row.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ),
              )
              .toList(),
      rowCount: json['row_count'] as int? ?? 0,
    );
  }
}

class CsvImportResult {
  const CsvImportResult({
    required this.sourceId,
    required this.title,
    required this.status,
    required this.cardCount,
    required this.skippedCount,
    required this.rowCount,
    required this.columns,
  });

  final String sourceId;
  final String? title;
  final String status;
  final int cardCount;
  final int skippedCount;
  final int rowCount;
  final List<String> columns;

  factory CsvImportResult.fromJson(Map<String, dynamic> json) {
    return CsvImportResult(
      sourceId: json['source_id'] as String,
      title: json['title'] as String?,
      status: json['status'] as String? ?? 'done',
      cardCount: json['card_count'] as int? ?? 0,
      skippedCount: json['skipped_count'] as int? ?? 0,
      rowCount: json['row_count'] as int? ?? 0,
      columns:
          ((json['columns'] as List?) ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

class GenerationJob {
  const GenerationJob({
    required this.id,
    required this.jobType,
    required this.status,
    required this.sourceId,
    required this.resultSummary,
    required this.errorMessage,
  });

  final String id;
  final String jobType;
  final String status;
  final String? sourceId;
  final Map<String, dynamic>? resultSummary;
  final String? errorMessage;

  factory GenerationJob.fromJson(Map<String, dynamic> json) {
    return GenerationJob(
      id: json['id'] as String,
      jobType: json['job_type'] as String? ?? 'card_generation',
      status: json['status'] as String? ?? 'pending',
      sourceId: json['source_id'] as String?,
      resultSummary: (json['result_summary'] as Map?)?.cast<String, dynamic>(),
      errorMessage: json['error_message'] as String?,
    );
  }
}

class SourceMaterial {
  const SourceMaterial({
    required this.id,
    required this.title,
    required this.status,
    required this.errorMessage,
    required this.metadata,
    required this.rawContent,
  });

  final String id;
  final String? title;
  final String status;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final String? rawContent;

  factory SourceMaterial.fromJson(Map<String, dynamic> json) {
    return SourceMaterial(
      id: json['id'] as String,
      title: json['title'] as String?,
      status: json['status'] as String? ?? 'uploaded',
      errorMessage: json['error_message'] as String?,
      metadata: (json['metadata_'] as Map?)?.cast<String, dynamic>(),
      rawContent: json['raw_content'] as String?,
    );
  }
}

class StudyCard {
  const StudyCard({
    required this.id,
    required this.sourceId,
    required this.cardType,
    required this.question,
    required this.answer,
    required this.difficulty,
    required this.isActive,
    required this.tags,
  });

  final String id;
  final String sourceId;
  final String cardType;
  final String question;
  final String answer;
  final int difficulty;
  final bool isActive;
  final Map<String, dynamic>? tags;

  String get domainHint => tags?['domain_hint']?.toString() ?? 'general';

  String? get domainSubtype => tags?['domain_subtype']?.toString();

  Map<String, String> get domainFields {
    final rawFields = tags?['domain_fields'];
    if (rawFields is! Map) {
      return const <String, String>{};
    }
    return rawFields.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  factory StudyCard.fromJson(Map<String, dynamic> json) {
    return StudyCard(
      id: json['id'] as String,
      sourceId: json['source_id'] as String,
      cardType: json['card_type'] as String? ?? 'definition',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      difficulty: json['difficulty'] as int? ?? 3,
      isActive: json['is_active'] as bool? ?? true,
      tags: (json['tags'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

class ReviewQueueItem {
  const ReviewQueueItem({
    required this.id,
    required this.sourceId,
    required this.sourceTitle,
    required this.question,
    required this.answer,
    required this.cardType,
    required this.difficulty,
    required this.tags,
    required this.state,
    required this.nextReviewAt,
    required this.reps,
    required this.lapses,
  });

  final String id;
  final String sourceId;
  final String? sourceTitle;
  final String question;
  final String answer;
  final String cardType;
  final int difficulty;
  final Map<String, dynamic>? tags;
  final String state;
  final DateTime? nextReviewAt;
  final int reps;
  final int lapses;

  factory ReviewQueueItem.fromJson(Map<String, dynamic> json) {
    return ReviewQueueItem(
      id: json['id'] as String,
      sourceId: json['source_id'] as String,
      sourceTitle: json['source_title'] as String?,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      cardType: json['card_type'] as String? ?? 'definition',
      difficulty: json['difficulty'] as int? ?? 3,
      tags: (json['tags'] as Map?)?.cast<String, dynamic>(),
      state: json['state'] as String? ?? 'new',
      nextReviewAt:
          json['next_review_at'] == null
              ? null
              : DateTime.parse(json['next_review_at'] as String).toLocal(),
      reps: json['reps'] as int? ?? 0,
      lapses: json['lapses'] as int? ?? 0,
    );
  }
}

class ReviewSubmission {
  const ReviewSubmission({
    required this.cardId,
    required this.rating,
    required this.responseTimeMs,
    required this.reviewedAt,
  });

  final String cardId;
  final String rating;
  final int responseTimeMs;
  final DateTime reviewedAt;

  factory ReviewSubmission.fromJson(Map<String, dynamic> json) {
    return ReviewSubmission(
      cardId: json['card_id'] as String,
      rating: json['rating'] as String,
      responseTimeMs: json['response_time_ms'] as int? ?? 0,
      reviewedAt: DateTime.parse(json['reviewed_at'] as String).toLocal(),
    );
  }
}

class TodayReviewSummary {
  const TodayReviewSummary({
    required this.totalCards,
    required this.againCount,
    required this.hardCount,
    required this.goodCount,
    required this.easyCount,
    required this.avgResponseTimeMs,
    required this.accuracyRate,
  });

  final int totalCards;
  final int againCount;
  final int hardCount;
  final int goodCount;
  final int easyCount;
  final double? avgResponseTimeMs;
  final double accuracyRate;

  factory TodayReviewSummary.fromJson(Map<String, dynamic> json) {
    return TodayReviewSummary(
      totalCards: json['total_cards'] as int? ?? 0,
      againCount: json['again_count'] as int? ?? 0,
      hardCount: json['hard_count'] as int? ?? 0,
      goodCount: json['good_count'] as int? ?? 0,
      easyCount: json['easy_count'] as int? ?? 0,
      avgResponseTimeMs: (json['avg_response_time_ms'] as num?)?.toDouble(),
      accuracyRate: (json['accuracy_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DailyInsightSnapshot {
  const DailyInsightSnapshot({
    required this.totalDueToday,
    required this.completedToday,
    required this.accuracyToday,
    required this.streakDays,
    required this.memoryStrength,
  });

  final int totalDueToday;
  final int completedToday;
  final double? accuracyToday;
  final int streakDays;
  final double memoryStrength;

  factory DailyInsightSnapshot.fromJson(Map<String, dynamic> json) {
    return DailyInsightSnapshot(
      totalDueToday: json['total_due_today'] as int? ?? 0,
      completedToday: json['completed_today'] as int? ?? 0,
      accuracyToday: (json['accuracy_today'] as num?)?.toDouble(),
      streakDays: json['streak_days'] as int? ?? 0,
      memoryStrength: (json['memory_strength'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WeakConceptInsight {
  const WeakConceptInsight({
    required this.conceptName,
    required this.failureCount,
    required this.lastFailedAt,
  });

  final String conceptName;
  final int failureCount;
  final DateTime? lastFailedAt;

  factory WeakConceptInsight.fromJson(Map<String, dynamic> json) {
    return WeakConceptInsight(
      conceptName: json['concept_name'] as String? ?? 'Unknown concept',
      failureCount: json['failure_count'] as int? ?? 0,
      lastFailedAt:
          json['last_failed_at'] == null
              ? null
              : DateTime.parse(json['last_failed_at'] as String).toLocal(),
    );
  }
}

class InsightSnapshot {
  const InsightSnapshot({
    required this.overview,
    required this.weakConcepts,
    required this.coachTitle,
    required this.coachMessage,
    required this.focusTopic,
  });

  final DailyInsightSnapshot overview;
  final List<WeakConceptInsight> weakConcepts;
  final String coachTitle;
  final String coachMessage;
  final String? focusTopic;

  factory InsightSnapshot.fromJson(Map<String, dynamic> json) {
    return InsightSnapshot(
      overview: DailyInsightSnapshot.fromJson(
        (json['overview'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      weakConcepts:
          ((json['weak_concepts'] as List?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(WeakConceptInsight.fromJson)
              .toList(),
      coachTitle: json['coach_title'] as String? ?? 'Stay consistent',
      coachMessage:
          json['coach_message'] as String? ??
          'Review a focused set before adding more material.',
      focusTopic: json['focus_topic'] as String?,
    );
  }
}

class TutorCardResponse {
  const TutorCardResponse({
    required this.cardId,
    required this.requestType,
    required this.title,
    required this.content,
    required this.bullets,
    required this.relatedConcepts,
    required this.cached,
    required this.generatedAt,
    required this.expiresAt,
  });

  final String cardId;
  final String requestType;
  final String title;
  final String content;
  final List<String> bullets;
  final List<String> relatedConcepts;
  final bool cached;
  final DateTime generatedAt;
  final DateTime expiresAt;

  factory TutorCardResponse.fromJson(Map<String, dynamic> json) {
    return TutorCardResponse(
      cardId: json['card_id'] as String,
      requestType: json['request_type'] as String? ?? 'explain',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      bullets:
          ((json['bullets'] as List?) ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      relatedConcepts:
          ((json['related_concepts'] as List?) ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      cached: json['cached'] as bool? ?? false,
      generatedAt: DateTime.parse(json['generated_at'] as String).toLocal(),
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
    );
  }
}

class CognitiveUpdateCardCandidate {
  const CognitiveUpdateCardCandidate({
    required this.cardId,
    required this.question,
    required this.answerExcerpt,
  });

  final String cardId;
  final String question;
  final String answerExcerpt;

  factory CognitiveUpdateCardCandidate.fromJson(Map<String, dynamic> json) {
    return CognitiveUpdateCardCandidate(
      cardId: json['card_id'] as String,
      question: json['question'] as String? ?? '',
      answerExcerpt: json['answer_excerpt'] as String? ?? '',
    );
  }
}

class CognitiveUpdateMatch {
  const CognitiveUpdateMatch({
    required this.conceptId,
    required this.conceptName,
    required this.similarity,
    required this.suggestedAction,
    required this.cards,
  });

  final String conceptId;
  final String conceptName;
  final double similarity;
  final String suggestedAction;
  final List<CognitiveUpdateCardCandidate> cards;

  factory CognitiveUpdateMatch.fromJson(Map<String, dynamic> json) {
    return CognitiveUpdateMatch(
      conceptId: json['concept_id'] as String,
      conceptName: json['concept_name'] as String? ?? 'Unknown concept',
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
      suggestedAction: json['suggested_action'] as String? ?? 'keep_separate',
      cards:
          ((json['cards'] as List?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(CognitiveUpdateCardCandidate.fromJson)
              .toList(),
    );
  }
}

class StudyRepository {
  StudyRepository({Dio? dio}) : _dio = dio ?? _buildDio();

  static const _accessTokenKey = 'access_token';
  final Dio _dio;

  Future<SourceGenerationResult> createTextSource({
    String? title,
    required String rawContent,
  }) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sources',
        data: {
          'title': title == null || title.trim().isEmpty ? null : title.trim(),
          'source_type': 'text',
          'raw_content': rawContent.trim(),
        },
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Source creation returned no payload.');
      }
      return SourceGenerationResult.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<SourceGenerationResult> createLinkSource({required String url}) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sources',
        data: {'source_type': 'link', 'url': url.trim()},
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Link source creation returned no payload.');
      }
      return SourceGenerationResult.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<SourceGenerationResult> createPdfSource({
    required String fileName,
    required Uint8List bytes,
  }) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sources/upload',
        data: FormData.fromMap({
          'source_type': 'pdf',
          'file': MultipartFile.fromBytes(bytes, filename: fileName),
        }),
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('PDF source creation returned no payload.');
      }
      return SourceGenerationResult.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<CsvPreview> previewCsvFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sources/csv/preview',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: fileName),
        }),
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('CSV preview returned no payload.');
      }
      return CsvPreview.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<CsvImportResult> importCsvFile({
    required String fileName,
    required Uint8List bytes,
    required int questionColumn,
    required int answerColumn,
    List<int> tagColumns = const [],
  }) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sources/csv/import',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: fileName),
          'question_column': questionColumn,
          'answer_column': answerColumn,
          if (tagColumns.isNotEmpty) 'tag_columns': tagColumns.join(','),
        }),
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('CSV import returned no payload.');
      }
      return CsvImportResult.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<GenerationJob> getJob(String jobId) async {
    await _authorize();
    try {
      final response = await _dio.get<Map<String, dynamic>>('/jobs/$jobId');
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Job lookup returned no payload.');
      }
      return GenerationJob.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<GenerationJob?> getLatestActiveGenerationJob() async {
    return getLatestGenerationJob(activeOnly: true);
  }

  Future<GenerationJob?> getLatestGenerationJob({
    bool activeOnly = false,
  }) async {
    await _authorize();
    try {
      final response = await _dio.get<List<dynamic>>(
        '/jobs',
        queryParameters: {'limit': 20},
      );
      final jobs =
          (response.data ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(GenerationJob.fromJson)
              .where(
                (job) =>
                    job.jobType == 'card_generation' &&
                    (!activeOnly ||
                        job.status == 'pending' ||
                        job.status == 'running'),
              )
              .toList();
      if (jobs.isEmpty) {
        return null;
      }
      return jobs.first;
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<GenerationJob> retryJob(String jobId) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/jobs/$jobId/retry',
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Job retry returned no payload.');
      }
      return GenerationJob.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<SourceMaterial> getSource(String sourceId) async {
    await _authorize();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sources/$sourceId',
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Source lookup returned no payload.');
      }
      return SourceMaterial.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<List<StudyCard>> getCards({String? sourceId}) async {
    await _authorize();
    try {
      final response = await _dio.get<List<dynamic>>(
        '/cards',
        queryParameters: {
          if (sourceId != null) 'source_id': sourceId,
          'limit': 100,
        },
      );
      return (response.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StudyCard.fromJson)
          .toList();
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<StudyCard> updateCard({
    required String cardId,
    required String question,
    required String answer,
    required int difficulty,
    Map<String, dynamic>? tags,
  }) async {
    await _authorize();
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/cards/$cardId',
        data: {
          'question': question.trim(),
          'answer': answer.trim(),
          'difficulty': difficulty,
          if (tags != null) 'tags': tags,
        },
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Card update returned no payload.');
      }
      return StudyCard.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<List<ReviewQueueItem>> getReviewQueue({int limit = 50}) async {
    await _authorize();
    try {
      final response = await _dio.get<List<dynamic>>(
        '/reviews/queue',
        queryParameters: {'limit': limit},
      );
      return (response.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ReviewQueueItem.fromJson)
          .toList();
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<ReviewSubmission> submitReview({
    required String cardId,
    required String rating,
    required int responseTimeMs,
    required String clientId,
  }) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reviews',
        data: {
          'card_id': cardId,
          'rating': rating,
          'response_time_ms': responseTimeMs,
          'client_id': clientId,
        },
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Review submission returned no payload.');
      }
      return ReviewSubmission.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<TodayReviewSummary> getTodaySummary() async {
    await _authorize();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reviews/summary/today',
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Review summary returned no payload.');
      }
      return TodayReviewSummary.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<InsightSnapshot> getInsightSnapshot() async {
    await _authorize();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/insights/snapshot',
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Insight snapshot returned no payload.');
      }
      return InsightSnapshot.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<TutorCardResponse> getTutorResponse({
    required String cardId,
    required String requestType,
  }) async {
    await _authorize();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/cards/$cardId/tutor/$requestType',
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException('Tutor response returned no payload.');
      }
      return TutorCardResponse.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<List<CognitiveUpdateMatch>> previewCognitiveUpdate({
    required String conceptName,
    required String description,
  }) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/insights/cognitive-update/preview',
        data: {
          'concept_name': conceptName.trim(),
          'description': description.trim().isEmpty ? null : description.trim(),
          'limit': 5,
        },
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException(
          'Cognitive update preview returned no payload.',
        );
      }
      return ((payload['matches'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CognitiveUpdateMatch.fromJson)
          .toList();
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<StudyCard> applyCognitiveUpdate({
    required String cardId,
    required String newEvidence,
    required String sourceConceptName,
    required String action,
  }) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/insights/cognitive-update/apply',
        data: {
          'card_id': cardId,
          'new_evidence': newEvidence.trim(),
          'source_concept_name': sourceConceptName.trim(),
          'action': action,
        },
      );
      final payload = response.data;
      if (payload == null) {
        throw const StudyException(
          'Cognitive update apply returned no payload.',
        );
      }
      return StudyCard.fromJson(payload);
    } on DioException catch (error) {
      throw StudyException(_mapDioError(error));
    }
  }

  Future<void> _authorize() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    if (accessToken == null || accessToken.isEmpty) {
      throw const StudyException(
        'No authenticated session found on this device.',
      );
    }
    _dio.options.headers['Authorization'] = 'Bearer $accessToken';
  }

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  String _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      final detail = error.response?.data;
      if (detail is Map<String, dynamic> && detail['detail'] is String) {
        return detail['detail'] as String;
      }
      if (detail is String && detail.isNotEmpty) {
        try {
          final decoded = jsonDecode(detail);
          if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
            return decoded['detail'] as String;
          }
        } catch (_) {
          return detail;
        }
      }
      return 'API request failed with status $statusCode.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The API request timed out. Check the backend server and try again.';
      case DioExceptionType.connectionError:
        return 'Unable to reach the backend API. Verify the server is running and the base URL is correct.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'The API certificate was rejected.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'The study request failed unexpectedly.';
    }
  }
}
