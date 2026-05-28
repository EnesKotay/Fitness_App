import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/exercise.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/premium_screen.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../models/exercise_guide_data.dart';
import '../providers/workout_provider.dart';
import '../providers/streak_provider.dart';
import '../widgets/achievement_overlay.dart';

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

class _ExerciseGuideScreenState extends State<ExerciseGuideScreen>
    with SingleTickerProviderStateMixin {
  late final ExerciseGuideData _guide;
  late String _selectedGoalKey;
  late Map<String, bool> _checkStates;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _guide = buildExerciseGuideData(widget.exercise);
    _selectedGoalKey = 'beginner';
    _checkStates = {for (final item in _guide.checklist) item.title: false};
  }

  Future<void> _openYouTube() async {
    final query = Uri.encodeComponent(
      '${widget.exercise.name} nasıl yapılır egzersiz',
    );
    final uri = Uri.parse(
      'https://www.youtube.com/results?search_query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildTabSelector() {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(top: 24, bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Rehber', Icons.menu_book_rounded),
          _buildTabButton(1, 'Detaylar', Icons.info_outline_rounded),
          _buildTabButton(2, 'Performans', Icons.analytics_rounded),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? widget.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYouTubeButton() {
    return GestureDetector(
      onTap: _openYouTube,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF0000).withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF2222).withValues(alpha: 0.25),
                    const Color(0xFF8B0000).withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF5555).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF1111),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFFF1111), blurRadius: 12),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hareketin Doğru Formu',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.exercise.name} İzle',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
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
        return 'Göğüs';
      case 'BACK':
        return 'Sırt';
      case 'LEGS':
        return 'Bacak';
      case 'SHOULDERS':
        return 'Omuz';
      case 'BICEPS':
        return 'Biseps';
      case 'TRICEPS':
        return 'Triseps';
      case 'CORE':
        return 'Karın';
      case 'GLUTES':
        return 'Kalça';
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
                bottom: 20,
              ),
              expandedTitleScale: 1.6,
              title: Text(
                widget.exercise.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
                maxLines: 2,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.8, -0.4),
                        radius: 1.4,
                        colors: [
                          widget.accentColor.withValues(alpha: 0.40),
                          widget.accentColor.withValues(alpha: 0.08),
                          const Color(0xFF0A0A0A),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: -20,
                    child: Transform.rotate(
                      angle: -0.15,
                      child: Icon(
                        _MuscleBadgeRow._iconFor(_muscleGroupLabel()),
                        size: 220,
                        color: widget.accentColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0A0A0A)],
                        stops: [0.6, 1],
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
                // ── ÜST BİLGİLER (Genel Bakış) ──────────────────────────────
                _MuscleBadgeRow(
                  primaryMuscles: _guide.targetMuscles.take(1).toList(),
                  secondaryMuscles: _guide.targetMuscles.skip(1).toList(),
                  accentColor: widget.accentColor,
                  groupLabel: _muscleGroupLabel(),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MetaChip(
                        icon: Icons.speed_rounded,
                        label: _guide.tempo,
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetaChip(
                        icon: Icons.air_rounded,
                        label: _guide.breathing,
                        color: const Color(0xFF4DD0E1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _buildTabSelector(),
                const SizedBox(height: 16),

                if (_selectedTab == 0) ...[
                  // ── VİDEO REHBERİ ──────────────────────────────────────────
                  _SectionTitle(
                    label: 'Video Rehberi',
                    color: const Color(0xFFFF5252),
                  ),
                  const SizedBox(height: 14),
                  _buildYouTubeButton(),
                  const SizedBox(height: 28),

                  // ── KURULUM ───────────────────────────────────────────────
                  _SectionTitle(label: 'Kurulum', color: widget.accentColor),
                  const SizedBox(height: 14),
                  _StartPositionCard(
                    group: widget.exercise.muscleGroup.trim().toUpperCase(),
                    setup: _guide.setup,
                    accentColor: widget.accentColor,
                    keyPoints: _guide.checklist.take(2).toList(),
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    color: widget.accentColor,
                    child: Text(_guide.setup, style: _bodyStyle()),
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
                ] else if (_selectedTab == 1) ...[
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
                  _SectionTitle(
                    label: 'Varyasyonlar',
                    color: widget.accentColor,
                  ),
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
                ] else if (_selectedTab == 2) ...[
                  // ── PERFORMANS GEÇMİŞİ ──────────────────────────────────────
                  _SectionTitle(
                    label: 'Performans Geçmişi',
                    color: widget.accentColor,
                  ),
                  const SizedBox(height: 14),
                  Consumer<WorkoutProvider>(
                    builder: (context, provider, _) =>
                        _ExercisePerformanceMiniChart(
                          exerciseName: widget.exercise.name,
                          workouts: provider.workouts,
                          accentColor: widget.accentColor,
                        ),
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
                ],
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
              _CompleteButton(
                checkStates: _checkStates,
                totalChecks: _guide.checklist.length,
                accentColor: widget.accentColor,
                onTap: _onComplete,
              ),
            ],
          ),
        ),
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
    final streakProvider = Provider.of<StreakProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final nav = Navigator.of(context); // Async gap oncesi navigator'i al

    // Streak güncelle — async
    streakProvider.onWorkoutCompleted().then((badge) {
      if (!nav.mounted) return;
      if (badge != null) {
        // Rozet kazanıldı — overlay göster
        final isPremiumUser =
            authProvider.user?.premiumTier?.toLowerCase().trim() == 'premium';

        showDialog<void>(
          context: nav.context, // Root/aktif navigator context'ini kullan
          barrierDismissible: true,
          barrierColor: Colors.transparent,
          builder: (dialogCtx) => AchievementOverlay(
            badge: badge,
            accentColor: widget.accentColor,
            isPremium: isPremiumUser,
            onUpgradeTap: isPremiumUser
                ? null
                : () {
                    streakProvider.clearJustUnlocked();
                    Navigator.of(dialogCtx).pop(); // dialog'u kapat
                    nav.push(
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    );
                  },
            onDismiss: () {
              streakProvider.clearJustUnlocked();
              Navigator.of(dialogCtx).pop(); // dialog'u kapat
            },
          ),
        );
      }
    });

    nav.pop(); // Mevcut guide screen'i kapat
    messenger?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              streakProvider.currentStreak > 0
                  ? '🔥 ${streakProvider.currentStreak} günlük seri devam ediyor!'
                  : 'Hareket gösterimi tamamlandı.',
            ),
          ],
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

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A).withValues(alpha: 0.75),
                    border: Border(
                      top: BorderSide(
                        color: accent.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
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
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                20,
                              ),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                28,
                              ),
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
                                      color: Colors.amber.withValues(
                                        alpha: 0.1,
                                      ),
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
                                        Expanded(
                                          child: Text(
                                            recommendation.headline,
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => setSheetState(() {
                                            weight = recommendation.suggestedKg;
                                            weightC.text =
                                                recommendation.suggestedKg %
                                                        1 ==
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                        {
                                          'label': '4×10',
                                          'sets': 4,
                                          'reps': 10,
                                        },
                                        {'label': '5×5', 'sets': 5, 'reps': 5},
                                        {
                                          'label': '3×12',
                                          'sets': 3,
                                          'reps': 12,
                                        },
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
                                                  ? accent.withValues(
                                                      alpha: 0.25,
                                                    )
                                                  : Colors.white.withValues(
                                                      alpha: 0.06,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                              keyboardType:
                                                  TextInputType.number,
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
                                              onPlus: () =>
                                                  changeVal('sets', 1),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: stepper(
                                              label: 'TEKRAR',
                                              unit: 'rep',
                                              controller: repsC,
                                              keyboardType:
                                                  TextInputType.number,
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
                                              onPlus: () =>
                                                  changeVal('reps', 1),
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
                                        onMinus: () =>
                                            changeVal('weight', -2.5),
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
                                        setSheetState(
                                          () => pickedDate = picked,
                                        );
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                                  .validate()) {
                                                return;
                                              }
                                              setSheetState(
                                                () => saving = true,
                                              );

                                              final calories =
                                                  _estimateCalories(
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
                                                notes:
                                                    notesC.text.trim().isEmpty
                                                    ? null
                                                    : notesC.text.trim(),
                                                muscleGroup:
                                                    widget.exercise.muscleGroup,
                                              );

                                              final ok = await workoutProvider
                                                  .createWorkout(
                                                    userId,
                                                    request,
                                                  );

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
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
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

class _ExercisePerformanceMiniChart extends StatelessWidget {
  final String exerciseName;
  final List<Workout> workouts;
  final Color accentColor;

  const _ExercisePerformanceMiniChart({
    required this.exerciseName,
    required this.workouts,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final entries =
        workouts
            .where(
              (workout) =>
                  workout.name.trim().toLowerCase() ==
                  exerciseName.trim().toLowerCase(),
            )
            .toList()
          ..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));
    final recent = entries.length > 6
        ? entries.sublist(entries.length - 6)
        : entries;

    if (recent.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.show_chart_rounded, color: accentColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu hareket için kayıt oluşunca son 6 performans burada görünecek.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    double metric(Workout workout) {
      if (workout.oneRepMax != null && workout.oneRepMax! > 0) {
        return workout.oneRepMax!;
      }
      if (workout.setDetails != null && workout.setDetails!.isNotEmpty) {
        return workout.setDetails!
            .map((set) => set.weight ?? 0.0)
            .fold<double>(0, (a, b) => a > b ? a : b);
      }
      return workout.weight ?? 0;
    }

    final maxMetric = recent
        .map(metric)
        .fold<double>(0, (a, b) => a > b ? a : b)
        .clamp(1, 500);
    final latest = recent.last;
    final latestMetric = metric(latest);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: accentColor, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Performans geçmişi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                latestMetric > 0
                    ? '${latestMetric.toStringAsFixed(latestMetric % 1 == 0 ? 0 : 1)} kg'
                    : '${latest.reps ?? 0} tekrar',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recent.map((workout) {
                final value = metric(workout);
                final barHeight = value > 0 ? (value / maxMetric) * 50 : 8.0;
                final isLatest = workout == latest;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: barHeight.clamp(6.0, 52.0),
                          decoration: BoxDecoration(
                            color: isLatest
                                ? accentColor
                                : accentColor.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          DateFormat('d/M').format(workout.workoutDate),
                          style: TextStyle(
                            color: isLatest
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.38),
                            fontSize: 9,
                            fontWeight: isLatest
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: child,
        ),
      ),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ❌ Hata bölümü ───────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '✕',
                    style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YANLIŞ',
                        style: TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        issue.issue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Ok geçiş ────────────────────────────────────────────
          Container(
            color: Colors.white.withValues(alpha: 0.04),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Icon(
                Icons.arrow_downward_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
            ),
          ),
          // ── ✅ Düzeltme bölümü ───────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF34C759).withValues(alpha: 0.1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '✓',
                    style: TextStyle(
                      color: Color(0xFF4CD964),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DÜZELTME',
                        style: TextStyle(
                          color: Color(0xFF4CD964),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        issue.fix,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.45,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Kas Grubu Badge Satırı
// ─────────────────────────────────────────────────────────────────────────────
class _MuscleBadgeRow extends StatelessWidget {
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final Color accentColor;
  final String groupLabel;

  const _MuscleBadgeRow({
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.accentColor,
    required this.groupLabel,
  });

  static IconData _iconFor(String label) {
    final upper = label.toUpperCase();
    return switch (upper) {
      'GÖĞÜS' || 'GOGUS' => Icons.open_with_rounded,
      'SIRT' || 'SIIRT' => Icons.flip_rounded,
      'BACAK' => Icons.directions_run_rounded,
      'OMUZ' => Icons.accessibility_new_rounded,
      'BISEPS' || 'BİSEPS' => Icons.sports_handball_rounded,
      'TRISEPS' || 'TRİSEPS' => Icons.sports_handball_rounded,
      'KARIN' || 'KARIIN' => Icons.shield_rounded,
      'KALÇA' || 'KALCA' => Icons.airline_seat_recline_normal_rounded,
      _ => Icons.fitness_center_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconFor(groupLabel), color: accentColor, size: 14),
              const SizedBox(width: 6),
              Text(
                groupLabel.toUpperCase(),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        ...primaryMuscles.map(
          (m) => _MuscleTag(label: m, color: accentColor, isPrimary: true),
        ),
        ...secondaryMuscles.map(
          (m) => _MuscleTag(
            label: m,
            color: accentColor.withValues(alpha: 0.7),
            isPrimary: false,
          ),
        ),
      ],
    );
  }
}

class _MuscleTag extends StatelessWidget {
  final String label;
  final Color color;
  final bool isPrimary;

  const _MuscleTag({
    required this.label,
    required this.color,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? color.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? color.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPrimary
              ? Colors.white
              : Colors.white.withValues(alpha: 0.65),
          fontSize: 11.5,
          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animasyonlu Hero İkon
// ─────────────────────────────────────────────────────────────────────────────
class _HeroIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _HeroIcon({required this.icon, required this.color});

  @override
  State<_HeroIcon> createState() => _HeroIconState();
}

class _HeroIconState extends State<_HeroIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(
      begin: 0.18,
      end: 0.42,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // outer glow ring
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: _glow.value * 0.6),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // inner circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.30),
                      widget.color.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: widget.color.withValues(alpha: _glow.value),
                    width: 1.8,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 38,
                  color: Colors.white.withValues(alpha: 0.90),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tamamla Butonu (checklist ilerleme sayacı dahil)
// ─────────────────────────────────────────────────────────────────────────────
class _CompleteButton extends StatelessWidget {
  final Map<String, bool> checkStates;
  final int totalChecks;
  final Color accentColor;
  final VoidCallback onTap;

  const _CompleteButton({
    required this.checkStates,
    required this.totalChecks,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final checked = checkStates.values.where((v) => v).length;
    final allDone = totalChecks == 0 || checked >= totalChecks;
    final progress = totalChecks > 0 ? checked / totalChecks : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: allDone ? const Color(0xFF1B5E20) : const Color(0xFF1A2A1A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: allDone
                ? const Color(0xFF2E7D32)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Progress fill strip
            if (!allDone)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2E7D32).withValues(alpha: 0.55),
                          const Color(0xFF388E3C).withValues(alpha: 0.25),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Content
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    allDone ? Icons.done_all_rounded : Icons.checklist_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  if (allDone)
                    const Text(
                      'GÖSTERİMİ TAMAMLADIM',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    )
                  else ...[
                    Text(
                      'TAMAMLA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$checked/$totalChecks kontrol',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Başlangıç Pozisyonu Kartı
// ─────────────────────────────────────────────────────────────────────────────
class _StartPositionCard extends StatelessWidget {
  final String group;
  final String setup;
  final Color accentColor;
  final List<ExerciseGuideChecklistItem> keyPoints;

  const _StartPositionCard({
    required this.group,
    required this.setup,
    required this.accentColor,
    required this.keyPoints,
  });

  static IconData _groupIcon(String group) {
    return switch (group) {
      'CHEST' => Icons.open_with_rounded,
      'BACK' => Icons.flip_rounded,
      'LEGS' => Icons.directions_run_rounded,
      'SHOULDERS' => Icons.accessibility_new_rounded,
      'BICEPS' || 'TRICEPS' => Icons.sports_handball_rounded,
      'CORE' => Icons.shield_rounded,
      'GLUTES' => Icons.airline_seat_recline_normal_rounded,
      _ => Icons.flag_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.35),
                      accentColor.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(_groupIcon(group), color: accentColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'BAŞLANGIÇ POZİSYONU',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      setup,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.5,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (keyPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  color: accentColor.withValues(alpha: 0.7),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Anahtar Kontrol Noktaları',
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...keyPoints.map(
              (kp) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: accentColor.withValues(alpha: 0.6),
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${kp.title} — ${kp.detail}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
