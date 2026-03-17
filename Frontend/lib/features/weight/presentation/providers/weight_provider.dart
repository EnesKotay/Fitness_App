import 'package:flutter/foundation.dart';
import '../../../../core/api/services/tracking_service.dart';
import '../../../../core/models/weight_record.dart';
import '../../../../core/models/weight_record_models.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/weight_entry.dart';
import '../../data/repositories/weight_repository_impl.dart';

/// Kilo takibi provider.
/// Birincil kaynak: Backend API.
/// İkincil (offline) cache: Hive.
class WeightProvider with ChangeNotifier {
  final TrackingService _trackingService = TrackingService();
  final HiveWeightRepository _hiveCache = HiveWeightRepository();

  List<WeightEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  List<WeightEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Tarihe göre en son kayıt (Güncel Kilo için kaynak)
  WeightEntry? get latestEntry {
    if (_entries.isEmpty) return null;
    return _entries.first; // _entries is sorted (newest first)
  }

  /// İlk (en eski) kayıt - "İlk kilo" / başlangıç için
  WeightEntry? get firstEntry {
    if (_entries.isEmpty) return null;
    return _entries.last;
  }

  double get totalChange {
    if (_entries.isEmpty) return 0;
    return _entries.first.weightKg - _entries.last.weightKg;
  }

  double get weeklyChange {
    if (_entries.isEmpty) return 0;
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final oldEntry = _entries.firstWhere(
      (e) => e.date.isBefore(oneWeekAgo) || e.date.isAtSameMomentAs(oneWeekAgo),
      orElse: () => _entries.last,
    );
    if (oldEntry == _entries.first) return 0;
    return _entries.first.weightKg - oldEntry.weightKg;
  }

  double get average7Days {
    if (_entries.isEmpty) return 0;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentEntries = _entries
        .where((e) => e.date.isAfter(sevenDaysAgo))
        .toList();
    if (recentEntries.isEmpty) return _entries.first.weightKg;
    final sum = recentEntries.fold(0.0, (p, e) => p + e.weightKg);
    return sum / recentEntries.length;
  }

  int get last30DaysCount {
    if (_entries.isEmpty) return 0;
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    return _entries.where((e) => e.date.isAfter(thirtyDaysAgo)).length;
  }

  /// Ard arda kaç gün kilo kaydı girildi (streak)
  int get currentStreak {
    if (_entries.isEmpty) return 0;
    final sorted = List<WeightEntry>.from(_entries)
      ..sort((a, b) => b.date.compareTo(a.date));
    int streak = 0;
    DateTime expectedDate = DateTime.now();
    for (final entry in sorted) {
      final entryDay = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      final expectedDay = DateTime(
        expectedDate.year,
        expectedDate.month,
        expectedDate.day,
      );
      final diff = expectedDay.difference(entryDay).inDays;
      if (diff == 0 || diff == 1) {
        streak++;
        expectedDate = entry.date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// Bu ay toplam değişim
  double get monthlyChange {
    if (_entries.isEmpty) return 0;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final thisMonthEntries = _entries
        .where((e) => e.date.isAfter(startOfMonth))
        .toList();
    if (thisMonthEntries.isEmpty) return 0;
    thisMonthEntries.sort((a, b) => a.date.compareTo(b.date));
    return _entries.first.weightKg - thisMonthEntries.first.weightKg;
  }

  /// Geçen ay toplam değişim
  double get previousMonthChange {
    if (_entries.isEmpty) return 0;
    final now = DateTime.now();
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthEntries = _entries
        .where(
          (e) =>
              e.date.isAfter(startOfLastMonth) &&
              e.date.isBefore(startOfThisMonth),
        )
        .toList();
    if (lastMonthEntries.length < 2) return 0;
    lastMonthEntries.sort((a, b) => a.date.compareTo(b.date));
    return lastMonthEntries.last.weightKg - lastMonthEntries.first.weightKg;
  }

  // ── Backend WeightRecord → UI WeightEntry dönüşümü ──
  static WeightEntry _toEntry(WeightRecord r) {
    return WeightEntry(
      id: r.id.toString(),
      date: r.recordedAt,
      weightKg: r.weight,
      note: r.notes,
    );
  }

  // ── Tüm kayıtları yükle (Backend → Hive cache) ──
  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    _entries = [];
    notifyListeners();

    try {
      // Backend'den çek
      final records = await _trackingService.getUserWeightRecords(0);
      final fetchedEntries = records.map(_toEntry).toList();
      fetchedEntries.sort((a, b) => b.date.compareTo(a.date));

      // Tekrar eden ID'leri kaldır (güvenlik için)
      final seen = <String>{};
      _entries = fetchedEntries.where((e) => seen.add(e.id)).toList();

      // Hive cache'i tazele (eski verileri sil, yenilerini yaz)
      _resyncHiveCache();
    } on ApiException catch (e) {
      debugPrint('WeightProvider.loadEntries API hatası: ${e.message}');
      // Offline fallback: Hive'dan yükle
      await _loadFromHiveCache();
    } catch (e) {
      debugPrint('WeightProvider.loadEntries hatası: $e');
      await _loadFromHiveCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Kilo ekle (Backend + Hive) ──
  Future<bool> addEntry(WeightEntry entry) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = WeightRecordRequest(
        weight: entry.weightKg,
        recordedAt: entry.date,
        notes: entry.note,
      );
      final record = await _trackingService.createWeightRecord(0, request);
      final newEntry = _toEntry(record);

      // Backend'den gelen gerçek ID ile güncelle (UUID'yi değiştir)
      _entries.removeWhere((e) => e.id == entry.id);
      _entries.add(newEntry);
      _entries.sort((a, b) => b.date.compareTo(a.date));

      // Hive cache güncelle (temiz yaz)
      await _hiveCache.addEntry(newEntry);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('WeightProvider.addEntry hatası: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Kilo kaydı eklenemedi';
      debugPrint('WeightProvider.addEntry hatası: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Kilo sil (Backend + Hive) ──
  Future<bool> deleteEntry(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final recordId = int.parse(id);
      await _trackingService.deleteWeightRecord(0, recordId);

      _entries.removeWhere((e) => e.id == id);
      await _hiveCache.deleteEntry(id);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('WeightProvider.deleteEntry hatası: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Kilo kaydı silinemedi';
      debugPrint('WeightProvider.deleteEntry hatası: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Kilo güncelle (Backend + Hive) ──
  Future<bool> updateEntry(WeightEntry entry) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final recordId = int.parse(entry.id);
      final request = WeightRecordRequest(
        weight: entry.weightKg,
        recordedAt: entry.date,
        notes: entry.note,
      );
      final record = await _trackingService.updateWeightRecord(
        0,
        recordId,
        request,
      );
      final updated = _toEntry(record);

      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = updated;
      }
      _entries.sort((a, b) => b.date.compareTo(a.date));
      await _hiveCache.updateEntry(updated);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('WeightProvider.updateEntry hatası: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Kilo kaydı güncellenemedi';
      debugPrint('WeightProvider.updateEntry hatası: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Chart Helpers ──

  List<WeightEntry> getFilteredEntries(int days) {
    if (_entries.isEmpty) return [];
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    return _entries.where((e) => e.date.isAfter(startDate)).toList();
  }

  // ── Trend Prediction ──

  DateTime? calculateEstimatedGoalDate(double targetWeight) {
    if (_entries.length < 2) return null;
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final recentEntries = _entries
        .where((e) => e.date.isAfter(twoWeeksAgo))
        .toList();

    if (recentEntries.length < 2) {
      if (_entries.length >= 2) {
        recentEntries.clear();
        recentEntries.addAll(_entries.take(5));
      } else {
        return null;
      }
    }

    recentEntries.sort((a, b) => a.date.compareTo(b.date));
    final startEntry = recentEntries.first;
    final endEntry = recentEntries.last;
    final currentWeight = endEntry.weightKg;
    final weightDiff = currentWeight - startEntry.weightKg;
    final daysDiff = endEntry.date.difference(startEntry.date).inDays;

    if (daysDiff == 0) return null;
    final dailyRate = weightDiff / daysDiff;
    final neededDiff = targetWeight - currentWeight;

    if (neededDiff < 0 && dailyRate >= 0) return null;
    if (neededDiff > 0 && dailyRate <= 0) return null;

    final daysRemaining = neededDiff / dailyRate;
    if (daysRemaining.abs() > 365 * 2) return null;

    return DateTime.now().add(Duration(days: daysRemaining.toInt()));
  }

  // ── Hive Cache Helpers ──

  void _resyncHiveCache() {
    // Hive cache'i tamamen temizleyip güncel verileri yaz
    Future.microtask(() async {
      try {
        await _hiveCache.clearAll();
        for (final entry in _entries) {
          await _hiveCache.addEntry(entry);
        }
      } catch (e) {
        debugPrint('WeightProvider._resyncHiveCache: $e');
      }
    });
  }

  Future<void> _loadFromHiveCache() async {
    try {
      _entries = await _hiveCache.getEntries();
      _entries.sort((a, b) => b.date.compareTo(a.date));
      debugPrint(
        'WeightProvider: Hive cache fallback, ${_entries.length} kayıt',
      );
    } catch (e) {
      debugPrint('WeightProvider._loadFromHiveCache: $e');
      _entries = [];
    }
  }

  void reset() {
    _entries = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
