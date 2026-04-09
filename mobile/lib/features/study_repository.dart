import 'dart:convert';

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
  });

  final String id;
  final String sourceId;
  final String cardType;
  final String question;
  final String answer;
  final int difficulty;
  final bool isActive;

  factory StudyCard.fromJson(Map<String, dynamic> json) {
    return StudyCard(
      id: json['id'] as String,
      sourceId: json['source_id'] as String,
      cardType: json['card_type'] as String? ?? 'definition',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      difficulty: json['difficulty'] as int? ?? 3,
      isActive: json['is_active'] as bool? ?? true,
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

class StudyRepository {
  StudyRepository({Dio? dio}) : _dio = dio ?? _buildDio();

  static const _accessTokenKey = 'access_token';
  final Dio _dio;

  Future<SourceGenerationResult> createTextSource({
    required String title,
    required String rawContent,
  }) async {
    await _authorize();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sources',
        data: {
          'title': title.trim().isEmpty ? null : title.trim(),
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
                    (job.status == 'pending' || job.status == 'running'),
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
  }) async {
    await _authorize();
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/cards/$cardId',
        data: {
          'question': question.trim(),
          'answer': answer.trim(),
          'difficulty': difficulty,
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
