import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'profile_setup_page.dart';
import '../../domain/entities/meal_type.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../widgets/date_strip.dart';
import '../widgets/visual_meal_card.dart';
import '../widgets/water_tracker.dart';
import '../widgets/meal_suggestion_sheet.dart';
import '../widgets/edit_entry_sheet.dart';
import '../../domain/entities/food_entry.dart';
import '../../../../core/widgets/ambient_glow_background.dart';
import '../widgets/scan_options_sheet.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/micro_nutrients_sheet.dart';
import '../../domain/repositories/diary_repository.dart';
import '../../../../core/services/page_guide_service.dart';
import '../../../../core/widgets/page_guide_overlay.dart';
import '../../../../core/widgets/page_guide_button.dart';

class DietDashboardPage extends StatefulWidget {
  const DietDashboardPage({super.key});

  @override
  State<DietDashboardPage> createState() => _DietDashboardPageState();
}

class _DietDashboardPageState extends State<DietDashboardPage> {
  int _waterGlasses = 0;
  String? _waterDateKey;
  int _waterGoalGlasses = 8;
  bool _didInitialLoadAttempt = false;
  Map<String, DiaryTotals> _weeklyData = {};
  bool _profileBannerDismissed = false;

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '🍽️',
      title: 'Öğün Ekleme',
      description:
          'Kahvaltı, öğle, akşam ve ara öğün eklemek için her öğünün sağ tarafındaki "+" butonuna dokun. Yemek ara, miktarı gir ve kaydet.',
      tip: 'Sık yediğin yemekler "Son Yenenler" listesinde otomatik çıkar — hızlıca ekleyebilirsin.',
    ),
    GuideStep(
      emoji: '🔢',
      title: 'Kalori & Makro Halkaları',
      description:
          'Üstteki renkli halkalar günlük kalori, protein, karb ve yağ tüketimini gösterir. Halka tam dolunca o makro hedefine ulaştın demektir.',
      tip: 'Bir halkaya dokununca detaylı gram ve yüzde bilgisini görebilirsin.',
    ),
    GuideStep(
      emoji: '📷',
      title: 'Kamera ile Tara',
      description:
          'Sağ alttaki kamera butonuna dokun:\n• Barkod — paketli ürünler için\n• Fotoğraf — tabaktaki yemeği AI analiz eder\n• Etiket OCR — besin tablosunu kameraya tut\nHepsi otomatik beslenmeye eklenir.',
      tip: 'Barkod tarama en hızlı ve en doğru yöntem — süpermarket ürünlerinin büyük çoğunluğu veritabanında mevcut.',
    ),
    GuideStep(
      emoji: '💧',
      title: 'Su Takibi',
      description:
          'Sayfayı aşağı kaydır → Su Takibi kartını bul → bardak ikonlarına dokun veya "+" ile ml ekle. Günlük su hedefin sağ üstte gösterilir.',
      tip: 'Günde 8 bardak (≈2000 ml) hedefle. Hedefini Profil → Ayarlar\'dan değiştirebilirsin.',
    ),
    GuideStep(
      emoji: '📅',
      title: 'Geçmiş Günlere Bak',
      description:
          'Üstteki tarih şeridini sola kaydır → istediğin güne git → o günkü öğün ve makroları gör. Beslenme geçmişini dilediğin zaman inceleyebilirsin.',
      tip: 'Haftalık trendler için Araçlar sekmesi → Beslenme Trendi\'ne git.',
    ),
  ];

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('nutrition')) return;
    await PageGuideService.markGuideSeen('nutrition');
    if (mounted) await _showGuide();
  }

  @override
  void initState() {
    super.initState();
    final rawWaterGoal = StorageHelper.getWaterGoalML();
    final waterGoalML = (rawWaterGoal > 0) ? rawWaterGoal : 2000;
    _waterGoalGlasses = (waterGoalML / 250).round().clamp(6, 20);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          if (_didInitialLoadAttempt) return;
          _didInitialLoadAttempt = true;
          final provider = Provider.of<DietProvider>(context, listen: false);
          if (provider.profile == null && !provider.loading) {
            provider.init();
          }
          _loadWeeklyData();
        } catch (e) {
          debugPrint('DietDashboardPage init hatası: $e');
        }
      }
      await _checkFirstVisitGuide();
    });
  }

  Future<void> _loadWeeklyData() async {
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final data = await provider.getWeeklySummary();
      if (mounted) setState(() => _weeklyData = data);
    } catch (e) {
      debugPrint('DietDashboardPage._loadWeeklyData error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DietProvider>(
      builder: (context, provider, _) {
        final hasNoEntries = provider.entries.isEmpty;
        final showLoading = provider.loading && hasNoEntries;
        final showError = provider.error != null && hasNoEntries;

        final bodyContent = showLoading
            ? _buildLoadingState()
            : (showError
                  ? _buildErrorState(context, provider)
                  : _buildMainContent(context, provider));

        return Scaffold(
          backgroundColor: AppColors.background,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(context, provider),
          floatingActionButton: provider.loading ? null : _buildFAB(context),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: AppGradientBackground(
            imagePath: 'assets/images/nutrition_bg_dark.png',
            child: Stack(
              children: [
                const AmbientGlowBackground(),
                Positioned.fill(child: bodyContent),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, DietProvider provider) {
    final target = provider.effectiveTargetKcal.round();
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Beslenme',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              if (provider.currentStreak > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.orange, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '${provider.currentStreak} gün',
                        style: GoogleFonts.dmSans(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Text(
            'Hedef: $target kcal',
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(child: PageGuideButton(onTap: _showGuide)),
        ),
        GestureDetector(
          onTap: () {
            try {
              Navigator.of(context, rootNavigator: false).pushNamed('nutrition_guide');
            } catch (e) {
              debugPrint('nutrition_guide navigation: $e');
            }
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 14, color: AppColors.secondary),
                const SizedBox(width: 5),
                Text(
                  'Rehber',
                  style: GoogleFonts.dmSans(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Loading / Error ──────────────────────────────────────────────────────
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
            style: GoogleFonts.dmSans(
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
              child: Icon(Icons.error_outline_rounded, size: 48,
                  color: AppColors.error.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 20),
            Text('Veriler yüklenemedi',
                style: GoogleFonts.dmSans(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(provider.error ?? 'Bilinmeyen hata',
                style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
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

  // ─── Main Content ─────────────────────────────────────────────────────────
  Widget _buildMainContent(BuildContext context, DietProvider provider) {
    final targetKcal = provider.effectiveTargetKcal;
    final consumed = provider.totals.totalKcal;
    final remaining = provider.remainingKcal;
    final burned = provider.todayBurnedKcal;
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
            // ── Tarih şeridi ───────────────────────────────────────────────
            DateStrip(
              selectedDate: provider.selectedDate,
              onDateSelected: (date) => provider.loadDay(date),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 16),

            // ── Profil eksik uyarısı ───────────────────────────────────────
            if (provider.profile == null && !provider.loading && !_profileBannerDismissed) ...[
              _buildMissingProfileBanner(context),
              const SizedBox(height: 14),
            ],

            // ── Kalori + Makro hero kartı ──────────────────────────────────
            _buildCalorieHeroCard(
              provider: provider,
              consumed: consumed,
              target: targetKcal,
              burned: burned,
              remaining: remaining,
              progress: progress,
            ),
            const SizedBox(height: 12),

            // ── BMI chips (profil varsa) ───────────────────────────────────
            if (provider.profile != null && provider.bmi > 0) ...[
              _buildBmiInsightRow(provider),
              const SizedBox(height: 12),
            ],

            // ── Araçlar bölümü ─────────────────────────────────────────────
            _buildSectionHeader(
              icon: Icons.apps_rounded,
              label: 'Araçlar',
              accentColor: AppColors.primaryLight,
            ).animate().fadeIn(delay: 60.ms, duration: 300.ms),
            const SizedBox(height: 12),
            _buildToolsGrid(context),
            const SizedBox(height: 20),

            // ── Su takibi ──────────────────────────────────────────────────
            WaterTracker(
              currentGlasses: _waterGlasses,
              goalGlasses: _waterGoalGlasses,
              onChanged: (val) {
                setState(() => _waterGlasses = val);
                StorageHelper.saveWaterForDate(dateKey, val * 250);
              },
              onGoalTap: _showWaterGoalDialog,
            ).animate().fadeIn(delay: 80.ms, duration: 350.ms)
                .slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 20),

            // ── Öğünler bölümü ─────────────────────────────────────────────
            _buildSectionHeader(
              icon: Icons.restaurant_menu_rounded,
              label: 'Öğünler',
              accentColor: AppColors.secondary,
              trailing: Text(
                '${provider.entries.length} öğe',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ).animate().fadeIn(delay: 140.ms, duration: 300.ms),
            const SizedBox(height: 10),

            // ── Öğün kartları ──────────────────────────────────────────────
            ...MealType.values.map((type) {
              final index = type.index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VisualMealCard(
                  mealType: type,
                  entries: provider.entriesForMeal(type),
                  onAdd: () => _openSearch(context, type),
                  onDelete: (id) => provider.deleteEntry(id),
                  onEdit: (entry) => _showEditSheet(context, entry, provider),
                ).animate()
                    .fadeIn(delay: (160 + index * 40).ms, duration: 380.ms)
                    .slideX(begin: 0.02, end: 0, curve: Curves.easeOut),
              );
            }),

            // ── Haftalık özet ──────────────────────────────────────────────
            if (_weeklyData.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSectionHeader(
                icon: Icons.calendar_today_rounded,
                label: 'Haftalık Özet',
                accentColor: const Color(0xFF4FACFE),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 10),
              WeeklySummaryCard(
                weeklyData: _weeklyData,
                dailyTarget: provider.effectiveTargetKcal,
              ).animate().fadeIn(delay: 220.ms),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    Widget? trailing,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppColors.secondary;
    return Row(
      children: [
        // Sol aksent çubuk
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  // ─── Profile Banner ───────────────────────────────────────────────────────
  Widget _buildMissingProfileBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add_alt_1_rounded,
              color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kişisel hedeflerin için profilini tamamla.',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => ProfileSetupPage(
                    initial: context.read<DietProvider>().profile,
                    navigateToHomeOnSave: false,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Tamamla',
                style: GoogleFonts.dmSans(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _profileBannerDismissed = true),
            child: Icon(Icons.close_rounded,
                size: 18, color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  // ─── Calorie Hero Card ────────────────────────────────────────────────────
  Widget _buildCalorieHeroCard({
    required DietProvider provider,
    required double consumed,
    required double target,
    required double burned,
    required double remaining,
    required double progress,
  }) {
    final isOver = consumed > target && target > 0;
    final overAmount = isOver ? (consumed - target).round() : 0;
    final t = provider.totals;
    final targets = provider.macroTargets;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Üst kısım: ring + stats ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Halka
                    SizedBox(
                      width: 116,
                      height: 116,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 116,
                            height: 116,
                            child: CircularProgressIndicator(
                              value: 1,
                              strokeWidth: 10,
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                            duration: const Duration(milliseconds: 950),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => SizedBox(
                              width: 116,
                              height: 116,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isOver ? AppColors.warning : AppColors.secondary,
                                ),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isOver
                                    ? '+$overAmount'
                                    : remaining.round().toString(),
                                style: GoogleFonts.dmSans(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: isOver
                                      ? AppColors.warning
                                      : Colors.white,
                                  height: 1.0,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                isOver ? 'fazla' : 'kalan',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    // İstatistik sütunu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _kcalStatRow(
                            label: 'Tüketilen',
                            value: '${consumed.round()} kcal',
                            color: AppColors.secondary,
                          ),
                          const SizedBox(height: 10),
                          _kcalStatRow(
                            label: 'Hedef',
                            value: '${target.round()} kcal',
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          if (burned > 0) ...[
                            const SizedBox(height: 10),
                            _kcalStatRow(
                              label: 'Antrenman',
                              value: '+${burned.round()} kcal',
                              color: Colors.orangeAccent,
                              icon: Icons.bolt_rounded,
                            ),
                          ],
                          const SizedBox(height: 12),
                          // İlerleme durumu chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (isOver
                                      ? AppColors.warning
                                      : AppColors.secondary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (isOver
                                        ? AppColors.warning
                                        : AppColors.secondary)
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              isOver
                                  ? '$overAmount kcal hedefi aştın'
                                  : target > 0
                                      ? '%${(progress * 100).round()} tamamlandı'
                                      : 'Hedef belirlenmedi',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isOver
                                    ? AppColors.warning
                                    : AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────────────
              Divider(
                  color: Colors.white.withValues(alpha: 0.07),
                  height: 1,
                  indent: 20,
                  endIndent: 20),

              // ── Makro mini strip ──────────────────────────────────────────
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => MicroNutrientsSheet(totals: t),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
                  child: Row(
                    children: [
                      _miniMacro('Protein', t.totalProtein, targets.protein,
                          const Color(0xFF5B9BFF), icon: Icons.fitness_center_rounded),
                      _macroSeparator(),
                      _miniMacro('Karb', t.totalCarb, targets.carb,
                          const Color(0xFF4CD1A3), icon: Icons.grass_rounded),
                      _macroSeparator(),
                      _miniMacro('Yağ', t.totalFat, targets.fat,
                          const Color(0xFFFFB74D), icon: Icons.water_drop_rounded),
                      _macroSeparator(),
                      // "Detay" butonu
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Detay',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.5,
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '',
                            style: GoogleFonts.dmSans(fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  '* Kalori ve makro değerleri Mifflin-St Jeor formülüyle tahmin edilir. Kişisel metabolizma farklılık gösterebilir.',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.5,
                    color: Colors.white.withValues(alpha: 0.28),
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  Widget _kcalStatRow({
    required String label,
    required String value,
    required Color color,
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _miniMacro(String label, double value, double target, Color color, {IconData? icon}) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - value).clamp(0, double.infinity);
    final isComplete = value >= target && target > 0;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular progress with value inside
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 3.5,
                    color: color.withValues(alpha: 0.12),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete ? const Color(0xFF43E97B) : color,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${value.round()}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Target info
          Text(
            target > 0
                ? (isComplete ? '✓ ${target.round()}g' : '${remaining.round()}g kaldı')
                : '—',
            style: GoogleFonts.dmSans(
              fontSize: 9,
              color: isComplete
                  ? const Color(0xFF43E97B).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.35),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroSeparator() {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  // ─── BMI Insight Row ──────────────────────────────────────────────────────
  Widget _buildBmiInsightRow(DietProvider provider) {
    final bmi = provider.bmi;
    final category = provider.bmiCategory;

    Color bmiColor;
    IconData bmiIcon;
    if (bmi < 18.5) {
      bmiColor = const Color(0xFF4FACFE);
      bmiIcon = Icons.arrow_downward_rounded;
    } else if (bmi < 25) {
      bmiColor = const Color(0xFF43E97B);
      bmiIcon = Icons.check_circle_rounded;
    } else if (bmi < 30) {
      bmiColor = const Color(0xFFFFB347);
      bmiIcon = Icons.warning_amber_rounded;
    } else {
      bmiColor = const Color(0xFFFF6B6B);
      bmiIcon = Icons.priority_high_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bmiColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bmiColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bmiColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(bmiIcon, size: 14, color: bmiColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'VKİ: ${bmi.toStringAsFixed(1)} · $category',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  provider.bmiAdvice,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 60.ms, duration: 350.ms).slideY(begin: 0.03, end: 0);
  }

  // ─── Tools Grid ───────────────────────────────────────────────────────────
  Widget _buildToolsGrid(BuildContext context) {
    void navigate(String route) {
      try {
        Navigator.of(context, rootNavigator: false).pushNamed(route);
      } catch (e) {
        debugPrint('DietDashboardPage $route navigation: $e');
      }
    }

    // ── Üst: 2 büyük AI kartı ──────────────────────────────────────────────
    Widget bigCard({
      required String label,
      required String sublabel,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      required int delay,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: color.withValues(alpha: 0.4)),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(delay: delay.ms, duration: 350.ms)
          .slideX(begin: 0.04, end: 0, curve: Curves.easeOut);
    }

    // ── Alt: küçük yatay kart ──────────────────────────────────────────────
    Widget smallCard({
      required String label,
      required String sublabel,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      required int delay,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      Text(
                        sublabel,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: color.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: delay.ms, duration: 350.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
      );
    }

    return Column(
      children: [
        // Üst: AI araçları (büyük yatay kartlar)
        bigCard(
          label: 'AI Öğün Önerisi',
          sublabel: 'Hedefine uygun menü al',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.primaryLight,
          onTap: () => showMealSuggestionSheet(context),
          delay: 120,
        ),
        const SizedBox(height: 10),
        bigCard(
          label: 'Beslenme Rehberi',
          sublabel: 'Hedef bazlı makro & öğün planı',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFFFF9F0A),
          onTap: () => navigate('nutrition_guide'),
          delay: 150,
        ),
        const SizedBox(height: 10),

        // Alt: 4 küçük araç (2x2 satır)
        Row(
          children: [
            smallCard(
              label: 'Tara',
              sublabel: 'Barkod / fotoğraf',
              icon: Icons.qr_code_scanner_rounded,
              color: AppColors.secondary,
              onTap: () => ScanOptionsSheet.show(
                context,
                defaultMealType: MealType.snack,
                onSearchTap: () => _openSearch(context, null),
              ),
              delay: 180,
            ),
            const SizedBox(width: 10),
            smallCard(
              label: 'Trendler',
              sublabel: 'Grafikler',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF4FACFE),
              onTap: () => navigate('nutrition_trends'),
              delay: 200,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            smallCard(
              label: 'Haftalık Plan',
              sublabel: '7 günlük öğün',
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF43E97B),
              onTap: () => navigate('weekly_meal_plan'),
              delay: 220,
            ),
            const SizedBox(width: 10),
            smallCard(
              label: 'Alışveriş',
              sublabel: 'Akıllı liste',
              icon: Icons.shopping_cart_outlined,
              color: const Color(0xFFFFB347),
              onTap: () => navigate('smart_grocery_list'),
              delay: 240,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            smallCard(
              label: 'Tarifler',
              sublabel: 'Bowl, yemek & daha fazlası',
              icon: Icons.menu_book_rounded,
              color: const Color(0xFFB467FF),
              onTap: () => navigate('recipes'),
              delay: 260,
            ),
            const SizedBox(width: 10),
            smallCard(
              label: 'Diyet Sohbeti',
              sublabel: 'AI beslenme asistanı',
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFF5AC8FA),
              onTap: () => navigate('diet_chat'),
              delay: 280,
            ),
          ],
        ),
      ],
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────
  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => ScanOptionsSheet.show(
        context,
        defaultMealType: MealType.snack,
        onSearchTap: () => _openSearch(context, null),
      ),
      backgroundColor: AppColors.secondary,
      elevation: 8,
      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      label: Text(
        'Yemek Ekle',
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Future<void> _openSearch(BuildContext context, MealType? type) async {
    try {
      await Navigator.of(context, rootNavigator: false)
          .pushNamed('search', arguments: type ?? MealType.snack);
      if (!context.mounted) return;
      try {
        final provider = Provider.of<DietProvider>(context, listen: false);
        provider.loadDay(provider.selectedDate);
      } catch (e) {
        debugPrint('DietDashboardPage _openSearch callback hatası: $e');
      }
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Günlük su hedefi',
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selected bardak · ${selected * 250} ml',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: selected.toDouble(),
                    min: 6,
                    max: 20,
                    divisions: 14,
                    activeColor: AppColors.secondary,
                    onChanged: (v) =>
                        setDialogState(() => selected = v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('6',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                      Text('20 bardak',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7))),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      await StorageHelper.saveWaterGoalML(result * 250);
      if (!mounted) return;
      setState(() {
        _waterGoalGlasses = result;
        if (_waterGlasses > result) _waterGlasses = result;
      });
    }
  }

  void _showEditSheet(
      BuildContext context, FoodEntry entry, DietProvider provider) {
    EditEntrySheet.show(
      context,
      entry: entry,
      onSave: ({
        required String entryId,
        required double newGrams,
        required MealType newMealType,
      }) =>
          provider.updateEntry(
        entryId: entryId,
        newGrams: newGrams,
        newMealType: newMealType,
      ),
    );
  }
}
