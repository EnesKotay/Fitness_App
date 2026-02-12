import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/food_entry.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../widgets/date_strip.dart';
import '../widgets/visual_meal_card.dart';
import '../widgets/water_tracker.dart';
import '../widgets/meal_suggestion_sheet.dart';
import '../../../../core/widgets/ambient_glow_background.dart';

class DietDashboardPage extends StatefulWidget {
  const DietDashboardPage({super.key});

  @override
  State<DietDashboardPage> createState() => _DietDashboardPageState();
}

class _DietDashboardPageState extends State<DietDashboardPage> {
  int _waterGlasses = 0;
  String? _waterDateKey;
  int _waterGoalGlasses = 8;

  @override
  void initState() {
    super.initState();
    _waterGoalGlasses = (StorageHelper.getWaterGoalML() / 250).round().clamp(6, 20);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          Provider.of<DietProvider>(context, listen: false).init();
        } catch (e) {
          debugPrint('DietDashboardPage init hatası: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: AppGradientBackground(
        imagePath: 'assets/images/nutrition_bg.jpg',
        child: Stack(
          children: [
            const AmbientGlowBackground(),
            Consumer<DietProvider>(
              builder: (context, provider, _) {
                if (provider.loading && provider.profile == null && provider.entries.isEmpty) {
                  return _buildLoadingState();
                }
                if (provider.profile == null) {
                  return _buildNoProfile(context);
                }
                if (provider.error != null && provider.error!.isNotEmpty) {
                  return _buildErrorState(context, provider);
                }
                return _buildMainContent(context, provider);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'suggest',
            onPressed: () => showMealSuggestionSheet(context),
            backgroundColor: AppColors.surface,
            elevation: 6,
            child: Tooltip(
              message: 'Ne ekleyeyim? – Kalan makroya uygun öneriler',
              child: Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          _buildFAB(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Beslenme',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 22),
          onPressed: () {
            try {
              Navigator.of(context, rootNavigator: false).pushNamed('diet_chat');
            } catch (e) {
              debugPrint('DietDashboardPage diet_chat hatası: $e');
            }
          },
          tooltip: 'Beslenme asistanı',
        ),
        Consumer<DietProvider>(
          builder: (context, provider, _) {
            final hasProfile = provider.profile != null;
            final name = provider.profile?.name;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (hasProfile) {
                      Navigator.of(context, rootNavigator: true).pushNamed('/profile');
                    } else {
                      Navigator.of(context, rootNavigator: true).pushNamed('/profile-setup');
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Tooltip(
                    message: hasProfile ? 'Profilim' : 'Profil oluştur',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasProfile
                                  ? AppColors.secondary.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.1),
                              border: Border.all(
                                color: hasProfile ? AppColors.secondary : Colors.white24,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              hasProfile ? Icons.person_rounded : Icons.person_outline_rounded,
                              size: 18,
                              color: hasProfile ? AppColors.secondary : Colors.white70,
                            ),
                          ),
                          if (hasProfile && name != null && name.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (!kReleaseMode)
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orangeAccent, size: 22),
            onPressed: () {
              try {
                Navigator.of(context, rootNavigator: false).pushNamed('test_mode');
              } catch (e) {
                debugPrint('DietDashboardPage test_mode navigation hatası: $e');
              }
            },
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DietProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 20),
            Text(
              'Veriler yüklenemedi',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'Bilinmeyen hata',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.init(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Tekrar Dene'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, DietProvider provider) {
    final baseTarget = provider.dailyTargetKcal ?? 2000;
    final burned = provider.todayBurnedKcal;
    final targetKcal = provider.effectiveTargetKcal;
    final consumed = provider.totals.totalKcal;
    final remaining = provider.remainingKcal;
    final progress = targetKcal > 0 ? (consumed / targetKcal).clamp(0.0, 1.0) : 0.0;
    final dateKey = DateFormat('yyyy-MM-dd').format(provider.selectedDate);
    if (dateKey != _waterDateKey) {
      _waterDateKey = dateKey;
      final keyToLoad = dateKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _waterDateKey != keyToLoad) return;
        final ml = StorageHelper.getWaterForDate(keyToLoad);
        setState(() => _waterGlasses = (ml / 250).round().clamp(0, _waterGoalGlasses));
      });
    }

    return RefreshIndicator(
      onRefresh: () => provider.init(),
      color: AppColors.secondary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
          left: 16,
          right: 16,
          bottom: 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarih şeridi
            DateStrip(
              selectedDate: provider.selectedDate,
              onDateSelected: (date) => provider.loadDay(date),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 20),

            // Kalori hero kartı
            _buildCalorieHeroCard(
              consumed: consumed, 
              target: targetKcal, 
              baseTarget: baseTarget,
              burned: burned,
              remaining: remaining, 
              progress: progress
            ),
            const SizedBox(height: 16),

            // Makro özet satırı
            _buildMacroRow(provider),
            const SizedBox(height: 16),

            // Su takibi (seçili güne göre kalıcı, hedef ayarlanabilir)
            WaterTracker(
              currentGlasses: _waterGlasses,
              goalGlasses: _waterGoalGlasses,
              onChanged: (val) {
                setState(() => _waterGlasses = val);
                StorageHelper.saveWaterForDate(dateKey, val * 250);
              },
              onGoalTap: _showWaterGoalDialog,
            ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 24),

            // Akıllı Asistan Öne Çıkarma Kartı (Yeni kullanıcılara yol gösterir)
            _buildAssistantSpotlight(context, provider),
            const SizedBox(height: 24),

            // Öğünler başlığı
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu_rounded, size: 20, color: AppColors.secondary.withValues(alpha: 0.9)),
                  const SizedBox(width: 8),
                  Text(
                    'Öğünler',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 350.ms),

            // Öğün kartları
            ...MealType.values.map((type) {
              final index = type.index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: VisualMealCard(
                  mealType: type,
                  entries: provider.entriesForMeal(type),
                  onAdd: () => _openSearch(context, type),
                  onDelete: (id) => provider.deleteEntry(id),
                ),
              ).animate().fadeIn(delay: (180 + index * 50).ms, duration: 400.ms).slideX(begin: 0.02, end: 0, curve: Curves.easeOut);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieHeroCard({
    required double consumed,
    required double target,
    required double baseTarget,
    required double burned,
    required double remaining,
    required double progress,
  }) {
    final isOver = consumed > target && target > 0;
    final overAmount = isOver ? (consumed - target).round() : 0;
    return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 10,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 1 ? AppColors.warning : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isOver ? '0' : remaining.round().toString(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.0,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            Text(
                              isOver ? 'kalan kcal' : 'kalan kcal',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${consumed.round()} / ${target.round()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bugünkü kalori',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            burned > 0 ? Icons.bolt_rounded : (progress >= 1 ? Icons.check_circle_rounded : Icons.local_fire_department_rounded),
                            size: 15,
                            color: burned > 0 ? Colors.orangeAccent : (progress >= 1 ? AppColors.success : AppColors.secondary),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              burned > 0 
                                  ? 'Antrenman: +${burned.round()} kcal bonus!'
                                  : (progress >= 1
                                      ? (isOver ? '$overAmount kcal aştın' : 'Hedef tamamlandı')
                                      : 'Hedefine ${remaining.round()} kcal kaldı'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ],
      ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  Widget _buildMacroRow(DietProvider provider) {
    final targets = provider.macroTargets;
    final t = provider.totals;
    final items = [
      (label: 'Protein', value: t.totalProtein, target: targets.protein, color: const Color(0xFF5B9BFF), icon: Icons.fitness_center_rounded),
      (label: 'Karb.', value: t.totalCarb, target: targets.carb, color: const Color(0xFF4CD1A3), icon: Icons.grain_rounded),
      (label: 'Yağ', value: t.totalFat, target: targets.fat, color: const Color(0xFFFFB74D), icon: Icons.water_drop_rounded),
    ];

    return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.pie_chart_rounded, size: 20, color: AppColors.secondary.withValues(alpha: 0.95)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugünkü makrolar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hedefler kilona göre hesaplanıyor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < items.length - 1 ? 18 : 0),
              child: _buildMacroItem(
                label: item.label,
                value: item.value,
                target: item.target,
                color: item.color,
                icon: item.icon,
              ),
            );
          }),
        ],
      ),
        ),
      ),
    ).animate().fadeIn(delay: 50.ms, duration: 400.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOut);
  }

  Widget _buildMacroItem({
    required String label,
    required double value,
    required double target,
    required Color color,
    required IconData icon,
  }) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final isOver = target > 0 && value > target;
    final displayProgress = isOver ? 1.0 : progress;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    '${value.round()} / ${target.round()}g',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isOver ? color : Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          width: constraints.maxWidth * displayProgress,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isOver
                                  ? [color, color.withValues(alpha: 0.7)]
                                  : [color.withValues(alpha: 0.9), color],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (isOver && value > target)
                          Positioned(
                            right: 6,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Text(
                                '+${(value - target).round()}g',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _openSearch(context, null),
      backgroundColor: AppColors.secondary,
      elevation: 8,
      focusElevation: 12,
      hoverElevation: 10,
      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      label: const Text(
        'Yemek Ekle',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildAssistantSpotlight(BuildContext context, DietProvider provider) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.5),
            AppColors.secondary.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 28)
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 2.seconds, color: Colors.white24)
                  .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1), curve: Curves.easeInOutSine),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bugün ne yesem?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kalan makro hedeflerine göre yapay zeka senin için en iyi seçenekleri bulsun.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => showMealSuggestionSheet(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Hemen Öneri Al',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primaryLight),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 120.ms, duration: 400.ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  void _openSearch(BuildContext context, MealType? type) {
    try {
      Navigator.of(context, rootNavigator: false)
          .pushNamed('search', arguments: type ?? MealType.snack)
          .then((_) {
        if (mounted) {
          try {
            final provider = Provider.of<DietProvider>(context, listen: false);
            provider.loadDay(provider.selectedDate);
          } catch (e) {
            debugPrint('DietDashboardPage _openSearch callback hatası: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('DietDashboardPage _openSearch navigation hatası: $e');
    }
  }

  Future<void> _showWaterGoalDialog() async {
    int selected = _waterGoalGlasses;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Günlük su hedefi', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selected bardak (${selected * 250} ml)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: selected.toDouble(),
                    min: 6,
                    max: 20,
                    divisions: 14,
                    activeColor: AppColors.secondary,
                    onChanged: (v) => setDialogState(() => selected = v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('6', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                      Text('20 bardak', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      await StorageHelper.saveWaterGoalML(result * 250);
      setState(() {
        _waterGoalGlasses = result;
        if (_waterGlasses > result) _waterGlasses = result;
      });
    }
  }

  Widget _buildNoProfile(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(
                Icons.person_add_rounded,
                size: 56,
                color: AppColors.secondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Profilini Oluştur',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sana özel kalori hedefini hesaplamamız için\nprofil bilgilerine ihtiyacımız var.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                try {
                  Navigator.of(context, rootNavigator: false).pushNamed('profile').then((_) {
                    if (mounted) {
                      try {
                        Provider.of<DietProvider>(context, listen: false).init();
                      } catch (e) {
                        debugPrint('DietDashboardPage profile callback hatası: $e');
                      }
                    }
                  });
                } catch (e) {
                  debugPrint('DietDashboardPage profile navigation hatası: $e');
                }
              },
              icon: const Icon(Icons.person_rounded, size: 20),
              label: const Text('Profil Oluştur'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
