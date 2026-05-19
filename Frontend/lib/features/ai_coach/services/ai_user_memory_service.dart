import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserMemoryFact {
  final String category;
  final String fact;
  final DateTime savedAt;

  const UserMemoryFact({
    required this.category,
    required this.fact,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'fact': fact,
        'savedAt': savedAt.toIso8601String(),
      };

  factory UserMemoryFact.fromJson(Map<String, dynamic> json) => UserMemoryFact(
        category: json['category'] as String? ?? 'genel',
        fact: json['fact'] as String? ?? '',
        savedAt: json['savedAt'] != null
            ? DateTime.tryParse(json['savedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class AiUserMemoryService {
  static const _keyPrefix = 'ai_user_memory_v1_';
  static const int maxFacts = 30;

  Future<List<UserMemoryFact>> getFacts(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$userId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => UserMemoryFact.fromJson(Map<String, dynamic>.from(m)))
          .where((f) => f.fact.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFact(int userId, UserMemoryFact fact) async {
    final facts = await getFacts(userId);
    // Avoid exact duplicates
    if (facts.any((f) => f.fact.trim() == fact.fact.trim())) return;
    facts.insert(0, fact);
    final trimmed = facts.take(maxFacts).toList();
    await _persist(userId, trimmed);
  }

  Future<void> deleteFact(int userId, int index) async {
    final facts = await getFacts(userId);
    if (index < 0 || index >= facts.length) return;
    facts.removeAt(index);
    await _persist(userId, facts);
  }

  Future<void> clearAll(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$userId');
  }

  Future<void> _persist(int userId, List<UserMemoryFact> facts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$userId', jsonEncode(facts.map((f) => f.toJson()).toList()));
  }

  /// Build a concise context string to include in AI requests.
  String buildContextString(List<UserMemoryFact> facts) {
    if (facts.isEmpty) return '';
    return facts.map((f) => f.fact).join('; ');
  }

  /// Parse and save a fact from JSON string returned by AI REMEMBER action.
  /// Expected format: {"category": "diet", "fact": "Kullanıcı vejetaryendir"}
  Future<void> saveFactFromJson(int userId, String jsonStr) async {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final fact = map['fact']?.toString() ?? '';
      if (fact.isEmpty) return;
      final category = map['category']?.toString() ?? 'genel';
      await saveFact(userId, UserMemoryFact(
        category: category,
        fact: fact,
        savedAt: DateTime.now(),
      ));
    } catch (_) {}
  }
}
