import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_phase.dart';

class TrainingPhaseService {
  static const _keyPhase = 'training_phase';
  static const _keyStartDate = 'training_phase_start';

  Future<TrainingPhase> loadPhase() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPhase);
    return TrainingPhase.values.firstWhere(
      (p) => p.name == raw,
      orElse: () => TrainingPhase.hypertrophy,
    );
  }

  Future<DateTime?> loadStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyStartDate);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> savePhase(TrainingPhase phase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhase, phase.name);
    await prefs.setString(_keyStartDate, DateTime.now().toIso8601String());
  }
}
