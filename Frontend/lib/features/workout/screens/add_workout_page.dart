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
import '../data/workout_catalog_data.dart';
import '../providers/workout_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';

// ---------------------------------------------------------------------------
// Data model — a single set row
// ---------------------------------------------------------------------------

/// Set tipleri
const _kSetTypes = ['Isınma', 'Normal', 'Drop-Set', 'Failure'];

class _SetEntry {
  final TextEditingController weightC;
  final TextEditingController repsC;
  String setType;
  bool isDone; // set tamamlandı mı?

  _SetEntry()
    : weightC = TextEditingController(),
      repsC = TextEditingController(),
      setType = 'Normal',
      isDone = false;

  _SetEntry.fromValues(String weight, String reps, {String type = 'Normal'})
    : weightC = TextEditingController(text: weight),
      repsC = TextEditingController(text: reps),
      setType = type,
      isDone = false;

  void dispose() {
    weightC.dispose();
    repsC.dispose();
  }
}

// ---------------------------------------------------------------------------
// AddWorkoutPage
// ---------------------------------------------------------------------------

class AddWorkoutPage extends StatefulWidget {
  final Workout? workout; // null → create, non-null → edit

  const AddWorkoutPage({super.key, this.workout});

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
  final List<_SetEntry> _sets = [];
  final List<_SetEntry> _retiredSetEntries = [];

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
  bool _isClosing = false;
  double _userWeight = 70.0;

  // ── colour helpers ───────────────────────────────────────────────────────
  static const _green = Color(0xFF2E7D32);
  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF1A1A1A);

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
      if (w != null) {
        _nameC.text = w.name;
        _typeC.text = w.workoutType ?? '';
        _durationC.text = w.durationMinutes?.toString() ?? '';
        _caloriesC.text = w.caloriesBurned?.toString() ?? '';
        _notesC.text = w.notes ?? '';
        _pickedDate = w.workoutDate;
        _selectedExerciseName = w.name;
        // pre-fill one set row from existing values
        final entry = _SetEntry.fromValues(
          w.weight?.toString() ?? '',
          w.reps?.toString() ?? '',
        );
        setState(() => _sets.add(entry));
      } else {
        _sets.add(_SetEntry());
      }
    });
  }

  @override
  void dispose() {
    _pageC.dispose();
    _swTimer?.cancel();
    _restTimer?.cancel();
    if (!_isClosing) {
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
    setState(() => _sets[idx].isDone = !_sets[idx].isDone);
    if (_sets[idx].isDone) _startRestTimer();
    HapticFeedback.selectionClick();
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

  void _loadPreviousWorkout() {
    final prov = Provider.of<WorkoutProvider>(context, listen: false);
    final name = _selectedExerciseName ?? _nameC.text.trim();
    if (name.isEmpty) return;
    final matches =
        prov.workouts
            .where((w) => w.name.toLowerCase() == name.toLowerCase())
            .toList()
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu egzersiz için önceki kayıt bulunamadı.'),
          backgroundColor: Color(0xFF333333),
        ),
      );
      return;
    }
    final prev = matches.first;
    final previousEntries = List<_SetEntry>.from(_sets);
    final nextEntries = <_SetEntry>[];

    if (prev.setDetails != null && prev.setDetails!.isNotEmpty) {
      for (final sd in prev.setDetails!) {
        nextEntries.add(
          _SetEntry.fromValues(
            sd.weight?.toString() ?? '',
            sd.reps?.toString() ?? '',
            type: sd.setType,
          ),
        );
      }
    } else {
      nextEntries.add(
        _SetEntry.fromValues(
          prev.weight?.toString() ?? '',
          prev.reps?.toString() ?? '',
        ),
      );
      if ((prev.sets ?? 1) > 1) {
        for (int i = 1; i < (prev.sets ?? 1); i++) {
          nextEntries.add(
            _SetEntry.fromValues(
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
      _notesC.text = prev.notes ?? '';
    });
    _retiredSetEntries.addAll(previousEntries);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${DateFormat("d MMM", "tr_TR").format(prev.workoutDate)} tarihli kayıt yüklendi.',
        ),
        backgroundColor: _green,
      ),
    );
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
      _nameC.text = name;
      if (_selectedMuscleGroup != null) {
        _typeC.text =
            kMuscleGroupInfo[_selectedMuscleGroup]?.label ??
            _selectedMuscleGroup!;
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
      _isClosing = true;
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

    // Özet istatistikler
    final validSets = _sets
        .where((s) => s.repsC.text.trim().isNotEmpty)
        .toList();
    final totalSets = validSets.isEmpty ? 1 : validSets.length;
    final avgReps = validSets.isEmpty
        ? int.tryParse(_sets.first.repsC.text.trim())
        : (validSets.fold(
                    0,
                    (sum, s) => sum + (int.tryParse(s.repsC.text.trim()) ?? 0),
                  ) /
                  validSets.length)
              .round();
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

    // Set detayları listesi
    final setDetails = _sets.asMap().entries.map((e) {
      final i = e.key;
      final s = e.value;
      return WorkoutSet(
        setNumber: i + 1,
        setType: _dartSetTypeToApi(s.setType),
        reps: int.tryParse(s.repsC.text.trim()),
        weight: double.tryParse(s.weightC.text.trim().replaceAll(',', '.')),
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
    _previousPR = prov.personalRecords[workoutName];
    final isNewPR =
        oneRM != null && (_previousPR == null || oneRM > _previousPR!);

    final request = WorkoutRequest(
      name: workoutName.isEmpty ? 'Antrenman' : workoutName,
      workoutType: _typeC.text.trim().isEmpty ? null : _typeC.text.trim(),
      sets: totalSets,
      reps: avgReps,
      weight: maxWeight,
      durationMinutes: int.tryParse(_durationC.text.trim()),
      caloriesBurned: int.tryParse(_caloriesC.text.trim()),
      workoutDate: _pickedDate,
      notes: _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      setDetails: setDetails,
      muscleGroup: _selectedMuscleGroup,
      isSuperset: _isSuperset,
      supersetPartner: _isSuperset ? _supersetExerciseName : null,
      oneRepMax: oneRM,
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
      _isClosing = true;
      FocusManager.instance.primaryFocus?.unfocus();
      _swTimer?.cancel();
      _restTimer?.cancel();
      Navigator.of(context).pop(
        isNewPR
            ? '🏆 Kişisel Rekor! Başarıyla kaydedildi!'
            : 'Başarıyla kaydedildi',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(prov.errorMessage ?? 'Kaydedilemedi'),
        backgroundColor: Colors.redAccent,
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
    return Stack(
      children: [
        Scaffold(
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
        ),
      ],
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _prevStep,
      ),
      title: Text(
        widget.workout == null ? 'Antrenman Kaydet' : 'Antrenmanı Düzenle',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  // ── Step Indicator ───────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const labels = ['Egzersiz', 'Setler', 'Kaydet'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        decoration: BoxDecoration(
                          color: done || active
                              ? _accentColor
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? _accentColor
                                  : active
                                  ? _accentColor.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: active || done
                                    ? _accentColor
                                    : Colors.white.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                            child: done
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : active
                                ? Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: _accentColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            labels[i],
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : done
                                  ? _accentColor
                                  : Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (i < 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 16,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── STEP 1 — Exercise Picker ─────────────────────────────────────────────

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        // ── Muscle group chips ─────────────────────────────────────────────
        Text(
          'Kas Grubu Seç',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kMuscleGroupInfo.entries.map((entry) {
            final selected = _selectedMuscleGroup == entry.key;
            final info = entry.value;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMuscleGroup = selected ? null : entry.key;
                  _exerciseSearchQuery = '';
                  _exerciseSearchC.clear();
                  if (!selected) _selectedExerciseName = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? info.color.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? info.color
                        : Colors.white.withValues(alpha: 0.1),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      info.icon,
                      color: selected ? info.color : Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      info.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white60,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
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
                  onTap: () => setState(() => _selectedExerciseName = null),
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: _filteredExercises(_selectedMuscleGroup!).map((ex) {
                  final selected = _selectedExerciseName == ex.name;
                  final recentWeights = workoutProv.maxWeightsFor(
                    ex.name,
                    limit: 4,
                  );

                  return GestureDetector(
                    onTap: () {
                      final newSelected = selected ? null : ex.name;
                      setState(() {
                        _selectedExerciseName = newSelected;
                        _exerciseSearchC.text = newSelected ?? '';
                        _exerciseSearchQuery = newSelected ?? '';
                      });
                      if (newSelected != null && authProv.user?.id != null) {
                        workoutProv.loadExerciseHistory(
                          authProv.user!.id,
                          newSelected,
                        );
                        workoutProv.loadPersonalRecords(authProv.user!.id);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? _accentColor.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? _accentColor.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.fitness_center_rounded,
                                color: selected ? _accentColor : Colors.white24,
                                size: 16,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ex.name,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Geçmiş ağırlık trendi
                          if (recentWeights.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              children: recentWeights
                                  .map(
                                    (w) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _accentColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${w.toStringAsFixed(1)} kg',
                                        style: TextStyle(
                                          color: _accentColor,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
        if (_restActive) _buildRestTimerPanel(),

        // ── Set rows ───────────────────────────────────────────────────────
        Row(
          children: [
            const Text(
              'Setler',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Text(
              '${_sets.length} set',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

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
            child: _buildSetRow(idx, s),
          );
        }),

        const SizedBox(height: 8),
        // Set ekle butonu
        GestureDetector(
          onTap: () {
            final last = _sets.last;
            setState(() {
              _sets.add(
                _SetEntry.fromValues(last.weightC.text, last.repsC.text),
              );
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: _accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Set Ekle',
                  style: TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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

  Widget _buildSetRow(int idx, _SetEntry s) {
    final accent = _accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.isDone
            ? accent.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: s.isDone
              ? accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Set no + Set tipi chips + ✓ butonu
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: s.isDone ? accent : accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: s.isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Set tipi chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _kSetTypes.map((type) {
                      final sel = s.setType == type;
                      return GestureDetector(
                        onTap: () => setState(() => s.setType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? accent.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? accent
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.white38,
                              fontSize: 10,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // ✓ Tamamlandı butonu
              GestureDetector(
                onTap: () => _markSetDone(idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: s.isDone
                        ? accent
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.isDone ? 'Tamam ✓' : 'Tamam',
                    style: TextStyle(
                      color: s.isDone ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Ağırlık ve tekrar stepper'ları + kopyala butonu
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildStepper(
                      label: 'kg',
                      controller: s.weightC,
                      step: 2.5,
                      isDecimal: true,
                    ),
                    const SizedBox(height: 10),
                    _buildStepper(
                      label: 'tekrar',
                      controller: s.repsC,
                      step: 1,
                      isDecimal: false,
                    ),
                  ],
                ),
              ),
              // Copy-down button — sets values to next set
              if (idx < _sets.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: GestureDetector(
                    onTap: () {
                      final next = _sets[idx + 1];
                      setState(() {
                        next.weightC.text = s.weightC.text;
                        next.repsC.text = s.repsC.text;
                        next.setType = s.setType;
                      });
                    },
                    child: Tooltip(
                      message: 'Sonraki sete kopyala',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          color: _accentColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── +/- Stepper widget'ı ─────────────────────────────────────────────────

  Widget _buildStepper({
    required String label,
    required TextEditingController controller,
    required double step,
    required bool isDecimal,
  }) {
    void change(double delta) {
      if (!mounted || _isClosing) return;
      final raw = controller.text.trim().replaceAll(',', '.');
      final current = double.tryParse(raw) ?? 0.0;
      final next = (current + delta).clamp(0.0, 999.0);
      setState(() {
        controller.text = isDecimal
            ? (next % 1 == 0 ? next.toStringAsFixed(1) : next.toString())
            : next.toInt().toString();
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // − butonu (uzun bas -> hızlı)
              GestureDetector(
                onTap: () => change(-step),
                onLongPress: () {
                  Timer.periodic(const Duration(milliseconds: 120), (t) {
                    if (!mounted || _isClosing) {
                      t.cancel();
                      return;
                    }
                    change(-step);
                    if (t.tick > 20) t.cancel();
                  });
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white70,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Değer metin alanı
              IntrinsicWidth(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 40),
                  child: TextField(
                    controller: controller,
                    keyboardType: isDecimal
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // + butonu
              GestureDetector(
                onTap: () => change(step),
                onLongPress: () {
                  Timer.periodic(const Duration(milliseconds: 120), (t) {
                    if (!mounted || _isClosing) {
                      t.cancel();
                      return;
                    }
                    change(step);
                    if (t.tick > 20) t.cancel();
                  });
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, color: _accentColor, size: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dinlenme zamanlayıcısı paneli ────────────────────────────────────────

  Widget _buildRestTimerPanel() {
    final pct = _restSeconds > 0 ? _restRemaining / _restSeconds : 0.0;
    final mins = _restRemaining ~/ 60;
    final secs = _restRemaining % 60;
    final timeStr = mins > 0
        ? '$mins:${secs.toString().padLeft(2, '0')}'
        : '$secs sn';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Dinlenme Süresi',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _stopRestTimer,
                child: const Icon(Icons.close, color: Colors.white38, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(96, 96),
                    painter: _RestTimerPainter(
                      progress: pct,
                      color: _restRemaining < 10 ? Colors.redAccent : Colors.orange,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: _restRemaining < 10 ? Colors.redAccent : Colors.orange,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'dinlenme',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Süre seçenekleri
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [60, 90, 120, 180].map((sec) {
              final sel = _restSeconds == sec;
              return GestureDetector(
                onTap: () {
                  setState(() => _restSeconds = sec);
                  _startRestTimer();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? Colors.orange
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    sec < 60 ? '${sec}s' : '${sec ~/ 60}dk',
                    style: TextStyle(
                      color: sel ? Colors.orange : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Özet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nameC.text.isEmpty
                        ? (_selectedExerciseName ?? 'Egzersiz')
                        : _nameC.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _summaryChip(Icons.repeat_rounded, '${_sets.length} set'),
                      const SizedBox(width: 8),
                      _summaryChip(Icons.fitness_center_rounded, () {
                        final weights = _sets
                            .map(
                              (s) =>
                                  double.tryParse(
                                    s.weightC.text.trim().replaceAll(',', '.'),
                                  ) ??
                                  0.0,
                            )
                            .where((w) => w > 0);
                        if (weights.isEmpty) return 'Ağırlık yok';
                        return '${weights.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} kg max';
                      }()),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Antrenman Adı',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameC,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('Antrenman adı'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Antrenman adı zorunlu'
                  : null,
            ),

            const SizedBox(height: 14),
            Text(
              'Tür / Kas Grubu',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _typeC,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('örn. Göğüs, Bacak...'),
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Süre (dk)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _durationC,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('0'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kalori (kcal)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _caloriesC,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            // Date
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
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: _accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('d MMMM yyyy', 'tr_TR').format(_pickedDate),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(
              'Not',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesC,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('Antrenman notu...'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _accentColor, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: _accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLast = _step == 2;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            GestureDetector(
              onTap: _prevStep,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white54,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Geri',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              onTap: _saving ? null : (isLast ? _save : _nextStep),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accentColor,
                      _accentColor.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Kaydet' : 'Devam Et',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.save_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
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
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

// ── Rest timer circular arc painter ─────────────────────────────────────────

class _RestTimerPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RestTimerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 6.0;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    // Progress arc (sweeps clockwise from top)
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RestTimerPainter old) =>
      old.progress != progress || old.color != color;
}
