import 'package:flutter/foundation.dart';
import '../../../core/api/services/tracking_service.dart';
import '../../../core/models/weight_record.dart';
import '../../../core/models/weight_record_models.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/api_cache.dart';

class TrackingProvider with ChangeNotifier {
  final TrackingService _trackingService = TrackingService();
  final ApiCache _cache = ApiCache();

  // State
  List<WeightRecord> _weightRecords = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<WeightRecord> get weightRecords => _weightRecords;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Kilo kayıtlarını yükle (cache + retry - performans için)
  Future<void> loadWeightRecords(int userId, {int retryCount = 0}) async {
    // Stale-while-revalidate: Önce cache varsa göster
    final cached = _cache.get<List<WeightRecord>>(ApiCache.weightRecordsKey(userId));
    if (cached != null && cached.isNotEmpty) {
      _weightRecords = cached;
      _isLoading = true;
      notifyListeners();
    } else {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _weightRecords = await _trackingService.getUserWeightRecords(userId);
      _cache.set(ApiCache.weightRecordsKey(userId), _weightRecords);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } on ApiException catch (e) {
      // İlk hata: kısa bekle ve 1 kez tekrar dene (backend cold start / ilk bağlantı gecikmesi)
      if (retryCount == 0) {
        await Future.delayed(const Duration(milliseconds: 800));
        return loadWeightRecords(userId, retryCount: 1);
      }
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (retryCount == 0) {
        await Future.delayed(const Duration(milliseconds: 800));
        return loadWeightRecords(userId, retryCount: 1);
      }
      _errorMessage = 'Kilo kayıtları yüklenemedi';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Yeni kilo kaydı oluştur
  Future<bool> createWeightRecord(int userId, WeightRecordRequest request) async {
    if (_useDemoData) {
      final record = WeightRecord(
        id: DateTime.now().millisecondsSinceEpoch,
        weight: request.weight ?? 0,
        recordedAt: request.recordedAt ?? DateTime.now(),
        notes: request.notes,
      );
      _weightRecords.insert(0, record);
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final record = await _trackingService.createWeightRecord(userId, request);
      _weightRecords.insert(0, record);
      _cache.set(ApiCache.weightRecordsKey(userId), _weightRecords);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Kilo kaydı oluşturulamadı';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Kilo kaydını güncelle
  Future<bool> updateWeightRecord(
    int userId,
    int recordId,
    WeightRecordRequest request,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedRecord = await _trackingService.updateWeightRecord(
        userId,
        recordId,
        request,
      );
      
      final index = _weightRecords.indexWhere((r) => r.id == recordId);
      if (index != -1) {
        _weightRecords[index] = updatedRecord;
        _cache.set(ApiCache.weightRecordsKey(userId), _weightRecords);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Kilo kaydı güncellenemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Kilo kaydını sil
  Future<bool> deleteWeightRecord(int userId, int recordId) async {
    if (_useDemoData) {
      _weightRecords.removeWhere((r) => r.id == recordId);
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _trackingService.deleteWeightRecord(userId, recordId);
      _weightRecords.removeWhere((r) => r.id == recordId);
      _cache.set(ApiCache.weightRecordsKey(userId), _weightRecords);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Kilo kaydı silinemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Demo veri yükle (Backend olmadan test için)
  void loadDemoData() {
    final now = DateTime.now();
    _weightRecords = [
      WeightRecord(
        id: 1,
        weight: 78.5,
        recordedAt: now,
        notes: null,
      ),
      WeightRecord(
        id: 2,
        weight: 78.8,
        recordedAt: now.subtract(const Duration(days: 1)),
        notes: null,
      ),
      WeightRecord(
        id: 3,
        weight: 79.0,
        recordedAt: now.subtract(const Duration(days: 2)),
        notes: null,
      ),
      WeightRecord(
        id: 4,
        weight: 79.2,
        recordedAt: now.subtract(const Duration(days: 3)),
        notes: null,
      ),
      WeightRecord(
        id: 5,
        weight: 79.5,
        recordedAt: now.subtract(const Duration(days: 5)),
        notes: null,
      ),
      WeightRecord(
        id: 6,
        weight: 79.8,
        recordedAt: now.subtract(const Duration(days: 7)),
        notes: null,
      ),
      WeightRecord(
        id: 7,
        weight: 80.0,
        recordedAt: now.subtract(const Duration(days: 10)),
        notes: null,
      ),
      WeightRecord(
        id: 8,
        weight: 80.2,
        recordedAt: now.subtract(const Duration(days: 14)),
        notes: null,
      ),
      WeightRecord(
        id: 9,
        weight: 80.5,
        recordedAt: now.subtract(const Duration(days: 21)),
        notes: null,
      ),
      WeightRecord(
        id: 10,
        weight: 81.0,
        recordedAt: now.subtract(const Duration(days: 30)),
        notes: null,
      ),
    ];
    _errorMessage = null;
    _isLoading = false;
    _useDemoData = true;
    notifyListeners();
  }

  /// Demo modunda mı? (Demo veri yüklendiyse silme/güncelleme API çağrılmaz)
  bool _useDemoData = false;
  bool get useDemoData => _useDemoData;

  void setUseDemoData(bool value) {
    _useDemoData = value;
    notifyListeners();
  }
}
