import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../constants/api_constants.dart';
import '../../features/nutrition/models/nutrition_ai_response.dart';
import '../../features/nutrition/ai_scan/domain/models/scanned_nutrition_result.dart';
import '../../features/nutrition/ai_scan/domain/models/scanned_meal_result.dart';
import '../../features/ai_coach/models/ai_coach_models.dart';

class AIService {
  AIService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  bool get isReady {
    // Basic readiness check - we assume it's ready if we have a token
    // A more thorough check could involve pinging a backend health endpoint
    return true; // StorageHelper is async, so we'll just return true and let ApiClient interceptors handle 401s
  }

  /// Serbest metinden yemek aramasi yapar.
  /// Ornek: "Bir tabak pilav ve tavuk sote yedim" -> ['pilav', 'tavuk sote']
  Future<List<String>> extractFoodItems(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return [];
    }

    try {
      final response = await _sendNutritionRequest(
        task: 'extract_food_items',
        message: normalized,
      );
      final reply = response.reply?.trim() ?? '';
      if (reply.isEmpty) {
        return [];
      }
      return reply
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } on ApiException catch (e) {
      debugPrint('AIService.extractFoodItems: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('AIService.extractFoodItems: $e');
      return [];
    }
  }

  /// Sohbet asistani icin structured JSON yanit uretir.
  /// Returns NutritionAiResponseModel with meals, shoppingList, followUpQuestions
  Future<NutritionAiResponseModel> getStructuredNutritionResponse(
    String message,
    String context, {
    String task = 'chat',
    Map<String, dynamic>? nutritionContext,
  }) async {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return NutritionAiResponseModel(reply: 'Mesaj bos olamaz.');
    }

    try {
      final response = await _sendNutritionRequest(
        task: task,
        message: normalized,
        contextSummary: context.trim(),
        nutritionContext: nutritionContext,
      );
      return response;
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        final retryAfter =
            _extractRetryAfterSeconds(e.data) ??
            _extractRetryAfterFromMessage(e.message);
        return NutritionAiResponseModel(
          reply: retryAfter != null
              ? 'Cok fazla istek. ${retryAfter}s sonra tekrar dene.'
              : 'Cok fazla istek. Lutfen biraz sonra tekrar dene.',
        );
      }
      if (e.statusCode == 401 || e.statusCode == 403) {
        return NutritionAiResponseModel(
          reply: 'Oturum suresi dolmus olabilir. Lutfen tekrar giris yap.',
        );
      }
      return NutritionAiResponseModel(
        reply: e.message.isNotEmpty ? e.message : 'Baglanti sorunu yasandi.',
      );
    } catch (e) {
      debugPrint('AIService.getStructuredNutritionResponse: $e');
      return NutritionAiResponseModel(reply: 'Baglanti sorunu yasandi.');
    }
  }

  /// Geriye donuk uyumluluk icin eski chat response formatini koru
  Future<String> getChatResponse(String message, String context) async {
    final response = await getStructuredNutritionResponse(message, context);

    // Eger meals varsa, reply'i meals bilgisiyle birlikte goster
    if (response.hasMeals) {
      final buffer = StringBuffer();
      if (response.reply != null && response.reply!.isNotEmpty) {
        buffer.writeln(response.reply);
      }
      buffer.writeln('\nOnerilen yemekler:');
      for (final meal in response.meals) {
        buffer.writeln('- ${meal.name} (${meal.kcal} kcal)');
      }
      return buffer.toString().trim();
    }

    return response.reply ?? 'Bir hata olustu.';
  }

  /// Onerilen yemekler icin kisa bir aciklama uretir.
  Future<String> getSuggestionReasoning(
    String foodNames,
    String context,
  ) async {
    final normalizedFoods = foodNames.trim();
    if (normalizedFoods.isEmpty) {
      return '';
    }

    try {
      final response = await _sendNutritionRequest(
        task: 'suggestion_reasoning',
        message: normalizedFoods,
        contextSummary: context.trim(),
      );
      return response.reply?.trim() ?? '';
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        final retryAfter =
            _extractRetryAfterSeconds(e.data) ??
            _extractRetryAfterFromMessage(e.message);
        return retryAfter != null
            ? 'Cok fazla istek. ${retryAfter}s sonra tekrar dene.'
            : 'Cok fazla istek. Lutfen biraz sonra tekrar dene.';
      }
      debugPrint('AIService.getSuggestionReasoning: ${e.message}');
      return '';
    } catch (e) {
      debugPrint('AIService.getSuggestionReasoning: $e');
      return '';
    }
  }

  Future<NutritionAiResponseModel> _sendNutritionRequest({
    required String task,
    required String message,
    String? contextSummary,
    Map<String, dynamic>? nutritionContext,
  }) async {
    final payload = <String, dynamic>{'task': task, 'message': message};
    final context = <String, dynamic>{...?nutritionContext};
    final summary = contextSummary?.trim();
    if (summary != null &&
        summary.isNotEmpty &&
        !context.containsKey('summaryText')) {
      context['summaryText'] = summary;
    }
    if (context.isNotEmpty) {
      payload['context'] = context;
    }

    final response = await _apiClient.post(
      ApiConstants.aiNutrition,
      data: payload,
      options: Options(
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
      ),
    );

    final raw = response.data;
    if (raw is! Map<String, dynamic>) {
      throw ApiException(message: 'AI yaniti beklenmeyen formatta.');
    }

    return NutritionAiResponseModel.fromJson(raw);
  }

  int? _extractRetryAfterFromMessage(String message) {
    final match = RegExp(r'(\d+)').firstMatch(message);
    if (match == null) {
      return null;
    }
    final parsed = int.tryParse(match.group(1)!);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
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

  /// Besin etiketi fotoğrafını backend'e gönderip yapılandırılmış sonuç alır.
  /// Gemini Vision API backend tarafında çağrılır.
  Future<ScannedNutritionResult> scanNutritionLabel(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _apiClient.dio.post(
        ApiConstants.aiScanLabel,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          throw ApiException(
            message: data['error'] as String? ?? 'Bilinmeyen hata',
          );
        }
        return ScannedNutritionResult.fromJson(data);
      }

      throw ApiException(message: 'Beklenmeyen yanıt formatı');
    } on DioException catch (e) {
      debugPrint('AIService.scanNutritionLabel DioException: ${e.message}');
      final errorMsg = e.response?.data is Map
          ? (e.response?.data['error'] as String? ?? 'Bağlantı hatası')
          : 'Sunucuya bağlanılamadı';
      throw ApiException(message: errorMsg);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('AIService.scanNutritionLabel: $e');
      throw ApiException(message: 'Etiket tarama hatası: $e');
    }
  }

  /// Yemek fotoğrafını backend'e gönderip yapılandırılmış makro analizi alır.
  Future<ScannedMealResult> analyzeFoodImage(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _apiClient.dio.post(
        ApiConstants.aiAnalyzeImage,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('error')) {
          throw ApiException(
            message: data['error'] as String? ?? 'Bilinmeyen hata',
          );
        }
        return ScannedMealResult.fromJson(data);
      }

      throw ApiException(message: 'Beklenmeyen yanıt formatı');
    } on DioException catch (e) {
      debugPrint('AIService.analyzeFoodImage DioException: ${e.message}');
      final errorMsg = e.response?.data is Map
          ? (e.response?.data['error'] as String? ?? 'Bağlantı hatası')
          : 'Sunucuya bağlanılamadı';
      throw ApiException(message: errorMsg);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('AIService.analyzeFoodImage: $e');
      throw ApiException(message: 'Yemek fotoğrafı analiz hatası: $e');
    }
  }

  /// Check if the current user has premium status.
  /// Returns true if premium is active, false otherwise, null on error.
  Future<bool?> checkPremiumStatus() async {
    try {
      final response = await _apiClient.get(ApiConstants.premiumStatus);
      if (response.statusCode == 200 && response.data is Map) {
        return response.data['isActive'] == true;
      }
      return false;
    } catch (_) {
      return null;
    }
  }

  /// Takip sayfası için AI Koç analizi alır.
  Future<CoachAdviceView> getTrackingAdvice({
    required String goal,
    required String question,
    DailySummary? dailySummary,
  }) async {
    try {
      final summary =
          dailySummary ??
          const DailySummary(
            steps: 0,
            calories: 0,
            waterLiters: 0,
            sleepHours: 0,
            workouts: 0,
            workoutMinutes: 0,
            workoutHighlights: <String>[],
          );

      final requestPayload = {
        'goal': goal,
        'question': question,
        'dailySummary': summary.toJson(),
      };

      final response = await _apiClient.post(
        ApiConstants.aiCoach,
        data: requestPayload,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return CoachAdviceView(
          focus: data['todayFocus'] ?? '',
          actions:
              (data['actionItems'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          nutritionNote: data['nutritionNote'] ?? '',
        );
      }
      throw ApiException(message: 'Beklenmeyen yanıt formatı');
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        throw ApiException(
          message: 'Çok fazla istek. Lütfen biraz bekleyip tekrar deneyin.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('AIService.getTrackingAdvice: $e');
      throw ApiException(message: 'AI Koç analizi alınamadı');
    }
  }
}
