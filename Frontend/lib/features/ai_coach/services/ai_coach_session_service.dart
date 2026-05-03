import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last N AI coach messages so conversations survive screen closes.
/// Only user/assistant content is stored — no structured responses, no errors.
class AiCoachSessionService {
  static const _keyPrefix = 'ai_coach_session_v1_';
  static const int maxStoredMessages = 20; // 10 turns

  /// Save messages for a user. Only non-error, non-system messages are persisted.
  Future<void> saveSession({
    required int userId,
    required List<Map<String, String>> messages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed =
        messages.length > maxStoredMessages
            ? messages.sublist(messages.length - maxStoredMessages)
            : messages;
    await prefs.setString(_key(userId), jsonEncode(trimmed));
  }

  /// Load persisted messages for a user. Returns empty list if none.
  Future<List<Map<String, String>>> loadSession({required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => {
                'role': m['role']?.toString() ?? '',
                'content': m['content']?.toString() ?? '',
              })
          .where((m) => m['role']!.isNotEmpty && m['content']!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear the stored session for a user (e.g., when they tap "Sohbeti Temizle").
  Future<void> clearSession({required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  String _key(int userId) => '$_keyPrefix$userId';
}
