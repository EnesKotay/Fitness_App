import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/models/exercise.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_set.dart';
import '../../../core/models/workout_models.dart';
import '../../../core/utils/storage_helper.dart';
import '../data/workout_catalog_data.dart';
import '../providers/workout_provider.dart';
import '../services/progression_engine.dart';
import '../../auth/providers/auth_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../tasks/controllers/daily_tasks_controller.dart';
import '../../tasks/models/daily_task.dart';
import '../widgets/workout_set_row_widget.dart';
import '../widgets/rest_timer_panel.dart';
import '../widgets/exercise_selection_list.dart';

// ---------------------------------------------------------------------------
// AddWorkoutPage
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// AddWorkoutPage
// ---------------------------------------------------------------------------

typedef TemplateData = ({
  String exerciseName,
  int sets,
  int reps,
  String workoutName,
  int duration,
  String? muscleGroup,
  String? difficulty,
});

class AddWorkoutPage extends StatefulWidget {
  final Workout? workout; // null → create, non-null → edit
  final TemplateData? templateData;

  const AddWorkoutPage({super.key, this.workout, this.templateData});

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends State<AddWorkoutPage>
    with SingleTickerProviderStateMixin {
  // ── step controller ──────────────────────────────────────────────────────
  late final PageController _pageC;
  int _step = 0; // 0 = exercise, 1 = sets, 2 = details

  // ── step 1 — exercise picker ─────────────────────────────────────────────
  String? _selectedMuscleGroup;
  String _exerciseSearchQuery = '';
  String? _selectedExerciseName;
  final _exerciseSearchC = TextEditingController();

  // superset
  bool _isSuperset = false;
  String? _supersetExerciseName;
  final _supersetSearchC = TextEditingController();

  // ── step 2 — sets ────────────────────────────────────────────────────────
  final List<SetEntry> _sets = [];
  final List<SetEntry> _retiredSetEntries = [];

  // stopwatch (antrenman süresi)
  final _stopwatch = Stopwatch();
  Timer? _swTimer;
  Duration _swElapsed = Duration.zero;

  // ── Dinlenme zamanlayıcısı ────────────────────────────────────────────────
  int _restSeconds = 90; // varsayılan 90 saniye
  int _restRemaining = 0;
  Timer? _restTimer;
  bool _restActive = false;

  // ── Kişisel rekor ─────────────────────────────────────────────────────────
  double? _previousPR;

  // ── step 3 — details ────────────────────────────────────────────────────
  DateTime _pickedDate = DateTime.now();
  final _nameC = TextEditingController();
  final _typeC = TextEditingController();
  final _durationC = TextEditingController();
  final _caloriesC = TextEditingController();
  final _notesC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── misc ─────────────────────────────────────────────────────────────────
  bool _saving = false;
  double _userWeight = 70.0;

  // ── plateau uyarısı ───────────────────────────────────────────────────────
  bool _hasPlateau = false;

  // ── zorluk seçici ─────────────────────────────────────────────────────────
  String? _difficulty;

  // ── ısınma sayfası gösterildi mi ──────────────────────────────────────────
  String? _warmupShownFor;

  // ── colour helpers ────────────────────────────────────────────────────────
  static const _green = Color(0xFF00E676);
  static const _bg = Color(0xFF080B0F);
  static const _card = Color(0xFF0E1318);
  static const _cardBorder = Color(0xFF1C2530);

  Color get _accentColor {
    if (_selectedMuscleGroup != null) {
      return kMuscleGroupInfo[_selectedMuscleGroup]?.color ?? _green;
    }
    return _green;
  }

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pageC = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final diet = Provider.of<DietProvider>(context, listen: false);
      _userWeight = diet.profile?.weight ?? 70.0;

      final w = widget.workout;
      final tmpl = widget.templateData;
      if (w != null) {
        _nameC.text = w.name;
        _typeC.text = w.workoutType ?? '';
        _durationC.text = w.durationMinutes?.toString() ?? '';
        _caloriesC.text = w.caloriesBurned?.toString() ?? '';
        _notesC.text = w.notes ?? '';
        _pickedDate = w.workoutDate;
        _selectedExerciseName = w.name;
        _exerciseSearchQuery = w.name;
        _exerciseSearchC.text = w.name;
        _selectedMuscleGroup = _normalizeMuscleGroupCode(
          w.muscleGroup ?? w.workoutType,
        );
        _isSuperset = w.isSuperset ?? false;
        _supersetExerciseName = w.supersetPartner;
        _supersetSearchC.text = w.supersetPartner ?? '';

        final loadedSets = <SetEntry>[];
        if (w.setDetails != null && w.setDetails!.isNotEmpty) {
          for (final detail in w.setDetails!) {
            loadedSets.add(
              SetEntry.fromValues(
                detail.weight?.toString() ?? '',
                detail.reps?.toString() ?? '',
                type: _apiSetTypeToLabel(detail.setType),
              ),
            );
          }
        } else {
          final repeatedCount = math.max(1, w.sets ?? 1);
          for (int i = 0; i < repeatedCount; i++) {
            loadedSets.add(
              SetEntry.fromValues(
                w.weight?.toString() ?? '',
                w.reps?.toString() ?? '',
              ),
            );
          }
        }

        setState(() => _sets.addAll(loadedSets));
        unawaited(_primeExerciseInsights(w.name));
      } else if (tmpl != null) {
        _selectedExerciseName = tmpl.exerciseName;
        _selectedMuscleGroup = tmpl.muscleGroup;
        _exerciseSearchQuery = tmpl.exerciseName;
        _exerciseSearchC.text = tmpl.exerciseName;
        _nameC.text = tmpl.workoutName;
        _durationC.text = tmpl.duration.toString();
        if (tmpl.muscleGroup != null) {
          _typeC.text =
              kMuscleGroupInfo[tmpl.muscleGroup]?.label ?? tmpl.muscleGroup!;
        }
        final sets = List.generate(
          tmpl.sets,
          (_) => SetEntry.fromValues('', tmpl.reps.toString(), type: 'Normal'),
        );
        // Step'i 1'e ayarla — page ve step indicator senkron olsun
        setState(() {
          _sets.addAll(sets);
          _step = 1;
        });
        // Kronometreyi otomatik başlat
        _stopwatch.start();
        _swTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _swElapsed = _stopwatch.elapsed);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pageC.jumpToPage(1);
        });
        unawaited(_primeExerciseInsights(tmpl.exerciseName));
      } else {
        _sets.add(SetEntry());
      }
    });
  }

  @override
  void dispose() {
    _pageC.dispose();
    _swTimer?.cancel();
    _restTimer?.cancel();
    // Controller'lar her zaman dispose edilmeli — memory leak önlenir
    _exerciseSearchC.dispose();
    _supersetSearchC.dispose();
    _nameC.dispose();
    _typeC.dispose();
    _durationC.dispose();
    _caloriesC.dispose();
    _notesC.dispose();
    for (final s in _sets) {
      s.dispose();
    }
    for (final s in _retiredSetEntries) {
      s.dispose();
    }
    super.dispose();
  }

  // ── stopwatch helpers ────────────────────────────────────────────────────

  void _toggleStopwatch() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _swTimer?.cancel();
        _swTimer = null;
        _durationC.text = (_stopwatch.elapsed.inSeconds / 60).ceil().toString();
      } else {
        _stopwatch.start();
        _swTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _swElapsed = _stopwatch.elapsed);
        });
      }
    });
  }

  // ── Dinlenme zamanlayıcısı ────────────────────────────────────────────────

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restRemaining = _restSeconds;
      _restActive = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_restRemaining > 0) {
          _restRemaining--;
        } else {
          _restActive = false;
          t.cancel();
          HapticFeedback.mediumImpact();
        }
      });
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restActive = false;
      _restRemaining = 0;
    });
  }

  void _markSetDone(int idx) {
    final isNowDone = !_sets[idx].isDone;
    setState(() => _sets[idx].isDone = isNowDone);
    if (isNowDone) {
      _startRestTimer();
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF12281A),
          content: Text(
            'Set ${idx + 1} tamamlandı. $_restSeconds sn dinlenme başladı.',
          ),
        ),
      );
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _resetStopwatch() {
    _swTimer?.cancel();
    _swTimer = null;
    _stopwatch
      ..stop()
      ..reset();
    setState(() {
      _swElapsed = Duration.zero;
      _durationC.clear();
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _normalizeMuscleGroupCode(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    final upper = value.toUpperCase();
    if (kMuscleGroupInfo.containsKey(upper)) return upper;

    const aliases = <String, String>{
      'GÖĞÜS': 'CHEST',
      'GOGUS': 'CHEST',
      'CHEST': 'CHEST',
      'SIRT': 'BACK',
      'BACK': 'BACK',
      'BACAK': 'LEGS',
      'QUADS': 'LEGS',
      'HAMSTRING': 'LEGS',
      'CALF': 'LEGS',
      'LEGS': 'LEGS',
      'OMUZ': 'SHOULDERS',
      'DELT': 'SHOULDERS',
      'TRAP': 'SHOULDERS',
      'SHOULDERS': 'SHOULDERS',
      'BİSEPS': 'BICEPS',
      'BISEPS': 'BICEPS',
      'BICEPS': 'BICEPS',
      'TRİCEPS': 'TRICEPS',
      'TRICEPS': 'TRICEPS',
      'KARIN': 'CORE',
      'CORE': 'CORE',
      'KALÇA': 'GLUTES',
      'KALCA': 'GLUTES',
      'GLUTES': 'GLUTES',
    };

    if (upper.contains('QUAD') ||
        upper.contains('HAMSTRING') ||
        upper.contains('CALF') ||
        upper.contains('BALDIR')) {
      return 'LEGS';
    }
    if (upper.contains('DELT') || upper.contains('TRAP')) {
      return 'SHOULDERS';
    }

    return aliases[upper] ?? upper;
  }

  String _apiSetTypeToLabel(String? apiType) {
    switch ((apiType ?? '').trim().toUpperCase()) {
      case 'WARMUP':
        return 'Isınma';
      case 'DROP':
        return 'Drop-Set';
      case 'FAILURE':
        return 'Failure';
      default:
        return 'Normal';
    }
  }

  Future<void> _primeExerciseInsights([String? exerciseName]) async {
    final selected = (exerciseName ?? _selectedExerciseName ?? '').trim();
    if (selected.isEmpty || !mounted) return;
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final workoutProv = Provider.of<WorkoutProvider>(context, listen: false);
    final userId = authProv.user?.id;
    if (userId == null) return;
    await workoutProv.loadExerciseHistory(userId, selected);
    await workoutProv.loadPersonalRecords(userId);
  }

  List<Workout> _historyForSelectedExercise(WorkoutProvider provider) {
    final selected = (_selectedExerciseName ?? _nameC.text)
        .trim()
        .toLowerCase();
    if (selected.isEmpty) return provider.workouts;
    final remoteHistory = provider.exerciseHistory.where(
      (workout) => workout.name.trim().toLowerCase() == selected,
    );
    final source = remoteHistory.isNotEmpty ? remoteHistory : provider.workouts;
    return source
        .where((workout) => workout.name.trim().toLowerCase() == selected)
        .toList();
  }

  int _currentTargetReps() {
    for (final set in _sets) {
      final reps = int.tryParse(set.repsC.text.trim());
      if (reps != null && reps > 0) return reps;
    }
    return 10;
  }

  int _completedSetCount() => _sets.where((set) => set.isDone).length;

  double _totalVolume() {
    double total = 0;
    for (final set in _sets) {
      final weight =
          double.tryParse(set.weightC.text.trim().replaceAll(',', '.')) ?? 0;
      final reps = int.tryParse(set.repsC.text.trim()) ?? 0;
      total += weight * reps;
    }
    return total;
  }

  double _averageRpe() {
    if (_sets.isEmpty) return 0;
    final sum = _sets.fold<int>(0, (total, set) => total + set.rpe);
    return sum / _sets.length;
  }

  int _emptySetCount() {
    return _sets.where((set) {
      final hasWeight = set.weightC.text.trim().isNotEmpty;
      final hasReps = set.repsC.text.trim().isNotEmpty;
      // Ağırlık VEYA tekrar eksikse bu set eksik sayılır
      return !hasWeight || !hasReps;
    }).length;
  }

  Workout? _latestWorkoutForExercise(
    WorkoutProvider provider,
    String exerciseName,
  ) {
    if (exerciseName.trim().isEmpty) return null;
    final matches =
        provider.workouts
            .where(
              (workout) =>
                  workout.name.toLowerCase() == exerciseName.toLowerCase(),
            )
            .toList()
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    return matches.isEmpty ? null : matches.first;
  }

  String _workoutCompactSummary(Workout workout) {
    final setCount = workout.setDetails?.isNotEmpty == true
        ? workout.setDetails!.length
        : (workout.sets ?? 1);
    final maxWeight = workout.setDetails?.isNotEmpty == true
        ? workout.setDetails!
              .map((set) => set.weight ?? 0)
              .fold<double>(0.0, (a, b) => a > b ? a : b)
        : (workout.weight ?? 0);
    final reps =
        workout.reps ??
        ((workout.setDetails?.isNotEmpty ?? false)
            ? workout.setDetails!.first.reps ?? 0
            : 0);
    final maxWeightLabel = maxWeight > 0
        ? '${maxWeight.toStringAsFixed(maxWeight % 1 == 0 ? 0 : 1)} kg'
        : 'BW';
    return '$maxWeightLabel x $reps tekrar, $setCount set';
  }

  void _applySetTemplate(int setCount, int reps) {
    final previous = List<SetEntry>.from(_sets);
    final lastWeight = _sets.isNotEmpty ? _sets.last.weightC.text : '';
    setState(() {
      _sets
        ..clear()
        ..addAll(
          List.generate(
            setCount,
            (_) => SetEntry.fromValues(lastWeight, reps.toString()),
          ),
        );
    });
    _retiredSetEntries.addAll(previous);
    HapticFeedback.mediumImpact();
  }

  void _adjustAllWeights(double delta) {
    var changed = false;
    setState(() {
      for (final set in _sets) {
        final raw = set.weightC.text.trim().replaceAll(',', '.');
        final current = double.tryParse(raw);
        if (current == null && delta < 0) continue;
        final next = ((current ?? 0) + delta).clamp(0.0, 500.0);
        set.weightC.text = next % 1 == 0
            ? next.toStringAsFixed(0)
            : next.toStringAsFixed(1);
        changed = true;
      }
    });
    if (changed) HapticFeedback.selectionClick();
  }

  Future<bool> _confirmEmptySets(int emptySetCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Boş setler var',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '$emptySetCount set boş bırakıldı. Yine de kaydetmek istiyor musun?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Geri Dön'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _accentColor),
            child: const Text('Yine de Kaydet'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  // ── 1RM (Epley) ──────────────────────────────────────────────────────────

  double? _calc1RM() {
    if (_sets.isEmpty) return null;
    double best = 0;
    for (final s in _sets) {
      final w = double.tryParse(s.weightC.text.trim().replaceAll(',', '.'));
      final r = int.tryParse(s.repsC.text.trim());
      if (w != null && r != null && r > 0 && w > 0) {
        final rm = w * (1 + r / 30);
        if (rm > best) best = rm;
      }
    }
    return best > 0 ? best : null;
  }

  // ── auto calorie estimator ───────────────────────────────────────────────

  void _recalcCalories() {
    int totalReps = 0;
    double totalWeight = 0;
    int count = 0;
    for (final s in _sets) {
      final w =
          double.tryParse(s.weightC.text.trim().replaceAll(',', '.')) ?? 0;
      final r = int.tryParse(s.repsC.text.trim()) ?? 0;
      if (r > 0) {
        totalReps += r;
        totalWeight += (w > 0 ? w : _userWeight * 0.5);
        count++;
      }
    }
    if (count == 0 || totalReps == 0) return;
    final avgW = totalWeight / count;
    double factor = 0.05;
    final mg = _selectedMuscleGroup ?? '';
    if (mg == 'LEGS') factor = 0.08;
    if (mg == 'CHEST' || mg == 'BACK') factor = 0.06;
    final est = (avgW * factor * totalReps).round();
    if (est > 0) _caloriesC.text = est.toString();
  }

  // ── load previous workout ────────────────────────────────────────────────

  void _loadPreviousWorkout({bool silent = false}) {
    final prov = Provider.of<WorkoutProvider>(context, listen: false);
    final name = _selectedExerciseName ?? _nameC.text.trim();
    if (name.isEmpty) return;
    final matches =
        prov.workouts
            .where((w) => w.name.toLowerCase() == name.toLowerCase())
            .toList()
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    if (matches.isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu egzersiz için önceki kayıt bulunamadı.'),
            backgroundColor: Color(0xFF333333),
          ),
        );
      }
      return;
    }
    final prev = matches.first;
    final previousEntries = List<SetEntry>.from(_sets);
    final nextEntries = <SetEntry>[];

    if (prev.setDetails != null && prev.setDetails!.isNotEmpty) {
      for (final sd in prev.setDetails!) {
        nextEntries.add(
          SetEntry.fromValues(
            sd.weight?.toString() ?? '',
            sd.reps?.toString() ?? '',
            type: _apiSetTypeToLabel(sd.setType),
          ),
        );
      }
    } else {
      nextEntries.add(
        SetEntry.fromValues(
          prev.weight?.toString() ?? '',
          prev.reps?.toString() ?? '',
        ),
      );
      if ((prev.sets ?? 1) > 1) {
        for (int i = 1; i < (prev.sets ?? 1); i++) {
          nextEntries.add(
            SetEntry.fromValues(
              prev.weight?.toString() ?? '',
              prev.reps?.toString() ?? '',
            ),
          );
        }
      }
    }
    setState(() {
      _sets.clear();
      _sets.addAll(nextEntries);
      _durationC.text = prev.durationMinutes?.toString() ?? '';
      if (!silent) _notesC.text = prev.notes ?? '';
    });
    _retiredSetEntries.addAll(previousEntries);
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${DateFormat("d MMM", "tr_TR").format(prev.workoutDate)} tarihli kayıt yüklendi.',
          ),
          backgroundColor: _green,
        ),
      );
    }
  }

  // ── Plateau tespiti ─────────────────────────────────────────────────────

  bool _checkPlateau(WorkoutProvider prov, String exerciseName) {
    if (exerciseName.isEmpty) return false;
    final matches =
        prov.workouts
            .where((w) => w.name.toLowerCase() == exerciseName.toLowerCase())
            .toList()
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    if (matches.length < 3) return false;
    final maxWeights = matches.take(3).map((w) {
      if (w.setDetails != null && w.setDetails!.isNotEmpty) {
        return w.setDetails!
            .map((s) => s.weight ?? 0.0)
            .fold<double>(0.0, (a, b) => a > b ? a : b);
      }
      return w.weight ?? 0.0;
    }).toList();
    if (maxWeights.any((w) => w <= 0)) return false;
    return maxWeights[0] == maxWeights[1] && maxWeights[1] == maxWeights[2];
  }

  // ── Isınma önerisi bottom sheet ─────────────────────────────────────────

  void _showWarmupSheet() {
    final mg = _selectedMuscleGroup ?? '';
    final warmups = _warmupForMuscleGroup(mg);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.whatshot_rounded, color: _accentColor, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Isınma Önerisi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Antrenmanından önce şu hareketleri dene:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ...warmups.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        w,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Anladım, Başla!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _warmupForMuscleGroup(String mg) {
    switch (mg) {
      case 'CHEST':
        return [
          'Kol çevirmesi — 2×15 her yön',
          'Hafif dambıl göğüs press — 2×15',
          'Pec stretch — 30 sn her taraf',
          'Band pull-apart — 2×20',
        ];
      case 'BACK':
        return [
          'Cat-cow mobilizasyon — 2×10',
          'Band yatay çekiş — 2×15',
          'Thoracic rotasyon — 2×10 her taraf',
          'Dead hang — 2×20 sn',
        ];
      case 'LEGS':
        return [
          'Leg swing — 2×15 öne/arkaya her bacak',
          'Bodyweight squat — 2×15',
          'Hip circle — 2×10 her yön',
          'Lunge rotasyonu — 2×8 her bacak',
        ];
      case 'SHOULDERS':
        return [
          'Kol çevirmesi — 2×15 her yön',
          'Band ön kaldırma — 2×15',
          'Wall slide — 2×10',
          'Yaw-pull (omuz dış rotasyon) — 2×15',
        ];
      case 'BICEPS':
        return [
          'Bilek çevirmesi — 30 sn',
          'Hafif curl — 2×15',
          'Kol ekstansiyonu — 2×15',
        ];
      case 'TRICEPS':
        return [
          'Tricep stretch — 30 sn her taraf',
          'Overhead tricep mobilizasyon — 2×10',
          'Hafif pushdown — 2×15',
        ];
      case 'CORE':
        return [
          'Dead bug — 2×10 her taraf',
          'Bird-dog — 2×10 her taraf',
          'Plank — 2×20 sn',
        ];
      case 'GLUTES':
        return [
          'Glute bridge — 2×15',
          'Clamshell — 2×15 her taraf',
          'Hip circle — 2×10 her yön',
        ];
      default:
        return [
          '5 dk hafif koşu / bisiklet',
          'Dinamik germe — tüm vücut',
          'Eklem mobilizasyonu — 5 dk',
        ];
    }
  }

  // ── exercise list for selected group ────────────────────────────────────

  List<Exercise> _exercisesForGroup(String group) {
    return buildExerciseCatalogForGroup(group);
  }

  List<Exercise> _filteredExercises(String group) {
    final q = _exerciseSearchQuery.toLowerCase().trim();
    return _exercisesForGroup(
      group,
    ).where((e) => q.isEmpty || e.name.toLowerCase().contains(q)).toList();
  }

  // ── navigation helpers ───────────────────────────────────────────────────

  void _nextStep() {
    if (_step == 0) {
      // Must have exercise name
      final name = _selectedExerciseName ?? '';
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen bir egzersiz seçin veya adını yazın.'),
            backgroundColor: Color(0xFF333333),
          ),
        );
        return;
      }
      if (_nameC.text.trim().isEmpty) _nameC.text = name;
      if (_selectedMuscleGroup != null && _typeC.text.trim().isEmpty) {
        _typeC.text =
            kMuscleGroupInfo[_selectedMuscleGroup]?.label ??
            _selectedMuscleGroup!;
      }
      // Isınma önerisini yalnızca ilk geçişte göster
      if (_warmupShownFor != name) {
        _warmupShownFor = name;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showWarmupSheet();
        });
      }
    }
    if (_step < 2) {
      setState(() => _step++);
      _pageC.animateToPage(
        _step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      if (_step == 2) _recalcCalories();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageC.animateToPage(
        _step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      _swTimer?.cancel();
      _restTimer?.cancel();
      Navigator.of(context).pop();
    }
  }

  // ── save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    setState(() => _saving = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final prov = Provider.of<WorkoutProvider>(context, listen: false);
    final userId = auth.user?.id;
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }

    final emptySetCount = _emptySetCount();
    if (emptySetCount > 0) {
      final shouldContinue = await _confirmEmptySets(emptySetCount);
      if (!mounted) return;
      if (!shouldContinue) {
        setState(() => _saving = false);
        return;
      }
    }

    // Özet istatistikler
    final validSets = _sets
        .where((s) => s.repsC.text.trim().isNotEmpty)
        .toList();
    final totalSets = validSets.isEmpty ? 1 : validSets.length;
    final totalReps = validSets.fold(
      0,
      (sum, s) => sum + (int.tryParse(s.repsC.text.trim()) ?? 0),
    );
    final avgReps = validSets.isEmpty
        ? int.tryParse(_sets.first.repsC.text.trim())
        : (totalReps / validSets.length).round();
    final maxWeight = validSets.isEmpty
        ? double.tryParse(_sets.first.weightC.text.trim().replaceAll(',', '.'))
        : validSets
              .map(
                (s) =>
                    double.tryParse(
                      s.weightC.text.trim().replaceAll(',', '.'),
                    ) ??
                    0.0,
              )
              .fold<double>(0.0, (a, b) => a > b ? a : b);

    // Toplam hacim (kg × tekrar)
    double totalVolume = 0;
    for (final s in _sets) {
      final w =
          double.tryParse(s.weightC.text.trim().replaceAll(',', '.')) ?? 0;
      final r = int.tryParse(s.repsC.text.trim()) ?? 0;
      totalVolume += w * r;
    }

    // Set detayları listesi
    final setDetails = _sets.asMap().entries.map((e) {
      final i = e.key;
      final s = e.value;
      return WorkoutSet(
        setNumber: i + 1,
        setType: _dartSetTypeToApi(s.setType),
        reps: int.tryParse(s.repsC.text.trim()),
        weight: double.tryParse(s.weightC.text.trim().replaceAll(',', '.')),
        rpe: s.rpe.toDouble(),
      );
    }).toList();

    // 1RM hesapla
    final oneRM = _calc1RM();

    // Superset adı
    String workoutName = _nameC.text.trim();
    if (_isSuperset && (_supersetExerciseName?.isNotEmpty ?? false)) {
      workoutName = '$workoutName + ${_supersetExerciseName!}';
    }

    // PR kontrolü
    final prLookupName = (_selectedExerciseName ?? _nameC.text).trim();
    _previousPR = prov.personalRecords[prLookupName];
    final isNewPR =
        oneRM != null && (_previousPR == null || oneRM > _previousPR!);

    final durationMinutes =
        int.tryParse(_durationC.text.trim()) ??
        (_swElapsed.inSeconds > 0 ? (_swElapsed.inSeconds / 60).ceil() : null);
    final caloriesBurned = int.tryParse(_caloriesC.text.trim());

    final request = WorkoutRequest(
      name: workoutName.isEmpty ? 'Antrenman' : workoutName,
      workoutType: _typeC.text.trim().isEmpty ? null : _typeC.text.trim(),
      sets: totalSets,
      reps: avgReps,
      weight: maxWeight,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesBurned,
      workoutDate: _pickedDate,
      notes: _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      setDetails: setDetails,
      muscleGroup: _selectedMuscleGroup,
      isSuperset: _isSuperset,
      supersetPartner: _isSuperset ? _supersetExerciseName : null,
      oneRepMax: oneRM,
      difficulty: _difficulty,
    );

    bool ok;
    if (widget.workout == null) {
      ok = await prov.createWorkout(userId, request);
    } else {
      ok = await prov.updateWorkout(userId, widget.workout!.id, request);
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
    });

    if (ok) {
      unawaited(
        context.read<DailyTasksController>().autoCompleteFirstUndoneByCategory(
          TaskCategory.sport,
        ),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      _swTimer?.cancel();
      _restTimer?.cancel();

      // Kaydet sonrası özet sheet göster
      await _showSaveSummarySheet(
        context: context,
        workoutName: workoutName.isEmpty ? 'Antrenman' : workoutName,
        totalSets: totalSets,
        totalReps: totalReps,
        totalVolume: totalVolume,
        maxWeight: maxWeight ?? 0,
        durationMinutes: durationMinutes,
        caloriesBurned: caloriesBurned,
        oneRM: oneRM,
        isNewPR: isNewPR,
        previousPR: _previousPR,
      );

      if (!mounted) return;
      Navigator.of(context).pop(isNewPR ? '🏆 Kişisel Rekor!' : 'ok');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(prov.errorMessage ?? 'Kaydedilemedi'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ── Kaydet sonrası özet sheet ─────────────────────────────────────────────

  Future<void> _showSaveSummarySheet({
    required BuildContext context,
    required String workoutName,
    required int totalSets,
    required int totalReps,
    required double totalVolume,
    required double maxWeight,
    int? durationMinutes,
    int? caloriesBurned,
    double? oneRM,
    required bool isNewPR,
    double? previousPR,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (ctx) => _SaveSummarySheet(
        workoutName: workoutName,
        totalSets: totalSets,
        totalReps: totalReps,
        totalVolume: totalVolume,
        maxWeight: maxWeight,
        durationMinutes: durationMinutes,
        caloriesBurned: caloriesBurned,
        oneRM: oneRM,
        isNewPR: isNewPR,
        previousPR: previousPR,
        accentColor: _accentColor,
      ),
    );
  }

  /// Kullanıcı dostu set tipi → API set tipi
  String _dartSetTypeToApi(String label) {
    switch (label) {
      case 'Isınma':
        return 'WARMUP';
      case 'Drop-Set':
        return 'DROP';
      case 'Failure':
        return 'FAILURE';
      default:
        return 'NORMAL';
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageC,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildStep1(), _buildStep2(), _buildStep3()],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final title = widget.workout == null
        ? 'Antrenman Kaydet'
        : 'Antrenmanı Düzenle';
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          border: Border(bottom: BorderSide(color: _cardBorder, width: 0.5)),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: _prevStep,
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentColor,
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
    );
  }

  // ── Step Indicator ───────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const labels = ['Egzersiz', 'Setler', 'Kaydet'];
    const icons = [
      Icons.sports_gymnastics_rounded,
      Icons.repeat_rounded,
      Icons.save_rounded,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _cardBorder, width: 0.5)),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _step;
          final done = i < _step;
          final accent = _accentColor;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Node circle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        width: active ? 44 : 36,
                        height: active ? 44 : 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? accent
                              : active
                              ? accent.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: done || active ? accent : _cardBorder,
                            width: active ? 2 : 1.5,
                          ),
                          boxShadow: (done || active)
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(
                                      alpha: active ? 0.3 : 0.15,
                                    ),
                                    blurRadius: active ? 14 : 6,
                                    spreadRadius: active ? 1 : 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: done
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : Icon(
                                icons[i],
                                size: active ? 20 : 16,
                                color: active ? accent : Colors.white30,
                              ),
                      ),
                      const SizedBox(height: 6),
                      // Label
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : done
                              ? accent
                              : Colors.white30,
                          fontSize: active ? 11 : 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                        child: Text(labels[i]),
                      ),
                    ],
                  ),
                ),
                // Connector line between steps
                if (i < 2)
                  Expanded(
                    flex: 0,
                    child: SizedBox(
                      width: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: 1.5,
                            width: (i < _step) ? 32 : 0,
                            color: _accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── STEP 1 — Exercise Picker ────────────────────────────────────────────────

  Widget _buildStep1() {
    final favoriteEntries = StorageHelper.getFavoriteExercises()
        .where((favorite) {
          if (_selectedMuscleGroup == null) return true;
          final group = _normalizeMuscleGroupCode(favorite.muscleGroup);
          return group.isEmpty || group == _selectedMuscleGroup;
        })
        .take(4)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // ── Muscle group grid ───────────────────────────────────────────
        Row(
          children: [
            Text(
              'KAS GRUBU',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 4-column grid of muscle group cards
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: kMuscleGroupInfo.entries.map((entry) {
            final selected = _selectedMuscleGroup == entry.key;
            final info = entry.value;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedMuscleGroup = selected ? null : entry.key;
                  _exerciseSearchQuery = '';
                  _exerciseSearchC.clear();
                  if (!selected) _selectedExerciseName = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected ? info.color.withValues(alpha: 0.18) : _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? info.color : _cardBorder,
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: info.color.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      info.icon,
                      color: selected ? info.color : Colors.white38,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      info.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white38,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (selected) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: info.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        Divider(color: Colors.white.withValues(alpha: 0.07)),
        const SizedBox(height: 16),

        // ── Exercise name (free text or from list) ─────────────────────────
        Text(
          _selectedMuscleGroup != null
              ? '${kMuscleGroupInfo[_selectedMuscleGroup]?.label ?? ""} Hareketleri'
              : 'Egzersiz Adı',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),

        // Search / free-text field
        TextField(
          controller: _exerciseSearchC,
          onChanged: (v) => setState(() {
            _exerciseSearchQuery = v;
            _selectedExerciseName = v.trim().isEmpty ? null : v.trim();
          }),
          style: const TextStyle(color: Colors.white),
          decoration:
              _inputDeco(
                _selectedMuscleGroup != null
                    ? 'Egzersiz ara veya yaz...'
                    : 'Egzersiz adı yaz...',
              ).copyWith(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _accentColor.withValues(alpha: 0.8),
                ),
                suffixIcon: _exerciseSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white38,
                        ),
                        onPressed: () {
                          _exerciseSearchC.clear();
                          setState(() {
                            _exerciseSearchQuery = '';
                            _selectedExerciseName = null;
                          });
                        },
                      )
                    : null,
              ),
        ),

        if (favoriteEntries.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber.shade300, size: 14),
              const SizedBox(width: 6),
              Text(
                'Favoriler',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favoriteEntries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final favorite = favoriteEntries[index];
                return GestureDetector(
                  onTap: () {
                    final favoriteGroup = _normalizeMuscleGroupCode(
                      favorite.muscleGroup,
                    );
                    setState(() {
                      if (favoriteGroup.isNotEmpty) {
                        _selectedMuscleGroup = favoriteGroup;
                      }
                      _selectedExerciseName = favorite.name;
                      _exerciseSearchQuery = favorite.name;
                      _exerciseSearchC.text = favorite.name;
                    });
                    unawaited(_primeExerciseInsights(favorite.name));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          favorite.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // Selected exercise badge
        if (_selectedExerciseName != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _accentColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedExerciseName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _exerciseSearchC.clear();
                    setState(() {
                      _exerciseSearchQuery = '';
                      _selectedExerciseName = null;
                    });
                  },
                  child: const Icon(
                    Icons.close,
                    color: Colors.white38,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Egzersiz listesi
        if (_selectedMuscleGroup != null) ...[
          const SizedBox(height: 12),
          // Provider'ları Builder ile döngü dışına çıkar — context assertion hatasını önler
          Builder(
            builder: (bCtx) {
              final authProv = Provider.of<AuthProvider>(bCtx);
              final workoutProv = Provider.of<WorkoutProvider>(bCtx);
              return ExerciseSelectionList(
                exercises: _filteredExercises(_selectedMuscleGroup!),
                selectedExerciseName: _selectedExerciseName,
                accentColor: _accentColor,
                workoutProv: workoutProv,
                latestWorkoutSummaryCallback:
                    (WorkoutProvider prov, String exName) {
                      final latest = _latestWorkoutForExercise(prov, exName);
                      if (latest == null) return null;
                      return _workoutCompactSummary(latest);
                    },
                onExerciseSelected: (newSelected) {
                  setState(() {
                    _selectedExerciseName = newSelected;
                    _exerciseSearchC.text = newSelected ?? '';
                    _exerciseSearchQuery = newSelected ?? '';
                  });
                  if (newSelected != null && authProv.user?.id != null) {
                    unawaited(_primeExerciseInsights(newSelected));
                    final allEmpty = _sets.every(
                      (s) => s.weightC.text.isEmpty && s.repsC.text.isEmpty,
                    );
                    if (allEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _loadPreviousWorkout(silent: true);
                      });
                    }
                  }
                },
              );
            },
          ),
        ],

        const SizedBox(height: 20),
        Divider(color: Colors.white.withValues(alpha: 0.07)),
        const SizedBox(height: 16),

        // ── Superset toggle ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Superset / Devre Modu',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'İkinci egzersizi bu sete ekle',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isSuperset,
              onChanged: (v) => setState(() => _isSuperset = v),
              activeThumbColor: _accentColor,
              inactiveTrackColor: Colors.white12,
            ),
          ],
        ),

        if (_isSuperset) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _supersetSearchC,
            onChanged: (v) => setState(() {
              _supersetExerciseName = v.trim().isEmpty ? null : v.trim();
            }),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('2. Egzersiz adı...').copyWith(
              prefixIcon: Icon(
                Icons.add_circle_outline_rounded,
                color: _accentColor.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (_supersetExerciseName != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _supersetExerciseName!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  // ── STEP 2 — Sets ────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final oneRM = _calc1RM();
    final workoutProvider = context.watch<WorkoutProvider>();
    final selectedExercise = (_selectedExerciseName ?? _nameC.text).trim();
    final totalVolume = _totalVolume();
    final avgRpe = _averageRpe();
    final progressionHint = selectedExercise.isEmpty
        ? null
        : ProgressionEngine.compute(
            history: _historyForSelectedExercise(workoutProvider),
            exerciseName: selectedExercise,
            targetReps: _currentTargetReps(),
            userWeight: _userWeight,
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedExerciseName ?? 'Egzersiz',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isSuperset &&
                      (_supersetExerciseName?.isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            color: Colors.orange,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _supersetExerciseName!,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Load previous button
            TextButton.icon(
              onPressed: _loadPreviousWorkout,
              icon: const Icon(Icons.history_rounded, size: 16),
              label: const Text('Önceki', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: _accentColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Stopwatch ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Antrenman Süresi',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_swElapsed),
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w200,
                  color: _stopwatch.isRunning ? _accentColor : Colors.white,
                  letterSpacing: 4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _swBtn(
                    icon: _stopwatch.isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    label: _stopwatch.isRunning ? 'Duraklat' : 'Başlat',
                    color: _accentColor,
                    onTap: _toggleStopwatch,
                  ),
                  const SizedBox(width: 12),
                  _swBtn(
                    icon: Icons.stop_rounded,
                    label: 'Sıfırla',
                    color: Colors.white24,
                    onTap: _resetStopwatch,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        if (progressionHint != null) ...[
          _buildProgressionCard(progressionHint),
          const SizedBox(height: 16),
        ],

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSetTemplateChip('3×10', 3, 10),
            _buildSetTemplateChip('5×5', 5, 5),
            _buildSetTemplateChip('4×8', 4, 8),
            _buildSetTemplateChip('3×12', 3, 12),
          ],
        ),

        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _quickWeightButton(
                label: '-2.5 kg',
                icon: Icons.remove_rounded,
                onTap: () => _adjustAllWeights(-2.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickWeightButton(
                label: '+2.5 kg',
                icon: Icons.add_rounded,
                onTap: () => _adjustAllWeights(2.5),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── 1RM badge ──────────────────────────────────────────────────────
        if (oneRM != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentColor.withValues(alpha: 0.25),
                  _accentColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: _accentColor, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tahmini 1RM (Epley)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${oneRM.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // ── Dinlenme zamanlayıcısı paneli ──────────────────────────────────
        if (_restActive)
          RestTimerPanel(
            restSeconds: _restSeconds,
            restRemaining: _restRemaining,
            onStopTimer: _stopRestTimer,
            onRestSecondsSelected: (sec) {
              setState(() => _restSeconds = sec);
              _startRestTimer();
            },
          ),

        // ── Plateau uyarısı ────────────────────────────────────────────────
        Builder(
          builder: (ctx) {
            final wp = Provider.of<WorkoutProvider>(ctx, listen: false);
            final ex = (_selectedExerciseName ?? '').trim();
            _hasPlateau = _checkPlateau(wp, ex);
            if (!_hasPlateau) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plateau Uyarısı',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Son 3 seansta aynı ağırlıkla çalıştın. Ağırlığı 2,5 kg artırmayı dene!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ── Set başlığı kartı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_rounded, color: _accentColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'SETLER',
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(_sets.length, (i) {
                  final done = i < _sets.where((s) => s.isDone).length;
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? _accentColor
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                '${_sets.where((s) => s.isDone).length}/${_sets.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                totalVolume > 0
                    ? '≈ ${totalVolume.toStringAsFixed(0)} kg'
                    : 'Hacim —',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RPE ${avgRpe.toStringAsFixed(1)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.32),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _sets.isEmpty
                ? 0
                : _sets.where((s) => s.isDone).length / _sets.length,
            minHeight: 2,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
          ),
        ),
        const SizedBox(height: 10),

        ..._sets.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          return Dismissible(
            key: ObjectKey(s),
            direction: _sets.length > 1
                ? DismissDirection.endToStart
                : DismissDirection.none,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
            ),
            onDismissed: (_) {
              final removed = _sets[idx];
              setState(() {
                _sets.removeAt(idx);
              });
              _retiredSetEntries.add(removed);
            },
            child: WorkoutSetRow(
              index: idx,
              setEntry: s,
              accentColor: _accentColor,
              isLast: idx == _sets.length - 1,
              onToggleDone: () => _markSetDone(idx),
              onSetTypeChanged: () => setState(() {}),
              onCopyNextClicked: () {
                final next = _sets[idx + 1];
                setState(() {
                  next.weightC.text = s.weightC.text;
                  next.repsC.text = s.repsC.text;
                  next.setType = s.setType;
                });
              },
              onRpeChanged: () => setState(() {}),
              onChanged: () => setState(() {}),
            ),
          );
        }),

        // Set ekle butonu
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            final last = _sets.last;
            setState(() {
              _sets.add(
                SetEntry.fromValues(last.weightC.text, last.repsC.text),
              );
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, color: _accentColor, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  'Set Ekle',
                  style: TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Set satırı widget'ı ─────────────────────────────────────────────────

  Widget _buildProgressionCard(ProgressionHint hint) {
    final canApplyWeight = hint.suggestedWeight > 0;
    final lastSummary = switch ((hint.lastWeight, hint.lastReps)) {
      (final double weight?, final int reps?) =>
        '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg x $reps',
      (final double weight?, null) =>
        '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg',
      (null, final int reps?) => '$reps tekrar',
      _ => 'İlk kayıt için hafif başla',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: _accentColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'İlerleme Önerisi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(hint.trendEmoji, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Son kayıt: $lastSummary',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bugün öneri: ${hint.weightLabel} • ${hint.suggestedReps} tekrar',
            style: TextStyle(
              color: _accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint.reason,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (canApplyWeight) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  for (final set in _sets) {
                    set.weightC.text = hint.suggestedWeight % 1 == 0
                        ? hint.suggestedWeight.toStringAsFixed(1)
                        : hint.suggestedWeight.toString();
                    if (set.repsC.text.trim().isEmpty) {
                      set.repsC.text = hint.suggestedReps.toString();
                    }
                  }
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _accentColor.withValues(alpha: 0.4)),
                foregroundColor: _accentColor,
              ),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text('Setlere uygula'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetTemplateChip(String label, int sets, int reps) {
    return GestureDetector(
      onTap: () => _applySetTemplate(sets, reps),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _accentColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _quickWeightButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.74),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _swBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 3 — Details ─────────────────────────────────────────────────────

  Widget _buildStep3() {
    // Canlı hesaplamalar
    final validSets = _sets
        .where((s) => s.repsC.text.trim().isNotEmpty)
        .toList();
    final totalReps = validSets.fold(
      0,
      (sum, s) => sum + (int.tryParse(s.repsC.text.trim()) ?? 0),
    );
    final totalVolume = _totalVolume();
    final maxW = validSets.isEmpty
        ? 0.0
        : validSets
              .map(
                (s) =>
                    double.tryParse(
                      s.weightC.text.trim().replaceAll(',', '.'),
                    ) ??
                    0.0,
              )
              .fold<double>(0.0, (a, b) => a > b ? a : b);
    final oneRM = _calc1RM();
    final avgRpe = _averageRpe();
    final completedCount = _completedSetCount();
    final durationSecs = _swElapsed.inSeconds;
    final durationDisplay = _durationC.text.trim().isNotEmpty
        ? '${_durationC.text.trim()} dk'
        : durationSecs > 0
        ? _formatDuration(_swElapsed)
        : '—';

    // Önceki antrenman karşılaştırma
    final prov = Provider.of<WorkoutProvider>(context, listen: false);
    final exerciseName = (_selectedExerciseName ?? _nameC.text).trim();
    final prevMatches =
        prov.workouts
            .where((w) => w.name.toLowerCase() == exerciseName.toLowerCase())
            .toList()
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    final prevWorkout = prevMatches.isNotEmpty ? prevMatches.first : null;
    double prevMaxW = 0;
    int prevTotalReps = 0;
    if (prevWorkout != null) {
      if (prevWorkout.setDetails != null &&
          prevWorkout.setDetails!.isNotEmpty) {
        prevMaxW = prevWorkout.setDetails!
            .map((s) => s.weight ?? 0.0)
            .fold<double>(0.0, (a, b) => a > b ? a : b);
        prevTotalReps = prevWorkout.setDetails!.fold(
          0,
          (sum, s) => sum + (s.reps ?? 0),
        );
      } else {
        prevMaxW = prevWorkout.weight ?? 0;
        prevTotalReps = (prevWorkout.reps ?? 0) * (prevWorkout.sets ?? 1);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ══════════════════════════════════════════════════════════════
            // ÖZET KARTI
            // ══════════════════════════════════════════════════════════════
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _accentColor.withValues(alpha: 0.22),
                    _accentColor.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _accentColor.withValues(alpha: 0.30),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Başlık bandı
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            color: _accentColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _nameC.text.isEmpty
                                ? (exerciseName.isEmpty
                                      ? 'Egzersiz'
                                      : exerciseName)
                                : _nameC.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isSuperset &&
                            (_supersetExerciseName?.isNotEmpty ?? false)) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.link_rounded,
                                  color: Colors.orange,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'SS',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Metrik 4'lü ızgara
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _metricTile(
                          'SET',
                          _sets.length.toString(),
                          Icons.repeat_rounded,
                        ),
                        _verticalDivider(),
                        _metricTile(
                          'TEKRAR',
                          totalReps > 0 ? totalReps.toString() : '—',
                          Icons.sports_gymnastics_rounded,
                        ),
                        _verticalDivider(),
                        _metricTile(
                          'MAX KG',
                          maxW > 0
                              ? maxW.toStringAsFixed(maxW % 1 == 0 ? 0 : 1)
                              : '—',
                          Icons.fitness_center_rounded,
                        ),
                        _verticalDivider(),
                        _metricTile(
                          'HACİM',
                          totalVolume > 0
                              ? totalVolume >= 1000
                                    ? '${(totalVolume / 1000).toStringAsFixed(1)}t'
                                    : '${totalVolume.toStringAsFixed(0)}kg'
                              : '—',
                          Icons.stacked_bar_chart_rounded,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 1RM + süre şeridi
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (oneRM != null)
                          _summaryInfoPill(
                            icon: Icons.emoji_events_rounded,
                            iconColor: Colors.amber,
                            text: '1RM ~ ${oneRM.toStringAsFixed(1)} kg',
                            textColor: Colors.amber,
                          ),
                        _summaryInfoPill(
                          icon: Icons.timer_rounded,
                          iconColor: Colors.white38,
                          text: durationDisplay,
                          textColor: Colors.white.withValues(alpha: 0.5),
                        ),
                        if (_durationC.text.trim().isNotEmpty ||
                            durationSecs > 0)
                          _summaryTagPill(
                            label: durationSecs > 0
                                ? 'Kronometre senkron'
                                : 'Manuel süre',
                          ),
                        _summaryTagPill(
                          label: 'Ort. RPE ${avgRpe.toStringAsFixed(1)}',
                        ),
                        _summaryTagPill(
                          label: '$completedCount/${_sets.length} tamamlandı',
                          color: _accentColor.withValues(alpha: 0.15),
                          textColor: _accentColor,
                        ),
                      ],
                    ),
                  ),

                  // Önceki antrenmanla karşılaştırma
                  if (prevWorkout != null && widget.workout == null) ...[
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.compare_arrows_rounded,
                            color: Colors.white30,
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Önceki  ${DateFormat("d MMM", "tr_TR").format(prevWorkout.workoutDate)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          _comparisonBadge(
                            prevMaxW > 0
                                ? '${prevMaxW.toStringAsFixed(prevMaxW % 1 == 0 ? 0 : 1)} kg'
                                : '—',
                            maxW > prevMaxW
                                ? Colors.greenAccent
                                : maxW < prevMaxW
                                ? Colors.redAccent
                                : Colors.white38,
                            maxW > prevMaxW
                                ? '↑'
                                : maxW < prevMaxW
                                ? '↓'
                                : '=',
                          ),
                          const SizedBox(width: 12),
                          _comparisonBadge(
                            '$prevTotalReps tekrar',
                            totalReps > prevTotalReps
                                ? Colors.greenAccent
                                : totalReps < prevTotalReps
                                ? Colors.redAccent
                                : Colors.white38,
                            totalReps > prevTotalReps
                                ? '↑'
                                : totalReps < prevTotalReps
                                ? '↓'
                                : '=',
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════════════════
            // ZORLUK SEÇİCİ
            // ══════════════════════════════════════════════════════════════
            _sectionLabel('Antrenman Zorluğu', Icons.speed_rounded),
            const SizedBox(height: 10),
            Row(
              children: [
                _difficultyChip('Kolay', '😊', const Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                _difficultyChip('Orta', '💪', const Color(0xFF2196F3)),
                const SizedBox(width: 8),
                _difficultyChip('Zorlu', '🔥', const Color(0xFFFF9800)),
                const SizedBox(width: 8),
                _difficultyChip('Max', '⚡', const Color(0xFFE53935)),
              ],
            ),

            const SizedBox(height: 24),
            _sectionDivider('EGZERSİZ BİLGİLERİ'),
            const SizedBox(height: 14),

            // ── Antrenman Adı ──────────────────────────────────────────────
            TextFormField(
              controller: _nameC,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _iconInputDeco(
                hint: 'Antrenman adı',
                icon: Icons.edit_rounded,
                label: 'Antrenman Adı',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Antrenman adı zorunlu'
                  : null,
            ),

            const SizedBox(height: 12),

            // ── Tür / Kas Grubu ────────────────────────────────────────────
            TextField(
              controller: _typeC,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _iconInputDeco(
                hint: 'örn. Göğüs, Bacak...',
                icon: Icons.category_rounded,
                label: 'Tür / Kas Grubu',
              ),
            ),

            const SizedBox(height: 24),
            _sectionDivider('ZAMAN & KALORİ'),
            const SizedBox(height: 14),

            // ── Süre + Kalori yan yana ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationC,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _iconInputDeco(
                      hint: durationDisplay,
                      icon: Icons.timer_rounded,
                      label: 'Süre (dk)',
                      iconColor: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _caloriesC,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _iconInputDeco(
                      hint: '0',
                      icon: Icons.local_fire_department_rounded,
                      label: 'Kalori (kcal)',
                      iconColor: Colors.deepOrangeAccent,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Tarih seçici ───────────────────────────────────────────────
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _pickedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: _accentColor,
                        onPrimary: Colors.white,
                        surface: _card,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (d != null) setState(() => _pickedDate = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: _accentColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Antrenman Tarihi',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat(
                            'd MMMM yyyy, EEEE',
                            'tr_TR',
                          ).format(_pickedDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.25),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            _sectionDivider('NOT'),
            const SizedBox(height: 14),

            // ── Not alanı ─────────────────────────────────────────────────
            TextField(
              controller: _notesC,
              maxLines: 4,
              maxLength: 300,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Bu antrenmanda neler hissettin? Özel notlar...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 13,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10, top: 14),
                  child: Icon(
                    Icons.sticky_note_2_rounded,
                    color: Colors.white.withValues(alpha: 0.25),
                    size: 18,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                counterStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accentColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Yardımcı widget'lar ────────────────────────────────────────────────────

  Widget _metricTile(String label, String value, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: _accentColor, size: 15),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonBadge(String text, Color color, String arrow) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          arrow,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _summaryInfoPill({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 15),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _summaryTagPill({
    required String label,
    Color? color,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? Colors.white.withValues(alpha: 0.72),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _difficultyChip(String label, String emoji, Color color) {
    final sel = _difficulty == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _difficulty = sel ? null : label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel
                ? color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? color : Colors.white.withValues(alpha: 0.1),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: sel ? color : Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Yeni yardımcı widget'lar ─────────────────────────────────────────────────

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.07),
    );
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _accentColor, size: 15),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _sectionDivider(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ],
    );
  }

  InputDecoration _iconInputDeco({
    required String hint,
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    final ic = iconColor ?? _accentColor;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.22),
        fontSize: 13,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 12, right: 10),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: ic.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: ic, size: 16),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ic, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ── Bottom Bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLast = _step == 2;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _cardBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            GestureDetector(
              onTap: _prevStep,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              onTap: _saving ? null : (isLast ? _save : _nextStep),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _saving
                        ? [Colors.white12, Colors.white12]
                        : [
                            _accentColor,
                            Color.lerp(_accentColor, Colors.black, 0.25)!,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _saving
                      ? null
                      : [
                          BoxShadow(
                            color: _accentColor.withValues(alpha: 0.38),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Center(
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: _accentColor,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Kaydet' : 'Devam Et',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isLast
                                    ? Icons.save_rounded
                                    : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input decoration ─────────────────────────────────────────────────────

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.25),
        fontSize: 13,
      ),
      filled: true,
      fillColor: _card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

// ── Rest timer circular arc painter ─────────────────────────────────────────

// ── Save Summary Sheet ────────────────────────────────────────────────────────

class _SaveSummarySheet extends StatefulWidget {
  final String workoutName;
  final int totalSets;
  final int totalReps;
  final double totalVolume;
  final double maxWeight;
  final int? durationMinutes;
  final int? caloriesBurned;
  final double? oneRM;
  final bool isNewPR;
  final double? previousPR;
  final Color accentColor;

  const _SaveSummarySheet({
    required this.workoutName,
    required this.totalSets,
    required this.totalReps,
    required this.totalVolume,
    required this.maxWeight,
    this.durationMinutes,
    this.caloriesBurned,
    this.oneRM,
    required this.isNewPR,
    this.previousPR,
    required this.accentColor,
  });

  @override
  State<_SaveSummarySheet> createState() => _SaveSummarySheetState();
}

class _SaveSummarySheetState extends State<_SaveSummarySheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final volumeStr = widget.totalVolume >= 1000
        ? '${(widget.totalVolume / 1000).toStringAsFixed(1)} t'
        : '${widget.totalVolume.toStringAsFixed(0)} kg';

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideUp,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // PR banner
              if (widget.isNewPR) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KİŞİSEL REKOR!',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                          if (widget.oneRM != null)
                            Text(
                              'Yeni 1RM: ${widget.oneRM!.toStringAsFixed(1)} kg${widget.previousPR != null ? " (önceki: ${widget.previousPR!.toStringAsFixed(1)} kg)" : ""}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Başlık
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: accent, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Antrenman Tamamlandı!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.workoutName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              // Metrik ızgarası
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _statTile('⚡ Hacim', volumeStr, accent),
                        _divider(),
                        _statTile('🔁 Set', '${widget.totalSets}', accent),
                        _divider(),
                        _statTile('💪 Tekrar', '${widget.totalReps}', accent),
                      ],
                    ),
                    if ((widget.maxWeight > 0) ||
                        widget.durationMinutes != null ||
                        widget.caloriesBurned != null) ...[
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (widget.maxWeight > 0)
                            _statTile(
                              '🏋️ Max',
                              '${widget.maxWeight.toStringAsFixed(widget.maxWeight % 1 == 0 ? 0 : 1)} kg',
                              Colors.white70,
                            ),
                          if (widget.maxWeight > 0 &&
                              widget.durationMinutes != null)
                            _divider(),
                          if (widget.durationMinutes != null)
                            _statTile(
                              '⏱ Süre',
                              '${widget.durationMinutes} dk',
                              Colors.white70,
                            ),
                          if (widget.durationMinutes != null &&
                              widget.caloriesBurned != null)
                            _divider(),
                          if (widget.caloriesBurned != null)
                            _statTile(
                              '🔥 Kalori',
                              '${widget.caloriesBurned} kcal',
                              Colors.white70,
                            ),
                        ],
                      ),
                    ],
                    if (widget.oneRM != null && !widget.isNewPR) ...[
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 14),
                      _statTile(
                        '🥇 1RM (Epley)',
                        '${widget.oneRM!.toStringAsFixed(1)} kg',
                        accent,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Kapat butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Harika, Devam Et! 💪',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: Colors.white10);
  }
}
