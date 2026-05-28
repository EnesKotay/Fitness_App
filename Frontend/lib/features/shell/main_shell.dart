import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/storage_helper.dart';
import '../../core/widgets/assistant_fab_visibility.dart';
import '../../core/widgets/app_tour_overlay.dart';
import '../../core/services/page_guide_service.dart';
import '../../core/services/update_checker_service.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/premium_hub_screen.dart';
import '../home/screens/dashboard_screen.dart';
import '../nutrition/presentation/pages/diet_tab_container.dart';
import '../tracking/screens/tracking_screen.dart';
import '../workout/screens/workout_screen.dart';

const Color _warmAccent = Color(0xFFD89A6A);
const double _assistantFabWidth = 148.0;
const double _assistantFabHeight = 58.0;
const double _assistantFabEdgePadding = 16.0;
const double _assistantFabBottomPadding = 72.0;

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final ValueNotifier<int?> tabSwitchRequest = ValueNotifier<int?>(null);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};

  double _fabRight = _assistantFabEdgePadding;
  double _fabBottom = _assistantFabBottomPadding;
  bool _isDraggingFab = false;
  bool _didRestoreFabCorner = false;

  // GlobalKey'ler — interaktif tur için her nav öğesini ve FAB'ı hedef alır
  final _navKey0 = GlobalKey();
  final _navKey1 = GlobalKey();
  final _navKey2 = GlobalKey();
  final _navKey3 = GlobalKey();
  final _fabKey = GlobalKey();

  static List<_NavItem> _navItemsFor(bool english) => [
    _NavItem(icon: Icons.home_rounded, label: english ? 'Home' : 'Ana Sayfa'),
    _NavItem(
      icon: Icons.fitness_center_rounded,
      label: english ? 'Workout' : 'Antrenman',
    ),
    _NavItem(
      icon: Icons.trending_up_rounded,
      label: english ? 'Progress' : 'Takip',
    ),
    _NavItem(
      icon: Icons.restaurant_rounded,
      label: english ? 'Nutrition' : 'Beslenme',
    ),
  ];

  @override
  void initState() {
    super.initState();
    MainShell.tabSwitchRequest.addListener(_handleExternalTabSwitch);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeCheckUpdate();
      await _maybeOfferUsExperience();
      _maybeStartTour();
    });
  }

  Future<void> _maybeCheckUpdate() async {
    if (!mounted) return;
    await UpdateCheckerService.checkAndPrompt(context);
  }

  Future<void> _maybeOfferUsExperience() async {
    if (!mounted || StorageHelper.getUsExperiencePromptSeen()) return;
    final prefs = context.read<AppPreferences>();
    final shouldOffer =
        prefs.effectiveMarketRegion == 'US' &&
        prefs.language == AppLanguage.system &&
        prefs.unitSystem == AppUnitSystem.system &&
        prefs.marketRegion == AppMarketRegion.system;
    if (!shouldOffer) return;

    await StorageHelper.saveUsExperiencePromptSeen(true);
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171A20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Use US experience?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Switch to English, lb/in, fl oz, and US-style meal suggestions.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Use US'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await prefs.setLanguage(AppLanguage.en);
    await prefs.setUnitSystem(AppUnitSystem.imperial);
    await prefs.setMarketRegion(AppMarketRegion.us);
  }

  Future<void> _maybeStartTour() async {
    if (!mounted) return;
    final shouldShowTour =
        StorageHelper.getPendingAppTour() && !StorageHelper.getAppTourSeen();
    if (!shouldShowTour) return;

    // Kısa gecikme: UI tam oturandan sonra başlat
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _startTour();
  }

  void _startTour() {
    AppTourOverlay.show(
      context,
      steps: [
        const TourStep(
          title: 'Hoş Geldin!',
          description:
              'Uygulamayı birkaç kısa adımda tanıyalım. İstediğin zaman turu atlayabilirsin.',
          emoji: '👋',
          accentColor: Color(0xFF4CAF50),
        ),
        TourStep(
          title: 'Ana Sayfa',
          description:
              'Bugünün planını, kalori durumunu ve hızlı aksiyonları burada görürsün.',
          emoji: '🏠',
          targetKey: _navKey0,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFF4CD1A3),
        ),
        TourStep(
          title: 'Antrenman',
          description:
              'Bugünkü antrenmanı başlatır, programını ve egzersiz rehberini buradan açarsın.',
          emoji: '💪',
          targetKey: _navKey1,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFF5B9BFF),
        ),
        TourStep(
          title: 'Beslenme',
          description:
              'Yemek ekle, yemek analizi yap ve AI Koçtan beslenme yorumu al.',
          emoji: '🥗',
          targetKey: _navKey3,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFF4CAF50),
        ),
        TourStep(
          title: 'Takip',
          description:
              'Kilo, ölçü ve antrenman performansını grafiklerle takip edersin.\n\n'
              'Ayrıca Toparlanma Skoru kartıyla uyku, kas ve su verilerini birleştirerek bugün ne kadar hazır olduğunu görürsün.',
          emoji: '📈',
          targetKey: _navKey2,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFFFFB74D),
        ),
        TourStep(
          title: 'Asistan Butonu',
          description:
              'AI Koç ve günlük görevlere hızlı erişim sağlar; sürükleyince köşelere sabitlenir.',
          emoji: '✨',
          targetKey: _fabKey,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFFEBC374),
        ),
      ],
      onComplete: () async {
        await StorageHelper.saveAppTourSeen(true);
        await StorageHelper.savePendingAppTour(false);
        // Tur zaten dashboard içeriğini kapsıyor; sayfa rehberini tekrar gösterme
        await PageGuideService.markGuideSeen('dashboard');
      },
    );
  }

  @override
  void dispose() {
    MainShell.tabSwitchRequest.removeListener(_handleExternalTabSwitch);
    super.dispose();
  }

  void _handleExternalTabSwitch() {
    final index = MainShell.tabSwitchRequest.value;
    if (index == null) {
      return;
    }
    MainShell.tabSwitchRequest.value = null;
    if (index < 0 || index >= 4) {
      return;
    }
    _onTabSelected(index);
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final english =
        context.watch<AppPreferences>().effectiveLanguageCode == 'en';
    final navItems = _navItemsFor(english);
    return Scaffold(
      backgroundColor: const Color(0xFF070809),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _restoreFabCornerIfNeeded(constraints);
          return Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: [
                  DashboardScreen(
                    onAddMeal: () => _onTabSelected(3),
                    onStartWorkout: () => _onTabSelected(1),
                    onNavigateToTab: _onTabSelected,
                  ),
                  _visitedTabs.contains(1)
                      ? const WorkoutScreen()
                      : const _TabLoadingPlaceholder(),
                  _visitedTabs.contains(2)
                      ? const TrackingScreen()
                      : const _TabLoadingPlaceholder(),
                  _visitedTabs.contains(3)
                      ? const DietTabContainer()
                      : const _TabLoadingPlaceholder(),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AssistantFabVisibility.hidden,
                builder: (context, hidden, _) {
                  if (hidden) return const SizedBox.shrink();
                  return AnimatedPositioned(
                    duration: _isDraggingFab
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    right: _fabRight,
                    bottom: _fabBottom,
                    child: GestureDetector(
                      key: _fabKey,
                      onPanStart: (_) {
                        setState(() => _isDraggingFab = true);
                      },
                      onPanUpdate: (details) {
                        _moveFabWithDrag(details.delta, constraints);
                      },
                      onPanEnd: (_) {
                        _snapFabToNearestCorner(constraints);
                      },
                      onPanCancel: () {
                        _snapFabToNearestCorner(constraints);
                      },
                      child: _AssistantFab(
                        onTap: () => _showAsistanSheet(context),
                        compact: _selectedIndex == 2 || _selectedIndex == 3,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111317),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                navItems.length,
                (index) => _buildNavItem(index, navItems[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _moveFabWithDrag(Offset delta, BoxConstraints constraints) {
    setState(() {
      _fabRight = (_fabRight - delta.dx).clamp(
        _assistantFabEdgePadding,
        _maxFabRight(constraints),
      );
      _fabBottom = (_fabBottom - delta.dy).clamp(
        _assistantFabBottomPadding,
        _maxFabBottom(constraints),
      );
    });
  }

  void _snapFabToNearestCorner(BoxConstraints constraints) {
    final fabCenterX =
        constraints.maxWidth - _fabRight - (_assistantFabWidth / 2);
    final fabCenterY =
        constraints.maxHeight - _fabBottom - (_assistantFabHeight / 2);
    final shouldStayRight = fabCenterX >= constraints.maxWidth / 2;
    final shouldStayBottom = fabCenterY >= constraints.maxHeight / 2;

    setState(() {
      _isDraggingFab = false;
      _fabRight = shouldStayRight
          ? _assistantFabEdgePadding
          : _maxFabRight(constraints);
      _fabBottom = shouldStayBottom
          ? _assistantFabBottomPadding
          : _maxFabBottom(constraints);
    });
    final horizontal = shouldStayRight ? 'Right' : 'Left';
    final vertical = shouldStayBottom ? 'bottom' : 'top';
    StorageHelper.saveAssistantFabCorner('$vertical$horizontal');
  }

  void _restoreFabCornerIfNeeded(BoxConstraints constraints) {
    if (_didRestoreFabCorner) return;
    _didRestoreFabCorner = true;
    final savedCorner = StorageHelper.getAssistantFabCorner();
    final shouldStayRight = savedCorner.endsWith('Right');
    final shouldStayBottom = savedCorner.startsWith('bottom');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _fabRight = shouldStayRight
            ? _assistantFabEdgePadding
            : _maxFabRight(constraints);
        _fabBottom = shouldStayBottom
            ? _assistantFabBottomPadding
            : _maxFabBottom(constraints);
      });
    });
  }

  double _maxFabRight(BoxConstraints constraints) {
    return (constraints.maxWidth -
            _assistantFabWidth -
            _assistantFabEdgePadding)
        .clamp(_assistantFabEdgePadding, constraints.maxWidth)
        .toDouble();
  }

  double _maxFabBottom(BoxConstraints constraints) {
    return (constraints.maxHeight -
            _assistantFabHeight -
            _assistantFabEdgePadding)
        .clamp(_assistantFabBottomPadding, constraints.maxHeight)
        .toDouble();
  }

  void _showAsistanSheet(BuildContext context) {
    final tier = context
        .read<AuthProvider?>()
        ?.user
        ?.premiumTier
        ?.toLowerCase()
        .trim();
    final isPremium = tier == 'premium';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF151B2A).withValues(alpha: 0.98),
                const Color(0xFF090D17).withValues(alpha: 0.995),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFEBC374).withValues(alpha: 0.14),
                width: 1.1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 42,
                offset: const Offset(0, -14),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 22),
                _AssistantHeroCard(isPremium: isPremium),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Hızlı Erişim',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AsistanCard(
                  title: 'AI Koç',
                  subtitle:
                      'Beslenme, antrenman ve günlük kararlarında yardım al',
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: const Color(0xFFEBC374),
                  badge: 'Önerilen',
                  accentStart: const Color(0xFF272112),
                  accentEnd: const Color(0xFF121826),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.aiCoach);
                  },
                ),
                const SizedBox(height: 12),
                _AsistanCard(
                  title: 'Günlük Görevler',
                  subtitle:
                      'Hedeflerini küçük adımlara böl ve düzenli takip et',
                  icon: Icons.checklist_rounded,
                  iconColor: const Color(0xFF7BCBFF),
                  accentStart: const Color(0xFF132839),
                  accentEnd: const Color(0xFF121826),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.dailyTasks);
                  },
                ),
                const SizedBox(height: 12),
                _AsistanCard(
                  title: 'Premium Özellikler',
                  subtitle: 'Gelişmiş analiz ve otomasyon araçlarını aç',
                  icon: Icons.workspace_premium_rounded,
                  iconColor: const Color(0xFFD97706),
                  isPremium: true,
                  badge: 'PRO',
                  accentStart: const Color(0xFF2B1908),
                  accentEnd: const Color(0xFF121826),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PremiumHubScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nav item'ları için uygun GlobalKey'i döndürür
  GlobalKey _navKeyFor(int index) {
    switch (index) {
      case 0:
        return _navKey0;
      case 1:
        return _navKey1;
      case 2:
        return _navKey2;
      case 3:
        return _navKey3;
      default:
        return _navKey0;
    }
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        key: _navKeyFor(index),
        onTap: () => _onTabSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 24,
                color: isSelected
                    ? _warmAccent
                    : Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? _warmAccent
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AsistanCard extends StatelessWidget {
  const _AsistanCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.accentStart,
    required this.accentEnd,
    this.isPremium = false,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Color accentStart;
  final Color accentEnd;
  final bool isPremium;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final titleColor = isPremium ? iconColor : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: iconColor.withValues(alpha: 0.1),
        highlightColor: iconColor.withValues(alpha: 0.05),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentStart.withValues(alpha: isPremium ? 0.64 : 0.52),
                accentEnd.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPremium
                  ? iconColor.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.075),
              width: isPremium ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: isPremium ? 0.12 : 0.07),
                blurRadius: 22,
                spreadRadius: -16,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.2),
                      iconColor.withValues(alpha: 0.075),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: iconColor.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: titleColor,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          _AssistantMiniBadge(
                            label: badge!,
                            color: iconColor,
                            filled: isPremium,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.34,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.44),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantHeroCard extends StatelessWidget {
  const _AssistantHeroCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final accent = isPremium
        ? const Color(0xFFEBC374)
        : const Color(0xFF7BCBFF);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF20283B).withValues(alpha: 0.92),
              const Color(0xFF121827).withValues(alpha: 0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 28,
              spreadRadius: -18,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      accent.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.18),
                        ),
                      ),
                      child: _AssistantSparkleGlyph(color: accent, size: 27),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isPremium) ...[
                            Text(
                              'PRO Erişim',
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFFEBC374),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            'Asistan Merkezi',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Koçluk, görevler ve gelişmiş araçlar tek dokunuşta.',
                            style: GoogleFonts.dmSans(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 13.2,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _AssistantAccessBadge(isPremium: isPremium),
                  ],
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const _AssistantBadge(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'AI Koç',
                    ),
                    const _AssistantBadge(
                      icon: Icons.checklist_rounded,
                      label: 'Görevler',
                    ),
                    _AssistantBadge(
                      icon: isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_open_rounded,
                      label: isPremium ? 'Premium' : 'Keşfet',
                      isAccent: isPremium,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantAccessBadge extends StatelessWidget {
  const _AssistantAccessBadge({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final accent = isPremium
        ? const Color(0xFFEBC374)
        : const Color(0xFF7BCBFF);
    final label = isPremium ? 'PRO' : 'Standart';
    final icon = isPremium
        ? Icons.workspace_premium_rounded
        : Icons.person_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isPremium ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMiniBadge extends StatelessWidget {
  const _AssistantMiniBadge({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _AssistantFab extends StatelessWidget {
  const _AssistantFab({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 124.0 : 148.0;
    final height = compact ? 50.0 : 58.0;
    final radius = compact ? 20.0 : 24.0;
    final iconBox = compact ? 34.0 : 40.0;
    final iconRadius = compact ? 12.0 : 14.0;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Asistan Menüsü',
        child: Opacity(
          opacity: compact ? 0.9 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEBC374).withValues(alpha: 0.1),
                  blurRadius: 22,
                  spreadRadius: -12,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 18,
                  spreadRadius: -12,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(radius),
                  child: Ink(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1B2130).withValues(alpha: 0.66),
                          const Color(0xFF0D1220).withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 14,
                          right: 14,
                          top: 8,
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: iconBox,
                                height: iconBox,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEBC374,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                    iconRadius,
                                  ),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFEBC374,
                                    ).withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Center(
                                  child: _AssistantSparkleGlyph(
                                    color: const Color(0xFFEBC374),
                                    size: compact ? 17 : 20,
                                  ),
                                ),
                              ),
                              SizedBox(width: compact ? 8 : 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Asistan',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white,
                                        fontSize: compact ? 12.5 : 13.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    if (!compact) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        'Koç ve araçlar',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(
                                          color: Colors.white.withValues(
                                            alpha: 0.56,
                                          ),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                width: compact ? 24 : 28,
                                height: compact ? 24 : 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withValues(alpha: 0.48),
                                  size: 18,
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
        ),
      ),
    );
  }
}

class _AssistantSparkleGlyph extends StatelessWidget {
  const _AssistantSparkleGlyph({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.08),
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          color: color,
          size: size * 0.72,
        ),
      ),
    );
  }
}

class _AssistantBadge extends StatelessWidget {
  const _AssistantBadge({
    required this.icon,
    required this.label,
    this.isAccent = false,
  });

  final IconData icon;
  final String label;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final color = isAccent ? const Color(0xFFEBC374) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isAccent
            ? const Color(0xFFEBC374).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isAccent
              ? const Color(0xFFEBC374).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color.withValues(alpha: isAccent ? 1 : 0.82),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: color.withValues(alpha: isAccent ? 1 : 0.78),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Loading Placeholder ──────────────────────────────────────────────────

class _TabLoadingPlaceholder extends StatelessWidget {
  const _TabLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF070809),
      body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
