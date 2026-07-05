import 'package:flutter/foundation.dart';
import '../models/exercise_library_model.dart';
import '../services/exercise_library_service.dart';

class ExerciseLibraryProvider extends ChangeNotifier {
  final ExerciseLibraryService _service;

  ExerciseLibraryProvider(this._service);

  // State
  List<ExerciseLibrary> _exercises = [];
  List<ExerciseLibrary> get exercises => _exercises;

  List<String> _categories = [];
  List<String> get categories => _categories;

  List<String> _equipmentTypes = [];
  List<String> get equipmentTypes => _equipmentTypes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Current filter
  ExerciseFilter _currentFilter = const ExerciseFilter();
  ExerciseFilter get currentFilter => _currentFilter;

  /// Load all exercises
  Future<void> loadExercises({ExerciseFilter? filter}) async {
    _isLoading = true;
    _error = null;
    if (filter != null) _currentFilter = filter;
    notifyListeners();

    try {
      _exercises = await _service.getExercises(filter: _currentFilter);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search exercises
  Future<void> searchExercises(String query) async {
    await loadExercises(filter: ExerciseFilter(search: query));
  }

  /// Filter by category
  Future<void> filterByCategory(String category) async {
    await loadExercises(filter: ExerciseFilter(category: category));
  }

  /// Filter by equipment
  Future<void> filterByEquipment(String equipment) async {
    await loadExercises(filter: ExerciseFilter(equipment: equipment));
  }

  /// Get bodyweight exercises
  Future<void> loadBodyweightExercises() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _exercises = await _service.getBodyweightExercises();
      _currentFilter = ExerciseFilter(equipment: ExerciseEquipment.bodyWeight);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load metadata (categories, equipment)
  Future<void> loadMetadata() async {
    try {
      _categories = await _service.getCategories();
      _equipmentTypes = await _service.getEquipmentTypes();
      notifyListeners();
    } catch (e) {
      // Use fallback
      _categories = ExerciseCategory.all;
      _equipmentTypes = ExerciseEquipment.all;
    }
  }

  /// Clear filter
  void clearFilter() {
    _currentFilter = const ExerciseFilter();
    loadExercises();
  }

  /// Get exercise by ID (cached)
  ExerciseLibrary? getExerciseById(String id) {
    try {
      return _exercises.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }
}
