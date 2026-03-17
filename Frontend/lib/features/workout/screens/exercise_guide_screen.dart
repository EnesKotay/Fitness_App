import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/exercise.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../models/exercise_guide_data.dart';
import '../providers/workout_provider.dart';

class ExerciseGuideScreen extends StatefulWidget {
  final Exercise exercise;
  final Color accentColor;
  final String? muscleGroupLabel;

  const ExerciseGuideScreen({
    super.key,
    required this.exercise,
    required this.accentColor,
    this.muscleGroupLabel,
  });

  @override
  State<ExerciseGuideScreen> createState() => _ExerciseGuideScreenState();
}

class _ExerciseGuideScreenState extends State<ExerciseGuideScreen> {
  late final ExerciseGuideData _guide;
  late String _selectedGoalKey;
  late Map<String, bool> _checkStates;

  @override
  void initState() {
    super.initState();
    _guide = buildExerciseGuideData(widget.exercise);
    _selectedGoalKey = 'beginner';
    _checkStates = {for (final item in _guide.checklist) item.title: false};
  }

  Future<void> _openYouTube() async {
    final query = Uri.encodeComponent('${widget.exercise.name} nasıl yapılır egzersiz');
    final uri = Uri.parse('https://www.youtube.com/results?search_query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildYouTubeButton() {
    return GestureDetector(
      onTap: _openYouTube,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF0000).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF0000).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_rounded, color: Color(0xFFFF4444), size: 18),
            const SizedBox(width: 8),
            Text(
              'YouTube\'da İzle — ${widget.exercise.name}',
              style: const TextStyle(
                color: Color(0xFFFF6666),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, color: const Color(0xFFFF4444).withValues(alpha: 0.7), size: 14),
          ],
        ),
      ),
    );
  }

  String _muscleGroupLabel() {
    if (widget.muscleGroupLabel != null &&
        widget.muscleGroupLabel!.trim().isNotEmpty) {
      return widget.muscleGroupLabel!;
    }

    switch (widget.exercise.muscleGroup.trim().toUpperCase()) {
      case 'CHEST':
        return 'Gogus';
      case 'BACK':
        return 'Sirt';
      case 'LEGS':
        return 'Bacak';
      case 'SHOULDERS':
        return 'Omuz';
      case 'BICEPS':
        return 'Biseps';
      case 'TRICEPS':
        return 'Triseps';
      case 'CORE':
        return 'Karin';
      case 'GLUTES':
        return 'Kalca';
      default:
        return widget.exercise.muscleGroup;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _guide.goalPlans[_selectedGoalKey]!;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: 56,
                right: 20,
                bottom: 18,
              ),
              title: Text(
                widget.exercise.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
                maxLines: 2,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.accentColor.withValues(alpha: 0.45),
                          widget.accentColor.withValues(alpha: 0.12),
                          const Color(0xFF0A0A0A),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        size: 44,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0A0A0A)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetaChip(
                      icon: Icons.grid_view_rounded,
                      label: _muscleGroupLabel(),
                      color: widget.accentColor,
                    ),
                    _MetaChip(
                      icon: Icons.speed_rounded,
                      label: _guide.tempo,
                      color: widget.accentColor,
                    ),
                    _MetaChip(
                      icon: Icons.my_location_rounded,
                      label: _guide.targetMuscles.join(' • '),
                      color: widget.accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildYouTubeButton(),
                const SizedBox(height: 18),
                _buildVisualFlow(),
                const SizedBox(height: 28),
                _SectionTitle(label: 'Kurulum', color: widget.accentColor),
                const SizedBox(height: 14),
                _InfoCard(
                  color: widget.accentColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_guide.setup, style: _bodyStyle()),
                      const SizedBox(height: 12),
                      _InlineFact(
                        label: 'Nefes',
                        value: _guide.breathing,
                        color: widget.accentColor,
                      ),
                      const SizedBox(height: 10),
                      _InlineFact(
                        label: 'Tempo',
                        value: _guide.tempo,
                        color: widget.accentColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                  label: 'Nasıl Yapılır',
                  color: widget.accentColor,
                ),
                const SizedBox(height: 14),
                ..._guide.executionSteps.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StepCard(
                      index: entry.key + 1,
                      text: entry.value,
                      color: widget.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                  label: 'Hedefe Göre Uygula',
                  color: widget.accentColor,
                ),
                const SizedBox(height: 12),
                _buildGoalSelector(),
                const SizedBox(height: 12),
                _InfoCard(
                  color: widget.accentColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.title, style: _titleStyle()),
                      const SizedBox(height: 8),
                      Text(
                        plan.prescription,
                        style: _bodyStyle(weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(plan.focus, style: _bodyStyle()),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                  label: 'Sık Yapılan Hatalar',
                  color: Colors.amber,
                ),
                const SizedBox(height: 14),
                ..._guide.commonMistakes.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _IssueCard(issue: issue, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _SenseCard(
                        title: 'Hissetmen gereken',
                        icon: Icons.favorite_rounded,
                        color: widget.accentColor,
                        items: _guide.normalFeel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SenseCard(
                        title: 'Durman gereken sinyal',
                        icon: Icons.health_and_safety_rounded,
                        color: Colors.redAccent,
                        items: _guide.stopSignals,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SectionTitle(label: 'Varyasyonlar', color: widget.accentColor),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _VariantCard(
                        variant: _guide.regression,
                        icon: Icons.trending_down_rounded,
                        color: const Color(0xFF26A69A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _VariantCard(
                        variant: _guide.progression,
                        icon: Icons.trending_up_rounded,
                        color: widget.accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                  label: 'Set Öncesi Kontrol',
                  color: widget.accentColor,
                ),
                const SizedBox(height: 14),
                _InfoCard(
                  color: widget.accentColor,
                  child: Column(
                    children: _guide.checklist.map((item) {
                      final value = _checkStates[item.title] ?? false;
                      return CheckboxListTile(
                        value: value,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: widget.accentColor,
                        checkColor: Colors.white,
                        title: Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          item.detail,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        onChanged: (next) {
                          setState(() {
                            _checkStates[item.title] = next ?? false;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openCoachMode,
                      icon: Icon(
                        Icons.headset_mic_rounded,
                        color: widget.accentColor,
                      ),
                      label: const Text(
                        'Koç Modu',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: widget.accentColor.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final userId = authProvider.user?.id;
                        return ElevatedButton.icon(
                          onPressed: userId == null
                              ? null
                              : () async {
                                  await _showAddToWorkoutSheet(context, userId);
                                },
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Antrenmana ekle',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _onComplete,
                  icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                  label: const Text(
                    'GÖSTERİMİ TAMAMLADIM',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualFlow() {
    return _InfoCard(
      color: widget.accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.animation_rounded, color: widget.accentColor),
              const SizedBox(width: 8),
              const Text(
                'Poz Akışı',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _guide.frames.asMap().entries.map((entry) {
                final frame = entry.value;
                final isLast = entry.key == _guide.frames.length - 1;
                return Container(
                  width: 150,
                  margin: EdgeInsets.only(right: isLast ? 0 : 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.accentColor.withValues(alpha: 0.2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        frame.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        frame.cue,
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        frame.detail,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.35,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _guide.goalPlans.entries.map((entry) {
        final selected = _selectedGoalKey == entry.key;
        return ChoiceChip(
          label: Text(entry.value.title),
          selected: selected,
          showCheckmark: false,
          selectedColor: widget.accentColor,
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          side: BorderSide(
            color: selected
                ? widget.accentColor
                : Colors.white.withValues(alpha: 0.14),
          ),
          labelStyle: TextStyle(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.72),
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() {
              _selectedGoalKey = entry.key;
            });
          },
        );
      }).toList(),
    );
  }

  TextStyle _bodyStyle({FontWeight weight = FontWeight.w500}) {
    return TextStyle(
      color: Colors.white.withValues(alpha: 0.82),
      fontSize: 14.5,
      height: 1.55,
      fontWeight: weight,
    );
  }

  TextStyle _titleStyle() {
    return const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );
  }

  void _openCoachMode() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _CoachModeSheet(
          prompts: _guide.coachPrompts,
          accentColor: widget.accentColor,
        );
      },
    );
  }

  void _onComplete() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(
        content: const Text(
          'Hareket gosterimi tamamlandi. Dilersen siradaki egzersize gecebilirsin.',
        ),
        backgroundColor: widget.accentColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAddToWorkoutSheet(BuildContext context, int userId) async {
    final formKey = GlobalKey<FormState>();
    final typeC = TextEditingController(
      text: widget.muscleGroupLabel ?? widget.exercise.muscleGroup,
    );
    final notesC = TextEditingController();
    final setsC = TextEditingController();
    final repsC = TextEditingController();
    final weightC = TextEditingController();
    DateTime pickedDate = DateTime.now();

    // State yönetimi için değişkenler
    int sets = 3;
    int reps = 10;
    double weight = 0.0;
    bool saving = false;

    final accent = widget.accentColor;

    // ── Provider'ları builder dışında al — _dependents.isEmpty hatasını önler
    final dietProvider = Provider.of<DietProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    final userWeight = dietProvider.profile?.weight ?? 70.0;
    final initialRecommendation = _buildWeightRecommendation(
      workoutProvider,
      userWeight,
      reps,
    );

    // İlk değeri ata (builder öncesi)
    weight = initialRecommendation.suggestedKg;
    setsC.text = '$sets';
    repsC.text = '$reps';
    weightC.text = weight % 1 == 0
        ? weight.toStringAsFixed(0)
        : weight.toStringAsFixed(1);

    final result = await showModalBottomSheet<_AddWorkoutSheetResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final recommendation = _buildWeightRecommendation(
                workoutProvider,
                userWeight,
                reps,
              );

              // +/- değişiklik yardımcısı
              void changeVal(String field, double delta) {
                setSheetState(() {
                  if (field == 'sets') {
                    sets = (sets + delta.toInt()).clamp(1, 20);
                    setsC.text = '$sets';
                  }
                  if (field == 'reps') {
                    reps = (reps + delta.toInt()).clamp(1, 50);
                    repsC.text = '$reps';
                  }
                  if (field == 'weight') {
                    weight = (weight + delta).clamp(0.0, 500.0);
                    weightC.text = weight % 1 == 0
                        ? weight.toStringAsFixed(0)
                        : weight.toStringAsFixed(1);
                  }
                });
              }

              Widget stepper({
                required String label,
                required String unit,
                required TextEditingController controller,
                required TextInputType keyboardType,
                required List<TextInputFormatter> inputFormatters,
                required ValueChanged<String> onChanged,
                required VoidCallback onMinus,
                required VoidCallback onPlus,
              }) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: onMinus,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: controller,
                                  keyboardType: keyboardType,
                                  inputFormatters: inputFormatters,
                                  textAlign: TextAlign.center,
                                  onChanged: onChanged,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  unit,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: onPlus,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.add, color: accent, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF151515),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Gradient header ──────────────────────────────
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accent.withValues(alpha: 0.30),
                                  accent.withValues(alpha: 0.06),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sürükleme tutacağı
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 18),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.fitness_center_rounded,
                                        color: accent,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.exercise.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: accent.withValues(
                                                alpha: 0.18,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              widget.muscleGroupLabel ??
                                                  widget.exercise.muscleGroup,
                                              style: TextStyle(
                                                color: accent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Önerilen ağırlık banner'ı ─────────────
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.amber.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.lightbulb_outline_rounded,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        recommendation.headline,
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => setSheetState(() {
                                          weight = recommendation.suggestedKg;
                                          weightC.text =
                                              recommendation.suggestedKg % 1 ==
                                                  0
                                              ? recommendation.suggestedKg
                                                    .toStringAsFixed(0)
                                              : recommendation.suggestedKg
                                                    .toStringAsFixed(1);
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Text(
                                            'Uygula',
                                            style: TextStyle(
                                              color: Colors.amber,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...recommendation.details.map(
                                  (detail) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: Colors.amber,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            detail,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.72,
                                              ),
                                              fontSize: 12.5,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // ── Hızlı preset chipsleri ────────────────
                                const Text(
                                  'Hızlı Preset',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    for (final preset in [
                                      {'label': '3×8', 'sets': 3, 'reps': 8},
                                      {'label': '4×10', 'sets': 4, 'reps': 10},
                                      {'label': '5×5', 'sets': 5, 'reps': 5},
                                      {'label': '3×12', 'sets': 3, 'reps': 12},
                                    ]) ...[
                                      GestureDetector(
                                        onTap: () => setSheetState(() {
                                          sets = preset['sets'] as int;
                                          reps = preset['reps'] as int;
                                          setsC.text = '$sets';
                                          repsC.text = '$reps';
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (sets == preset['sets'] &&
                                                    reps == preset['reps'])
                                                ? accent.withValues(alpha: 0.25)
                                                : Colors.white.withValues(
                                                    alpha: 0.06,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (sets == preset['sets'] &&
                                                      reps == preset['reps'])
                                                  ? accent
                                                  : Colors.white.withValues(
                                                      alpha: 0.12,
                                                    ),
                                            ),
                                          ),
                                          child: Text(
                                            preset['label'] as String,
                                            style: TextStyle(
                                              color:
                                                  (sets == preset['sets'] &&
                                                      reps == preset['reps'])
                                                  ? Colors.white
                                                  : Colors.white54,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // ── Set / Tekrar / Ağırlık stepperları ─────
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: stepper(
                                            label: 'SET',
                                            unit: 'kez',
                                            controller: setsC,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            onChanged: (value) {
                                              final parsed = int.tryParse(
                                                value,
                                              );
                                              if (parsed == null) return;
                                              setSheetState(() {
                                                sets = parsed.clamp(1, 20);
                                              });
                                            },
                                            onMinus: () =>
                                                changeVal('sets', -1),
                                            onPlus: () => changeVal('sets', 1),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: stepper(
                                            label: 'TEKRAR',
                                            unit: 'rep',
                                            controller: repsC,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            onChanged: (value) {
                                              final parsed = int.tryParse(
                                                value,
                                              );
                                              if (parsed == null) return;
                                              setSheetState(() {
                                                reps = parsed.clamp(1, 50);
                                              });
                                            },
                                            onMinus: () =>
                                                changeVal('reps', -1),
                                            onPlus: () => changeVal('reps', 1),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    stepper(
                                      label: 'AĞIRLIK',
                                      unit: 'kg',
                                      controller: weightC,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d*([.,]\d{0,2})?$'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        final parsed = double.tryParse(
                                          value.replaceAll(',', '.'),
                                        );
                                        if (parsed == null) return;
                                        setSheetState(() {
                                          weight = parsed.clamp(0.0, 500.0);
                                        });
                                      },
                                      onMinus: () => changeVal('weight', -2.5),
                                      onPlus: () => changeVal('weight', 2.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // ── Tarih seçici ──────────────────────────
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: pickedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                      builder: (dCtx, child) => Theme(
                                        data: Theme.of(dCtx).copyWith(
                                          colorScheme: ColorScheme.dark(
                                            primary: accent,
                                            onPrimary: Colors.white,
                                            surface: const Color(0xFF1F1F1F),
                                            onSurface: Colors.white,
                                          ),
                                        ),
                                        child: child!,
                                      ),
                                    );
                                    if (picked != null) {
                                      setSheetState(() => pickedDate = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.09,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          color: accent,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          DateFormat(
                                            'd MMMM yyyy',
                                            'tr_TR',
                                          ).format(pickedDate),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.white38,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // ── Not alanı (opsiyonel, hint ile) ───────
                                TextField(
                                  controller: notesC,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Not ekle (isteğe bağlı)...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(
                                      alpha: 0.04,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.09,
                                        ),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.09,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: accent,
                                        width: 1.4,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),

                                // ── Kaydet butonu ─────────────────────────
                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: saving
                                        ? null
                                        : () async {
                                            if (!formKey.currentState!
                                                .validate())
                                              return;
                                            setSheetState(() => saving = true);

                                            final calories = _estimateCalories(
                                              sets,
                                              reps,
                                              weight,
                                              userWeight,
                                            );

                                            final request = WorkoutRequest(
                                              name: widget.exercise.name,
                                              workoutType:
                                                  typeC.text.trim().isEmpty
                                                  ? null
                                                  : typeC.text.trim(),
                                              caloriesBurned: calories,
                                              sets: sets,
                                              reps: reps,
                                              weight: weight > 0
                                                  ? weight
                                                  : null,
                                              workoutDate: pickedDate,
                                              notes: notesC.text.trim().isEmpty
                                                  ? null
                                                  : notesC.text.trim(),
                                              muscleGroup:
                                                  widget.exercise.muscleGroup,
                                            );

                                            final ok = await workoutProvider
                                                .createWorkout(userId, request);

                                            if (!ctx.mounted) return;
                                            Navigator.pop(
                                              ctx,
                                              _AddWorkoutSheetResult(
                                                ok
                                                    ? 'Antrenmana eklendi!'
                                                    : (workoutProvider
                                                              .errorMessage ??
                                                          'Kaydedilemedi'),
                                                ok
                                                    ? const Color(0xFF2E7D32)
                                                    : Colors.redAccent,
                                              ),
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      disabledBackgroundColor: accent
                                          .withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: saving
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.add_circle_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Antrenmana Ekle • '
                                                '$sets×$reps'
                                                '${weight > 0 ? " @ ${weight % 1 == 0 ? weight.toInt() : weight} kg" : ""}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

    if (!mounted || result == null) return;

    messenger?.showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int? _estimateCalories(
    int? sets,
    int? reps,
    double? weight,
    double userWeight,
  ) {
    if (sets == null || reps == null || sets <= 0 || reps <= 0) return null;
    final effectiveWeight = weight != null && weight > 0
        ? weight
        : userWeight * 0.35;
    return (sets * reps * effectiveWeight * 0.05).round();
  }

  _WeightRecommendation _buildWeightRecommendation(
    WorkoutProvider provider,
    double userWeight,
    int targetReps,
  ) {
    final name = widget.exercise.name.trim();
    final group = widget.exercise.muscleGroup.trim().toUpperCase();
    final category = _movementCategory(name);
    final exactMatches =
        provider.workouts
            .where((w) => w.name.toLowerCase() == name.toLowerCase())
            .toList()
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));

    final exactWeights = exactMatches
        .map(_extractReferenceWeight)
        .whereType<double>()
        .where((w) => w > 0)
        .take(3)
        .toList();
    final exactReps = exactMatches
        .map((w) => w.reps)
        .whereType<int>()
        .where((r) => r > 0)
        .take(3)
        .toList();

    final similarMatches = provider.workouts.where((w) {
      final sameGroup = (w.muscleGroup ?? '').trim().toUpperCase() == group;
      return sameGroup && _movementCategory(w.name) == category;
    }).toList()..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));

    final similarWeights = similarMatches
        .map(_extractReferenceWeight)
        .whereType<double>()
        .where((w) => w > 0)
        .take(4)
        .toList();

    final baseline = _baselineWeight(userWeight, group, category);
    final pr = provider.personalRecords[name];

    if (category == _MovementCategory.bodyweight) {
      return const _WeightRecommendation(
        suggestedKg: 0,
        headline: 'Bu hareketi önce vücut ağırlığıyla başla',
        details: [
          'Bu hareket temel olarak vücut ağırlığıyla uygulanır.',
          'Form oturduğunda destek veya ek yük eklenebilir.',
        ],
      );
    }

    if (exactWeights.isNotEmpty) {
      final median = _median(exactWeights);
      final recentReps = exactReps.isEmpty
          ? targetReps.toDouble()
          : exactReps.reduce((a, b) => a + b) / exactReps.length;
      final adjusted = _adjustForTargetReps(
        median,
        targetReps: targetReps,
        referenceReps: recentReps,
      );
      final bounded = pr == null
          ? adjusted
          : adjusted.clamp(pr * 0.55, pr * 0.9).toDouble();
      return _WeightRecommendation(
        suggestedKg: _roundToIncrement(bounded, 2.5),
        headline:
            'Sana önerilen başlangıç: ${_formatKg(_roundToIncrement(bounded, 2.5))}',
        details: [
          'Aynı hareketin son ${exactWeights.length} kaydı baz alındı.',
          'Hedef tekrarın $targetReps olduğu için ağırlık buna göre ayarlandı.',
          if (pr != null)
            'Kişisel rekorun ${_formatKg(pr)} olduğu için güvenli aralık korundu.',
        ],
      );
    }

    if (similarWeights.isNotEmpty) {
      final median = _median(similarWeights);
      final equipmentAdjusted = switch (category) {
        _MovementCategory.machine => median * 0.9,
        _MovementCategory.cable => median * 0.85,
        _MovementCategory.dumbbell => median * 0.8,
        _MovementCategory.barbell => median * 0.78,
        _MovementCategory.isolation => median * 0.82,
        _MovementCategory.compound => median * 0.75,
        _MovementCategory.bodyweight => 0.0,
      };
      final suggestion = _roundToIncrement(
        equipmentAdjusted.clamp(baseline * 0.85, baseline * 1.25).toDouble(),
        2.5,
      );
      return _WeightRecommendation(
        suggestedKg: suggestion,
        headline: 'Sana önerilen başlangıç: ${_formatKg(suggestion)}',
        details: [
          'Benzer $group hareketlerindeki son antrenmanların baz alındı.',
          'Hareket tipi $category için daha güvenli başlangıç katsayısı uygulandı.',
          'Profil kilon (${userWeight.toStringAsFixed(0)} kg) ile alt sınır dengelendi.',
        ],
      );
    }

    final fallback = _roundToIncrement(baseline, 2.5);
    return _WeightRecommendation(
      suggestedKg: fallback,
      headline: 'Sana önerilen başlangıç: ${_formatKg(fallback)}',
      details: [
        'Bu hareket için kayıt geçmişin bulunamadı.',
        'Profil kilon ve hareket tipi baz alınarak güvenli bir başlangıç önerildi.',
        'İlk sette formuna göre yukarı veya aşağı ayarlayabilirsin.',
      ],
    );
  }

  double _baselineWeight(
    double userWeight,
    String group,
    _MovementCategory category,
  ) {
    final groupFactor = switch (group) {
      'LEGS' => 0.45,
      'GLUTES' => 0.42,
      'CHEST' => 0.35,
      'BACK' => 0.35,
      'SHOULDERS' => 0.16,
      'BICEPS' => 0.1,
      'TRICEPS' => 0.1,
      _ => 0.2,
    };
    final typeFactor = switch (category) {
      _MovementCategory.barbell => 1.0,
      _MovementCategory.machine => 0.95,
      _MovementCategory.cable => 0.8,
      _MovementCategory.dumbbell => 0.7,
      _MovementCategory.isolation => 0.55,
      _MovementCategory.compound => 0.9,
      _MovementCategory.bodyweight => 0.0,
    };
    return userWeight * groupFactor * typeFactor;
  }

  double? _extractReferenceWeight(Workout workout) {
    if (workout.setDetails != null && workout.setDetails!.isNotEmpty) {
      final weights = workout.setDetails!
          .map((s) => s.weight)
          .whereType<double>()
          .where((w) => w > 0)
          .toList();
      if (weights.isNotEmpty) {
        return weights.reduce((a, b) => a > b ? a : b);
      }
    }
    return workout.weight;
  }

  double _adjustForTargetReps(
    double weight, {
    required int targetReps,
    required double referenceReps,
  }) {
    final diff = targetReps - referenceReps;
    if (diff.abs() < 1) return weight;
    final adjustment = (diff / 2) * 0.035;
    final factor = (1 - adjustment).clamp(0.82, 1.15);
    return weight * factor;
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _roundToIncrement(double value, double increment) {
    if (value <= 0) return 0;
    return (value / increment).round() * increment;
  }

  String _formatKg(double value) {
    return value % 1 == 0
        ? '${value.toStringAsFixed(0)} kg'
        : '${value.toStringAsFixed(1)} kg';
  }

  _MovementCategory _movementCategory(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (_containsAnyToken(name, const [
      'push-up',
      'push up',
      'pull-up',
      'pull up',
      'plank',
      'crunch',
      'sit-up',
      'sit up',
    ])) {
      return _MovementCategory.bodyweight;
    }
    if (_containsAnyToken(name, const [
      'machine',
      'press machine',
      'pec deck',
    ])) {
      return _MovementCategory.machine;
    }
    if (_containsAnyToken(name, const [
      'cable',
      'pushdown',
      'crossover',
      'pulldown',
    ])) {
      return _MovementCategory.cable;
    }
    if (_containsAnyToken(name, const ['dumbbell', 'db '])) {
      return _MovementCategory.dumbbell;
    }
    if (_containsAnyToken(name, const [
      'barbell',
      'bench press',
      'squat',
      'deadlift',
      'row',
    ])) {
      return _MovementCategory.barbell;
    }
    if (_containsAnyToken(name, const [
      'curl',
      'extension',
      'raise',
      'fly',
      'kickback',
    ])) {
      return _MovementCategory.isolation;
    }
    return _MovementCategory.compound;
  }

  bool _containsAnyToken(String text, List<String> tokens) {
    return tokens.any(text.contains);
  }
}

class _WeightRecommendation {
  final double suggestedKg;
  final String headline;
  final List<String> details;

  const _WeightRecommendation({
    required this.suggestedKg,
    required this.headline,
    required this.details,
  });
}

class _AddWorkoutSheetResult {
  final String message;
  final Color backgroundColor;

  const _AddWorkoutSheetResult(this.message, this.backgroundColor);
}

enum _MovementCategory {
  bodyweight,
  machine,
  cable,
  dumbbell,
  barbell,
  isolation,
  compound,
}

class _CoachModeSheet extends StatefulWidget {
  final List<String> prompts;
  final Color accentColor;

  const _CoachModeSheet({required this.prompts, required this.accentColor});

  @override
  State<_CoachModeSheet> createState() => _CoachModeSheetState();
}

class _CoachModeSheetState extends State<_CoachModeSheet> {
  int _index = 0;
  bool _autoPlay = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleAutoPlay() {
    setState(() {
      _autoPlay = !_autoPlay;
    });
    if (_autoPlay) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        if (_index >= widget.prompts.length - 1) {
          _timer?.cancel();
          setState(() => _autoPlay = false);
          return;
        }
        setState(() => _index += 1);
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.headset_mic_rounded, color: widget.accentColor),
                const SizedBox(width: 8),
                const Text(
                  'Koç Modu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _toggleAutoPlay,
                  child: Text(
                    _autoPlay ? 'Duraklat' : 'Otomatik ilerlet',
                    style: TextStyle(color: widget.accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Adım ${_index + 1} / ${widget.prompts.length}',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      widget.prompts[_index],
                      key: ValueKey(_index),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _index == 0
                        ? null
                        : () => setState(() => _index -= 1),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Text(
                      'Geri',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _index == widget.prompts.length - 1
                        ? null
                        : () => setState(() => _index += 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                    ),
                    child: const Text(
                      'İleri',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Color color;
  final Widget child;

  const _InfoCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: child,
    );
  }
}

class _InlineFact extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InlineFact({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final String text;
  final Color color;

  const _StepCard({
    required this.index,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.18),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  final ExerciseGuideIssue issue;
  final Color color;

  const _IssueCard({required this.issue, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sorun: ${issue.issue}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Düzeltme: ${issue.fix}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SenseCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _SenseCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  final ExerciseGuideVariant variant;
  final IconData icon;
  final Color color;

  const _VariantCard({
    required this.variant,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            variant.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            variant.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
