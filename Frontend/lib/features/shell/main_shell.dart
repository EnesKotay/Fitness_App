import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/storage_helper.dart';
import '../../core/widgets/app_tour_overlay.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/premium_hub_screen.dart';
import '../home/screens/dashboard_screen.dart';
import '../nutrition/presentation/pages/diet_tab_container.dart';
import '../tracking/screens/tracking_screen.dart';
import '../workout/screens/workout_screen.dart';

const Color _warmAccent = Color(0xFFD89A6A);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final ValueNotifier<int?> tabSwitchRequest = ValueNotifier<int?>(null);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};

  double _fabRight = 16.0;
  double _fabBottom = 72.0;

  // GlobalKey'ler — interaktif tur için her nav öğesini ve FAB'ı hedef alır
  final _navKey0 = GlobalKey();
  final _navKey1 = GlobalKey();
  final _navKey2 = GlobalKey();
  final _navKey3 = GlobalKey();
  final _fabKey = GlobalKey();

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Ana Sayfa'),
    _NavItem(icon: Icons.fitness_center_rounded, label: 'Antrenman'),
    _NavItem(icon: Icons.trending_up_rounded, label: 'Takip'),
    _NavItem(icon: Icons.restaurant_rounded, label: 'Beslenme'),
  ];

  @override
  void initState() {
    super.initState();
    MainShell.tabSwitchRequest.addListener(_handleExternalTabSwitch);
    // Yeni kayıt olan kullanıcı için interaktif turu başlat
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
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
              'Sana 30 saniyede uygulamayı tanıtacağız.\n\nEkrana dokun veya "Sonraki" butonuna bas. İstediğin zaman "Turu Atla" diyebilirsin.',
          emoji: '👋',
          accentColor: Color(0xFF4CAF50),
        ),
        TourStep(
          title: 'Ana Sayfa',
          description:
              'Günlük kalori özetini, su takibini ve hızlı erişim kartlarını buradan gör. Her sabah buradan başla!',
          emoji: '🏠',
          targetKey: _navKey0,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFF4CD1A3),
        ),
        TourStep(
          title: 'Antrenman',
          description:
              '500+ egzersiz rehberi ve antrenman geçmişin burada. "+" butonuyla egzersiz ekle, planını oluştur.',
          emoji: '💪',
          targetKey: _navKey1,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFF5B9BFF),
        ),
        TourStep(
          title: 'Beslenme',
          description:
              'Öğün kaydet, barkod okut veya fotoğrafla tara.\n\n4 alt sekme:\n• Dashboard – günlük özet\n• Öğünler – yemek ekle\n• Rehber – beslenme planın\n• Araçlar – AI tarama, tarifler',
          emoji: '🥗',
          targetKey: _navKey3,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFF4CAF50),
        ),
        TourStep(
          title: 'Takip',
          description:
              'Kilo ve vücut ölçülerini grafik olarak izle. İlerlemenin büyüklüğünü görmek için gir.',
          emoji: '📈',
          targetKey: _navKey2,
          spotShape: TourSpotShape.rect,
          tooltipSide: TourTooltipSide.top,
          accentColor: const Color(0xFFFFB74D),
        ),
        TourStep(
          title: 'Asistan Butonu',
          description:
              'Dokun → AI Koç, Günlük Görevler ve Premium özelliklere anında ulaş.\nSürükleyerek istediğin köşeye taşıyabilirsin!',
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
    if (index < 0 || index >= _navItems.length) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF070809),
      body: LayoutBuilder(
        builder: (context, constraints) {
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
              Positioned(
                right: _fabRight,
                bottom: _fabBottom,
                child: GestureDetector(
                  key: _fabKey,
                  onPanUpdate: (details) {
                    setState(() {
                      _fabRight -= details.delta.dx;
                      _fabBottom -= details.delta.dy;
                      _fabRight = _fabRight.clamp(
                        0.0,
                        constraints.maxWidth - 148.0,
                      );
                      _fabBottom = _fabBottom.clamp(
                        0.0,
                        constraints.maxHeight - 58.0,
                      );
                    });
                  },
                  child: _AssistantFab(onTap: () => _showAsistanSheet(context)),
                ),
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
                _navItems.length,
                (index) => _buildNavItem(index),
              ),
            ),
          ),
        ),
      ),
    );
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
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 34),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF161B2A).withValues(alpha: 0.98),
                const Color(0xFF090C15).withValues(alpha: 0.995),
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
                const SizedBox(height: 24),
                _AssistantHeroCard(isPremium: isPremium),
                const SizedBox(height: 18),
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
                  title: 'Yapay Zeka Koç',
                  subtitle:
                      'Beslenme, antrenman ve gün planı için net yönlendirme al',
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: const Color(0xFFEBC374),
                  badge: 'Önerilen',
                  accentStart: const Color(0xFF322714),
                  accentEnd: const Color(0xFF171B29),
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
                  accentStart: const Color(0xFF1B3042),
                  accentEnd: const Color(0xFF171B29),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.dailyTasks);
                  },
                ),
                const SizedBox(height: 12),
                _AsistanCard(
                  title: 'Premium Özellikler',
                  subtitle:
                      'Daha güçlü analizler ve tüm profesyonel araçları aç',
                  icon: Icons.workspace_premium_rounded,
                  iconColor: const Color(0xFFD97706),
                  isPremium: true,
                  badge: 'PRO',
                  accentStart: const Color(0xFF37210F),
                  accentEnd: const Color(0xFF171B29),
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

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
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
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            splashColor: iconColor.withValues(alpha: 0.1),
            highlightColor: iconColor.withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentStart.withValues(alpha: isPremium ? 0.9 : 0.72),
                    accentEnd.withValues(alpha: 0.98),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isPremium
                      ? iconColor.withValues(alpha: 0.34)
                      : Colors.white.withValues(alpha: 0.08),
                  width: isPremium ? 1.3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: isPremium ? 0.16 : 0.1),
                    blurRadius: 24,
                    spreadRadius: -14,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          iconColor.withValues(alpha: 0.18),
                          iconColor.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.dmSans(
                                  color: isPremium ? iconColor : Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: iconColor.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  badge!,
                                  style: GoogleFonts.dmSans(
                                    color: iconColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withValues(alpha: 0.64),
                            fontSize: 13.2,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withValues(alpha: 0.42),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1D2334), const Color(0xFF161B29)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: accent.withValues(alpha: 0.16)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 24,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: _AssistantSparkleGlyph(color: accent, size: 28),
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
                      'Asistan & Araçlar',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Koç, görevler ve gelişmiş özellikler tek yerde.',
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
          const SizedBox(height: 16),
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
                label: 'Günlük Akış',
              ),
              if (isPremium)
                const _AssistantBadge(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Premium',
                  isAccent: true,
                ),
            ],
          ),
        ],
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

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _AssistantFab extends StatelessWidget {
  const _AssistantFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Asistan Menüsü',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  width: 148,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1B2130).withValues(alpha: 0.76),
                        const Color(0xFF0D1220).withValues(alpha: 0.88),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
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
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEBC374,
                                ).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(
                                    0xFFEBC374,
                                  ).withValues(alpha: 0.1),
                                ),
                              ),
                              child: const Center(
                                child: _AssistantSparkleGlyph(
                                  color: Color(0xFFEBC374),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
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
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: const Alignment(-0.25, 0.1),
            child: Transform.rotate(
              angle: 0.15,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: color,
                size: size * 0.74,
              ),
            ),
          ),
          Positioned(
            top: size * 0.1,
            right: size * 0.08,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: color.withValues(alpha: 0.96),
              size: size * 0.28,
            ),
          ),
          Positioned(
            bottom: size * 0.06,
            right: size * 0.12,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: color.withValues(alpha: 0.9),
              size: size * 0.24,
            ),
          ),
        ],
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
