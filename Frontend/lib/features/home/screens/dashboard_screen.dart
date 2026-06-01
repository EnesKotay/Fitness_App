import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/pro_badge.dart';
import '../../../core/widgets/premium_state_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/controllers/daily_tasks_controller.dart';
import '../../tasks/models/daily_task.dart';
import '../../workout/providers/workout_provider.dart';
import '../../../core/models/workout.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../../nutrition/domain/entities/meal_type.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../auth/screens/premium_screen.dart';
import '../../workout/providers/streak_provider.dart';
import '../../tracking/screens/tracking_screen.dart';
import '../../workout/screens/achievements_screen.dart';
import '../../../core/utils/storage_helper.dart';
import '../../../core/services/app_review_service.dart';
import '../../../core/services/page_guide_service.dart';
import '../../../core/widgets/page_guide_overlay.dart';
import '../../../core/widgets/page_guide_button.dart';
import '../../workout/services/recovery_engine.dart';
import '../../tracking/providers/tracking_provider.dart';
import 'dart:async';

const Color _warmAccent = Color(0xFFFFA56E);
const Color _freshGreen = Color(0xFF5FD8B7);
const Color _softBlue = Color(0xFF7BCBFF);

/// Ana sayfa (Dashboard) içeriği - gerçek veri: NutritionProvider, WorkoutProvider
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onAddMeal;
  final VoidCallback? onStartWorkout;

  /// Profil sayfasindan "Hizli erisim" ile donuldugunde acilacak sekme
  /// (0=Ana, 1=Antrenman, 2=Takip, 3=Beslenme).
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
  SuggestedFoodInsight? _todayMealSuggestion;
  TodayWorkoutSuggestion? _todayWorkoutSuggestion;
  bool _didTryShowOnboardingSummary = false;
  bool _isAddingWater = false;

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '🏠',
      title: 'Ana Sayfa',
      description:
          'Bugünün planını, kalori durumunu ve hızlı aksiyonları burada görürsün.',
      tip: 'Güne nereden başlayacağını en üstteki plan kartı söyler.',
    ),
    GuideStep(
      emoji: '🔢',
      title: 'Kalori ve Makro',
      description:
          'Kalori, protein, karbonhidrat ve yağ durumun tek kartta görünür.',
      tip: 'Karta dokunarak beslenme detayına geçebilirsin.',
    ),
    GuideStep(
      emoji: '💧',
      title: 'Su Takibi',
      description: 'Su kartından bardak ekleyip günlük hedefini takip edersin.',
      tip: 'Hedefe dokunarak su miktarını değiştirebilirsin.',
    ),
    GuideStep(
      emoji: '🚀',
      title: 'Hızlı Erişim Kartları',
      description:
          'Seri, antrenman ve kilo kartları seni ilgili sayfaya götürür.',
      tip: 'Kartlara dokunarak ilgili sayfaya doğrudan gidebilirsin!',
    ),
    GuideStep(
      emoji: '🤖',
      title: 'AI Koç',
      description: 'AI Koç günlük yorum, yemek fikri ve antrenman yönü verir.',
      tip: 'Aynı isim her yerde aynı yardımcıyı anlatır.',
    ),
    GuideStep(
      emoji: '✅',
      title: 'Günlük Görevler',
      description:
          'Günün küçük hedeflerini tamamladıkça ilerleme çubuğu dolar.',
      tip: 'Asistan butonu → Günlük Görevler ile tamamını açabilirsin.',
    ),
    GuideStep(
      emoji: '❤️',
      title: 'Toparlanma Skoru',
      description:
          'Ana sayfanın alt bölümünde Toparlanma Skoru kartı bulunur. Bu kart 3 faktörden hesaplanan günlük hazırlık endeksini gösterir:\n\n'
          '• 💪 Kas toparlanması (%55 etki)\n'
          '• 🌙 Uyku süresi (%30 etki)\n'
          '• 💧 Su tüketimi (%15 etki)\n\n'
          'Karta dokunarak her faktörün detayını görebilirsin.',
      tip:
          'Uyku süresini slider\'dan gir — skor anında güncellenir. Kart sarı veya kırmızıysa bugün toparlanmayı öne al.',
    ),
    GuideStep(
      emoji: '✨',
      title: 'Asistan Butonu ve Rehber',
      description:
          'Asistan butonu AI Koç, görevler ve hesap araçlarına hızlı erişim sağlar.',
      tip: 'Sağ üstteki rehber ikonuyla bu turu tekrar açabilirsin.',
    ),
  ];

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    // Uygulama turu aktifken sayfa rehberini gösterme (aynı anda çakışır)
    if (StorageHelper.getPendingAppTour() && !StorageHelper.getAppTourSeen()) {
      return;
    }
    if (await PageGuideService.hasSeenGuide('dashboard')) return;
    await PageGuideService.markGuideSeen('dashboard');
    if (mounted) await _showGuide();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadHomeData();
      await _checkFirstVisitGuide();
    });
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
    final today = DateTime.now();
    final failedSections = <String>[];
    final loadResults = await Future.wait<String?>([
      _loadSectionSafely(
        sectionLabel: 'antrenmanlar',
        loader: () => workoutProvider.loadWorkouts(userId),
      ),
      _loadSectionSafely(
        sectionLabel: 'kilo takibi',
        loader: weightProvider.loadEntries,
      ),
      _loadSectionSafely(
        sectionLabel: 'beslenme',
        loader: () =>
            dietProvider.loadDay(DateTime(today.year, today.month, today.day)),
      ),
    ]);
    failedSections.addAll(loadResults.whereType<String>());

    await _refreshTodaySuggestions(
      dietProvider,
      workoutProvider,
      allowMealSuggestion: !failedSections.contains('beslenme'),
      allowWorkoutSuggestion: !failedSections.contains('antrenmanlar'),
    );

    try {
      final aiService = dietProvider.aiService;
      if (aiService != null) {
        final remotePremium = await aiService.checkPremiumStatus();
        if (remotePremium != null && mounted) {
          authProvider.setPremiumActive(remotePremium);
        }
      }
    } catch (e) {
      debugPrint('Dashboard premium sync error: $e');
    }

    if (!failedSections.contains('beslenme')) {
      await _maybeShowOnboardingSummary(dietProvider);
    }

    // Uygulama içi değerlendirme tetikleyicisi (7 gün veya 5+ antrenman kontrolü)
    unawaited(
      AppReviewService.instance.requestReviewIfNeeded(
        workoutProvider.workouts.length,
      ),
    );

    if (failedSections.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bazı veriler yüklenemedi: ${failedSections.join(', ')}.',
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  Future<void> _refreshTodaySuggestions(
    DietProvider dietProvider,
    WorkoutProvider workoutProvider, {
    bool allowMealSuggestion = true,
    bool allowWorkoutSuggestion = true,
  }) async {
    SuggestedFoodInsight? mealSuggestion;
    if (allowMealSuggestion) {
      try {
        final hour = DateTime.now().hour;
        final mealType = hour < 10
            ? MealType.breakfast
            : hour < 14
            ? MealType.lunch
            : hour < 18
            ? MealType.snack
            : MealType.dinner;
        final mealInsights = await dietProvider.getSuggestedFoodInsights(
          mealType,
          limit: 1,
        );
        mealSuggestion = mealInsights.isNotEmpty ? mealInsights.first : null;
      } catch (e) {
        debugPrint('Dashboard meal suggestion error: $e');
      }
    }

    final workoutSuggestion = allowWorkoutSuggestion
        ? workoutProvider.workoutSuggestion
        : null;

    if (!mounted) return;
    setState(() {
      _todayMealSuggestion = mealSuggestion;
      _todayWorkoutSuggestion = workoutSuggestion;
    });
  }

  Future<String?> _loadSectionSafely({
    required String sectionLabel,
    required Future<void> Function() loader,
  }) async {
    try {
      await loader();
      return null;
    } catch (e) {
      debugPrint('Dashboard $sectionLabel load error: $e');
      return sectionLabel;
    }
  }

  Future<void> _maybeShowOnboardingSummary(DietProvider dietProvider) async {
    if (_didTryShowOnboardingSummary) return;
    _didTryShowOnboardingSummary = true;
    if (!StorageHelper.getPendingOnboardingSummary()) return;
    // Tur henüz gösterilmediyse, summary'yi bu seferlik atla.
    // Bayrak temizlenmez — tur tamamlandıktan sonraki açılışta gösterilir.
    if (StorageHelper.getPendingAppTour() && !StorageHelper.getAppTourSeen()) {
      return;
    }
    if (!mounted) return;
    // Tur overlay'i tam yerleşsin diye kısa bekleme
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _OnboardingSummarySheet(
          macroTargets: dietProvider.macroTargets,
          mealSuggestion: _todayMealSuggestion,
          workoutSuggestion: _todayWorkoutSuggestion,
          accent: _goalPrimaryColor(dietProvider.profile?.goal),
        ),
      );
      await StorageHelper.savePendingOnboardingSummary(false);
    });
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatInt(num value) {
    final raw = value.round().toString();
    return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  String _capitalizeFirst(String text) {
    return text
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _todayDateString() {
    final now = DateTime.now();
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    const weekdays = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    return '${now.day} ${months[now.month - 1]}, ${weekdays[now.weekday - 1]}';
  }

  /// Saate + hedefe + bugünkü ilerlemeye göre kişiselleştirilmiş selamlama.
  String _dynamicGreeting({
    required String name,
    required Goal? goal,
    required double calorieProgress,
    required double proteinProgress,
    required double waterLiters,
  }) {
    final hour = DateTime.now().hour;
    final allDone =
        calorieProgress >= 1.0 && proteinProgress >= 1.0 && waterLiters >= 2.0;
    if (allDone) {
      return 'Harika iş, $name. Bugünün hedefleri tamam.';
    }
    if (hour >= 5 && hour < 11) {
      switch (goal) {
        case Goal.cut:
          return 'Günaydın $name, bugün dengeli ilerleyelim.';
        case Goal.bulk:
          return 'Günaydın $name, güçlü bir başlangıç yap.';
        case Goal.strength:
          return 'Günaydın $name, bugün güç sende.';
        default:
          return 'Günaydın $name, güne suyla başla.';
      }
    } else if (hour >= 11 && hour < 14) {
      if (proteinProgress < 0.3) {
        return 'Öğle vakti $name, proteini ihmal etme.';
      }
      return 'Öğle arası $name, ritmini koru.';
    } else if (hour >= 14 && hour < 18) {
      return 'İyi günler $name, tempoyu dengede tut.';
    } else if (hour >= 18 && hour < 22) {
      if (calorieProgress < 0.7) {
        return 'Akşam oldu $name, kalan hedefini tamamlayalım.';
      }
      return 'Güzel gidiyorsun $name, günü güçlü kapat.';
    } else {
      return 'Geç oldu $name, dinlenmek de planın parçası.';
    }
  }

  String _goalLabel(Goal? goal) {
    switch (goal) {
      case Goal.cut:
        return 'Yağ Yakımı';
      case Goal.bulk:
        return 'Kas Kazanımı';
      case Goal.strength:
        return 'Güç Artışı';
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
        return 'Kalori açığını kontrollü sürdür';
      case Goal.bulk:
        return 'Kalori fazlasını temiz beslenmeyle tamamla';
      case Goal.strength:
        return 'Antrenman performansını beslenmeyle destekle';
      case Goal.maintain:
      case null:
        return 'Bugün ritmini koru ve istikrar sağla';
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
    required String greetingText,
    required bool isPremium,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Üst satır: sadece butonlar (sağ hizalı) ──
        Row(
          children: [
            const Spacer(),
            PageGuideButton(onTap: _showGuide),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PremiumScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(999),
              child: isPremium
                  ? const PremiumStateBadge(active: true)
                  : const ProBadge(),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () async {
                final result = await Navigator.pushNamed(context, '/profile');
                if (result is int && widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(result);
                }
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 40,
                height: 40,
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
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _softBlue.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── Alt satır: tam selamlama metni (tam genişlik, 2 satır) ──
        Text(
          greetingText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          _todayDateString(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            fontSize: 13,
            fontWeight: FontWeight.w500,
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

  Widget _macroMini(
    String label,
    int current,
    int target,
    Color color, {
    IconData? icon,
    String? emptyHint,
  }) {
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final isEmpty = current == 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 10, color: color),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  isEmpty && emptyHint != null
                      ? Text(
                          emptyHint,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.55),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                        )
                      : Text(
                          '$current / $target g',
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ],
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  isEmpty ? color.withValues(alpha: 0.3) : color,
                ),
              ),
            ),
          ],
        ),
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
    required int dailyCarb,
    required int targetCarb,
    required int dailyFat,
    required int targetFat,
    VoidCallback? onTapCalories,
    VoidCallback? onTapProtein,
    VoidCallback? onTapCard,
    VoidCallback? onAddMeal,
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
                      progressPct == 0
                          ? 'Başla →'
                          : '${_goalLabel(goal)} • %$progressPct',
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
          // ── Kalori ana satırı ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Büyük ring solda
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 5,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, val, child) => CircularProgressIndicator(
                        value: val,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation(calorieAccent),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: calorieAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 13,
                          color: calorieAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'KALORİ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.50),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _formatInt(dailyCalories),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${_formatInt(targetCalories)} kcal',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 14),
          // ── Protein bar satırı ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: proteinAccent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: proteinAccent.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 12,
                      color: proteinAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'PROTEİN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$dailyProtein',
                            style: TextStyle(
                              color: proteinAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: ' / $targetProtein g',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: proteinProgress.clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, child) => LinearProgressIndicator(
                      value: val,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation(
                        proteinAccent.withValues(alpha: 0.85),
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _macroMini(
                'KARB',
                dailyCarb,
                targetCarb,
                const Color(0xFF5FD8B7),
                icon: Icons.grass_rounded,
                emptyHint: 'Henüz karb girmedin',
              ),
              const SizedBox(width: 8),
              _macroMini(
                'YAĞ',
                dailyFat,
                targetFat,
                const Color(0xFFFFA56E),
                icon: Icons.water_drop_rounded,
                emptyHint: 'Henüz yağ girmedin',
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
          if (dailyCalories == 0) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bugün henüz öğün eklemedin. İlk öğününle günü başlat.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildActionPill(
                  icon: Icons.add_rounded,
                  label: 'Öğün Ekle',
                  onTap: onAddMeal,
                  accent: calorieAccent,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Beslenme detayları',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 9,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStatusRow({
    required int streak,
    required bool hasWorkoutToday,
    required int workoutCount,
    required String? firstWorkoutName,
    required double? weightKg,
    required double weeklyWeightChange,
    required Color accent,
    required Color secondaryAccent,
    VoidCallback? onWorkoutTap,
    VoidCallback? onWeightTap,
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
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 11, color: color.withValues(alpha: 0.75)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.40),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final streakColor = streak >= 30
        ? const Color(0xFFFFD700)
        : streak >= 7
        ? const Color(0xFFFFA56E)
        : streak >= 3
        ? _freshGreen
        : Colors.white54;
    final streakValue = streak > 0 ? '$streak Gün 🔥' : 'İlk Günün!';

    final workoutColor = hasWorkoutToday ? accent : Colors.white38;
    final workoutValue = hasWorkoutToday ? '${workoutCount}x Kayıt' : 'Başla!';

    final weightColor = weightKg != null ? secondaryAccent : Colors.white38;
    String weightValue;
    if (weightKg != null) {
      final delta = weeklyWeightChange;
      final deltaStr = delta == 0
          ? ''
          : delta > 0
          ? ' ▲${delta.abs().toStringAsFixed(1)}'
          : ' ▼${delta.abs().toStringAsFixed(1)}';
      weightValue = '${weightKg.toStringAsFixed(1)}$deltaStr';
    } else {
      weightValue = 'Kilo Ekle';
    }

    return Row(
      children: [
        chip(
          icon: Icons.local_fire_department_rounded,
          label: 'SERİ',
          value: streakValue,
          color: streakColor,
        ),
        const SizedBox(width: 8),
        chip(
          icon: Icons.fitness_center_rounded,
          label: 'ANTRENMAN',
          value: workoutValue,
          color: workoutColor,
          onTap: onWorkoutTap,
        ),
        const SizedBox(width: 8),
        chip(
          icon: Icons.monitor_weight_rounded,
          label: 'KİLO',
          value: weightValue,
          color: weightColor,
          onTap: onWeightTap,
        ),
      ],
    );
  }

  Widget _buildMotivationCard({
    required StreakProvider streakProvider,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final progress = streakProvider.weeklyChallengeProgress;
    final weeklyCount = streakProvider.weeklyWorkoutCount;
    final weeklyTarget = streakProvider.weeklyWorkoutTarget;
    final completed = streakProvider.weeklyChallengeCompleted;
    final unlockedCount = streakProvider.unlockedBadges.length;

    return GestureDetector(
      onTap: onTap,
      child: _glassCard(
        accentColor: completed ? _freshGreen : accent,
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (completed ? _freshGreen : accent).withValues(
                      alpha: 0.14,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: (completed ? _freshGreen : accent).withValues(
                        alpha: 0.26,
                      ),
                    ),
                  ),
                  child: Icon(
                    completed ? Icons.verified_rounded : Icons.flag_rounded,
                    color: completed ? _freshGreen : accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        completed
                            ? 'Haftalık hedef tamam'
                            : 'Bu hafta $weeklyTarget antrenman',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$weeklyCount/$weeklyTarget antrenman · $unlockedCount rozet · ${streakProvider.taskStreak} gün görev serisi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.42),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completed ? _freshGreen : accent,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  completed ? '✓' : '%${(progress * 100).round()}',
                  style: TextStyle(
                    color: (completed ? _freshGreen : accent).withValues(
                      alpha: 0.80,
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
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
          color: accent.withValues(alpha: 0.2),
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

  Widget _buildTodayPlanCard({
    required int mealCount,
    required double remainingKcal,
    required int dailyProtein,
    required int targetProtein,
    required bool hasWorkoutToday,
    required int completedTasks,
    required int totalTasks,
    required Color accent,
    required double waterLiters,
    VoidCallback? onMealTap,
    VoidCallback? onWorkoutTap,
    VoidCallback? onTrackingTap,
    VoidCallback? onWaterTap,
  }) {
    final kcalText = remainingKcal.round();
    final proteinGap = targetProtein - dailyProtein;
    final taskGap = totalTasks - completedTasks;
    late final String title;
    late final String subtitle;

    if (mealCount == 0) {
      title = 'Sıradaki hamle: ilk öğün';
      subtitle = 'İlk öğünü ekle; AI Koç günün kalanını daha net yönlendirsin.';
    } else if (waterLiters < 1.25) {
      title = 'Sıradaki hamle: su hedefi';
      subtitle =
          '${waterLiters.toStringAsFixed(1)}L kaydın var. Bir bardak ekleyip ritmi koru.';
    } else if (proteinGap > 20) {
      title = 'Sıradaki hamle: protein';
      subtitle =
          'Yaklaşık $proteinGap g protein açığın var. Sonraki öğünü buna göre seç.';
    } else if (!hasWorkoutToday) {
      title = 'Sıradaki hamle: antrenman';
      subtitle = '$mealCount öğün kayıtlı. Kısa bir seans günü tamamlar.';
    } else if (taskGap > 0) {
      title = 'Sıradaki hamle: görev serisi';
      subtitle =
          '$completedTasks/$totalTasks görev tamam. En kısa kalan görevi bitir.';
    } else if (kcalText >= 0) {
      title = 'Bugünün planı akıyor';
      subtitle =
          '$mealCount öğün ve antrenman kayıtlı. $kcalText kcal alan kaldı.';
    } else {
      title = 'Bugünün planı akıyor';
      subtitle =
          '$mealCount öğün ve antrenman kayıtlı. Kaloride biraz frene bas.';
    }

    Widget miniAction({
      required String label,
      required IconData icon,
      required VoidCallback? onTap,
      required Color iconColor,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: iconColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _glassCard(
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: 0.20)),
                ),
                child: Icon(Icons.route_rounded, color: accent, size: 20),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 11.5,
                        height: 1.30,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              miniAction(
                label: 'Öğün',
                icon: Icons.restaurant_rounded,
                onTap: onMealTap,
                iconColor: const Color(0xFF30D158),
              ),
              const SizedBox(width: 8),
              miniAction(
                label: 'Antrenman',
                icon: Icons.fitness_center_rounded,
                onTap: onWorkoutTap,
                iconColor: const Color(0xFF5B9BFF),
              ),
              const SizedBox(width: 8),
              _waterMiniAction(
                waterLiters: waterLiters,
                accent: accent,
                onTap: onWaterTap,
              ),
              const SizedBox(width: 8),
              miniAction(
                label: 'Takip',
                icon: Icons.trending_up_rounded,
                onTap: onTrackingTap,
                iconColor: const Color(0xFFBF5AF2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waterMiniAction({
    required double waterLiters,
    required Color accent,
    VoidCallback? onTap,
  }) {
    const targetLiters = 2.0;
    final ratio = (waterLiters / targetLiters).clamp(0.0, 1.0);
    final isDone = waterLiters >= targetLiters;
    final waterColor = isDone
        ? const Color(0xFF5FD8B7)
        : const Color(0xFF7BCBFF);
    final label = waterLiters <= 0
        ? '+ Su'
        : '${waterLiters.toStringAsFixed(1)}L';

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: waterColor.withValues(alpha: isDone ? 0.15 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: waterColor.withValues(alpha: isDone ? 0.4 : 0.15),
            ),
          ),
          child: Stack(
            children: [
              // progress fill
              if (ratio > 0)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratio,
                      child: Container(
                        color: waterColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.water_drop_rounded,
                      color: waterColor,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: waterColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiSuggestionCard({
    required SuggestedFoodInsight? mealSuggestion,
    required TodayWorkoutSuggestion? workoutSuggestion,
    String? coachNote,
    required Color accent,
    VoidCallback? onMealTap,
  }) {
    if (mealSuggestion == null &&
        workoutSuggestion == null &&
        coachNote == null) {
      return const SizedBox.shrink();
    }
    return _glassCard(
      accentColor: accent,
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 16),
              const SizedBox(width: 8),
              Text(
                'AI Günlük Öneri',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (coachNote != null) ...[
            const SizedBox(height: 10),
            Text(
              coachNote,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (mealSuggestion != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onMealTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restaurant_rounded, color: accent, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mealSuggestion.item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (mealSuggestion.reasons.isNotEmpty)
                            Text(
                              '${mealSuggestion.suggestedPortionG.round()} g · ${mealSuggestion.reasons.first}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (workoutSuggestion != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Row(
                children: [
                  Icon(
                    workoutSuggestion.icon,
                    color: workoutSuggestion.color,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      workoutSuggestion.detail,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _buildContextualCoachNote({
    required int dailyCalories,
    required int targetCalories,
    required int dailyProtein,
    required int targetProtein,
    required double waterLiters,
    required int mealCount,
    required bool hasWorkoutToday,
  }) {
    if (targetCalories <= 0) return null;
    final remaining = targetCalories - dailyCalories;
    final proteinRemaining = targetProtein - dailyProtein;
    if (mealCount == 0) {
      return 'Bugün henüz öğün yok. İlk kayıt sonrası koç önerileri daha netleşir.';
    }
    if (remaining > 450 && proteinRemaining > 20) {
      return 'Bugün hâlâ $remaining kcal ve yaklaşık $proteinRemaining g protein boşluğun var; akşamı protein ağırlıklı planla.';
    }
    if (remaining < -150) {
      return 'Kalori hedefini ${remaining.abs()} kcal geçtin; kalan öğünlerde hafif ve lifli seçenekler iyi gider.';
    }
    if (waterLiters < 1.5) {
      return 'Su tüketimin düşük görünüyor; bugün 2 litreye yaklaşmak toparlanmana yardım eder.';
    }
    if (!hasWorkoutToday && mealCount >= 2) {
      return 'Beslenme kaydın iyi gidiyor; kısa bir yürüyüş veya hafif antrenman günü tamamlar.';
    }
    return 'Günün dengeli ilerliyor; küçük kayıtları atlamadan devam et.';
  }

  // ── Toparlanma Skoru ─────────────────────────────────────────────────────
  Widget _buildRecoveryScoreCard({
    required List<Workout> workouts,
    required double waterLiters,
    required double sleepHours,
    required Color accent,
    required VoidCallback onTrackingTap,
    required VoidCallback? onWaterTap,
    required VoidCallback? onSleepTap,
    required VoidCallback? onWorkoutTap,
  }) {
    final fatigue = RecoveryEngine.computeAll(workouts);
    final muscleAvg = fatigue.isEmpty
        ? 1.0
        : fatigue.values.map((s) => s.recoveryPercent).reduce((a, b) => a + b) /
              fatigue.length;

    final sleepScore = (sleepHours / 8.0).clamp(0.0, 1.0);
    final hydrationScore = (waterLiters / 2.5).clamp(0.0, 1.0);

    final total =
        ((muscleAvg * 0.55 + sleepScore * 0.30 + hydrationScore * 0.15) * 100)
            .round()
            .clamp(0, 100);

    final (scoreColor, scoreLabel, scoreMessage) = switch (total) {
      >= 80 => (
        const Color(0xFF30D158),
        'Hazır',
        'Ağır antrenman için mükemmel bir gün 💪',
      ),
      >= 60 => (
        const Color(0xFF64D2FF),
        'İyi',
        'Toparlanma yolunda, planlı devam et.',
      ),
      >= 40 => (
        const Color(0xFFFFD60A),
        'Orta',
        'Biraz daha uyku veya suya ihtiyacın var.',
      ),
      _ => (
        const Color(0xFFFF6B6B),
        'Yorgun',
        'Lütfen dinlen, kasların yorgun.',
      ),
    };

    Widget chip(
      String label,
      String valueStr,
      Color color,
      IconData icon,
      VoidCallback? onTap,
    ) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.03),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: color.withValues(alpha: 0.8), size: 14),
                const SizedBox(height: 6),
                Text(
                  valueStr,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _glassCard(
      accentColor: scoreColor,
      radius: 22,
      padding: const EdgeInsets.all(16),
      onTap: onTrackingTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Şık dairesel progress
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 5,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    CircularProgressIndicator(
                      value: total / 100,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$total',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(
                                  color: scoreColor.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '/100',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Toparlanma',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: scoreColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            scoreLabel,
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scoreMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Alt 3 fizyolojik metrik
          Row(
            children: [
              chip(
                'Kas',
                '%${(muscleAvg * 100).round()}',
                const Color(0xFF30D158),
                Icons.fitness_center_rounded,
                onWorkoutTap,
              ),
              const SizedBox(width: 8),
              chip(
                'Uyku',
                '${sleepHours.toStringAsFixed(1)}s',
                const Color(0xFFFF9F0A),
                Icons.nights_stay_rounded,
                onSleepTap,
              ),
              const SizedBox(width: 8),
              chip(
                'Su',
                '${waterLiters.toStringAsFixed(1)}L',
                const Color(0xFF64D2FF),
                Icons.water_drop_rounded,
                onWaterTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealSummaryCard({
    required List<dynamic> todayEntries,
    required int dailyCalories,
    required double progress,
    required Color primaryAccent,
    VoidCallback? onRepeatMeal,
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
                Text(
                  hasEntries ? 'Bugünün Öğünleri' : 'Bugün ne yemek istersin?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasEntries
                      ? '${todayEntries.length} öğün · $dailyCalories kcal · %${(progress * 100).round()} tamamlandı'
                      : 'Hemen bir öğün aratarak veya barkod okutarak hedefine yaklaş.',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildActionPill(
                icon: Icons.add_rounded,
                label: 'Öğün Ekle',
                onTap: widget.onAddMeal,
                accent: primaryAccent,
              ),
              if (!hasEntries && onRepeatMeal != null) ...[
                const SizedBox(height: 7),
                _buildActionPill(
                  icon: Icons.replay_rounded,
                  label: 'Son Öğün',
                  onTap: onRepeatMeal,
                  accent: const Color(0xFFEBC374),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTasksCard({
    required int completed,
    required int total,
    required List<DailyTask> tasks,
    required Color accent,
    required void Function(String taskId) onToggle,
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
                          ? 'AI Koç\'tan kişisel görev önerileri alabilirsin'
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
              ...tasks.map((task) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: GestureDetector(
                    onTap: () => onToggle(task.id),
                    behavior: HitTestBehavior.opaque,
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
                            task.title,
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
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  /// Tüm günlük hedefler tamamlandıysa altın glow rengi döndürür.
  Color? _successGlowColor({
    required double calorieProgress,
    required double proteinProgress,
    required double waterLiters,
  }) {
    if (calorieProgress >= 1.0 &&
        proteinProgress >= 1.0 &&
        waterLiters >= 2.0) {
      return const Color(0xFFFFD700);
    }
    return null;
  }

  Widget _buildNeglectedMuscleWarning({
    required List<String> neglectedGroups,
    required Color accent,
  }) {
    if (neglectedGroups.isEmpty) return const SizedBox.shrink();
    
    // Yalnızca ilk kas grubunu göster veya virgülle birleştir
    final musclesText = neglectedGroups.take(2).join(', ');
    final suffix = neglectedGroups.length > 2 ? ' ve diğerleri' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_rounded, color: Color(0xFFFF3B30), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Koç Uyarısı',
                  style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '3 haftadır $musclesText$suffix çalışmadın! Kasların küçülüyor olabilir, antrenman programını gözden geçir.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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
                      final trackingProvider = context
                          .watch<TrackingProvider>();
                      final targetCalories = dietProvider.effectiveTargetKcal
                          .round();
                      final tasksController = context
                          .watch<DailyTasksController>();
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
                      final dailyCarb = dietProvider.totals.totalCarb.round();
                      final targetCarb = macroTargets.carb.round();
                      final dailyFat = dietProvider.totals.totalFat.round();
                      final targetFat = macroTargets.fat.round();
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
                            'Kullanıcı',
                      );
                      final goal = dietProvider.profile?.goal;
                      final hasWorkoutToday = firstWorkout != null;
                      final coachNote = _buildContextualCoachNote(
                        dailyCalories: dailyCalories,
                        targetCalories: targetCalories,
                        dailyProtein: dailyProtein,
                        targetProtein: targetProtein,
                        waterLiters: dietProvider.waterLiters,
                        mealCount: todayEntries.length,
                        hasWorkoutToday: hasWorkoutToday,
                      );
                      final isDietLoading = dietProvider.loading;
                      final isWorkoutLoading = workoutProvider.isLoading;
                      final isWeightLoading = weightProvider.isLoading;
                      final primaryAccent = _goalPrimaryColor(goal);
                      final secondaryAccent = _goalSecondaryColor(goal);
                      // Başarı rengi: tüm günlük hedefler tamamlanınca altın glow
                      final successGlow = _successGlowColor(
                        calorieProgress: targetCalories > 0
                            ? (dailyCalories / targetCalories).clamp(0.0, 1.0)
                            : 0.0,
                        proteinProgress: targetProtein > 0
                            ? (dailyProtein / targetProtein).clamp(0.0, 1.0)
                            : 0.0,
                        waterLiters: dietProvider.waterLiters,
                      );
                      final effectiveAccent = successGlow ?? primaryAccent;
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

                      final isPremium =
                          authProvider.user?.premiumTier
                              ?.toLowerCase()
                              .trim() ==
                          'premium';

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── 1. Header ──
                            _buildTopHeader(
                                  context: context,
                                  displayName: displayName,
                                  greetingText: _dynamicGreeting(
                                    name: displayName,
                                    goal: goal,
                                    calorieProgress: progress,
                                    proteinProgress: proteinProgress,
                                    waterLiters: dietProvider.waterLiters,
                                  ),
                                  isPremium: isPremium,
                                )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideY(
                                  begin: -0.05,
                                  end: 0,
                                  duration: 300.ms,
                                  curve: Curves.easeOut,
                                ),
                            const SizedBox(height: 16),

                            if (firstError != null) ...[
                              _buildStatusErrorCard(
                                message:
                                    'Bazı veriler yüklenemedi: $firstError',
                                accent: primaryAccent,
                                onRetry: _loadHomeData,
                              ),
                              const SizedBox(height: 12),
                            ],
                            
                            Consumer<StreakProvider>(
                              builder: (context, streakProvider, _) {
                                final neglected = streakProvider.getNeglectedMuscleGroups(3);
                                return _buildNeglectedMuscleWarning(
                                  neglectedGroups: neglected,
                                  accent: primaryAccent,
                                );
                              },
                            ),

                            // ── 2. Hero: Kalori + Protein ──
                            (isDietLoading && todayEntries.isEmpty)
                                ? _buildSkeletonCard(
                                    height: 190,
                                    accent: effectiveAccent,
                                  )
                                : _buildHeroCard(
                                        goal: goal,
                                        calorieAccent: effectiveAccent,
                                        proteinAccent: secondaryAccent,
                                        progress: progress,
                                        dailyCalories: dailyCalories,
                                        targetCalories: targetCalories,
                                        proteinProgress: proteinProgress,
                                        dailyProtein: dailyProtein,
                                        targetProtein: targetProtein,
                                        dailyCarb: dailyCarb,
                                        targetCarb: targetCarb,
                                        dailyFat: dailyFat,
                                        targetFat: targetFat,
                                        onTapCalories: () =>
                                            widget.onNavigateToTab?.call(3),
                                        onTapProtein: () =>
                                            widget.onNavigateToTab?.call(3),
                                        onTapCard: () =>
                                            widget.onNavigateToTab?.call(3),
                                        onAddMeal: widget.onAddMeal,
                                      )
                                      .animate()
                                      .fadeIn(delay: 60.ms, duration: 320.ms)
                                      .slideY(
                                        begin: 0.06,
                                        end: 0,
                                        delay: 60.ms,
                                        duration: 320.ms,
                                        curve: Curves.easeOutCubic,
                                      ),
                            const SizedBox(height: 12),

                            _buildTodayPlanCard(
                                  mealCount: todayEntries.length,
                                  remainingKcal:
                                      (targetCalories - dailyCalories)
                                          .toDouble(),
                                  dailyProtein: dailyProtein,
                                  targetProtein: targetProtein,
                                  hasWorkoutToday: hasWorkoutToday,
                                  completedTasks:
                                      tasksController.completedCount,
                                  totalTasks: tasksController.totalCount,
                                  accent: effectiveAccent,
                                  waterLiters: dietProvider.waterLiters,
                                  onMealTap: widget.onAddMeal,
                                  onWorkoutTap: () =>
                                      widget.onNavigateToTab?.call(1),
                                  onTrackingTap: () =>
                                      widget.onNavigateToTab?.call(2),
                                  onWaterTap: _isAddingWater
                                      ? null
                                      : () async {
                                          if (_isAddingWater) return;
                                          setState(() => _isAddingWater = true);
                                          dietProvider.addWater(0.25);
                                          final total =
                                              dietProvider.waterLiters;
                                          if (mounted) {
                                            final isDone = total >= 2.0;
                                            ScaffoldMessenger.of(context)
                                              ..clearSnackBars()
                                              ..showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    isDone
                                                        ? '💧 Su hedefine ulaştın! Toplam: ${total.toStringAsFixed(1)}L'
                                                        : '💧 +250ml eklendi · Toplam: ${total.toStringAsFixed(1)}L',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                  backgroundColor: const Color(
                                                    0xFF1A3A4A,
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            if (isDone) {
                                              unawaited(
                                                context
                                                    .read<
                                                      DailyTasksController
                                                    >()
                                                    .autoCompleteFirstUndoneByCategory(
                                                      TaskCategory.water,
                                                    ),
                                              );
                                            }
                                          }
                                          await Future.delayed(
                                            const Duration(milliseconds: 800),
                                          );
                                          if (mounted) {
                                            setState(
                                              () => _isAddingWater = false,
                                            );
                                          }
                                        },
                                )
                                .animate()
                                .fadeIn(delay: 80.ms, duration: 300.ms)
                                .slideY(
                                  begin: 0.05,
                                  end: 0,
                                  delay: 80.ms,
                                  duration: 300.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: 12),

                            // ── 3. Hızlı durum: Streak | Antrenman | Kilo ──
                            (isInitialCompositeLoading)
                                ? _buildSkeletonCard(
                                    height: 72,
                                    accent: effectiveAccent,
                                  )
                                : _buildQuickStatusRow(
                                        streak: dietProvider.currentStreak,
                                        hasWorkoutToday: hasWorkoutToday,
                                        workoutCount: todayWorkouts.length,
                                        firstWorkoutName: firstWorkout?.name,
                                        weightKg: weightProvider
                                            .latestEntry
                                            ?.weightKg,
                                        weeklyWeightChange:
                                            weightProvider.weeklyChange,
                                        accent: effectiveAccent,
                                        secondaryAccent: secondaryAccent,
                                        onWorkoutTap: () =>
                                            widget.onNavigateToTab?.call(1),
                                        onWeightTap: () =>
                                            widget.onNavigateToTab?.call(2),
                                      )
                                      .animate()
                                      .fadeIn(delay: 160.ms, duration: 320.ms)
                                      .slideY(
                                        begin: 0.06,
                                        end: 0,
                                        delay: 160.ms,
                                        duration: 320.ms,
                                        curve: Curves.easeOutCubic,
                                      ),
                            const SizedBox(height: 12),

                            Consumer<StreakProvider>(
                              builder: (context, streakProvider, _) =>
                                  _buildMotivationCard(
                                        streakProvider: streakProvider,
                                        accent: primaryAccent,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => AchievementsScreen(
                                                highlightBadgeId:
                                                    'weekly_${streakProvider.weeklyWorkoutTarget}_workouts',
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                      .animate()
                                      .fadeIn(delay: 220.ms, duration: 320.ms)
                                      .slideY(
                                        begin: 0.06,
                                        end: 0,
                                        delay: 220.ms,
                                        duration: 320.ms,
                                        curve: Curves.easeOutCubic,
                                      ),
                            ),
                            const SizedBox(height: 12),

                            // ── 4. Toparlanma skoru ──
                            _buildRecoveryScoreCard(
                                  workouts: workoutProvider.workouts,
                                  waterLiters: dietProvider.waterLiters,
                                  sleepHours: trackingProvider.sleepHours,
                                  accent: primaryAccent,
                                  onTrackingTap: () {
                                    widget.onNavigateToTab?.call(2);
                                  },
                                  onSleepTap: () {
                                    widget.onNavigateToTab?.call(2);
                                  },
                                  onWorkoutTap: () =>
                                      widget.onNavigateToTab?.call(1),
                                  onWaterTap: _isAddingWater
                                      ? null
                                      : () async {
                                          if (_isAddingWater) return;
                                          setState(() => _isAddingWater = true);
                                          dietProvider.addWater(0.25);
                                          final total =
                                              dietProvider.waterLiters;
                                          if (mounted) {
                                            final isDone = total >= 2.0;
                                            ScaffoldMessenger.of(context)
                                              ..clearSnackBars()
                                              ..showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    isDone
                                                        ? '💧 Su hedefine ulaştın! Toplam: ${total.toStringAsFixed(1)}L'
                                                        : '💧 +250ml eklendi · Toplam: ${total.toStringAsFixed(1)}L',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor:
                                                      AppColors.surfaceElevated,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                          }
                                          await Future.delayed(
                                            const Duration(milliseconds: 500),
                                          );
                                          if (mounted) {
                                            setState(
                                              () => _isAddingWater = false,
                                            );
                                          }
                                        },
                                )
                                .animate()
                                .fadeIn(delay: 280.ms, duration: 320.ms)
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  delay: 280.ms,
                                  duration: 320.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: 12),

                            // ── 5. Günlük görevler ──
                            Consumer<DailyTasksController>(
                              builder: (ctx, tasksCtrl, _) =>
                                  _buildDailyTasksCard(
                                        completed: tasksCtrl.completedCount,
                                        total: tasksCtrl.totalCount,
                                        tasks: tasksCtrl.tasks.take(3).toList(),
                                        accent: primaryAccent,
                                        onToggle: (taskId) async {
                                          final allDone = await tasksCtrl
                                              .toggleTaskDone(taskId);
                                          if (allDone && context.mounted) {
                                            await context
                                                .read<StreakProvider>()
                                                .onDailyTasksAllCompleted();
                                          }
                                        },
                                      )
                                      .animate()
                                      .fadeIn(delay: 320.ms, duration: 320.ms)
                                      .slideY(
                                        begin: 0.06,
                                        end: 0,
                                        delay: 320.ms,
                                        duration: 320.ms,
                                        curve: Curves.easeOutCubic,
                                      ),
                            ),
                            const SizedBox(height: 12),

                            // ── 5. Öğün ekle ──
                            _buildMealSummaryCard(
                                  todayEntries: todayEntries,
                                  dailyCalories: dailyCalories,
                                  progress: progress,
                                  primaryAccent: primaryAccent,
                                  onRepeatMeal: () async {
                                    final added = await dietProvider
                                        .repeatMostRecentMeal();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                      ..clearSnackBars()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            added > 0
                                                ? '$added kayıt son öğünden eklendi.'
                                                : 'Tekrarlanacak son öğün bulunamadı.',
                                          ),
                                          backgroundColor: const Color(
                                            0xFF1A3A4A,
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      );
                                  },
                                )
                                .animate()
                                .fadeIn(delay: 400.ms, duration: 320.ms)
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  delay: 400.ms,
                                  duration: 320.ms,
                                  curve: Curves.easeOutCubic,
                                ),

                            // ── 8. AI Öneri ──
                            if (_todayMealSuggestion != null ||
                                _todayWorkoutSuggestion != null ||
                                coachNote != null) ...[
                              const SizedBox(height: 12),
                              _buildAiSuggestionCard(
                                    mealSuggestion: _todayMealSuggestion,
                                    workoutSuggestion: _todayWorkoutSuggestion,
                                    coachNote: coachNote,
                                    accent: primaryAccent,
                                    onMealTap: () =>
                                        widget.onNavigateToTab?.call(3),
                                  )
                                  .animate()
                                  .fadeIn(delay: 110.ms, duration: 240.ms)
                                  .slideY(
                                    begin: 0.04,
                                    end: 0,
                                    duration: 240.ms,
                                    curve: Curves.easeOut,
                                  ),
                            ],

                            // ── Premium hub (yalnızca premium değilse ve kullanıcı en az bir aksiyon aldıysa) ──
                            if (!isPremium &&
                                (dietProvider.currentStreak > 0 ||
                                    workoutProvider.workouts.isNotEmpty ||
                                    todayEntries.isNotEmpty)) ...[
                              const SizedBox(height: 12),
                              _buildPremiumHubCard(
                                    isPremium: false,
                                    onManage: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const PremiumScreen(),
                                      ),
                                    ),
                                    onCoach: () => Navigator.of(
                                      context,
                                    ).pushNamed('/ai-coach'),
                                    onPhoto: () =>
                                        widget.onNavigateToTab?.call(3),
                                    onTrends: () => Navigator.of(
                                      context,
                                    ).pushNamed('/nutrition-trends'),
                                  )
                                  .animate()
                                  .fadeIn(delay: 100.ms, duration: 240.ms)
                                  .slideY(
                                    begin: 0.04,
                                    end: 0,
                                    duration: 240.ms,
                                    curve: Curves.easeOut,
                                  ),
                            ],
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

class _OnboardingSummarySheet extends StatelessWidget {
  final MacroTargets macroTargets;
  final SuggestedFoodInsight? mealSuggestion;
  final TodayWorkoutSuggestion? workoutSuggestion;
  final Color accent;

  const _OnboardingSummarySheet({
    required this.macroTargets,
    required this.mealSuggestion,
    required this.workoutSuggestion,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF15171B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Bugünün Hızlı Planı',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.96),
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kurulumu bitirdin. Şimdi direkt uygulanabilir ilk adımları görelim.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _SummaryMetric(
                  label: 'Protein',
                  value: '${macroTargets.protein.round()} g',
                  color: const Color(0xFF7BCBFF),
                ),
                const SizedBox(width: 10),
                _SummaryMetric(
                  label: 'Karb',
                  value: '${macroTargets.carb.round()} g',
                  color: const Color(0xFF5FD8B7),
                ),
                const SizedBox(width: 10),
                _SummaryMetric(
                  label: 'Yağ',
                  value: '${macroTargets.fat.round()} g',
                  color: const Color(0xFFFFA56E),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SummaryBlock(
              title: 'Öğün önerisi',
              subtitle: mealSuggestion == null
                  ? 'Makrona uygun ilk öğünü beslenme sekmesinde seçebilirsin.'
                  : '${mealSuggestion!.item.name} • ${mealSuggestion!.suggestedPortionG.round()} g\n${mealSuggestion!.reasons.join(' • ')}',
              icon: Icons.restaurant_rounded,
              color: accent,
            ),
            const SizedBox(height: 10),
            _SummaryBlock(
              title: 'Antrenman önerisi',
              subtitle:
                  workoutSuggestion?.detail ??
                  'Bugün kısa bir başlangıç seansı ile ritim kurabilirsin.',
              icon: workoutSuggestion?.icon ?? Icons.fitness_center_rounded,
              color: workoutSuggestion?.color ?? accent,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Harika, Başlayalım',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 18),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12.5,
                    height: 1.4,
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
