import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/storage_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../auth/providers/auth_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';

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
    if (userId == null) return;
    final nutritionProvider = Provider.of<NutritionProvider>(
      context,
      listen: false,
    );
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final now = DateTime.now();
    await Future.wait([
      nutritionProvider.loadMealsByDate(userId, now),
      workoutProvider.loadWorkouts(userId),
    ]);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatInt(num value) {
    final raw = value.round().toString();
    return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  static const _mealTypeLabels = {
    'BREAKFAST': 'KahvaltÄ±',
    'LUNCH': 'Ã–ÄŸle',
    'DINNER': 'AkÅŸam',
    'SNACK': 'Ara Ã¶ÄŸÃ¼n',
  };

  static const _mealTypeIcons = {
    'BREAKFAST': Icons.wb_sunny_outlined,
    'LUNCH': Icons.wb_cloudy_outlined,
    'DINNER': Icons.nightlight_round_outlined,
    'SNACK': Icons.apple,
  };

  Widget _buildMealItem(IconData icon, String mealType, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _warmAccent.withValues(
                alpha: 0.15,
              ), // Slightly more opaque
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _warmAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealType,
                  style: TextStyle(
                    color: _warmAccent.withValues(
                      alpha: 0.9,
                    ), // Accent color for label
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white, // Pure white for content
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildHeroCard({
    required double progress,
    required int dailyCalories,
    required int targetCalories,
  }) {
    final remaining = (targetCalories - dailyCalories).clamp(0, 999999);
    final progressPct = (progress * 100).round();
    return _glassCard(
      accentColor: _warmAccent,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günlük Hedef',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hedefinin %$progressPct kadari tamamlandi',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatInt(dailyCalories),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ' / ${_formatInt(targetCalories)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ' kcal',
                        style: TextStyle(
                          color: _warmAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _warmAccent.withValues(alpha: 0.3),
                    width: 4,
                  ),
                  color: _warmAccent.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Text(
                    '%$progressPct',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8, // Thicker for visibility
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(_warmAccent),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _heroMetricV2(
                'Kalan',
                '${_formatInt(remaining)} kcal',
                _warmAccent,
              ),
              const SizedBox(width: 24),
              _heroMetricV2(
                'Hedef',
                '${_formatInt(targetCalories)} kcal',
                Colors.white,
              ),
              const Spacer(),
              // Mock data example - removed or kept based on need, kept for layout consistency
              _heroMetricV2('Tamam', '%$progressPct', _freshGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetricV2(String label, String value, Color color) {
    return Column(
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
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    VoidCallback? onTap,
  }) {
    return _glassCard(
      accentColor: accent,
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String? subtitle,
    required String actionLabel,
    required VoidCallback? onAction,
    required Color accent,
    required Widget child,
  }) {
    return _glassCard(
      accentColor: accent,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildActionPill(
                icon: Icons.add_rounded,
                label: actionLabel,
                onTap: onAction,
                accent: accent,
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
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

  Widget _buildEmptyHint({
    required IconData icon,
    required String title,
    required String message,
    required Color accent,
    required VoidCallback? onCta,
    required String cta,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildActionPill(
            icon: Icons.arrow_forward_rounded,
            label: cta,
            onTap: onCta,
            accent: accent,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetCalories = StorageHelper.getTargetCalories() ?? 2000;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppGradientBackground(
        imagePath: 'assets/images/dc02dfc9-c143-4c87-a0fa-2beaf6736dab.png',
        lightOverlay: true,
        child: Stack(
          children: [
            const _DashboardBackdrop(),
            SafeArea(
              child: Consumer4<AuthProvider, NutritionProvider, WorkoutProvider, DietProvider>(
                builder:
                    (
                      context,
                      authProvider,
                      nutritionProvider,
                      workoutProvider,
                      dietProvider,
                      child,
                    ) {
                      final dailyCalories = nutritionProvider.dailyCalories;
                      final progress = (dailyCalories / targetCalories).clamp(
                        0.0,
                        1.0,
                      );
                      final todayMeals = nutritionProvider.meals;
                      final now = DateTime.now();
                      final todayWorkouts = workoutProvider.workouts
                          .where((w) => _isSameDay(w.workoutDate, now))
                          .toList();
                      final firstWorkout = todayWorkouts.isNotEmpty
                          ? todayWorkouts.first
                          : null;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTopHeader(
                                  context: context,
                                  displayName:
                                      dietProvider.profile?.name ??
                                      authProvider.user?.name ??
                                      'Kullanici',
                                )
                                .animate()
                                .fadeIn(duration: 220.ms)
                                .slideY(
                                  begin: -0.03,
                                  end: 0,
                                  duration: 220.ms,
                                  curve: Curves.easeOut,
                                ),
                            const SizedBox(height: 14),
                            _buildHeroCard(
                                  progress: progress,
                                  dailyCalories: dailyCalories,
                                  targetCalories: targetCalories,
                                )
                                .animate()
                                .fadeIn(duration: 240.ms)
                                .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  duration: 240.ms,
                                  curve: Curves.easeOut,
                                ),
                            const SizedBox(height: 14),
                            Row(
                                  children: [
                                    Expanded(
                                      child: _buildQuickActionCard(
                                        icon: Icons.restaurant_menu_rounded,
                                        title: 'Ogun Ekle',
                                        subtitle: 'Kalori takibini guncelle',
                                        accent: _warmAccent,
                                        onTap: widget.onAddMeal,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuickActionCard(
                                        icon: Icons.fitness_center_rounded,
                                        title: 'Antrenmani Baslat',
                                        subtitle:
                                            'Bugunku performansini kaydet',
                                        accent: _freshGreen,
                                        onTap: widget.onStartWorkout,
                                      ),
                                    ),
                                  ],
                                )
                                .animate()
                                .fadeIn(delay: 70.ms, duration: 240.ms)
                                .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  duration: 240.ms,
                                  curve: Curves.easeOut,
                                ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                                  title: 'Beslenme Ozeti',
                                  subtitle: todayMeals.isEmpty
                                      ? 'Bugun henuz ogun kaydi yok'
                                      : '${todayMeals.length} ogun kayitli, hedefin %${(progress * 100).round()} tamam',
                                  actionLabel: 'Ogun Ekle',
                                  onAction: widget.onAddMeal,
                                  accent: _warmAccent,
                                  child: todayMeals.isEmpty
                                      ? _buildEmptyHint(
                                          icon: Icons.restaurant_outlined,
                                          title: 'Ogun kaydi bulunamadi',
                                          message:
                                              'Ilk ogunu ekleyerek kalori hedefini daha net takip et.',
                                          accent: _warmAccent,
                                          onCta: widget.onAddMeal,
                                          cta: 'Ilk Ogunu Ekle',
                                        )
                                      : Column(
                                          children: todayMeals.map((m) {
                                            final label =
                                                _mealTypeLabels[m.mealType] ??
                                                m.mealType;
                                            final icon =
                                                _mealTypeIcons[m.mealType] ??
                                                Icons.restaurant;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: _buildMealItem(
                                                icon,
                                                label,
                                                '${m.name} (${_formatInt(m.calories)} kcal)',
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                )
                                .animate()
                                .fadeIn(delay: 120.ms, duration: 240.ms)
                                .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  duration: 240.ms,
                                  curve: Curves.easeOut,
                                ),
                            const SizedBox(height: 14),
                            _buildSectionCard(
                                  title: 'Antrenman Durumu',
                                  subtitle: firstWorkout == null
                                      ? 'Bugun antrenman kaydin bulunmuyor'
                                      : null,
                                  actionLabel: 'Antrenmana Git',
                                  onAction: widget.onStartWorkout,
                                  accent: _softBlue,
                                  child: firstWorkout == null
                                      ? _buildEmptyHint(
                                          icon: Icons.fitness_center_outlined,
                                          title: 'Antrenman hazir bekliyor',
                                          message:
                                              'Tek tikla antrenmana basla ve bugunku ilerlemeyi kaydet.',
                                          accent: _softBlue,
                                          onCta: widget.onStartWorkout,
                                          cta: 'Antrenmani Baslat',
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: _softBlue.withValues(
                                                alpha: 0.22,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _softBlue.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.fitness_center_rounded,
                                                  color: _softBlue,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      firstWorkout.name,
                                                      style: AppTextStyles
                                                          .sectionSubtitle
                                                          .copyWith(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    if (firstWorkout
                                                            .durationMinutes !=
                                                        null) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${_formatInt(firstWorkout.durationMinutes!)} dk',
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.72,
                                                              ),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                )
                                .animate()
                                .fadeIn(delay: 170.ms, duration: 240.ms)
                                .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  duration: 240.ms,
                                  curve: Curves.easeOut,
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

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -140,
            left: -70,
            child: _glowOrb(
              size: 300,
              colors: [
                _softBlue.withValues(alpha: 0.24),
                _softBlue.withValues(alpha: 0.0),
              ],
            ),
          ),
          Positioned(
            top: 120,
            right: -90,
            child: _glowOrb(
              size: 250,
              colors: [
                _warmAccent.withValues(alpha: 0.24),
                _warmAccent.withValues(alpha: 0.0),
              ],
            ),
          ),
          Positioned(
            bottom: -130,
            left: -60,
            child: _glowOrb(
              size: 280,
              colors: [_freshGreen.withValues(alpha: 0.16), Colors.transparent],
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb({required double size, required List<Color> colors}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors, stops: const [0, 1]),
      ),
    );
  }
}
