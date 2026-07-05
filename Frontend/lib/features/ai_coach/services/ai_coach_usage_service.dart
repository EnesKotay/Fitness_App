import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/storage_helper.dart';

class AiCoachUsageService {
  static const int freeDailyPromptLimit = 2;
  final ApiClient _apiClient;

  AiCoachUsageService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<int?> getServerRemainingFreePrompts() async {
    final response = await _apiClient.get(ApiConstants.aiCoachQuota);
    final data = response.data;
    if (data is! Map) return null;

    final remaining = data['remainingFreeRequests'];
    if (remaining is int) {
      return remaining.clamp(0, freeDailyPromptLimit).toInt();
    }
    if (remaining is num) {
      return remaining.toInt().clamp(0, freeDailyPromptLimit).toInt();
    }
    return null;
  }

  Future<int> getRemainingFreePrompts({
    required int userId,
    DateTime? date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_key(userId: userId, date: date)) ?? 0;
    final remaining = freeDailyPromptLimit - used;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> incrementPromptCount({
    required int userId,
    DateTime? date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId: userId, date: date);
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
  }

  Future<void> setRemainingFreePrompts({
    required int userId,
    required int remaining,
    DateTime? date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedRemaining = remaining
        .clamp(0, freeDailyPromptLimit)
        .toInt();
    await prefs.setInt(
      _key(userId: userId, date: date),
      freeDailyPromptLimit - normalizedRemaining,
    );
  }

  String _key({required int userId, DateTime? date}) {
    final target = date ?? DateTime.now();
    final normalized =
        '${target.year.toString().padLeft(4, '0')}${target.month.toString().padLeft(2, '0')}${target.day.toString().padLeft(2, '0')}';
    return StorageHelper.userScopedKey('ai_coach_daily_usage_$normalized');
  }
}
