import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../constants/api_constants.dart';
import '../utils/storage_helper.dart';

/// AI özelliklerinin güvenli kullanımı için yardımcı sınıf.
/// - Backend sağlık kontrolü
/// - Günlük istek limiti (rate limiting)
/// - AI arama sonuçları cache'i
class AiSafetyHelper {
  AiSafetyHelper._();
  static final AiSafetyHelper instance = AiSafetyHelper._();

  // ─── Backend Sağlık Kontrolü ─────────────────────────────────
  bool _backendAvailable = false;
  DateTime? _lastHealthCheck;
  static const _healthCheckInterval = Duration(minutes: 5);

  bool get isBackendAvailable => _backendAvailable;

  /// Backend'in erişilebilir olup olmadığını kontrol eder.
  /// Sonucu 5 dakika cache'ler, gereksiz istek atmaz.
  Future<bool> checkBackendHealth({bool force = false}) async {
    if (!force &&
        _lastHealthCheck != null &&
        DateTime.now().difference(_lastHealthCheck!) < _healthCheckInterval) {
      return _backendAvailable;
    }

    final client = ApiClient();

    // 1) Quarkus SmallRye health endpoint (requires quarkus-smallrye-health)
    try {
      final response = await client.dio
          .get(
            '${ApiConstants.baseUrl}/q/health',
            options: _quickOptions(),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        _backendAvailable = true;
        _lastHealthCheck = DateTime.now();
        return true;
      }
    } catch (_) {
      // Fallthrough to secondary check
    }

    // 2) Fallback: lightweight auth ping
    try {
      final response = await client.dio
          .get(
            '${ApiConstants.baseUrl}${ApiConstants.healthTest}',
            options: _quickOptions(),
          )
          .timeout(const Duration(seconds: 4));
      // Any non-5xx response means the server is up
      _backendAvailable = (response.statusCode ?? 500) < 500;
    } catch (e) {
      debugPrint('AiSafetyHelper.checkBackendHealth: Backend erişilemez → $e');
      _backendAvailable = false;
    }

    _lastHealthCheck = DateTime.now();
    return _backendAvailable;
  }

  /// Backend'i hızlı kontrol sonrası kullanılabilirliğe göre bool döner.
  /// UI'dan çağrılabilir, cache'li.
  bool get cachedBackendStatus => _backendAvailable;

  // ─── Günlük İstek Limiti (Rate Limiting) ─────────────────────
  int _dailyRequestCount = 0;
  String? _currentDay;
  String? _activeUserSuffix;
  static const int dailyLimit = 50; // Günlük AI istek limiti

  /// Yeni bir AI isteği yapılabilir mi?
  Future<bool> canMakeRequest() async {
    _ensureUserScope();
    await _resetIfNewDay();
    return _dailyRequestCount < dailyLimit;
  }

  /// Kalan istek sayısı
  Future<int> get remainingRequests async {
    _ensureUserScope();
    await _resetIfNewDay();
    return (dailyLimit - _dailyRequestCount).clamp(0, dailyLimit);
  }

  /// AI isteği yapıldığında çağır
  Future<void> recordRequest() async {
    _ensureUserScope();
    await _resetIfNewDay();
    _dailyRequestCount++;
    await StorageHelper.saveAiDailyRequestCount(_dailyRequestCount);
    debugPrint('AiSafetyHelper: Günlük AI istek: $_dailyRequestCount / $dailyLimit');
  }

  Future<void> _resetIfNewDay() async {
    _ensureUserScope();
    if (_currentDay == null) {
      _currentDay = StorageHelper.getAiCurrentDay();
      _dailyRequestCount = StorageHelper.getAiDailyRequestCount();
    }

    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_currentDay != today) {
      _currentDay = today;
      _dailyRequestCount = 0;
      await StorageHelper.saveAiCurrentDay(today);
      await StorageHelper.saveAiDailyRequestCount(0);
    }
  }

  // ─── AI Arama Cache ──────────────────────────────────────────
  final Map<String, _CachedResult> _searchCache = {};
  static const int _maxCacheSize = 100;
  static const _cacheExpiry = Duration(hours: 2);

  /// Cache'den sonuç getir (varsa ve süresi dolmadıysa)
  List<String>? getCachedSearch(String query) {
    _ensureUserScope();
    final key = query.trim().toLowerCase();
    final cached = _searchCache[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.timestamp) > _cacheExpiry) {
      _searchCache.remove(key);
      return null;
    }
    return cached.results;
  }

  /// Sonucu cache'e kaydet
  void cacheSearchResult(String query, List<String> results) {
    _ensureUserScope();
    if (results.isEmpty) return;
    final key = query.trim().toLowerCase();

    // Cache boyutunu kontrol et
    if (_searchCache.length >= _maxCacheSize) {
      // En eski entry'yi sil
      final oldest = _searchCache.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b);
      _searchCache.remove(oldest.key);
    }

    _searchCache[key] = _CachedResult(results, DateTime.now());
  }

  // ─── Yardımcı ────────────────────────────────────────────────
  static Options _quickOptions() {
    return Options(
      receiveTimeout: const Duration(seconds: 3),
      sendTimeout: const Duration(seconds: 2),
    );
  }

  void _ensureUserScope() {
    final current = StorageHelper.getUserStorageSuffix();
    if (_activeUserSuffix == null) {
      _activeUserSuffix = current;
      return;
    }
    if (_activeUserSuffix != current) {
      _activeUserSuffix = current;
      _dailyRequestCount = 0;
      _currentDay = null;
      _searchCache.clear();
      _backendAvailable = false;
      _lastHealthCheck = null;
    }
  }
}

class _CachedResult {
  final List<String> results;
  final DateTime timestamp;
  _CachedResult(this.results, this.timestamp);
}
