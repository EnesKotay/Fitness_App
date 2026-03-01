import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../controllers/ai_coach_controller.dart';
import '../../tasks/controllers/daily_tasks_controller.dart';
import '../widgets/coach_prompt_box.dart';
import '../widgets/daily_summary_card.dart';
import '../widgets/goal_selector.dart';
import '../widgets/suggestion_list.dart';

class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AiCoachController>(
          create: (_) => AiCoachController(),
        ),
        ChangeNotifierProvider<DailyTasksController>(
          create: (_) => DailyTasksController()..loadToday(),
        ),
      ],
      child: const AiCoachScreenBody(),
    );
  }
}

class AiCoachScreenBody extends StatelessWidget {
  const AiCoachScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AiCoachController>(
      builder: (context, controller, _) {
        final tasksController = context.watch<DailyTasksController?>();

        return Scaffold(
          backgroundColor: const Color(0xFF070B16),
          appBar: AppBar(
            title: Text(
              'AI Koc',
              style: GoogleFonts.cinzel(
                color: const Color(0xFFF6ECD2),
                fontWeight: FontWeight.w700,
                fontSize: 21,
                letterSpacing: 0.6,
              ),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFFF8F2DF),
            elevation: 0,
            actions: const [_PremiumBadge()],
          ),
          body: Stack(
            children: [
              const _PremiumBackground(),
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: ListView(
                          children: [
                            GoalSelector(
                                  goal: controller.goal,
                                  onChanged: controller.setGoal,
                                )
                                .animate()
                                .fadeIn(duration: 360.ms, curve: Curves.easeOut)
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  duration: 380.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: 12),
                            DailySummaryCard(
                                  goal: controller.goal,
                                  summary: controller.dailySummary,
                                )
                                .animate()
                                .fadeIn(duration: 360.ms, curve: Curves.easeOut)
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  duration: 380.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: 12),
                            SuggestionList(
                                  advice: controller.advice,
                                  isLoading: controller.isLoading,
                                  errorMessage: controller.errorMessage,
                                  canRetry: controller.canRetryLastPrompt,
                                  onRetry: controller.retryLastPrompt,
                                  showLoginButton: controller.isSessionError,
                                  cooldownSecondsRemaining:
                                      controller.cooldownSecondsRemaining,
                                  onLoginRequired: () => Navigator.of(
                                    context,
                                  ).pushReplacementNamed('/login'),
                                  plannedActionsByTitle:
                                      tasksController?.tasksByNormalizedTitle ??
                                      const {},
                                  onAddActionToPlan: tasksController == null
                                      ? null
                                      : (title) {
                                          final alreadyInPlan =
                                              tasksController.taskForTitle(
                                                title,
                                              ) !=
                                              null;
                                          tasksController.addFromAiAction(title).then((
                                            _,
                                          ) {
                                            if (!context.mounted) {
                                              return;
                                            }
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  alreadyInPlan
                                                      ? 'Gorev bugun zaten planda.'
                                                      : 'Gorev bugunku plana eklendi.',
                                                ),
                                              ),
                                            );
                                          });
                                        },
                                  onToggleActionTaskDone:
                                      tasksController == null
                                      ? null
                                      : (taskId) {
                                          tasksController.toggleTaskDone(
                                            taskId,
                                          );
                                        },
                                )
                                .animate()
                                .fadeIn(duration: 360.ms, curve: Curves.easeOut)
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  duration: 380.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child:
                          CoachPromptBox(
                                isLoading: controller.isLoading,
                                cooldownSecondsRemaining:
                                    controller.cooldownSecondsRemaining,
                                onSend: controller.submitPrompt,
                                quickPrompts: controller.quickPrompts,
                                maxLength: AiCoachController.maxPromptLength,
                              )
                              .animate()
                              .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                              .slideY(
                                begin: 0.08,
                                end: 0,
                                duration: 400.ms,
                                curve: Curves.easeOutCubic,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD37A), Color(0xFFCD8F35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE9B858).withValues(alpha: 0.45),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          'PREMIUM',
          style: GoogleFonts.dmSans(
            color: const Color(0xFF241607),
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF060912),
                  Color(0xFF0A1326),
                  Color(0xFF090E1C),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -70,
            child: _GlowOrb(
              size: 240,
              colors: const [Color(0xFFEFB756), Color(0x00EFB756)],
            ),
          ),
          Positioned(
            top: 180,
            right: -80,
            child: _GlowOrb(
              size: 260,
              colors: const [Color(0xFF3D8AF7), Color(0x003D8AF7)],
            ),
          ),
          Positioned(
            bottom: -110,
            left: -50,
            child: _GlowOrb(
              size: 280,
              colors: const [Color(0xFF48D7B8), Color(0x0048D7B8)],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
