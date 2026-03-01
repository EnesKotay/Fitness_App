import 'package:flutter/foundation.dart';
import '../../../core/api/services/workout_service.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_models.dart';
import '../../../core/api/api_exception.dart';

class WorkoutProvider with ChangeNotifier {
  final WorkoutService _workoutService = WorkoutService();

  // State
  List<Workout> _workouts = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Workout> get workouts => _workouts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Antrenmanları yükle
  Future<void> loadWorkouts(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _workouts = await _workoutService.getUserWorkouts(userId);
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Antrenmanlar yüklenemedi';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Yeni antrenman oluştur
  Future<bool> createWorkout(int userId, WorkoutRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final workout = await _workoutService.createWorkout(userId, request);
      _workouts.insert(0, workout); // En üste ekle
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Antrenman oluşturulamadı';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Antrenman güncelle
  Future<bool> updateWorkout(
    int userId,
    int workoutId,
    WorkoutRequest request,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedWorkout = await _workoutService.updateWorkout(
        userId,
        workoutId,
        request,
      );
      
      final index = _workouts.indexWhere((w) => w.id == workoutId);
      if (index != -1) {
        _workouts[index] = updatedWorkout;
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
      _errorMessage = 'Antrenman güncellenemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Antrenman sil
  Future<bool> deleteWorkout(int userId, int workoutId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _workoutService.deleteWorkout(userId, workoutId);
      _workouts.removeWhere((w) => w.id == workoutId);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Antrenman silinemedi';
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
}
