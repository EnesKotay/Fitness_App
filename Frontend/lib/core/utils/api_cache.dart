/// Basit in-memory API cache - TTL ile (performans için tekrarlayan istekleri azaltır)
class ApiCache {
  static final ApiCache _instance = ApiCache._internal();
  factory ApiCache() => _instance;

  ApiCache._internal();

  final Map<String, _CacheEntry> _cache = {};
  static const Duration defaultTtl = Duration(minutes: 5);

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) return null;
    return entry.value as T?;
  }

  void set<T>(String key, T value, {Duration ttl = defaultTtl}) {
    _cache[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }

  void remove(String key) => _cache.remove(key);

  void clear() => _cache.clear();

  static String weightRecordsKey(int userId) => 'weight_records_$userId';
  static String mealsByDateKey(int userId, String date) => 'meals_${userId}_$date';
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry(this.value, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
