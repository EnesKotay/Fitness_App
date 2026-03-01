import 'package:flutter/foundation.dart';
import '../../data/models/body_region.dart';
import '../../data/models/exercise_catalog.dart';
import '../../data/repositories/exercise_catalog_repository.dart';

class WorkoutCatalogProvider with ChangeNotifier {
  final ExerciseCatalogRepository _repo = LocalExerciseCatalogRepository();

  List<BodyRegion> _regions = [];
  List<ExerciseCatalog> _exercises = [];
  BodyRegion? _selectedRegion;
  String _searchQuery = '';
  bool _loadingRegions = false;
  bool _loadingExercises = false;
  String? _error;

  List<BodyRegion> get regions => _regions;
  List<ExerciseCatalog> get exercises => _exercises;
  BodyRegion? get selectedRegion => _selectedRegion;
  String get searchQuery => _searchQuery;
  bool get loadingRegions => _loadingRegions;
  bool get loadingExercises => _loadingExercises;
  String? get error => _error;

  /// Bölge listesini yükle (ilk açılışta).
  Future<void> loadRegions() async {
    _loadingRegions = true;
    _error = null;
    notifyListeners();
    try {
      _regions = await _repo.getRegions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingRegions = false;
      notifyListeners();
    }
  }

  /// Seçilen bölgeye göre hareketleri yükle.
  Future<void> selectRegion(BodyRegion region) async {
    _selectedRegion = region;
    _exercises = [];
    _loadingExercises = true;
    _error = null;
    notifyListeners();
    try {
      _exercises = await _repo.getExercisesByRegion(region.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingExercises = false;
      notifyListeners();
    }
  }

  void clearRegion() {
    _selectedRegion = null;
    _exercises = [];
    _searchQuery = '';
    _error = null;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  /// Arama sonucuna göre filtrelenmiş hareket listesi.
  List<ExerciseCatalog> get filteredExercises {
    if (_searchQuery.trim().isEmpty) return _exercises;
    final q = _searchQuery.trim().toLowerCase();
    return _exercises.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<ExerciseCatalog?> getExerciseById(String id) async {
    return _repo.getExerciseById(id);
  }
}
