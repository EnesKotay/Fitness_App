import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/pro_badge.dart';
import '../../../core/widgets/premium_state_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/controllers/daily_tasks_controller.dart';
import '../../workout/providers/workout_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../auth/screens/premium_screen.dart';

const Color _warmAccent = Color(0xFFFFA56E);
const Color _freshGreen = Color(0xFF5FD8B7);
const Color _softBlue = Color(0xFF7BCBFF);

/// Ana sayfa (Dashboard) iÃ§eriÄŸi - gerÃ§ek veri: NutritionProvider, WorkoutProvider
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onAddMeal;
  final VoidCallback? onStartWorkout;

  /// Profil sayfasÄ±ndan "HÄ±zlÄ± eriÅŸim" ile dÃ¶nÃ¼ldÃ¼ÄŸÃ¼nde aÃ§Ä±lacak sekme (0=Ana, 1=Antrenman, 2=Takip, 3=Beslenme)
  final void Function(int index)? onNavigateToTab;

  const DashboardScreen({
    super.key,
    this.onAddMeal,
    this.onStartWorkout,
    this.onNavigateToTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHomeData());
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    final dietProvider = Provider.of<DietProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final weightProvider = Provider.of<WeightProvider>(context, listen: false);
    if (userId == null || userId <= 0) {
      // Oturum yoksa ekranda önceki hesaptan kalan provider state'i kalmasın.
      dietProvider.reset();
      workoutProvider.reset();
      weightProvider.reset();
      return;
    }
    try {
      final today = DateTime.now();
      await Future.wait([
        workoutProvider.loadWorkouts(userId),
        weightProvider.loadEntries(),
        dietProvider.loadDay(DateTime(today.year, today.month, today.day)),
      ]);
      final aiService = dietProvider.aiService;
      if (aiService != null) {
        final remotePremium = await aiService.checkPremiumStatus();
        if (remotePremium != null && mounted) {
          authProvider.setPremiumActive(remotePremium);
        }
      }
    } catch (e) {
      debugPrint('Dashboard._loadHomeData error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ana sayfa verileri yüklenirken hata oluştu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatInt(num value) {
    final raw = value.round().toString();
    return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _capitalizeFirst(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _goalLabel(Goal? goal) {
    switch (goal) {
      case Goal.cut:
        return 'Yag Yakimi';
      case Goal.bulk:
        return 'Kas Kazanimi';
      case Goal.strength:
        return 'Guc Artisi';
      case Goal.maintain:
      case null:
        return 'Kilo Koruma';
    }
  }

  String _heroTitleByGoal(Goal? goal) {
    switch (goal) {
      case Goal.cut:
        return 'Definasyon Modu';
      case Goal.bulk:
        return 'Hacim Modu';
      case Goal.strength:
        return 'Performans Modu';
      case Goal.maintain:
      case null:
        return 'Denge Modu';
    }
  }

  String _heroSubtitleByGoal(Goal? goal) {
    switch (goal) {
      case Goal.cut:
        return 'Kalori acigini kontrollu surdur';
      case Goal.bulk:
        return 'Kalori fazlasini temiz beslenmeyle tamamla';
      case Goal.strength:
        return 'Antrenman performansini beslenmeyle destekle';
      case Goal.maintain:
      case null:
        return 'Bugun ritmini koru ve istikrar sagla';
    }
  }

  Color _goalPrimaryColor(Goal? goal) {
    switch (goal) {
      case Goal.cut:
        return _freshGreen;
      case Goal.bulk:
        return _warmAccent;
      case Goal.strength:
        return _softBlue;
      case Goal.maintain:
      case null:
        return const Color(0xFF9FD5FF);
    }
  }

  Color _goalSecondaryColor(Goal? goal) {
    switch (goal) {
      case Goal.cut:
        return _softBlue;
      case Goal.bulk:
        return const Color(0xFFFFC084);
      case Goal.strength:
        return _freshGreen;
      case Goal.maintain:
      case null:
        return _warmAccent;
    }
  }


  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
    double radius = 32,
    Color? accentColor,
    VoidCallback? onTap,
  }) {
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // V3: Much darker, solid background for readability
            color: const Color(0xFF15171B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: (accentColor ?? Colors.white).withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        splashColor: (accentColor ?? Colors.white).withValues(alpha: 0.05),
        highlightColor: (accentColor ?? Colors.white).withValues(alpha: 0.02),
        child: panel,
      ),
    );
  }

  Widget _buildTopHeader({
    required BuildContext context,
    required String displayName,
  }) {
    final isPremium =
        context.watch<AuthProvider>().user?.premiumTier?.toLowerCase().trim() ==
        'premium';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merhaba, $displayName',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Bugun ritmini takip et ve hedefte kal.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // PRO Badge / Premium Button
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const PremiumScreen()),
            );
          },
          borderRadius: BorderRadius.circular(999),
          child: isPremium
              ? const PremiumStateBadge(active: true)
              : const ProBadge(),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/profile');
            if (result is int && widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(result);
            }
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44, // Slightly larger
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _softBlue.withValues(alpha: 0.5),
                  _warmAccent.withValues(alpha: 0.4),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _softBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumHubCard({
    required bool isPremium,
    required VoidCallback onManage,
    required VoidCallback onCoach,
    required VoidCallback onPhoto,
    required VoidCallback onTrends,
  }) {
    final accent = isPremium
        ? const Color(0xFFD9B15A)
        : const Color(0xFFD97706);
    final title = isPremium
        ? 'Premium araçların hazır'
        : 'Daha güçlü araçları aç';
    final subtitle = isPremium
        ? 'AI koç, foto analiz ve trendler sende aktif.'
        : 'AI analiz ve otomasyon katmanını tek yerden aç.';

    Widget quickChip({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _glassCard(
      accentColor: accent,
      radius: 24,
      padding: const EdgeInsets.all(16),
      onTap: onManage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPremium
                      ? Icons.verified_rounded
                      : Icons.workspace_premium_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              isPremium
                  ? const PremiumStateBadge(active: true, compact: true)
                  : const ProBadge(compact: true),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              quickChip(
                icon: Icons.smart_toy_rounded,
                label: isPremium ? 'AI Koç açık' : 'AI Koç',
                onTap: onCoach,
              ),
              quickChip(
                icon: Icons.camera_alt_rounded,
                label: isPremium ? 'Foto analiz açık' : 'Foto analiz',
                onTap: onPhoto,
              ),
              quickChip(
                icon: Icons.insights_rounded,
                label: isPremium ? 'Trendler açık' : 'Trendler',
                onTap: onTrends,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPremium
                ? 'Tüm premium AI araçlarına doğrudan erişebilirsin.'
                : 'Premium sayfasından üyeliği yönetebilir ve tüm araçların kilidini açabilirsin.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required Goal? goal,
    required Color calorieAccent,
    required Color proteinAccent,
    required double progress,
    required int dailyCalories,
    required int targetCalories,
    required double proteinProgress,
    required int dailyProtein,
    required int targetProtein,
    VoidCallback? onTapCalories,
    VoidCallback? onTapProtein,
    VoidCallback? onTapCard,
  }) {
    final remaining = (targetCalories - dailyCalories).clamp(0, 999999);
    final progressPct = (progress * 100).round();
    final proteinPct = (proteinProgress * 100).round();

    return _glassCard(
      accentColor: calorieAccent,
      padding: const EdgeInsets.all(24),
      onTap: onTapCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _heroTitleByGoal(goal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _heroSubtitleByGoal(goal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: calorieAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: calorieAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${_goalLabel(goal)} • %$progressPct',
                      style: TextStyle(
                        color: calorieAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Calorie Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: calorieAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'KALORİ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _formatInt(dailyCalories),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${_formatInt(targetCalories)} kcal',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation(calorieAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Protein Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center_rounded,
                          size: 14,
                          color: proteinAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PROTEİN',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: dailyProtein.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: ' / $targetProtein g',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: proteinProgress,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation(proteinAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _heroMetricV2(
                'Kalan Kalori',
                '${_formatInt(remaining)} kcal',
                calorieAccent,
                onTap: onTapCalories,
              ),
              const SizedBox(width: 24),
              _heroMetricV2(
                'Protein %',
                '%$proteinPct',
                proteinAccent,
                onTap: onTapProtein,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoryFlowCard({
    required bool mealDone,
    required bool workoutDone,
    required bool trackingDone,
    required Color accent,
    VoidCallback? onMealTap,
    VoidCallback? onWorkoutTap,
    VoidCallback? onTrackingTap,
  }) {
    Widget step({
      required String title,
      required bool done,
      required IconData icon,
      VoidCallback? onTap,
    }) {
      final panel = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: done
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? accent.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : icon,
              color: done ? accent : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      return Expanded(
        child: onTap == null
            ? panel
            : InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: panel,
              ),
      );
    }

    return _glassCard(
      accentColor: accent,
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugun Akisi',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              step(
                title: 'Beslenme',
                done: mealDone,
                icon: Icons.restaurant_menu_rounded,
                onTap: onMealTap,
              ),
              const SizedBox(width: 8),
              step(
                title: 'Antrenman',
                done: workoutDone,
                icon: Icons.fitness_center_rounded,
                onTap: onWorkoutTap,
              ),
              const SizedBox(width: 8),
              step(
                title: 'Takip',
                done: trackingDone,
                icon: Icons.monitor_weight_rounded,
                onTap: onTrackingTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusErrorCard({
    required String message,
    required Color accent,
    required VoidCallback onRetry,
  }) {
    return _glassCard(
      accentColor: Colors.redAccent,
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildActionPill(
            icon: Icons.refresh_rounded,
            label: 'Tekrar Dene',
            onTap: onRetry,
            accent: accent,
          ),
        ],
      ),
    );
  }


  Widget _heroMetricV2(
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 11.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: content,
      ),
    );
  }

  Widget _skeletonLine({double width = double.infinity, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildSkeletonCard({
    double height = 120,
    Color accent = Colors.white,
  }) {
    return SizedBox(
      height: height,
      child: _glassCard(
        accentColor: accent,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _skeletonLine(width: 140, height: 16),
            _skeletonLine(width: 220),
            _skeletonLine(width: 190),
            _skeletonLine(width: 120, height: 14),
          ],
        ),
      ),
    );
  }


  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color accent,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.2), // More visible
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color accentColor,
    required Color subtextColor,
    VoidCallback? onTap,
  }) {
    return _glassCard(
      accentColor: accentColor,
      padding: const EdgeInsets.all(16),
      radius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: subtextColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakActivityRow({
    required int streak,
    required int netKcal,
    required int burnedKcal,
    required Color accent,
  }) {
    Widget chip({
      required IconData icon,
      required String label,
      required String value,
      required Color color,
      VoidCallback? onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Streak badge rengi
    final streakColor = streak >= 30
        ? const Color(0xFFFFD700)
        : streak >= 7
            ? const Color(0xFFFFA56E)
            : streak >= 3
                ? _freshGreen
                : Colors.white54;
    final streakLabel = streak >= 30
        ? '🔥 $streak Gün Seri'
        : streak >= 7
            ? '🔥 $streak Gün'
            : streak > 0
                ? '$streak Gün'
                : '—';

    final netColor = netKcal <= 0 ? _freshGreen : _warmAccent;

    return Row(
      children: [
        chip(
          icon: Icons.local_fire_department_rounded,
          label: 'SERİ',
          value: streakLabel,
          color: streakColor,
        ),
        const SizedBox(width: 8),
        chip(
          icon: Icons.bolt_rounded,
          label: 'NET KALORİ',
          value: netKcal >= 0 ? '+$netKcal kcal' : '$netKcal kcal',
          color: netColor,
        ),
        const SizedBox(width: 8),
        chip(
          icon: Icons.fitness_center_rounded,
          label: 'YAKILAN',
          value: burnedKcal > 0 ? '$burnedKcal kcal' : '—',
          color: _softBlue,
        ),
      ],
    );
  }

  Widget _buildMealSummaryCard({
    required List<dynamic> todayEntries,
    required int dailyCalories,
    required double progress,
    required Color primaryAccent,
  }) {
    final hasEntries = todayEntries.isNotEmpty;
    return _glassCard(
      accentColor: primaryAccent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 22,
      onTap: () => widget.onNavigateToTab?.call(3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              color: primaryAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bugünün Öğünleri',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasEntries
                      ? '${todayEntries.length} öğün · $dailyCalories kcal · %${(progress * 100).round()} tamamlandı'
                      : 'Henüz öğün kaydı yok. İlk öğünü ekle.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildActionPill(
            icon: Icons.add_rounded,
            label: 'Ekle',
            onTap: widget.onAddMeal,
            accent: primaryAccent,
          ),
        ],
      ),
    );
  }


  Widget _buildDailyTasksCard({
    required int completed,
    required int total,
    required List<dynamic> tasks,
    required Color accent,
  }) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return _glassCard(
      accentColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 22,
      onTap: () => Navigator.of(context).pushNamed('/daily-tasks'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.checklist_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Günlük Görevler',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total == 0
                          ? 'Henüz görev eklenmedi'
                          : '$completed/$total tamamlandı · %${(ratio * 100).toInt()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildActionPill(
                icon: Icons.open_in_new_rounded,
                label: 'Aç',
                onTap: () => Navigator.of(context).pushNamed('/daily-tasks'),
                accent: accent,
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...tasks.map((t) {
                final task = t as dynamic;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Icon(
                        task.isDone
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: task.isDone ? accent : Colors.white30,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: task.isDone
                                ? Colors.white38
                                : Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppGradientBackground(
        imagePath: 'assets/images/anasayfa.png',
        imageFit: BoxFit.cover,
        imageAlignment: Alignment.center,
        lightOverlay: true,
        child: Stack(
          children: [
            const SizedBox.shrink(),
            SafeArea(
              child: Consumer4<AuthProvider, WorkoutProvider, DietProvider, WeightProvider>(
                builder:
                    (
                      context,
                      authProvider,
                      workoutProvider,
                      dietProvider,
                      weightProvider,
                      child,
                    ) {
                      final targetCalories = dietProvider.effectiveTargetKcal
                          .round();
                      final dailyCalories = dietProvider.totals.totalKcal
                          .round();
                      final progress = targetCalories > 0
                          ? (dailyCalories / targetCalories).clamp(0.0, 1.0)
                          : 0.0;
                      final todayEntries = dietProvider.entries;

                      final macroTargets = dietProvider.macroTargets;
                      final dailyProtein = dietProvider.totals.totalProtein
                          .round();
                      final targetProtein = macroTargets.protein.round();
                      final proteinProgress = targetProtein > 0
                          ? (dailyProtein / targetProtein).clamp(0.0, 1.0)
                          : 0.0;

                      final now = DateTime.now();
                      final todayWorkouts = workoutProvider.workouts
                          .where((w) => _isSameDay(w.workoutDate, now))
                          .toList();
                      final firstWorkout = todayWorkouts.isNotEmpty
                          ? todayWorkouts.first
                          : null;
                      final displayName = _capitalizeFirst(
                        dietProvider.profile?.name ??
                            authProvider.user?.name ??
                            'Kullanici',
                      );
                      final goal = dietProvider.profile?.goal;
                      final hasWorkoutToday = firstWorkout != null;
                      final isDietLoading = dietProvider.loading;
                      final isWorkoutLoading = workoutProvider.isLoading;
                      final isWeightLoading = weightProvider.isLoading;
                      final primaryAccent = _goalPrimaryColor(goal);
                      final secondaryAccent = _goalSecondaryColor(goal);
                      final nutritionDone =
                          progress >= 0.8 && proteinProgress >= 0.8;
                      final trackingDone =
                          weightProvider.latestEntry != null &&
                          _isSameDay(weightProvider.latestEntry!.date, now);
                      final isInitialCompositeLoading =
                          isDietLoading &&
                          isWorkoutLoading &&
                          isWeightLoading &&
                          todayEntries.isEmpty &&
                          weightProvider.entries.isEmpty &&
                          workoutProvider.workouts.isEmpty;
                      final firstError =
                          dietProvider.error ??
                          workoutProvider.errorMessage ??
                          weightProvider.error;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── 1. Header ──
                            _buildTopHeader(
                                  context: context,
                                  displayName: displayName,
                                )
                                .animate()
                                .fadeIn(duration: 200.ms)
                                .slideY(begin: -0.03, end: 0, duration: 200.ms, curve: Curves.easeOut),
                            const SizedBox(height: 16),

                            if (firstError != null) ...[
                              _buildStatusErrorCard(
                                message: 'Bazı veriler yüklenemedi: $firstError',
                                accent: primaryAccent,
                                onRetry: _loadHomeData,
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ── 2. Hero: Kalori + Protein ──
                            (isDietLoading && todayEntries.isEmpty)
                                ? _buildSkeletonCard(height: 190, accent: primaryAccent)
                                : _buildHeroCard(
                                        goal: goal,
                                        calorieAccent: primaryAccent,
                                        proteinAccent: secondaryAccent,
                                        progress: progress,
                                        dailyCalories: dailyCalories,
                                        targetCalories: targetCalories,
                                        proteinProgress: proteinProgress,
                                        dailyProtein: dailyProtein,
                                        targetProtein: targetProtein,
                                        onTapCalories: () => widget.onNavigateToTab?.call(3),
                                        onTapProtein: () => widget.onNavigateToTab?.call(3),
                                        onTapCard: () => widget.onNavigateToTab?.call(3),
                                      )
                                      .animate()
                                      .fadeIn(duration: 240.ms)
                                      .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut),
                            const SizedBox(height: 12),

                            // ── 3. Günlük akış (3-adım checklist) ──
                            isInitialCompositeLoading
                                ? _buildSkeletonCard(height: 80, accent: primaryAccent)
                                : _buildStoryFlowCard(
                                        mealDone: nutritionDone,
                                        workoutDone: hasWorkoutToday,
                                        trackingDone: trackingDone,
                                        accent: primaryAccent,
                                        onMealTap: () => widget.onNavigateToTab?.call(3),
                                        onWorkoutTap: () => widget.onNavigateToTab?.call(1),
                                        onTrackingTap: () => widget.onNavigateToTab?.call(2),
                                      )
                                      .animate()
                                      .fadeIn(delay: 40.ms, duration: 240.ms)
                                      .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut),
                            const SizedBox(height: 12),

                            // ── 4. Yan yana: Kilo + Antrenman ──
                            Row(
                              children: [
                                Expanded(
                                  child: isWeightLoading && weightProvider.latestEntry == null
                                      ? _buildSkeletonCard(height: 100, accent: secondaryAccent)
                                      : _buildStatTile(
                                          icon: Icons.monitor_weight_rounded,
                                          label: 'KİLO',
                                          value: weightProvider.latestEntry != null
                                              ? '${weightProvider.latestEntry!.weightKg.toStringAsFixed(1)} kg'
                                              : '—',
                                          subtext: weightProvider.weeklyChange == 0
                                              ? 'Stabil'
                                              : '${weightProvider.weeklyChange > 0 ? "+" : ""}${weightProvider.weeklyChange.toStringAsFixed(1)} kg bu hafta',
                                          accentColor: secondaryAccent,
                                          subtextColor: weightProvider.weeklyChange == 0
                                              ? Colors.white38
                                              : weightProvider.weeklyChange < 0
                                                  ? _freshGreen
                                                  : Colors.orangeAccent,
                                          onTap: () => widget.onNavigateToTab?.call(2),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: isWorkoutLoading && todayWorkouts.isEmpty
                                      ? _buildSkeletonCard(height: 100, accent: primaryAccent)
                                      : _buildStatTile(
                                          icon: Icons.fitness_center_rounded,
                                          label: 'ANTRENMAN',
                                          value: hasWorkoutToday
                                              ? '${todayWorkouts.length} kayıt'
                                              : 'Yok',
                                          subtext: firstWorkout?.name ?? 'Bugün kaydı yok',
                                          accentColor: primaryAccent,
                                          subtextColor: hasWorkoutToday
                                              ? primaryAccent.withValues(alpha: 0.75)
                                              : Colors.white38,
                                          onTap: () => widget.onNavigateToTab?.call(1),
                                        ),
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(delay: 60.ms, duration: 240.ms)
                                .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut),
                            const SizedBox(height: 12),

                            // ── 4b. Streak + Net Kalori + Yakılan ──
                            _buildStreakActivityRow(
                                  streak: dietProvider.currentStreak,
                                  netKcal: (dietProvider.totals.totalKcal - dietProvider.todayBurnedKcal).round(),
                                  burnedKcal: dietProvider.todayBurnedKcal.round(),
                                  accent: primaryAccent,
                                )
                                .animate()
                                .fadeIn(delay: 70.ms, duration: 240.ms)
                                .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut),
                            const SizedBox(height: 12),

                            // ── 5. Premium banner (kompakt) ──
                            _buildPremiumHubCard(
                                  isPremium: authProvider.user?.premiumTier?.toLowerCase().trim() == 'premium',
                                  onManage: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                                  ),
                                  onCoach: () => Navigator.of(context).pushNamed('/ai-coach'),
                                  onPhoto: () => widget.onNavigateToTab?.call(3),
                                  onTrends: () => Navigator.of(context).pushNamed('/nutrition-trends'),
                                )
                                .animate()
                                .fadeIn(delay: 80.ms, duration: 240.ms)
                                .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut),
                            const SizedBox(height: 12),

                            // ── 6. Öğün özeti (kompakt) ──
                            _buildMealSummaryCard(
                                  todayEntries: todayEntries,
                                  dailyCalories: dailyCalories,
                                  progress: progress,
                                  primaryAccent: primaryAccent,
                                )
                                .animate()
                                .fadeIn(delay: 100.ms, duration: 240.ms)
                                .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut),
                            const SizedBox(height: 12),

                            // ── 7. Günlük görev özeti ──
                            Consumer<DailyTasksController>(
                              builder: (ctx, tasksCtrl, _) =>
                                  _buildDailyTasksCard(
                                    completed: tasksCtrl.completedCount,
                                    total: tasksCtrl.totalCount,
                                    tasks: tasksCtrl.tasks.take(3).toList(),
                                    accent: primaryAccent,
                                  )
                                  .animate()
                                  .fadeIn(delay: 120.ms, duration: 240.ms)
                                  .slideY(begin: 0.04, end: 0, duration: 240.ms, curve: Curves.easeOut),
                            ),
                          ],
                        ),
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
