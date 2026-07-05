import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/storage_helper.dart';
import '../models/workout_program.dart';

class WorkoutProgramProvider extends ChangeNotifier {
  static const _kKey = 'workout_programs_v1';
  static const _kStateKey = 'workout_program_state_v1';

  List<WorkoutProgram> _programs = [];
  String? _activeProgramId;
  final Set<String> _completedDayIds = {};
  bool _loaded = false;

  List<WorkoutProgram> get programs => List.unmodifiable(_programs);
  String? get activeProgramId => _activeProgramId;
  Set<String> get completedDayIds => Set.unmodifiable(_completedDayIds);
  WorkoutProgram? get activeProgram {
    final id = _activeProgramId;
    if (id == null) return _programs.isEmpty ? null : _programs.first;
    for (final program in _programs) {
      if (program.id == id) return program;
    }
    return _programs.isEmpty ? null : _programs.first;
  }

  bool get loaded => _loaded;
  String get _programsKey => StorageHelper.userScopedKey(_kKey);
  String get _stateKey => StorageHelper.userScopedKey(_kStateKey);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_programsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _programs = list
            .map((e) => WorkoutProgram.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final stateRaw = prefs.getString(_stateKey);
      if (stateRaw != null) {
        final state = jsonDecode(stateRaw) as Map<String, dynamic>;
        _activeProgramId = state['activeProgramId']?.toString();
        _completedDayIds
          ..clear()
          ..addAll(
            (state['completedDayIds'] as List<dynamic>? ?? const []).map(
              (item) => item.toString(),
            ),
          );
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveProgram(WorkoutProgram program) async {
    final idx = _programs.indexWhere((p) => p.id == program.id);
    if (idx >= 0) {
      _programs[idx] = program;
    } else {
      _programs.insert(0, program);
      _activeProgramId ??= program.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteProgram(String id) async {
    _programs.removeWhere((p) => p.id == id);
    if (_activeProgramId == id) {
      _activeProgramId = _programs.isEmpty ? null : _programs.first.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setActiveProgram(String id) async {
    if (!_programs.any((program) => program.id == id)) return;
    _activeProgramId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> markDayCompleted(String programId, String dayId) async {
    _activeProgramId = programId;
    _completedDayIds.add('${programId}_$dayId');
    await _persist();
    notifyListeners();
  }

  bool isDayCompleted(String programId, String dayId) =>
      _completedDayIds.contains('${programId}_$dayId');

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _programsKey,
      jsonEncode(_programs.map((p) => p.toJson()).toList()),
    );
    await prefs.setString(
      _stateKey,
      jsonEncode({
        'activeProgramId': _activeProgramId,
        'completedDayIds': _completedDayIds.toList(),
      }),
    );
  }

  void reset() {
    _programs = [];
    _activeProgramId = null;
    _completedDayIds.clear();
    _loaded = false;
    notifyListeners();
  }
}
