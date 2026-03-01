import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../constants/api_constants.dart';
import '../../features/nutrition/models/nutrition_ai_response.dart';

class AIService {
  AIService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  bool get isReady => true;

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
    String context,
  ) async {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return NutritionAiResponseModel(reply: 'Mesaj bos olamaz.');
    }

    try {
      final response = await _sendNutritionRequest(
        task: 'chat',
        message: normalized,
        contextSummary: context.trim(),
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
  }) async {
    final payload = <String, dynamic>{'task': task, 'message': message};
    final summary = contextSummary?.trim();
    if (summary != null && summary.isNotEmpty) {
      payload['context'] = {'summaryText': summary};
    }

    final response = await _apiClient.post(
      ApiConstants.aiNutrition,
      data: payload,
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
}
