import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../nutrition/presentation/state/diet_provider.dart';
import '../../nutrition/domain/entities/meal_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../../core/models/workout_models.dart';

// ─── Typing Indicator ─────────────────────────────────────────────────────────

/// Animated "AI is thinking..." indicator shown while waiting for a response.
class AiTypingIndicator extends StatefulWidget {
  const AiTypingIndicator({super.key});

  @override
  State<AiTypingIndicator> createState() => _AiTypingIndicatorState();
}

class _AiTypingIndicatorState extends State<AiTypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _dotControllers;

  @override
  void initState() {
    super.initState();
    _dotControllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _dotControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFEBC374), Color(0xFFC88934)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEBC374).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.9, end: 1.05, duration: 1800.ms, curve: Curves.easeInOut),
          const SizedBox(width: 10),
          // Bubble with dots
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF141E30), Color(0xFF0F1822)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: const Color(0xFFEBC374).withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Analiz ediliyor',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: _dotControllers[i],
                      builder: (context, _) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 6,
                          height: 6 + (_dotControllers[i].value * 6),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              const Color(0xFFEBC374).withValues(alpha: 0.3),
                              const Color(0xFFEBC374),
                              _dotControllers[i].value,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
}

// ─── Smart Meal Log Card ─────────────────────────────────────────────────────

/// When the AI suggests a food to log (ADD_FOOD action), this beautiful inline
/// card appears inside the chat bubble allowing one-tap logging.
class SmartMealLogCard extends StatefulWidget {
  final String actionData; // JSON string with name, kcal, protein, carbs, fat, mealType
  final VoidCallback? onLogged;

  const SmartMealLogCard({
    super.key,
    required this.actionData,
    this.onLogged,
  });

  @override
  State<SmartMealLogCard> createState() => _SmartMealLogCardState();
}

class _SmartMealLogCardState extends State<SmartMealLogCard> {
  bool _logged = false;
  bool _loading = false;

  late Map<String, dynamic> _data;
  bool _parsed = false;

  @override
  void initState() {
    super.initState();
    try {
      _data = jsonDecode(widget.actionData) as Map<String, dynamic>;
      _parsed = true;
    } catch (_) {
      _parsed = false;
      _data = {};
    }
  }

  Future<void> _logMeal(BuildContext context) async {
    if (_loading || _logged || !_parsed) return;
    setState(() => _loading = true);

    try {
      final diet = context.read<DietProvider>();
      final name = _data['name']?.toString() ?? 'Yemek';
      final kcal = (_data['kcal'] as num?)?.toDouble() ?? 0;
      final protein = (_data['protein'] as num?)?.toDouble() ?? 0;
      final carbs = (_data['carbs'] as num?)?.toDouble() ?? 0;
      final fat = (_data['fat'] as num?)?.toDouble() ?? 0;
      final mealTypeStr = _data['mealType']?.toString() ?? 'snack';

      final mealType = MealType.values.firstWhere(
        (m) => m.name == mealTypeStr,
        orElse: () => MealType.snack,
      );

      await diet.addAiMealToDiary(
        mealName: name,
        kcal: kcal,
        protein: protein,
        carbs: carbs,
        fat: fat,
        mealType: mealType,
        date: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _logged = true;
          _loading = false;
        });
        widget.onLogged?.call();
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_parsed) return const SizedBox.shrink();

    final name = _data['name']?.toString() ?? 'Yemek';
    final kcal = (_data['kcal'] as num?)?.toInt() ?? 0;
    final protein = (_data['protein'] as num?)?.toInt() ?? 0;
    final carbs = (_data['carbs'] as num?)?.toInt() ?? 0;
    final fat = (_data['fat'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _logged
                ? [const Color(0xFF1A3A2A), const Color(0xFF122B1E)]
                : [const Color(0xFF1A2B1A), const Color(0xFF12221A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _logged
                ? const Color(0xFF34D399).withValues(alpha: 0.4)
                : const Color(0xFF34D399).withValues(alpha: 0.2),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _logged ? null : () => _logMeal(context),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _logged
                              ? Icons.check_circle_rounded
                              : Icons.restaurant_menu_rounded,
                          color: const Color(0xFF34D399),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$kcal kcal',
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFF34D399),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_logged)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34D399).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF34D399).withValues(alpha: 0.5),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF34D399),
                                  ),
                                )
                              : Text(
                                  'Ekle',
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFF34D399),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        )
                      else
                        Text(
                          '✓ Günlüğe eklendi',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF34D399).withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _macroChip('P', '$protein g', const Color(0xFF34D399)),
                      const SizedBox(width: 8),
                      _macroChip('K', '$carbs g', const Color(0xFF73D4FF)),
                      const SizedBox(width: 8),
                      _macroChip('Y', '$fat g', const Color(0xFFEBC374)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Workout Save Card ────────────────────────────────────────────────────────

/// Smart card shown when AI generates a workout plan — allows one-tap saving.
class SmartWorkoutSaveCard extends StatefulWidget {
  final String actionData;

  const SmartWorkoutSaveCard({super.key, required this.actionData});

  @override
  State<SmartWorkoutSaveCard> createState() => _SmartWorkoutSaveCardState();
}

class _SmartWorkoutSaveCardState extends State<SmartWorkoutSaveCard> {
  bool _saved = false;
  bool _saving = false;

  Future<void> _save(Map<String, dynamic> data) async {
    if (_saved || _saving) return;
    setState(() => _saving = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final workoutProv = Provider.of<WorkoutProvider>(context, listen: false);
    final userId = auth.user?.id ?? 0;

    final request = WorkoutRequest(
      name: data['name']?.toString() ?? 'Antrenman',
      workoutType: data['workoutType']?.toString() ?? 'strength',
      muscleGroup: data['muscleGroup']?.toString(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
      caloriesBurned: (data['caloriesBurned'] as num?)?.toInt(),
      sets: (data['sets'] as num?)?.toInt(),
      reps: (data['reps'] as num?)?.toInt(),
      notes: data['notes']?.toString(),
      workoutDate: DateTime.now(),
    );

    final ok = await workoutProv.createWorkout(userId, request);
    if (!mounted) return;

    HapticFeedback.lightImpact();
    if (ok) {
      setState(() {
        _saved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '💪 "${request.name}" antrenmanı kaydedildi!',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: const Color(0xFF1A3A2A),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            workoutProv.errorMessage ?? 'Kaydetme başarısız, tekrar deneyin.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(widget.actionData) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final name = data['name']?.toString() ?? 'Antrenman';
    final duration = data['durationMinutes']?.toString() ?? '?';
    final muscleGroup = data['muscleGroup']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: (_saved || _saving) ? null : () => _save(data),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _saved
                  ? [const Color(0xFF1A2A3A), const Color(0xFF12202E)]
                  : [const Color(0xFF12202E), const Color(0xFF0D1A28)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _saved
                  ? const Color(0xFF73D4FF).withValues(alpha: 0.5)
                  : const Color(0xFF73D4FF).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF73D4FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _saved
                      ? Icons.check_circle_rounded
                      : Icons.fitness_center_rounded,
                  color: const Color(0xFF73D4FF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      [
                        if (muscleGroup.isNotEmpty) muscleGroup,
                        '$duration dk',
                      ].join(' · '),
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF73D4FF).withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_saved)
                Text(
                  '✓ Kaydedildi',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF73D4FF).withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF73D4FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF73D4FF).withValues(alpha: 0.4),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              Color(0xFF73D4FF),
                            ),
                          ),
                        )
                      : Text(
                          'Kaydet',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF73D4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }
}
