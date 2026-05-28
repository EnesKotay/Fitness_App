import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../core/api/services/workout_service.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_models.dart';
import '../../../core/api/api_exception.dart';
import '../../sync/domain/entities/pending_sync.dart';
import '../../sync/services/offline_sync_service.dart';
import '../data/hive_workout_repository.dart';
import '../data/workout_catalog_data.dart';
import '../services/progression_engine.dart';
import '../services/recovery_engine.dart';

class TodayWorkoutSuggestion {
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const TodayWorkoutSuggestion({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class WorkoutProvider with ChangeNotifier {
  final WorkoutService _workoutService = WorkoutService();
  final HiveWorkoutRepository _hiveRepo = HiveWorkoutRepository();

  // ── State ─────────────────────────────────────────────────────────────────
  List<Workout> _workouts = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  // Yeni state
  List<Workout> _exerciseHistory = [];
  Map<String, double> _personalRecords = {};
  Map<String, dynamic> _workoutStats = {};
  TodayWorkoutSuggestion? _workoutSuggestion;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<Workout> get workouts => _workouts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  List<Workout> get exerciseHistory => _exerciseHistory;
  Map<String, double> get personalRecords => _personalRecords;
  Map<String, dynamic> get workoutStats => _workoutStats;
  TodayWorkoutSuggestion? get workoutSuggestion => _workoutSuggestion;

  /// Seçili tarihe ait antrenmanlar
  List<Workout> get workoutsForSelectedDate {
    return _workouts.where((w) {
      return w.workoutDate.year == _selectedDate.year &&
          w.workoutDate.month == _selectedDate.month &&
          w.workoutDate.day == _selectedDate.day;
    }).toList();
  }

  /// Bir egzersizin son N kaydındaki max ağırlıklarını döndürür (trend için)
  /// Bir egzersizin son [limit] kaydındaki max ağırlıklarını kronolojik sırayla döndürür.
  List<double> maxWeightsFor(String exerciseName, {int limit = 6}) {
    final matching =
        _workouts
            .where((w) => w.name.toLowerCase() == exerciseName.toLowerCase())
            .toList()
          ..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));
    // Son 'limit' antrenmanı kronolojik sırayla al (eski→yeni)
    final start = (matching.length - limit).clamp(0, matching.length);
    return matching.sublist(start).map((w) => w.weight ?? 0.0).toList();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadWorkouts(int userId) async {
    if (userId <= 0) {
      reset();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _workouts = await _workoutService.getUserWorkouts(userId);
      unawaited(_hiveRepo.saveAll(_workouts));
      _sortWorkouts();
      _buildWorkoutSuggestion();
      _isLoading = false;
      notifyListeners();
      unawaited(loadPersonalRecords(userId));
      unawaited(loadWorkoutStats(userId));
    } on ApiException catch (e) {
      if (_isOfflineConnectionIssue(e)) {
        final cached = await _hiveRepo.getAll();
        if (cached.isNotEmpty) {
          _workouts = cached;
          _sortWorkouts();
          _buildWorkoutSuggestion();
        }
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      } else {
        _errorMessage = e.message;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      final cached = await _hiveRepo.getAll();
      if (cached.isNotEmpty) {
        _workouts = cached;
        _sortWorkouts();
        _buildWorkoutSuggestion();
        _isLoading = false;
        _errorMessage = null;
      } else {
        _errorMessage = 'Antrenmanlar yüklenemedi';
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// Egzersiz geçmişini yükle (Step 1 — egzersiz seçildiğinde)
  Future<void> loadExerciseHistory(int userId, String exerciseName) async {
    if (userId <= 0 || exerciseName.isEmpty) return;
    try {
      _exerciseHistory = await _workoutService.getExerciseHistory(
        userId,
        exerciseName,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('loadExerciseHistory error: $e');
    }
  }

  /// Kişisel rekorları yükle
  Future<void> loadPersonalRecords(int userId) async {
    if (userId <= 0) return;
    try {
      _personalRecords = await _workoutService.getPersonalRecords(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('loadPersonalRecords error: $e');
    }
  }

  /// Genel istatistikleri yükle
  Future<void> loadWorkoutStats(int userId) async {
    if (userId <= 0) return;
    try {
      _workoutStats = await _workoutService.getWorkoutStats(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('loadWorkoutStats error: $e');
    }
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
      unawaited(loadPersonalRecords(userId));
      unawaited(loadWorkoutStats(userId));
      return true;
    } on ApiException catch (e) {
      if (_isOfflineConnectionIssue(e)) {
        final id = const Uuid().v4();
        await OfflineSyncService().addToQueue(
          PendingSync(
            id: id,
            entityType: 'workout',
            action: 'create',
            payload: jsonEncode(request.toJson()),
          ),
        );

        final optimistic = _buildOptimisticWorkout(
          request,
          id: DateTime.now().millisecondsSinceEpoch,
        );
        _upsertWorkout(optimistic);
        unawaited(_hiveRepo.put(optimistic));
        _isLoading = false;
        _errorMessage = null;
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

  Future<bool> createWorkoutSession(
    int userId,
    WorkoutSessionRequest request,
  ) async {
    if (userId <= 0) {
      _errorMessage = 'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final session = await _workoutService.createWorkoutSession(
        userId,
        request,
      );
      for (final workout in session.workouts) {
        _upsertWorkout(workout);
      }
      _isLoading = false;
      notifyListeners();
      unawaited(loadPersonalRecords(userId));
      unawaited(loadWorkoutStats(userId));
      return true;
    } on ApiException catch (e) {
      if (_isOfflineConnectionIssue(e)) {
        final id = const Uuid().v4();
        await OfflineSyncService().addToQueue(
          PendingSync(
            id: id,
            entityType: 'workout_session',
            action: 'create',
            payload: jsonEncode(request.toJson()),
          ),
        );
        for (final exercise in request.exercises) {
          final optimistic = _buildOptimisticWorkout(
            WorkoutRequest(
              name: exercise.name,
              workoutType: exercise.workoutType,
              sets: exercise.completedSets > 0
                  ? exercise.completedSets
                  : exercise.plannedSets,
              reps: exercise.reps,
              weight: exercise.weight,
              workoutDate: request.finishedAt,
              notes: exercise.notes ?? request.notes,
              setDetails: exercise.setDetails,
              muscleGroup: exercise.muscleGroup,
              difficulty: request.difficulty,
            ),
            id: DateTime.now().microsecondsSinceEpoch + _workouts.length,
          );
          _upsertWorkout(optimistic);
          unawaited(_hiveRepo.put(optimistic));
        }
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Antrenman seansı kaydedilemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWorkout(
    int userId,
    int workoutId,
    WorkoutRequest request,
  ) async {
    if (userId <= 0) {
      _errorMessage = 'Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updatedWorkout = await _workoutService.updateWorkout(
        userId,
        workoutId,
        request,
      );
      _upsertWorkout(updatedWorkout);
      _isLoading = false;
      notifyListeners();
      unawaited(loadPersonalRecords(userId));
      unawaited(loadWorkoutStats(userId));
      return true;
    } on ApiException catch (e) {
      if (_isOfflineConnectionIssue(e)) {
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
        Workout updated;
        if (existingIndex != -1) {
          final previous = _workouts[existingIndex];
          updated = Workout(
            id: previous.id,
            name: request.name ?? previous.name,
            workoutDate: request.workoutDate ?? previous.workoutDate,
            workoutType: request.workoutType ?? previous.workoutType,
            durationMinutes:
                request.durationMinutes ?? previous.durationMinutes,
            caloriesBurned: request.caloriesBurned ?? previous.caloriesBurned,
            sets: request.sets ?? previous.sets,
            reps: request.reps ?? previous.reps,
            weight: request.weight ?? previous.weight,
            notes: request.notes ?? previous.notes,
            setDetails: request.setDetails ?? previous.setDetails,
            muscleGroup: request.muscleGroup ?? previous.muscleGroup,
            isSuperset: request.isSuperset ?? previous.isSuperset,
            supersetPartner:
                request.supersetPartner ?? previous.supersetPartner,
            oneRepMax: request.oneRepMax ?? previous.oneRepMax,
            difficulty: request.difficulty ?? previous.difficulty,
            createdAt: previous.createdAt,
            updatedAt: DateTime.now(),
          );
          _workouts[existingIndex] = updated;
        } else {
          updated = _buildOptimisticWorkout(request, id: workoutId);
          _workouts.add(updated);
        }
        unawaited(_hiveRepo.put(updated));
        _sortWorkouts();
        _buildWorkoutSuggestion();
        _isLoading = false;
        _errorMessage = null;
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
      _sortWorkouts();
      _buildWorkoutSuggestion();
      _isLoading = false;
      notifyListeners();
      unawaited(loadPersonalRecords(userId));
      unawaited(loadWorkoutStats(userId));
      return true;
    } on ApiException catch (e) {
      if (_isOfflineConnectionIssue(e)) {
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
        unawaited(_hiveRepo.delete(workoutId));
        _sortWorkouts();
        _buildWorkoutSuggestion();
        _isLoading = false;
        _errorMessage = null;
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
    _workoutSuggestion = null;
    _isLoading = false;
    _errorMessage = null;
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  bool _isOfflineConnectionIssue(ApiException e) {
    if (e.statusCode != null) {
      return false;
    }
    final message = e.message.toLowerCase();
    return message.contains('sunucuya bağlanılamadı') ||
        message.contains('internet bağlantınızı kontrol edin') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup');
  }

  Workout _buildOptimisticWorkout(WorkoutRequest request, {required int id}) {
    final now = DateTime.now();
    return Workout(
      id: id,
      name: request.name ?? 'Yeni Antrenman',
      workoutDate: request.workoutDate ?? now,
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
      createdAt: now,
      updatedAt: now,
    );
  }

  void _upsertWorkout(Workout workout) {
    final index = _workouts.indexWhere((w) => w.id == workout.id);
    if (index == -1) {
      _workouts.add(workout);
    } else {
      _workouts[index] = workout;
    }
    _sortWorkouts();
    _buildWorkoutSuggestion();
  }

  void _buildWorkoutSuggestion() {
    if (_workouts.isEmpty) {
      _workoutSuggestion = null;
      return;
    }

    final now = DateTime.now();
    final fatigueByGroup = RecoveryEngine.computeAll(_workouts);
    final freshGroups = RecoveryEngine.recommendedGroupsToday(_workouts);
    final allGroups = kMuscleGroupInfo.keys.toList();
    final targetGroup =
        (freshGroups.isNotEmpty ? freshGroups : allGroups).first;
    final info = kMuscleGroupInfo[targetGroup]!;
    final status = fatigueByGroup[targetGroup];
    final lastDate = status?.lastWorkoutDate;
    final daysSince = lastDate == null ? null : now.difference(lastDate).inDays;
    final recoveryDetail = daysSince == null
        ? '${info.label} için başlangıç seansı planla ve temel hareketlerle ritim kur.'
        : status?.level == FatigueLevel.fresh
        ? '${info.label} toparlanmış görünüyor. Son odaklı kaydın üzerinden $daysSince gün geçti.'
        : '${info.label} hâlâ ${status?.levelLabel.toLowerCase() ?? 'izleniyor'}. Bugün daha hazır bir bölgeye yönelebilirsin.';
    final progressionDetail = _buildProgressionDetail(targetGroup);
    final detail = progressionDetail == null
        ? recoveryDetail
        : '$recoveryDetail $progressionDetail';

    _workoutSuggestion = TodayWorkoutSuggestion(
      title: '${info.label} odaklı antrenman',
      detail: detail,
      icon: info.icon,
      color: info.color,
    );
  }

  String? _buildProgressionDetail(String muscleGroup) {
    final candidates =
        _workouts
            .where((workout) => workout.muscleGroup == muscleGroup)
            .toList()
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    if (candidates.isEmpty) return null;

    for (final candidate in candidates.take(5)) {
      final hint = ProgressionEngine.compute(
        history: _workouts,
        exerciseName: candidate.name,
        targetReps: candidate.reps ?? 10,
      );
      if (hint.lastWeight == null && hint.suggestedWeight <= 0) continue;
      return 'Son ${candidate.name} kaydına göre bugün ${hint.weightLabel} x ${hint.suggestedReps} denenebilir.';
    }
    return null;
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
