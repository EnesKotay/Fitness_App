import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/storage_helper.dart';

/// Persists AI coach sessions.
/// Current session: single key per user (overwritten each message).
/// History: one key per day per user + an index for listing.
class AiCoachSessionService {
  static const _currentKeyPrefix = 'ai_coach_session_v1_';
  static const _historyPrefix = 'ai_coach_history_v1_';
  static const _indexPrefix = 'ai_coach_index_v1_';
  static const int maxStoredMessages = 20;
  static const int maxHistoryDays = 60;

  // ─── Current session ────────────────────────────────────────────

  Future<void> saveSession({
    required int userId,
    required List<Map<String, String>> messages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > maxStoredMessages
        ? messages.sublist(messages.length - maxStoredMessages)
        : messages;
    await prefs.setString(_currentKey(userId), jsonEncode(trimmed));
  }

  Future<List<Map<String, String>>> loadSession({required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeMessages(prefs.getString(_currentKey(userId)));
  }

  Future<void> clearSession({required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey(userId));
  }

  // ─── Daily history archive ───────────────────────────────────────

  /// Archive a session under [date] (format: "2025-05-10").
  /// Overwrites if the same date already exists — keeps the latest snapshot.
  Future<void> archiveSession({
    required int userId,
    required String date,
    required List<Map<String, String>> messages,
  }) async {
    if (messages.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey(userId, date), jsonEncode(messages));

    // Update index
    final index = _loadIndex(prefs, userId);
    index.removeWhere((e) => e['date'] == date);
    final firstUserMsg =
        messages.firstWhere(
          (m) => m['role'] == 'user',
          orElse: () => {'content': ''},
        )['content'] ??
        '';
    index.insert(0, {
      'date': date,
      'preview': firstUserMsg.length > 100
          ? '${firstUserMsg.substring(0, 100)}…'
          : firstUserMsg,
      'count': messages.length.toString(),
      'savedAt': DateTime.now().toIso8601String(),
    });
    final trimmed = index.take(maxHistoryDays).toList();
    await prefs.setString(_indexKey(userId), jsonEncode(trimmed));
  }

  Future<List<Map<String, String>>> loadHistorySession({
    required int userId,
    required String date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeMessages(prefs.getString(_historyKey(userId, date)));
  }

  List<Map<String, dynamic>> listSessions({
    required int userId,
    required SharedPreferences prefs,
  }) {
    return _loadIndex(prefs, userId);
  }

  Future<List<Map<String, dynamic>>> listSessionsAsync({
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return _loadIndex(prefs, userId);
  }

  Future<void> deleteHistorySession({
    required int userId,
    required String date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey(userId, date));
    final index = _loadIndex(prefs, userId);
    index.removeWhere((e) => e['date'] == date);
    await prefs.setString(_indexKey(userId), jsonEncode(index));
  }

  Future<Map<String, dynamic>> exportSessions({required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _loadIndex(prefs, userId);
    final history = <String, List<Map<String, String>>>{};

    for (final item in index) {
      final date = item['date']?.toString() ?? '';
      if (date.isEmpty) continue;
      history[date] = _decodeMessages(
        prefs.getString(_historyKey(userId, date)),
      );
    }

    return <String, dynamic>{
      'currentSession': _decodeMessages(prefs.getString(_currentKey(userId))),
      'historyIndex': index,
      'historySessions': history,
    };
  }

  // ─── Helpers ────────────────────────────────────────────────────

  List<Map<String, dynamic>> _loadIndex(SharedPreferences prefs, int userId) {
    final raw = prefs.getString(_indexKey(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, String>> _decodeMessages(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (m) => {
              'role': m['role']?.toString() ?? '',
              'content': m['content']?.toString() ?? '',
            },
          )
          .where((m) => m['role']!.isNotEmpty && m['content']!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _currentKey(int userId) =>
      StorageHelper.userScopedKey(_currentKeyPrefix);
  String _historyKey(int userId, String date) =>
      StorageHelper.userScopedKey('$_historyPrefix$date');
  String _indexKey(int userId) => StorageHelper.userScopedKey(_indexPrefix);
}
