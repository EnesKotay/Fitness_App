part of '../workout_screen.dart';

class _CompletedSessionExercise {
  const _CompletedSessionExercise({
    required this.name,
    required this.plannedSets,
    required this.completedSets,
    required this.reps,
    required this.restSeconds,
    required this.setDetails,
    this.muscleGroup,
  });

  final String name;
  final int plannedSets;
  final int completedSets;
  final int reps;
  final int restSeconds;
  final List<WorkoutSet> setDetails;
  final String? muscleGroup;
}

class _CompletedSessionSummary {
  const _CompletedSessionSummary({
    required this.title,
    required this.exercises,
    required this.startedAt,
    required this.finishedAt,
  });

  factory _CompletedSessionSummary.fromPlans({
    required String title,
    required List<_SessionExercisePlan> plans,
    DateTime? startedAt,
    Set<String> completedSetKeys = const {},
    Map<String, _SessionSetSnapshot> setSnapshots = const {},
  }) {
    return _CompletedSessionSummary(
      title: title,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      exercises: plans.asMap().entries.map((entry) {
        final exerciseIndex = entry.key;
        final plan = entry.value;
        final completedSets = List.generate(
          plan.sets,
          (setIndex) => completedSetKeys.contains('$exerciseIndex-$setIndex'),
        ).where((done) => done).length;
        final details = List.generate(plan.sets, (setIndex) {
          final key = '$exerciseIndex-$setIndex';
          final snapshot = setSnapshots[key];
          return WorkoutSet(
            setNumber: setIndex + 1,
            setType: 'NORMAL',
            reps: snapshot?.reps ?? plan.reps,
            weight: snapshot?.weight,
            rpe: snapshot?.rpe,
          );
        });
        return _CompletedSessionExercise(
          name: plan.name,
          plannedSets: plan.sets,
          completedSets: completedSets,
          reps: details.isEmpty
              ? plan.reps
              : (details
                            .map((set) => set.reps ?? plan.reps)
                            .fold<int>(0, (a, b) => a + b) /
                        details.length)
                    .round(),
          restSeconds: plan.restSeconds,
          muscleGroup: plan.muscleGroup,
          setDetails: details,
        );
      }).toList(),
    );
  }

  final String title;
  final List<_CompletedSessionExercise> exercises;
  final DateTime? startedAt;
  final DateTime finishedAt;

  int get totalSetCount =>
      exercises.fold<int>(0, (sum, exercise) => sum + exercise.plannedSets);

  int get completedSetCount =>
      exercises.fold<int>(0, (sum, exercise) => sum + exercise.completedSets);
}

class _SessionSetSnapshot {
  const _SessionSetSnapshot({this.weight, this.reps, this.rpe});

  final double? weight;
  final int? reps;
  final double? rpe;
}

class _SessionSetInput {
  _SessionSetInput({required int reps})
    : weightC = TextEditingController(),
      repsC = TextEditingController(text: reps.toString()),
      rpeC = TextEditingController();

  final TextEditingController weightC;
  final TextEditingController repsC;
  final TextEditingController rpeC;

  _SessionSetSnapshot get snapshot => _SessionSetSnapshot(
    weight: double.tryParse(weightC.text.trim().replaceAll(',', '.')),
    reps: int.tryParse(repsC.text.trim()),
    rpe: double.tryParse(rpeC.text.trim().replaceAll(',', '.')),
  );

  Map<String, dynamic> toJson() => {
    'weight': weightC.text,
    'reps': repsC.text,
    'rpe': rpeC.text,
  };

  void applyJson(Map<String, dynamic> json) {
    weightC.text = json['weight']?.toString() ?? weightC.text;
    repsC.text = json['reps']?.toString() ?? repsC.text;
    rpeC.text = json['rpe']?.toString() ?? rpeC.text;
  }

  void dispose() {
    weightC.dispose();
    repsC.dispose();
    rpeC.dispose();
  }
}

class _ActiveWorkoutSessionSheet extends StatefulWidget {
  final String title;
  final List<_SessionExercisePlan> plans;
  final void Function(_CompletedSessionSummary summary) onFinish;

  const _ActiveWorkoutSessionSheet({
    required this.title,
    required this.plans,
    required this.onFinish,
  });

  @override
  State<_ActiveWorkoutSessionSheet> createState() =>
      _ActiveWorkoutSessionSheetState();
}

class _ActiveWorkoutSessionSheetState
    extends State<_ActiveWorkoutSessionSheet> {
  late final Set<String> _completedSets = <String>{};
  late final Map<String, _SessionSetInput> _setInputs;
  late final DateTime _startedAt;
  Timer? _restTimer;
  Timer? _sessionTimer;
  int _remaining = 0;
  int _sessionSeconds = 0;
  String _currentCoachCue = '';
  final List<String> _cues = [
    'Nefesini toparla. Sıradaki set formuna odaklan.',
    'Harika gidiyorsun! Core bölgesini sıkı tut.',
    'Acele etme, gücünü topla. Hareketi kontrollü yap.',
    'Zorlanırsan ağırlığı düşür, formu bozmak yok!',
    'Mükemmel set! Toparlanmak için derin nefes al.',
    'Kaslarını hisset, momentum kullanmadan kaldır.',
  ];

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _setInputs = {
      for (final entry in widget.plans.asMap().entries)
        for (var setIndex = 0; setIndex < entry.value.sets; setIndex++)
          '${entry.key}-$setIndex': _SessionSetInput(reps: entry.value.reps),
    };
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _sessionSeconds = DateTime.now().difference(_startedAt).inSeconds;
      });
    });
    _restoreDraft();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _sessionTimer?.cancel();
    for (final input in _setInputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  void _toggleSet(String key, int restSeconds) {
    setState(() {
      if (_completedSets.contains(key)) {
        _completedSets.remove(key);
      } else {
        _completedSets.add(key);
        _startRest(restSeconds);
      }
    });
    _saveDraft();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    _remaining = seconds;
    _currentCoachCue = _cues[DateTime.now().millisecond % _cues.length];
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _remaining = 0;
          timer.cancel();
        }
      });
    });
  }

  Map<String, _SessionSetSnapshot> _snapshots() => {
    for (final entry in _setInputs.entries) entry.key: entry.value.snapshot,
  };

  Future<void> _saveDraft() async {
    final payload = {
      'title': widget.title,
      'completed': _completedSets.toList(),
      'sets': _setInputs.map((key, value) => MapEntry(key, value.toJson())),
    };
    await StorageHelper.saveActiveWorkoutSessionDraft(jsonEncode(payload));
  }

  void _restoreDraft() {
    final raw = StorageHelper.getActiveWorkoutSessionDraft();
    if (raw == null || raw.isEmpty) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['title']?.toString() != widget.title) return;
      final completed = (json['completed'] as List<dynamic>? ?? const []).map(
        (item) => item.toString(),
      );
      _completedSets
        ..clear()
        ..addAll(completed);
      final sets = json['sets'] as Map<String, dynamic>? ?? const {};
      for (final entry in sets.entries) {
        final input = _setInputs[entry.key];
        final value = entry.value;
        if (input != null && value is Map<String, dynamic>) {
          input.applyJson(value);
        }
      }
    } catch (_) {}
  }

  Future<void> _finish() async {
    await StorageHelper.clearActiveWorkoutSessionDraft();
    widget.onFinish(
      _CompletedSessionSummary.fromPlans(
        title: widget.title,
        plans: widget.plans,
        startedAt: _startedAt,
        completedSetKeys: _completedSets,
        setSnapshots: _snapshots(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = widget.plans.fold<int>(0, (sum, plan) => sum + plan.sets);
    final progress = totalSets == 0 ? 0.0 : _completedSets.length / totalSets;
    final restM = (_remaining ~/ 60).toString().padLeft(2, '0');
    final restS = (_remaining % 60).toString().padLeft(2, '0');
    
    final sessionH = (_sessionSeconds ~/ 3600);
    final sessionM = ((_sessionSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final sessionS = (_sessionSeconds % 60).toString().padLeft(2, '0');
    final sessionTimeStr = sessionH > 0 ? '$sessionH:$sessionM:$sessionS' : '$sessionM:$sessionS';

    String? firstIncompleteKey;
    for (final entry in widget.plans.asMap().entries) {
      for (var i = 0; i < entry.value.sets; i++) {
        final k = '${entry.key}-$i';
        if (!_completedSets.contains(k)) {
          firstIncompleteKey = k;
          break;
        }
      }
      if (firstIncompleteKey != null) break;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        sessionTimeStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_remaining > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFF66BB6A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Dinlenme: ', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              Text(
                                '$restM:$restS',
                                style: const TextStyle(
                                  color: Color(0xFF66BB6A),
                                  fontSize: 22,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.psychology, color: Colors.cyanAccent, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Koç: $_currentCoachCue',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_completedSets.length}/$totalSets set tamamlandı',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.plans.asMap().entries.map((entry) {
              final exerciseIndex = entry.key;
              final plan = entry.value;
              final color =
                  kMuscleGroupInfo[plan.muscleGroup]?.color ??
                  const Color(0xFF66BB6A);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        // Isınma Butonu
                        GestureDetector(
                          onTap: () {
                            final wStr = _setInputs['$exerciseIndex-0']?.weightC.text.replaceAll(',', '.') ?? '0';
                            final rStr = _setInputs['$exerciseIndex-0']?.repsC.text ?? '0';
                            final w = double.tryParse(wStr) ?? 0;
                            final r = int.tryParse(rStr) ?? 0;
                            final max = ProgressionEngine.calculate1RM(w, r);
                            if (max > 0) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Isınma eklendi! 1RM: ${max.toStringAsFixed(1)} kg'), backgroundColor: Colors.amber));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İlk sete tahmini bir ağırlık girin.'), backgroundColor: Colors.orange));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department, color: Colors.amber, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Isınma',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Superset Butonu
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Süperset bağlandı!'), backgroundColor: Colors.purpleAccent));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, color: Colors.purpleAccent, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Süperset',
                                  style: TextStyle(
                                    color: Colors.purpleAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // AI Banner
                    Builder(
                      builder: (context) {
                        final provider = context.watch<WorkoutProvider>();
                        final hint = ProgressionEngine.compute(
                          history: provider.workouts,
                          exerciseName: plan.name,
                          targetReps: plan.reps,
                        );
                        if (hint.suggestedWeight > 0) {
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blueAccent.withValues(alpha: 0.2), Colors.purpleAccent.withValues(alpha: 0.1)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.psychology, color: Colors.cyanAccent, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'AI Önerisi: ${hint.weightLabel} x ${hint.suggestedReps} ${hint.trendEmoji} — ${hint.reason}',
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(plan.sets, (setIndex) {
                        final key = '$exerciseIndex-$setIndex';
                        final done = _completedSets.contains(key);
                        final isActive = key == firstIncompleteKey;
                        final input = _setInputs[key]!;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: done
                                ? color.withValues(alpha: 0.16)
                                : isActive 
                                    ? color.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: done
                                  ? color.withValues(alpha: 0.45)
                                  : isActive
                                      ? color
                                      : Colors.white.withValues(alpha: 0.08),
                              width: isActive ? 2.0 : 1.0,
                            ),
                            boxShadow: isActive ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _toggleSet(key, plan.restSeconds),
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    done
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: done ? color : Colors.white38,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 42,
                                child: Text(
                                  '${setIndex + 1}. set',
                                  style: TextStyle(
                                    color: done ? Colors.white : Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _miniInput(
                                  controller: input.weightC,
                                  label: 'kg',
                                  onChanged: (_) => _saveDraft(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _miniInput(
                                  controller: input.repsC,
                                  label: 'rep',
                                  onChanged: (_) => _saveDraft(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _miniInput(
                                  controller: input.rpeC,
                                  label: 'RPE',
                                  onChanged: (_) => _saveDraft(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.save_rounded, color: Colors.white),
                label: const Text(
                  'Seansı Kaydet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInput({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.38),
          fontSize: 10,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(9)),
          borderSide: BorderSide(color: Color(0xFF66BB6A)),
        ),
      ),
    );
  }
}
