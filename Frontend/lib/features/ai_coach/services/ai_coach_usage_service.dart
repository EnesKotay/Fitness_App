import 'package:shared_preferences/shared_preferences.dart';

class AiCoachUsageService {
  static const int freeDailyPromptLimit = 2;

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

  String _key({required int userId, DateTime? date}) {
    final target = date ?? DateTime.now();
    final normalized =
        '${target.year.toString().padLeft(4, '0')}${target.month.toString().padLeft(2, '0')}${target.day.toString().padLeft(2, '0')}';
    return 'ai_coach_daily_usage_${userId}_$normalized';
  }
}
