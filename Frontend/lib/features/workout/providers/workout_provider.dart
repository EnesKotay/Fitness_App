import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../core/api/services/workout_service.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_models.dart';
import '../../../core/api/api_exception.dart';
import '../../sync/domain/entities/pending_sync.dart';
import '../../sync/services/offline_sync_service.dart';

class WorkoutProvider with ChangeNotifier {
  final WorkoutService _workoutService = WorkoutService();

  // ── State ─────────────────────────────────────────────────────────────────
  List<Workout> _workouts = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  // Yeni state
  List<Workout> _exerciseHistory = [];
  Map<String, double> _personalRecords = {};
  Map<String, dynamic> _workoutStats = {};

  // ── Getters ───────────────────────────────────────────────────────────────
  List<Workout> get workouts => _workouts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  List<Workout> get exerciseHistory => _exerciseHistory;
  Map<String, double> get personalRecords => _personalRecords;
  Map<String, dynamic> get workoutStats => _workoutStats;

  /// Seçili tarihe ait antrenmanlar
  List<Workout> get workoutsForSelectedDate {
    return _workouts.where((w) {
      return w.workoutDate.year == _selectedDate.year &&
          w.workoutDate.month == _selectedDate.month &&
          w.workoutDate.day == _selectedDate.day;
    }).toList();
  }

  /// Bir egzersizin son N kaydındaki max ağırlıklarını döndürür (trend için)
  List<double> maxWeightsFor(String exerciseName, {int limit = 6}) {
    final matching = _workouts
        .where((w) => w.name.toLowerCase() == exerciseName.toLowerCase())
        .toList()
      ..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));
    return matching
        .reversed
        .take(limit)
        .toList()
        .reversed
        .map((w) => w.weight ?? 0.0)
        .toList();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadWorkouts(int userId) async {
    if (userId <= 0) { reset(); return; }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _workouts = await _workoutService.getUserWorkouts(userId);
      _sortWorkouts();
      _isLoading = false;
      notifyListeners();
      unawaited(loadPersonalRecords(userId));
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

  /// Egzersiz geçmişini yükle (Step 1 — egzersiz seçildiğinde)
  Future<void> loadExerciseHistory(int userId, String exerciseName) async {
    if (userId <= 0 || exerciseName.isEmpty) return;
    try {
      _exerciseHistory = await _workoutService.getExerciseHistory(userId, exerciseName);
      notifyListeners();
    } catch (_) {
      // Sessizce başarısız — geçmiş gösterilmeyecek
    }
  }

  /// Kişisel rekorları yükle
  Future<void> loadPersonalRecords(int userId) async {
    if (userId <= 0) return;
    try {
      _personalRecords = await _workoutService.getPersonalRecords(userId);
      notifyListeners();
    } catch (_) { /* sessiz */ }
  }

  /// Genel istatistikleri yükle
  Future<void> loadWorkoutStats(int userId) async {
    if (userId <= 0) return;
    try {
      _workoutStats = await _workoutService.getWorkoutStats(userId);
      notifyListeners();
    } catch (_) { /* sessiz */ }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<bool> createWorkout(int userId, WorkoutRequest request) async {
    if (userId <= 0) {
      _errorMessage = 'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final workout = await _workoutService.createWorkout(userId, request);
      _upsertWorkout(workout);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.message.contains('SocketException') || e.message.contains('Failed host lookup')) {
        final id = const Uuid().v4();
        await OfflineSyncService().addToQueue(
          PendingSync(
            id: id,
            entityType: 'workout',
            action: 'create',
            payload: jsonEncode(request.toJson()),
          ),
        );
        
        final fakeWorkout = Workout(
          id: DateTime.now().millisecondsSinceEpoch,
          name: request.name ?? 'Yeni Antrenman',
          workoutDate: request.workoutDate ?? DateTime.now(),
          workoutType: request.workoutType,
          durationMinutes: request.durationMinutes,
          caloriesBurned: request.caloriesBurned,
          sets: request.sets,
          reps: request.reps,
          weight: request.weight,
          notes: request.notes,
          setDetails: request.setDetails,
          muscleGroup: request.muscleGroup,
          isSuperset: request.isSuperset,
          supersetPartner: request.supersetPartner,
          oneRepMax: request.oneRepMax,
          difficulty: request.difficulty,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        _upsertWorkout(fakeWorkout);
        _isLoading = false;
        notifyListeners();
        return true;
      }
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

  Future<bool> updateWorkout(int userId, int workoutId, WorkoutRequest request) async {
    if (userId <= 0) {
      _errorMessage = 'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updatedWorkout = await _workoutService.updateWorkout(userId, workoutId, request);
      _upsertWorkout(updatedWorkout);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.message.contains('SocketException') || e.message.contains('Failed host lookup')) {
        final id = const Uuid().v4();
        await OfflineSyncService().addToQueue(
          PendingSync(
            id: id,
            entityType: 'workout',
            action: 'update',
            payload: jsonEncode({'id': workoutId, 'data': request.toJson()}),
          ),
        );

        final existingIndex = _workouts.indexWhere((w) => w.id == workoutId);
        if (existingIndex != -1) {
          final previous = _workouts[existingIndex];
          _workouts[existingIndex] = Workout(
            id: previous.id,
            name: request.name ?? previous.name,
            workoutDate: request.workoutDate ?? previous.workoutDate,
            workoutType: request.workoutType ?? previous.workoutType,
            durationMinutes: request.durationMinutes ?? previous.durationMinutes,
            caloriesBurned: request.caloriesBurned ?? previous.caloriesBurned,
            sets: request.sets ?? previous.sets,
            reps: request.reps ?? previous.reps,
            weight: request.weight ?? previous.weight,
            notes: request.notes ?? previous.notes,
            setDetails: request.setDetails ?? previous.setDetails,
            muscleGroup: request.muscleGroup ?? previous.muscleGroup,
            isSuperset: request.isSuperset ?? previous.isSuperset,
            supersetPartner: request.supersetPartner ?? previous.supersetPartner,
            oneRepMax: request.oneRepMax ?? previous.oneRepMax,
            difficulty: request.difficulty ?? previous.difficulty,
            createdAt: previous.createdAt,
            updatedAt: DateTime.now(),
          );
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
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

  Future<bool> deleteWorkout(int userId, int workoutId) async {
    if (userId <= 0) {
      _errorMessage = 'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }
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
      if (e.message.contains('SocketException') || e.message.contains('Failed host lookup')) {
        final id = const Uuid().v4();
        await OfflineSyncService().addToQueue(
          PendingSync(
            id: id,
            entityType: 'workout',
            action: 'delete',
            payload: jsonEncode({'id': workoutId}),
          ),
        );
        _workouts.removeWhere((w) => w.id == workoutId);
        _isLoading = false;
        notifyListeners();
        return true;
      }
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

  // ── Misc ──────────────────────────────────────────────────────────────────

  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _workouts = [];
    _exerciseHistory = [];
    _personalRecords = {};
    _workoutStats = {};
    _isLoading = false;
    _errorMessage = null;
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  void _upsertWorkout(Workout workout) {
    final index = _workouts.indexWhere((w) => w.id == workout.id);
    if (index == -1) {
      _workouts.add(workout);
    } else {
      _workouts[index] = workout;
    }
    _sortWorkouts();
  }

  void _sortWorkouts() {
    _workouts.sort((a, b) {
      final byDate = b.workoutDate.compareTo(a.workoutDate);
      if (byDate != 0) return byDate;
      final bUp = b.updatedAt ?? b.createdAt ?? b.workoutDate;
      final aUp = a.updatedAt ?? a.createdAt ?? a.workoutDate;
      return bUp.compareTo(aUp);
    });
  }
}
