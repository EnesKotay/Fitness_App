import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:confetti/confetti.dart';

import '../../auth/screens/premium_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../nutrition/domain/entities/user_profile.dart';

import '../controllers/ai_coach_controller.dart';
import '../models/ai_coach_models.dart';
import '../services/ai_coach_usage_service.dart';
import '../../tasks/controllers/daily_tasks_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/ai_coach_dashboard.dart';
import '../../../core/services/notification_service.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../weight/presentation/providers/weight_provider.dart';

class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({super.key, this.initialSummary});
  final DailySummary? initialSummary;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AiCoachController>(
          create: (_) => AiCoachController(initialSummary: initialSummary),
        ),
        ChangeNotifierProvider<DailyTasksController>(
          create: (_) => DailyTasksController()..loadToday(),
        ),
      ],
      child: const AiCoachScreenBody(),
    );
  }
}

class AiCoachScreenBody extends StatefulWidget {
  const AiCoachScreenBody({super.key});
  @override
  State<AiCoachScreenBody> createState() => _AiCoachScreenBodyState();
}

class _AiCoachScreenBodyState extends State<AiCoachScreenBody> {
  static const Color _surface = Color(0xFF101826);
  static const Color _surfaceSoft = Color(0xFF141F31);
  static const Color _brandBlue = Color(0xFF73D4FF);
  static const Color _brandGold = Color(0xFFEBC374);
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiCoachUsageService _usageService = AiCoachUsageService();
  late ConfettiController _confettiController;
  bool _isPremium = false;
  int _remainingFreePrompts = AiCoachUsageService.freeDailyPromptLimit;
  AiCoachController? _aiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccessState();
      if (mounted) {
        _aiController = context.read<AiCoachController>();
        _aiController!.addListener(_onAiControllerUpdate);
      }
    });
  }

  @override
  void dispose() {
    _aiController?.removeListener(_onAiControllerUpdate);
    _textController.dispose();
    _scrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onAiControllerUpdate() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Kullanıcı en alttaysa (300px içindeyse) otomatik scroll yap
    if (pos.maxScrollExtent - pos.pixels < 300) {
      _scrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadAccessState() async {
    final auth = context.read<AuthProvider?>();
    final user = auth?.user;
    var isPremium = user?.premiumTier?.toLowerCase().trim() == 'premium';

    if (!isPremium) {
      try {
        final aiService = context.read<DietProvider>().aiService;
        if (aiService != null) {
          final remotePremium = await aiService.checkPremiumStatus();
          if (remotePremium != null) {
            isPremium = remotePremium;
            if (auth != null) {
              auth.setPremiumActive(remotePremium);
            }
          }
        }
      } catch (e) {
        debugPrint('AiCoachScreen: premium kontrol hatası: $e');
      }
    }

    _syncUserData();

    final remaining = isPremium
        ? AiCoachUsageService.freeDailyPromptLimit
        : (user != null
              ? await _usageService.getRemainingFreePrompts(userId: user.id)
              : 0);

    if (mounted) {
      setState(() {
        _isPremium = isPremium;
        _remainingFreePrompts = remaining;
      });
    }
  }

  Future<void> _syncUserData() async {
    if (!mounted) return;

    final controller = context.read<AiCoachController>();
    final diet = context.read<DietProvider>();
    final workout = context.read<WorkoutProvider>();
    final weight = context.read<WeightProvider>();

    // 1. Current Day Data
    final calories = diet.totals.totalKcal.round();
    final todayWorkouts = workout.workoutsForSelectedDate;
    final workoutMinutes = todayWorkouts.fold<int>(
      0,
      (sum, w) => sum + (w.durationMinutes ?? 0),
    );
    final highlights = todayWorkouts.map((w) => w.name).take(5).toList();

    // 2. Macros
    final proteinGrams = diet.totals.totalProtein > 0 ? diet.totals.totalProtein.round() : null;
    final carbsGrams = diet.totals.totalCarb > 0 ? diet.totals.totalCarb.round() : null;
    final fatGrams = diet.totals.totalFat > 0 ? diet.totals.totalFat.round() : null;

    // 3. Meal names eaten today
    final mealNames = diet.entries.map((e) => e.foodName).take(6).toList();

    // 4. User profile demographics
    final profile = diet.profile;
    final userAge = profile?.age;
    final userHeightCm = profile?.height;
    final userGender = profile?.gender.name;
    final activityLevel = profile?.activityLevel.name;
    final tdee = profile != null ? profile.tdee.round() : null;

    // 5. Weight trend
    final weeklyWeightChangeKg = weight.entries.isNotEmpty ? weight.weeklyChange : null;
    final weightStreak = weight.currentStreak > 0 ? weight.currentStreak : null;

    // 6. Phase 8: Historical Context (Last 7 Days)
    int? avgCalories;
    double? avgWater;

    try {
      final logs = await diet.getRecentDaysLogs(7);
      if (!mounted) return;
      if (logs.isNotEmpty) {
        final totalKcal = logs.fold<double>(0, (sum, l) => sum + l.totalKcal);
        final totalWater = logs.fold<double>(
          0,
          (sum, l) => sum + (l.totalKcal > 0 ? 2.0 : 0.0),
        );
        avgCalories = (totalKcal / logs.length).round();
        avgWater = totalWater / logs.length;
      }
    } catch (e) {
      debugPrint('Error calculating averages for AI Coach: $e');
    }

    controller.setDailySummary(
      DailySummary(
        steps: 0,
        calories: calories,
        waterLiters: diet.waterLiters,
        sleepHours: 0.0,
        workouts: todayWorkouts.length,
        workoutMinutes: workoutMinutes,
        workoutHighlights: highlights,
        avgCaloriesLast7Days: avgCalories,
        avgWaterLast7Days: avgWater,
        avgStepsLast7Days: 0,
        targetCalories: diet.dailyTargetKcal?.round(),
        currentWeightKg: diet.profile?.weight,
        targetWeightKg: diet.profile?.targetWeight,
        bmi: diet.bmi > 0 ? diet.bmi : null,
        proteinGrams: proteinGrams,
        carbsGrams: carbsGrams,
        fatGrams: fatGrams,
        mealNames: mealNames,
        weeklyWeightChangeKg: weeklyWeightChangeKg,
        weightStreak: weightStreak,
        userAge: userAge,
        userHeightCm: userHeightCm,
        userGender: userGender,
        activityLevel: activityLevel,
        tdee: tdee,
      ),
    );

    // Sync goal from profile
    if (diet.profile != null) {
      controller.setGoal(diet.profile!.goal);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    });
  }

  Future<void> _handleSend(AiCoachController controller) async {
    final text = _textController.text.trim();
    if (text.isEmpty || controller.isLoading) return;

    if (!_isPremium && _remainingFreePrompts <= 0) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
      return;
    }

    _textController.clear();
    final success = await controller.submitPrompt(text);
    if (!mounted) return;

    if (success) {
      // Sync with DailyTasksController
      final dailyTasks = context.read<DailyTasksController>();
      final lastMsg = controller.messages.last;
      if (lastMsg.role == ChatRole.assistant &&
          lastMsg.structuredResponse != null) {
        for (var item in lastMsg.structuredResponse!.todoItems) {
          await dailyTasks.addFromAiAction(item);
          if (!mounted) return;
        }
      }

      if (!_isPremium) {
        final auth = context.read<AuthProvider?>();
        final user = auth?.user;
        if (user != null) {
          await _usageService.incrementPromptCount(userId: user.id);
          if (mounted) _loadAccessState();
        }
      }
    }

    _scrollToBottom();
  }

  void _applyPrompt(AiCoachController controller, String prompt) {
    _textController.text = prompt;
    _handleSend(controller);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiCoachController>(
      builder: (context, controller, _) {
        final hasConversation = controller.messages.length > 1;
        // Step: Confetti Trigger
        if (controller.shouldShowConfetti) {
          _confettiController.play();
          // Reset trigger after a slight delay
          Future.delayed(const Duration(seconds: 1), () {
            controller.resetConfetti();
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF070B16),
          appBar: _buildAppBar(controller),
          body: Stack(
            children: [
              const _AnimatedMeshBackground(),
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          hasConversation ? 132 : 16,
                        ),
                        children: [
                          if (!hasConversation) ...[
                            _buildStartExperience(controller),
                          ] else ...[
                            _buildCompactConversationHeader(controller),
                          ],
                          const SizedBox(height: 6),
                          ...controller.messages.map(
                            (message) => ChatBubble(message: message)
                                .animate()
                                .fadeIn(duration: 320.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.08, end: 0),
                          ),
                          if (controller.messages.isNotEmpty &&
                              controller.messages.last.isError &&
                              controller.canRetryLastPrompt) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => controller.retryLastPrompt(),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: Color(0xFFEBC374),
                                ),
                                label: Text(
                                  'Tekrar dene',
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFFEBC374),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (controller.isLoading)
                            const TypingBubble().animate().fadeIn(
                              duration: 300.ms,
                            ),
                        ],
                      ),
                    ),
                    _buildInputSection(controller),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFEBC374),
                    Color(0xFFBC74EB),
                    Colors.white,
                  ],
                  numberOfParticles: 30,
                  gravity: 0.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AiCoachController controller) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: Colors.black.withValues(alpha: 0.16)),
        ),
      ),
      title: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 250;
          final accent = _isPremium ? _brandGold : _brandBlue;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'AI Koç',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 18 : 19,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.24)),
                    ),
                    child: Text(
                      _isPremium ? 'Premium' : 'Free',
                      style: GoogleFonts.dmSans(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (controller.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEBC374),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _isPremium
                    ? 'Bugünün planı, analiz ve hızlı öneriler'
                    : '$_remainingFreePrompts ücretsiz hak kaldı',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: Consumer<NotificationService>(
            builder: (context, ns, _) => Badge(
              isLabelVisible: ns.unreadCount > 0,
              label: Text(
                ns.unreadCount.toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          tooltip: 'Bildirimler',
          onPressed: () => _showNotifications(context),
        ),
        PopupMenuButton<String>(
          tooltip: 'AI Koç ayarları',
          color: const Color(0xFF0F1528),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: Colors.white.withValues(alpha: 0.82),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Ayarlar',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          onSelected: (value) {
            if (value == 'goal') {
              _showGoalPicker(context, controller);
            } else if (value == 'personality') {
              _showPersonalityPicker(context, controller);
            } else if (value == 'clear') {
              controller.clearMessages();
            } else if (value == 'premium') {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'goal',
              child: Text(
                'Hedef seç',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
            ),
            PopupMenuItem<String>(
              value: 'personality',
              child: Text(
                'Koç karakteri',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
            ),
            PopupMenuItem<String>(
              value: 'clear',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_sweep_rounded,
                    size: 18,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sohbeti Temizle',
                    style: GoogleFonts.dmSans(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (!_isPremium)
              PopupMenuItem<String>(
                value: 'premium',
                child: Text(
                  'Premium\'u aç',
                  style: GoogleFonts.dmSans(color: const Color(0xFFEBC374)),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  String _buildContextLine(AiCoachController controller) {
    final s = controller.dailySummary;
    final parts = <String>[];
    if (s.calories > 0) parts.add('${s.calories} kcal');
    if (s.waterLiters > 0) parts.add('${s.waterLiters.toStringAsFixed(1)} L su');
    if (s.workouts > 0) {
      parts.add(
        '${s.workouts} antrenman${s.workoutMinutes > 0 ? ' (${s.workoutMinutes} dk)' : ''}',
      );
    }
    if (parts.isEmpty) {
      return 'Bugün henüz kayıt yok — veri girdikçe öneriler kişiselleşir.';
    }
    return 'Bugün: ${parts.join(' · ')}';
  }

  bool _hasEnoughData(AiCoachController controller) {
    final s = controller.dailySummary;
    return s.calories > 0 ||
        s.waterLiters > 0 ||
        s.workouts > 0 ||
        (s.currentWeightKg ?? 0) > 0;
  }

  List<(IconData, String, Color)> _buildInsightItems(AiCoachController controller) {
    final s = controller.dailySummary;
    final items = <(IconData, String, Color)>[];

    if (s.targetCalories != null && s.calories > 0) {
      final diff = s.calories - s.targetCalories!;
      if (diff.abs() <= 150) {
        items.add((
          Icons.track_changes_rounded,
          'Kalori hedefin çizgide',
          const Color(0xFF34D399),
        ));
      } else if (diff > 150) {
        items.add((
          Icons.local_fire_department_rounded,
          '${diff.abs()} kcal fazla gidiyorsun',
          const Color(0xFFFF8A65),
        ));
      } else {
        items.add((
          Icons.restaurant_rounded,
          '${diff.abs()} kcal daha alınabilir',
          const Color(0xFFEBC374),
        ));
      }
    }

    if (s.avgWaterLast7Days != null && s.waterLiters > 0) {
      if (s.waterLiters < s.avgWaterLast7Days!) {
        items.add((
          Icons.water_drop_rounded,
          'Su tüketimin ortalamanın altında',
          const Color(0xFF73D4FF),
        ));
      } else {
        items.add((
          Icons.water_rounded,
          'Su performansın güçlü gidiyor',
          const Color(0xFF4FACFE),
        ));
      }
    } else if (s.waterLiters < 1.0) {
      items.add((
        Icons.opacity_rounded,
        'Su hedefin için biraz daha alan var',
        const Color(0xFF73D4FF),
      ));
    }

    if (s.workouts == 0) {
      items.add((
        Icons.self_improvement_rounded,
        'Bugün hareket eklemek iyi gelir',
        const Color(0xFFA78BFA),
      ));
    } else if (s.workoutMinutes >= 45) {
      items.add((
        Icons.fitness_center_rounded,
        'Antrenman hacmi iyi, toparlanma onemli',
        const Color(0xFF34D399),
      ));
    }

    if ((s.bmi ?? 0) > 0) {
      items.add((
        Icons.monitor_weight_rounded,
        'BMI: ${s.bmi!.toStringAsFixed(1)}',
        const Color(0xFFBC74EB),
      ));
    }

    return items.take(4).toList();
  }

  IconData _modeIcon(CoachTaskMode mode) {
    switch (mode) {
      case CoachTaskMode.plan:
        return Icons.route_rounded;
      case CoachTaskMode.nutrition:
        return Icons.restaurant_menu_rounded;
      case CoachTaskMode.workout:
        return Icons.fitness_center_rounded;
      case CoachTaskMode.recovery:
        return Icons.self_improvement_rounded;
      case CoachTaskMode.analysis:
        return Icons.analytics_rounded;
    }
  }


  Widget _buildStartExperience(AiCoachController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntroCard(controller),
        const SizedBox(height: 12),
        _buildPersonalitySelector(controller),
        if (_hasEnoughData(controller)) ...[
          const SizedBox(height: 12),
          AiCoachDashboard(
            summary: controller.dailySummary,
            goal: controller.goal,
          ),
        ],
        const SizedBox(height: 12),
        _buildStarterPromptSection(controller),
      ],
    );
  }

  Widget _buildPersonalitySelector(AiCoachController controller) {
    const personalities = [
      (
        p: CoachPersonality.motivator,
        emoji: '💪',
        name: 'Motivatör',
        desc: 'Sert & disiplinli',
        color: Color(0xFFFF7043),
      ),
      (
        p: CoachPersonality.scientist,
        emoji: '🔬',
        name: 'Bilimsel',
        desc: 'Veri & analize dayalı',
        color: Color(0xFF73D4FF),
      ),
      (
        p: CoachPersonality.supportive,
        emoji: '🤝',
        name: 'Destekçi',
        desc: 'Nazik & motive edici',
        color: Color(0xFF34D399),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: Color(0xFF73D4FF)),
              const SizedBox(width: 6),
              Text(
                'Koç karakterini seç',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: personalities.map((item) {
            final selected = controller.personality == item.p;
            return Expanded(
              child: GestureDetector(
                onTap: () => controller.setPersonality(item.p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: item.p != CoachPersonality.supportive ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? item.color.withValues(alpha: 0.12)
                        : const Color(0xFF101826),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? item.color.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.07),
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.15),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        style: GoogleFonts.dmSans(
                          color: selected
                              ? item.color
                              : Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.desc,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: selected ? 0.6 : 0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStarterPromptSection(AiCoachController controller) {
    return _buildStarterPromptGrid(controller);
  }

  Widget _buildIntroCard(AiCoachController controller) {
    final modelLabel = _isPremium ? 'Claude Sonnet' : 'Gemini Flash';
    final modelColor = _isPremium
        ? const Color(0xFFEBC374)
        : const Color(0xFF73D4FF);
    final modelIcon = _isPremium
        ? Icons.stars_rounded
        : Icons.auto_awesome_rounded;

    final rawName = context.read<AuthProvider?>()?.user?.name ?? '';
    final userName = rawName.isNotEmpty ? rawName.split(' ').first : null;
    final hour = DateTime.now().hour;
    final timeGreeting = hour >= 5 && hour < 12
        ? 'Günaydın'
        : hour >= 12 && hour < 17
            ? 'Merhaba'
            : hour >= 17 && hour < 22
                ? 'İyi akşamlar'
                : 'İyi geceler';
    final greeting = userName != null && userName.isNotEmpty
        ? '$timeGreeting, $userName!'
        : '$timeGreeting!';
    final contextLine = _buildContextLine(controller);
    final insights = _buildInsightItems(controller);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceSoft.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: modelColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      modelColor.withValues(alpha: 0.22),
                      modelColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: modelColor.withValues(alpha: 0.24)),
                ),
                child: Icon(modelIcon, size: 20, color: modelColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contextLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: modelColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: modelColor.withValues(alpha: 0.22)),
                ),
                child: Text(
                  modelLabel,
                  style: GoogleFonts.dmSans(
                    color: modelColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: insights
                  .take(3)
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            item.$3.withValues(alpha: 0.1),
                            item.$3.withValues(alpha: 0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.$3.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: item.$3.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(item.$1, size: 12, color: item.$3),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            item.$2,
                            style: GoogleFonts.dmSans(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactConversationHeader(AiCoachController controller) {
    final summary = controller.dailySummary;
    final chips = <String>[];
    if (summary.calories > 0) chips.add('${summary.calories} kcal');
    if (summary.waterLiters > 0) {
      chips.add('${summary.waterLiters.toStringAsFixed(1)} L su');
    }
    if (summary.workouts > 0) chips.add('${summary.workouts} antrenman');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _modeIcon(controller.taskMode),
                  size: 14,
                  color: _brandBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  controller.taskMode.label,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                chips.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _promptCardThemes = [
    (
      bg: Color(0xFF0E2218),
      accent: Color(0xFF34D399),
      icon: Icons.fitness_center_rounded,
      label: 'Antrenman',
    ),
    (
      bg: Color(0xFF1F1508),
      accent: Color(0xFFEBC374),
      icon: Icons.restaurant_rounded,
      label: 'Beslenme',
    ),
    (
      bg: Color(0xFF0D1633),
      accent: Color(0xFF6B9FFF),
      icon: Icons.trending_up_rounded,
      label: 'Analiz',
    ),
    (
      bg: Color(0xFF1B0E2A),
      accent: Color(0xFFBC74EB),
      icon: Icons.psychology_rounded,
      label: 'Genel',
    ),
  ];

  Widget _buildStarterPromptGrid(AiCoachController controller) {
    final prompts = controller.actionChips.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Önerilen başlangıçlar',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'dokun ve gönder',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.32),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(prompts.length, (index) {
                final prompt = prompts[index];
                final theme = _promptCardThemes[index % _promptCardThemes.length];
                return InkWell(
                      onTap: () => _applyPrompt(controller, prompt),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: itemWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111A2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.accent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: theme.accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    theme.icon,
                                    size: 14,
                                    color: theme.accent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    theme.label,
                                    style: GoogleFonts.dmSans(
                                      color: theme.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(
                      duration: 360.ms,
                      delay: (index * 80).ms,
                      curve: Curves.easeOut,
                    )
                    .slideY(begin: 0.08, end: 0);
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInputSection(AiCoachController controller) {
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactModeBar(controller),
                if (controller.isCooldownActive) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBC374).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEBC374).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: Color(0xFFEBC374),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${controller.cooldownSecondsRemaining ?? 0}s sonra tekrar deneyebilirsin',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFFEBC374),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isPremium && _remainingFreePrompts == 1) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PremiumScreen(),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFEBC374).withValues(alpha: 0.12),
                            const Color(0xFFC88934).withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEBC374).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 14,
                            color: Color(0xFFEBC374),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Son ücretsiz hakkın kaldı. PRO\'ya geç — sınırsız kullan.',
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFFEBC374),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Color(0xFFEBC374),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (controller.selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(controller.selectedImage!.path),
                            height: 72,
                            width: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -5,
                          right: -5,
                          child: GestureDetector(
                            onTap: () => controller.setSelectedImage(null),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cancel,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: controller.isLoading
                          ? _brandGold.withValues(alpha: 0.24)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 18,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: Icon(
                            controller.selectedImage != null
                                ? Icons.image_rounded
                                : Icons.add_photo_alternate_outlined,
                            color: controller.selectedImage != null
                                ? _brandGold
                                : Colors.white.withValues(alpha: 0.34),
                            size: 18,
                          ),
                          onPressed: () => _pickImage(context, controller),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 2,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                          decoration: InputDecoration(
                            hintText: controller.isCooldownActive
                                ? 'Bekleniyor...'
                                : !_isPremium && _remainingFreePrompts <= 1
                                    ? 'Son hakkın, iyi kullan'
                                    : controller.taskMode.hint,
                            hintStyle: GoogleFonts.dmSans(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 13.5,
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(
                              0,
                              12,
                              8,
                              12,
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _handleSend(controller),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildSendButton(controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactModeBar(AiCoachController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CoachTaskMode.values.map((mode) {
          final selected = controller.taskMode == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => controller.setTaskMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? _brandBlue.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? _brandBlue.withValues(alpha: 0.28)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _modeIcon(mode),
                      size: 14,
                      color: selected
                          ? _brandBlue
                          : Colors.white.withValues(alpha: 0.52),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.label,
                      style: GoogleFonts.dmSans(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.68),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickImage(
    BuildContext context,
    AiCoachController controller,
  ) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0F1528),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFEBC374)),
              title: Text(
                'Kamerayı Aç',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFEBC374),
              ),
              title: Text(
                'Galeriden Seç',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        controller.setSelectedImage(image);
      }
    }
  }

  void _showNotifications(BuildContext context) {
    final ns = context.read<NotificationService>();
    ns.fetchNotifications();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F1528),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AI TAVSİYELERİ',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFEBC374),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Consumer<NotificationService>(
                  builder: (context, ns, _) {
                    if (ns.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (ns.notifications.isEmpty) {
                      return Center(
                        child: Text(
                          'Henüz bir tavsiye yok.',
                          style: GoogleFonts.dmSans(color: Colors.white54),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: ns.notifications.length,
                      itemBuilder: (context, index) {
                        final n = ns.notifications[index];
                        return Card(
                              color: n.isRead
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : const Color(
                                      0xFFEBC374,
                                    ).withValues(alpha: 0.1),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: n.isRead
                                      ? Colors.transparent
                                      : const Color(
                                          0xFFEBC374,
                                        ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.bolt_rounded,
                                  color: n.isRead
                                      ? Colors.white38
                                      : const Color(0xFFEBC374),
                                ),
                                title: Text(
                                  n.title,
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  n.message,
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Text(
                                  '${n.createdAt.hour}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontSize: 10,
                                  ),
                                ),
                                onTap: () => ns.markAsRead(n.id),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: (index * 100).ms)
                            .slideX(begin: 0.1, end: 0);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalPicker(BuildContext context, AiCoachController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1528).withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'HEDEF SEÇ',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFEBC374),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...Goal.values.map(
                (g) => ListTile(
                  leading: Radio<Goal>(
                    value: g,
                    groupValue: controller.goal,
                    activeColor: const Color(0xFFEBC374),
                    onChanged: (val) {
                      if (val != null) {
                        controller.setGoal(val);
                        Navigator.pop(context);
                      }
                    },
                  ),
                  title: Text(
                    g.label,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    g.subtitle,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    controller.setGoal(g);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showPersonalityPicker(
    BuildContext context,
    AiCoachController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1528).withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'KOÇ KARAKTERİ SEÇ',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFEBC374),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...CoachPersonality.values.map(
                (p) => ListTile(
                  leading: Radio<CoachPersonality>(
                    value: p,
                    groupValue: controller.personality,
                    activeColor: const Color(0xFFEBC374),
                    onChanged: (val) {
                      if (val != null) {
                        controller.setPersonality(val);
                        Navigator.pop(context);
                      }
                    },
                  ),
                  title: Text(
                    p.label,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    p.instruction,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    controller.setPersonality(p);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(AiCoachController controller) {
    final disabled = controller.isLoading || controller.isCooldownActive;
    return GestureDetector(
          onTap: disabled ? null : () => _handleSend(controller),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: disabled
                  ? const LinearGradient(
                      colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFEBC374), Color(0xFFC88934)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFFEBC374).withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                    ],
            ),
              child: Center(
                child: controller.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: disabled
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white,
                      size: 20,
                    ),
            ),
          ),
        )
        .animate(
          key: ValueKey(controller.isLoading),
          onPlay: (c) => controller.isLoading ? c.repeat() : c.forward(),
        )
        .shimmer(
          duration: 1200.ms,
          color: Colors.white.withValues(alpha: 0.15),
        );
  }
}

class _AnimatedMeshBackground extends StatefulWidget {
  const _AnimatedMeshBackground();

  @override
  State<_AnimatedMeshBackground> createState() =>
      _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<_AnimatedMeshBackground> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF050814),
                Color(0xFF09111E),
                Color(0xFF060A12),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        _buildAura(
          const Color(0xFF0F6B85),
          380,
          alignment: Alignment.topRight,
          offset: const Offset(80, -90),
        ),
        _buildAura(
          const Color(0xFF0C8C6C),
          320,
          alignment: Alignment.topLeft,
          offset: const Offset(-100, 120),
        ),
        _buildAura(
          const Color(0xFF5E3A1B),
          280,
          alignment: Alignment.bottomCenter,
          offset: const Offset(0, 180),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _CoachBackdropPainter(),
            size: Size.infinite,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.12),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.18),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAura(
    Color color,
    double size, {
    required Alignment alignment,
    required Offset offset,
  }) {
    return Align(
          alignment: alignment,
          child: Transform.translate(
            offset: offset,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.22),
                    color.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .move(
          begin: const Offset(0, 0),
          end: const Offset(18, 24),
          duration: 12.seconds,
          curve: Curves.easeInOut,
        )
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.08, 1.08),
          duration: 10.seconds,
        );
  }
}

class _CoachBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.035);

    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF73D4FF).withValues(alpha: 0.05),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    const spacing = 56.0;
    for (double x = -20; x < size.width + 20; x += spacing) {
      final path = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(x + 18, size.height * 0.35, x - 10, size.height);
      canvas.drawPath(path, linePaint);
    }

    final beamRect = Rect.fromCenter(
      center: Offset(size.width * 0.78, size.height * 0.22),
      width: size.width * 0.28,
      height: size.height * 0.6,
    );
    canvas.drawOval(beamRect, beamPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
