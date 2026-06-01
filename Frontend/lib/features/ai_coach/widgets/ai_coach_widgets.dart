import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../nutrition/presentation/state/diet_provider.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../../nutrition/domain/entities/meal_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../../core/models/workout_models.dart';
import '../../tasks/controllers/daily_tasks_controller.dart';
import '../../tasks/models/daily_task.dart';
import '../../recipes/domain/entities/recipe.dart';
import '../../recipes/presentation/state/recipe_provider.dart';

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

// ─── Smart Shopping List Card ────────────────────────────────────────────────

/// Interactive checklist shown when AI generates a grocery/shopping list.
class SmartShoppingListCard extends StatefulWidget {
  final String actionData; // JSON: {"title": "Yemek Listesi Alışverişi", "items": ["1 kg Tavuk", "500g Yulaf"]}

  const SmartShoppingListCard({super.key, required this.actionData});

  @override
  State<SmartShoppingListCard> createState() => _SmartShoppingListCardState();
}

class _SmartShoppingListCardState extends State<SmartShoppingListCard> {
  late Map<String, dynamic> _data;
  late List<String> _items;
  late Set<String> _checkedItems;
  bool _parsed = false;

  @override
  void initState() {
    super.initState();
    try {
      _data = jsonDecode(widget.actionData) as Map<String, dynamic>;
      final rawItems = _data['items'] as List?;
      _items = rawItems != null ? rawItems.map((e) => e.toString()).toList() : [];
      _checkedItems = {};
      _parsed = true;
    } catch (_) {
      _parsed = false;
      _items = [];
      _checkedItems = {};
    }
  }

  void _copyList(BuildContext context) {
    if (_items.isEmpty) return;
    final title = _data['title']?.toString() ?? 'Alışveriş Listesi';
    final buffer = StringBuffer();
    buffer.writeln('📋 $title:');
    for (final item in _items) {
      final isChecked = _checkedItems.contains(item);
      buffer.writeln('${isChecked ? '✓' : '☐'} $item');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Alışveriş listesi kopyalandı! 📋',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF131926),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_parsed || _items.isEmpty) return const SizedBox.shrink();
    final title = _data['title']?.toString() ?? 'Alışveriş Listesi';
    final progress = _items.isEmpty ? 0.0 : _checkedItems.length / _items.length;
    final isFullyCompleted = _items.isNotEmpty && _checkedItems.length == _items.length;
    final themeColor = isFullyCompleted ? const Color(0xFF34D399) : const Color(0xFFEBC374);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFullyCompleted
                ? [const Color(0xFF0C2219), const Color(0xFF071410)]
                : [const Color(0xFF131926), const Color(0xFF0D121B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: themeColor.withValues(alpha: isFullyCompleted ? 0.45 : 0.25),
          ),
          boxShadow: isFullyCompleted
              ? [
                  BoxShadow(
                    color: const Color(0xFF34D399).withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isFullyCompleted
                          ? Icons.check_circle_rounded
                          : Icons.shopping_basket_rounded,
                      color: themeColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isFullyCompleted
                              ? 'Tüm ürünler alındı! 🎉'
                              : '${_checkedItems.length}/${_items.length} alındı',
                          style: GoogleFonts.dmSans(
                            color: isFullyCompleted
                                ? const Color(0xFF34D399)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: isFullyCompleted ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyList(context),
                    icon: Icon(
                      Icons.copy_all_rounded,
                      color: themeColor.withValues(alpha: 0.7),
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                    tooltip: 'Listeyi Kopyala',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              // Smooth animated progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 5,
                  child: Stack(
                    children: [
                      Container(color: Colors.white10),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isFullyCompleted
                                  ? [const Color(0xFF34D399), const Color(0xFF059669)]
                                  : [const Color(0xFFEBC374), const Color(0xFFC88934)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ..._items.map((item) {
                final isChecked = _checkedItems.contains(item);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isChecked) {
                        _checkedItems.remove(item);
                      } else {
                        _checkedItems.add(item);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          isChecked
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: isChecked ? themeColor : Colors.white24,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: GoogleFonts.dmSans(
                              color: isChecked
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.82),
                              fontSize: 12.5,
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
    );
  }
}

// ─── Smart Quest Card ────────────────────────────────────────────────────────

/// Quest card shown when AI recommends daily habits/quests — allows one-tap enjection.
class SmartQuestCard extends StatefulWidget {
  final String actionData; // JSON: {"title": "Günün Görevleri", "quests": [{"text": "Görev", "category": "water"}]}

  const SmartQuestCard({super.key, required this.actionData});

  @override
  State<SmartQuestCard> createState() => _SmartQuestCardState();
}

class _SmartQuestCardState extends State<SmartQuestCard> {
  late Map<String, dynamic> _data;
  late List<Map<String, dynamic>> _quests;
  late Set<int> _selectedIndices;
  bool _parsed = false;
  bool _imported = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    try {
      _data = jsonDecode(widget.actionData) as Map<String, dynamic>;
      final rawQuests = _data['quests'] as List?;
      _quests = rawQuests != null
          ? rawQuests.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      _selectedIndices = List.generate(_quests.length, (i) => i).toSet();
      _parsed = true;
    } catch (_) {
      _parsed = false;
      _quests = [];
      _selectedIndices = {};
    }
  }

  int _getQuestXP(String categoryStr) {
    if (categoryStr == 'water') return 10;
    if (categoryStr == 'sport') return 25;
    if (categoryStr == 'nutrition') return 15;
    return 10;
  }

  int get _totalXP {
    int xp = 0;
    for (int i = 0; i < _quests.length; i++) {
      if (_selectedIndices.contains(i)) {
        final q = _quests[i];
        final cat = q['category']?.toString() ?? 'other';
        xp += _getQuestXP(cat);
      }
    }
    return xp;
  }

  Future<void> _importQuests(BuildContext context) async {
    if (_imported || _importing || !_parsed || _selectedIndices.isEmpty) return;
    setState(() => _importing = true);
    HapticFeedback.mediumImpact();

    try {
      final dailyTasks = context.read<DailyTasksController>();
      int importedCount = 0;
      int earnedXp = 0;

      for (int i = 0; i < _quests.length; i++) {
        if (!_selectedIndices.contains(i)) continue;
        final q = _quests[i];
        final text = q['text']?.toString() ?? '';
        final categoryStr = q['category']?.toString() ?? 'other';

        TaskCategory category = TaskCategory.other;
        if (categoryStr == 'water') category = TaskCategory.water;
        else if (categoryStr == 'sport') category = TaskCategory.sport;
        else if (categoryStr == 'nutrition') category = TaskCategory.nutrition;

        await dailyTasks.addTask(
          text,
          category: category,
          priority: TaskPriority.medium,
        );
        importedCount++;
        earnedXp += _getQuestXP(categoryStr);
      }

      setState(() {
        _imported = true;
        _importing = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFBC74EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎮 +$earnedXp XP fitness günlüğüne aktarıldı! ($importedCount görev eklendi)',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1430),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_parsed || _quests.isEmpty) return const SizedBox.shrink();
    final title = _data['title']?.toString() ?? 'Günün AI Görevleri';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF191326), Color(0xFF100D1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFBC74EB).withValues(alpha: 0.25),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBC74EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFBC74EB),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _imported
                              ? 'Görevler günlüğüne eklendi! ✓'
                              : '${_selectedIndices.length}/${_quests.length} seçildi · +$_totalXP XP',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFFBC74EB),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_imported)
                    GestureDetector(
                      onTap: _selectedIndices.isEmpty ? null : () => _importQuests(context),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedIndices.isEmpty
                              ? Colors.white10
                              : const Color(0xFFBC74EB).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedIndices.isEmpty
                                ? Colors.white24
                                : const Color(0xFFBC74EB).withValues(alpha: 0.4),
                          ),
                        ),
                        child: _importing
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFFBC74EB)),
                                ),
                              )
                            : Text(
                                'Aktar',
                                style: GoogleFonts.dmSans(
                                  color: _selectedIndices.isEmpty
                                      ? Colors.white38
                                      : const Color(0xFFBC74EB),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFFBC74EB),
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              ..._quests.asMap().entries.map((entry) {
                final idx = entry.key;
                final q = entry.value;
                final text = q['text']?.toString() ?? '';
                final cat = q['category']?.toString() ?? 'other';
                final isSelected = _selectedIndices.contains(idx);
                final (icon, color) = _getQuestCategoryMeta(cat);
                final xp = _getQuestXP(cat);

                return GestureDetector(
                  onTap: _imported
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selectedIndices.remove(idx);
                            } else {
                              _selectedIndices.add(idx);
                            }
                          });
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        if (!_imported) ...[
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_off_rounded,
                            color: isSelected ? const Color(0xFFBC74EB) : Colors.white24,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          icon,
                          size: 14,
                          color: isSelected ? color : color.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text,
                            style: GoogleFonts.dmSans(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.82)
                                  : Colors.white.withValues(alpha: 0.35),
                              fontSize: 12.5,
                              decoration: _imported ? null : (isSelected ? null : TextDecoration.lineThrough),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isSelected ? 0.12 : 0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: color.withValues(alpha: isSelected ? 0.3 : 0.1),
                            ),
                          ),
                          child: Text(
                            '+$xp XP',
                            style: GoogleFonts.dmMono(
                              color: isSelected ? color : color.withValues(alpha: 0.35),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
    );
  }

  (IconData, Color) _getQuestCategoryMeta(String cat) {
    switch (cat) {
      case 'water':
        return (Icons.water_drop_rounded, const Color(0xFF73D4FF));
      case 'sport':
        return (Icons.fitness_center_rounded, const Color(0xFF34D399));
      case 'nutrition':
        return (Icons.restaurant_rounded, const Color(0xFFEBC374));
      default:
        return (Icons.star_rounded, const Color(0xFFBC74EB));
    }
  }
}

// ─── Smart Recipe Card ────────────────────────────────────────────────────────

class SmartRecipeCard extends StatefulWidget {
  final String actionData; // JSON: {"name": "Yulaf L.", "kcal": 450, "protein": 30, ...}

  const SmartRecipeCard({super.key, required this.actionData});

  @override
  State<SmartRecipeCard> createState() => _SmartRecipeCardState();
}

class _SmartRecipeCardState extends State<SmartRecipeCard> {
  bool _saved = false;
  bool _saving = false;
  bool _expanded = false;

  late Map<String, dynamic> _data;
  late List<String> _ingredients;
  late List<String> _steps;
  bool _parsed = false;

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    final str = val.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(str) ?? 0;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final str = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(str) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    try {
      _data = jsonDecode(widget.actionData) as Map<String, dynamic>;
      
      final rawIngs = _data['ingredients'];
      if (rawIngs is List) {
        _ingredients = rawIngs.map((e) {
          if (e is Map) {
            final name = e['name']?.toString() ?? '';
            final amount = e['amount'];
            final unit = e['unit']?.toString() ?? '';
            if (amount != null && unit.isNotEmpty) {
              return '$amount$unit $name';
            } else if (amount != null) {
              return '$amount $name';
            } else {
              return name;
            }
          }
          return e.toString();
        }).toList();
      } else {
        _ingredients = [];
      }

      final rawSteps = _data['instructions'] ?? _data['steps'];
      if (rawSteps is List) {
        _steps = rawSteps.map((e) => e.toString()).toList();
      } else if (rawSteps is String) {
        _steps = rawSteps.split(RegExp(r'\r?\n')).where((s) => s.trim().isNotEmpty).toList();
      } else {
        _steps = [];
      }
      _parsed = true;
    } catch (_) {
      _parsed = false;
      _ingredients = [];
      _steps = [];
      _data = {};
    }
  }

  Future<void> _saveRecipe(BuildContext context) async {
    if (_saved || _saving || !_parsed) return;
    
    // Retrieve providers before the async gap!
    final recipeProv = Provider.of<RecipeProvider>(context, listen: false);
    final diet = Provider.of<DietProvider>(context, listen: false);
    
    setState(() => _saving = true);

    try {
      await recipeProv.init(); // Ensure initialized

      final name = _data['name']?.toString() ?? 'AI Tarifi';
      final kcal = _parseDouble(_data['kcal']);
      final protein = _parseDouble(_data['protein']);
      final carbs = _parseDouble(_data['carbs']);
      final fat = _parseDouble(_data['fat']);

      final mappedIngredients = _ingredients.map((ing) {
        return RecipeIngredient(
          name: ing,
          amount: 1.0,
          unit: 'porsiyon',
          category: 'other',
        );
      }).toList();

      final userGoal = diet.profile?.goal;

      final tagsList = ['ai', 'pratik', 'yuksek protein'];
      if (userGoal == Goal.bulk) {
        tagsList.add('bulk');
        tagsList.add('hacim');
      } else if (userGoal == Goal.cut) {
        tagsList.add('cut');
        tagsList.add('definasyon');
      } else if (userGoal == Goal.maintain) {
        tagsList.add('kilo koruma');
      } else if (userGoal == Goal.strength) {
        tagsList.add('guc');
      }

      final newRecipe = Recipe(
        id: 'recipe_ai_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: 'AI Koç tarafından özel olarak oluşturulmuş yüksek proteinli tarif.',
        category: 'atistirmalik',
        servings: 1,
        prepTimeMinutes: 10,
        cookTimeMinutes: 10,
        ingredients: mappedIngredients,
        steps: _steps.isNotEmpty ? _steps : ['Tarif adımlarını takip edin.'],
        imageEmoji: '🍳',
        kcalPerServing: kcal,
        proteinPerServing: protein,
        carbPerServing: carbs,
        fatPerServing: fat,
        fiberPerServing: 0.0,
        sugarPerServing: 0.0,
        tags: tagsList,
        difficulty: 'kolay',
      );

      await recipeProv.addCustomRecipe(newRecipe);

      if (mounted) {
        setState(() {
          _saved = true;
          _saving = false;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      debugPrint('CREATE_RECIPE save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_parsed) return const SizedBox.shrink();

    final name = _data['name']?.toString() ?? 'Tarif';
    final kcal = _parseInt(_data['kcal']);
    final protein = _parseInt(_data['protein']);
    final carbs = _parseInt(_data['carbs']);
    final fat = _parseInt(_data['fat']);

    final themeColor = const Color(0xFFEBC374);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1D1812), const Color(0xFF110F0D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: themeColor.withValues(alpha: _saved ? 0.45 : 0.25),
          ),
          boxShadow: _saved
              ? [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _saved ? Icons.bookmark_added_rounded : Icons.menu_book_rounded,
                          color: themeColor,
                          size: 18,
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
                              _expanded ? 'Detayları kapat' : 'Malzemeleri ve yapılışını gör',
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: Colors.white.withValues(alpha: 0.35),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _macroChip('P', '$protein g', const Color(0xFF34D399)),
                        _macroChip('K', '$carbs g', const Color(0xFF73D4FF)),
                        _macroChip('Y', '$fat g', const Color(0xFFEBC374)),
                        _macroChip('Kcal', '$kcal kcal', const Color(0xFFFF8A65)),
                      ],
                    ),
                    if (_ingredients.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Malzemeler',
                        style: GoogleFonts.dmSans(
                          color: themeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._ingredients.map((ing) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.fiber_manual_record_rounded, size: 8, color: Colors.white30),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ing,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    if (_steps.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Hazırlanışı',
                        style: GoogleFonts.dmSans(
                          color: themeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._steps.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 1.5),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: GoogleFonts.dmSans(
                                      color: themeColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: themeColor.withValues(alpha: _saved ? 0.2 : 0.5),
                          ),
                          backgroundColor: _saved ? Colors.transparent : themeColor.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_saved || _saving) ? null : () => _saveRecipe(context),
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFFEBC374)),
                                ),
                              )
                            : Icon(
                                _saved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                                color: _saved ? Colors.white30 : themeColor,
                                size: 16,
                              ),
                        label: Text(
                          _saved ? 'Tarif Kaydedildi ✓' : 'Tariflerime Kaydet',
                          style: GoogleFonts.dmSans(
                            color: _saved ? Colors.white30 : Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
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
