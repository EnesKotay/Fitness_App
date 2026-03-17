import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../models/ai_coach_models.dart';

class AiCoachService {
  final ApiClient _apiClient;

  AiCoachService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<CoachResponse> generatePlan({
    required Goal goal,
    required DailySummary summary,
    required String userPrompt,
    CoachPersonality personality = CoachPersonality.supportive,
    CoachTaskMode taskMode = CoachTaskMode.plan,
    List<CoachConversationTurn> conversationHistory =
        const <CoachConversationTurn>[],
  }) async {
    try {
      final token = StorageHelper.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException(
          message: 'Oturum bulunamadı. Lütfen tekrar giriş yap.',
        );
      }

      final baseOptions = Options(
        headers: {'Authorization': 'Bearer $token'},
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      );
      final richPayload = {
        'goal': goal.name,
        'taskMode': taskMode.name,
        'taskModeInstruction': taskMode.promptLead,
        'personality': personality.name,
        'personalityInstruction': personality.instruction,
        'dailySummary': summary.toJson(),
        'conversationHistory': conversationHistory
            .map((turn) => turn.toJson())
            .toList(),
        'question': userPrompt,
      };

      Response<dynamic> response;
      try {
        response = await _apiClient.post(
          ApiConstants.aiCoach,
          options: baseOptions,
          data: richPayload,
        );
      } on ApiException catch (e) {
        if (e.statusCode == 400 || e.statusCode == 422) {
          response = await _apiClient.post(
            ApiConstants.aiCoach,
            options: baseOptions,
            data: {
              'goal': goal.name,
              'personality': personality.name,
              'personalityInstruction': personality.instruction,
              'dailySummary': summary.toJson(),
              'question': userPrompt,
            },
          );
        } else {
          rethrow;
        }
      }

      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw ApiException(message: 'Koç yanıtı beklenmeyen formatta.');
      }
      return CoachResponse.fromJson(raw);
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
                  'AI servisi henüz hazır değil. Backend GEMINI_API_KEY ayarını kontrol et.',
            );
          }
          if (backendError.isNotEmpty) {
            throw ApiException(message: backendError);
          }
          throw ApiException(
            message:
                'AI servisi geçici olarak kullanılamıyor. Lütfen biraz sonra tekrar dene.',
          );
        }
        rethrow;
      }
      throw ApiException(
        message: 'Koç yanıtı oluşturulamadı. Lütfen tekrar dene.',
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

  Future<CoachResponse> analyzeVision({
    required XFile image,
    required String userPrompt,
    required Goal goal,
    CoachPersonality personality = CoachPersonality.supportive,
    required DailySummary summary,
    CoachTaskMode taskMode = CoachTaskMode.nutrition,
    List<CoachConversationTurn> conversationHistory =
        const <CoachConversationTurn>[],
  }) async {
    try {
      final token = StorageHelper.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException(
          message: 'Oturum bulunamadı. Lütfen tekrar giriş yap.',
        );
      }
      // Backend vision endpoint expects dailySummary as JSON string
      final dailySummaryJson = jsonEncode(summary.toJson());
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(image.path, filename: image.name),
        'question': userPrompt,
        'goal': goal.name,
        'taskMode': taskMode.name,
        'taskModeInstruction': taskMode.promptLead,
        'personality': personality.name,
        'personalityInstruction': personality.instruction,
        'dailySummary': dailySummaryJson,
        'conversationHistory': jsonEncode(
          conversationHistory.map((turn) => turn.toJson()).toList(),
        ),
      });

      Response<dynamic> response;
      try {
        response = await _apiClient.post(
          '${ApiConstants.apiPrefix}/ai/vision',
          data: formData,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
      } on ApiException catch (e) {
        if (e.statusCode == 400 || e.statusCode == 422) {
          final fallbackForm = FormData.fromMap({
            'image': await MultipartFile.fromFile(
              image.path,
              filename: image.name,
            ),
            'question': userPrompt,
            'goal': goal.name,
            'personality': personality.name,
            'personalityInstruction': personality.instruction,
            'dailySummary': dailySummaryJson,
          });
          response = await _apiClient.post(
            '${ApiConstants.apiPrefix}/ai/vision',
            data: fallbackForm,
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );
        } else {
          rethrow;
        }
      }

      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        throw ApiException(message: 'Görüntü yanıtı beklenmeyen formatta.');
      }
      return CoachResponse.fromJson(raw);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        message: 'Görüntü analizi başarısız oldu. Lütfen tekrar dene.',
      );
    }
  }
}
