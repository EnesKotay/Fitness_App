import 'package:flutter/foundation.dart';
import '../../domain/entities/weight_entry.dart';
import '../../domain/repositories/weight_repository.dart';
import '../../data/repositories/weight_repository_impl.dart';

class WeightProvider with ChangeNotifier {
  final WeightRepository _repository = HiveWeightRepository();
  
  List<WeightEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  List<WeightEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Tarihe göre en son kayıt (Güncel Kilo için kaynak)
  /// Eğer kayıt yoksa null döner (Nutrition bu durumda profile kilosunu kullanabilir)
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
    // Find entry closest to 7 days ago
    final oldEntry = _entries.firstWhere(
      (e) => e.date.isBefore(oneWeekAgo) || e.date.isAtSameMomentAs(oneWeekAgo),
      orElse: () => _entries.last,
    );
    if (oldEntry == _entries.first) return 0; // Not enough data
    return _entries.first.weightKg - oldEntry.weightKg;
  }

  double get average7Days {
    if (_entries.isEmpty) return 0;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentEntries = _entries.where((e) => e.date.isAfter(sevenDaysAgo)).toList();
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

  /// Hesap değişince çağrılır (login/register). Önceki hesabın kiloları temizlenir, yeni hesabın verisi yüklenir.
  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    _entries = []; // Hesap değiştiyse eski listeyi hemen temizle
    notifyListeners();

    try {
      _entries = await _repository.getEntries();
      // Ensure sorted: Newest first
      _entries.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addEntry(WeightEntry entry) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.addEntry(entry);
      await loadEntries(); // Listeyi yenile ve sırala
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteEntry(id);
      await loadEntries();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Chart Helpers (Optimized) ---

  List<WeightEntry> getFilteredEntries(int days) {
    if (_entries.isEmpty) return [];
    
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    return _entries.where((e) => e.date.isAfter(startDate)).toList();
  }

  // --- Trend Prediction (Smart logic) ---

  /// Calculates estimated date to reach [targetWeight] based on recent progress.
  /// Returns null if:
  /// - Not enough data (needs 2 entries in last 14 days)
  /// - Gaining weight when target is lower (or vice versa)
  /// - Rate is 0
  DateTime? calculateEstimatedGoalDate(double targetWeight) {
    if (_entries.length < 2) return null;
    
    // Use last 14 days for a realistic recent trend
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    
    // Get entries in this window
    final recentEntries = _entries.where((e) => e.date.isAfter(twoWeeksAgo)).toList();
    
    // Start from the oldest in this window (or if not enough, use all)
    if (recentEntries.length < 2) {
      // Fallback: Use all history if short (e.g. started 5 days ago)
      if (_entries.length >= 2) {
         // Use the last 5 entries or so
         recentEntries.clear();
         recentEntries.addAll(_entries.take(5));
      } else {
        return null;
      }
    }
    
    // Sort Oldest -> Newest for calculation
    recentEntries.sort((a, b) => a.date.compareTo(b.date));
    
    final startEntry = recentEntries.first;
    final endEntry = recentEntries.last;
    
    final currentWeight = endEntry.weightKg;
    final weightDiff = currentWeight - startEntry.weightKg; // Negative means loss
    final daysDiff = endEntry.date.difference(startEntry.date).inDays;
    
    if (daysDiff == 0) return null;
    
    final dailyRate = weightDiff / daysDiff; // kg per day
    
    // Check if moving in right direction
    final neededDiff = targetWeight - currentWeight;
    
    // If neededDiff is negative (need to lose) and rate is positive (gaining) -> Fail
    if (neededDiff < 0 && dailyRate >= 0) return null;
    // If neededDiff is positive (need to gain) and rate is negative (losing) -> Fail
    if (neededDiff > 0 && dailyRate <= 0) return null;
    
    // Days remaining = Needed / Rate
    final daysRemaining = neededDiff / dailyRate;
    
    if (daysRemaining.abs() > 365 * 2) return null; // Too far away (>2 years)
    
    return DateTime.now().add(Duration(days: daysRemaining.toInt()));
  }

  void reset() {
    _entries = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
