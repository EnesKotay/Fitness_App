import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/storage_helper.dart';
import '../models/ai_coach_models.dart';

class AiCoachService {
  final ApiClient _apiClient;

  AiCoachService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<CoachResponse> generatePlan({
    required CoachGoal goal,
    required DailySummary summary,
    required String userPrompt,
  }) async {
    try {
      final token = StorageHelper.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException(
          message: 'Oturum bulunamadi. Lutfen tekrar giris yap.',
        );
      }

      final response = await _apiClient.post(
        ApiConstants.aiCoach,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          // AI response can take longer because backend may try fallback models.
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'goal': goal.name,
          'dailySummary': {
            'steps': summary.steps,
            'calories': summary.calories,
            'waterLiters': summary.waterLiters,
            'sleepHours': summary.sleepHours,
            'workouts': summary.workouts,
          },
          'question': userPrompt,
        },
      );

      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw ApiException(message: 'Koc yaniti beklenmeyen formatta.');
      }
      final data = raw;
      final actionItemsRaw = data['actionItems'] as List<dynamic>? ?? const [];
      final actionItems = actionItemsRaw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();

      return CoachResponse(
        focus: (data['todayFocus'] ?? '').toString().trim(),
        todoItems: actionItems,
        nutritionNote: (data['nutritionNote'] ?? '').toString().trim(),
      );
    } catch (e) {
      if (e is ApiException) {
        if (e.statusCode == 429) {
          final retry = _extractRetryAfterSeconds(e.data);
          throw ApiException(
            message: retry != null
                ? 'Cok fazla istek. ${retry}s sonra tekrar dene.'
                : 'Cok fazla istek. Lutfen biraz sonra tekrar dene.',
            statusCode: 429,
            data: e.data,
          );
        }
        if (e.statusCode == 502 || e.statusCode == 503) {
          final data = e.data;
          final backendError = data is Map
              ? (data['error']?.toString() ?? '')
              : e.message;
          if (backendError.contains('GEMINI_API_KEY')) {
            throw ApiException(
              message:
                  'AI servisi henuz hazir degil. Backend GEMINI_API_KEY ayarini kontrol et.',
            );
          }
          if (backendError.isNotEmpty) {
            throw ApiException(message: backendError);
          }
          throw ApiException(
            message:
                'AI servisi gecici olarak kullanilamiyor. Lutfen biraz sonra tekrar dene.',
          );
        }
        rethrow;
      }
      throw ApiException(
        message: 'Koc yaniti olusturulamadi. Lutfen tekrar dene.',
      );
    }
  }

  int? _extractRetryAfterSeconds(dynamic data) {
    if (data is! Map) {
      return null;
    }
    final direct =
        _parsePositiveInt(data['retryAfterSeconds']) ??
        _parsePositiveInt(data['retry_after_seconds']);
    if (direct != null) {
      return direct;
    }

    final nested = data['data'];
    if (nested is Map) {
      return _parsePositiveInt(nested['retryAfterSeconds']) ??
          _parsePositiveInt(nested['retry_after_seconds']);
    }
    return null;
  }

  int? _parsePositiveInt(dynamic value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is num && value > 0) {
      return value.floor();
    }
    if (value is String) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }
    return null;
  }
}
