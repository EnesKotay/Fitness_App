import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_program.dart';

class WorkoutProgramProvider extends ChangeNotifier {
  static const _kKey = 'workout_programs_v1';

  List<WorkoutProgram> _programs = [];
  bool _loaded = false;

  List<WorkoutProgram> get programs => List.unmodifiable(_programs);
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _programs = list
            .map((e) => WorkoutProgram.fromJson(e as Map<String, dynamic>))
            .toList();
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
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteProgram(String id) async {
    _programs.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(_programs.map((p) => p.toJson()).toList()),
    );
  }

  void reset() {
    _programs = [];
    _loaded = false;
    notifyListeners();
  }
}
