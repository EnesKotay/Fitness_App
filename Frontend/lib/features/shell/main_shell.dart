import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/premium_hub_screen.dart';
import '../home/screens/dashboard_screen.dart';
import '../nutrition/presentation/pages/diet_tab_container.dart';
import '../tracking/screens/tracking_screen.dart';
import '../workout/screens/workout_screen.dart';

const Color _warmAccent = Color(0xFFD89A6A);
const Color _freshGreen = Color(0xFF5FAE78);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final ValueNotifier<int?> tabSwitchRequest = ValueNotifier<int?>(null);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};
  bool _quickMenuOpen = false;

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
      _quickMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070809),
      body: Column(
        children: [
          const _OfflineBanner(),
          Expanded(child: IndexedStack(
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
      )),
        ],
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: _QuickAccessFab(
          isOpen: _quickMenuOpen,
          onToggle: () => setState(() => _quickMenuOpen = !_quickMenuOpen),
          onActionSelected: () => setState(() => _quickMenuOpen = false),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
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

class _QuickAccessFab extends StatelessWidget {
  const _QuickAccessFab({
    required this.isOpen,
    required this.onToggle,
    required this.onActionSelected,
  });

  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onActionSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isOpen
              ? Column(
                  key: const ValueKey('quick-actions-open'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _QuickMiniFab(
                      heroTag: 'daily_tasks_fab',
                      tooltip: 'Günlük Görevler',
                      backgroundColor: _warmAccent,
                      icon: Icons.checklist_rounded,
                      onPressed: () {
                        onActionSelected();
                        Navigator.pushNamed(context, AppRoutes.dailyTasks);
                      },
                    ),
                    const SizedBox(height: 10),
                    _QuickMiniFab(
                      heroTag: 'ai_coach_fab',
                      tooltip: 'AI Koç',
                      backgroundColor: _freshGreen,
                      icon: Icons.auto_awesome_rounded,
                      onPressed: () {
                        onActionSelected();
                        Navigator.pushNamed(context, AppRoutes.aiCoach);
                      },
                    ),
                    const SizedBox(height: 10),
                    _ProMenuFab(
                      onPressed: () {
                        onActionSelected();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PremiumHubScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton.small(
          heroTag: 'quick_access_toggle_fab',
          tooltip: isOpen ? 'Kısayolları Kapat' : 'Kısayolları Aç',
          onPressed: onToggle,
          backgroundColor: const Color(0xFF171A20),
          child: AnimatedRotation(
            turns: isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(
              isOpen ? Icons.close_rounded : Icons.grid_view_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickMiniFab extends StatelessWidget {
  const _QuickMiniFab({
    required this.heroTag,
    required this.tooltip,
    required this.backgroundColor,
    required this.icon,
    required this.onPressed,
  });

  final String heroTag;
  final String tooltip;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      tooltip: tooltip,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

// ─── Offline Banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner();

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && offline != _offline) setState(() => _offline = offline);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xFF7F1D1D),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white70),
            SizedBox(width: 6),
            Text(
              'İnternet bağlantısı yok',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      body: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

// ─── PRO Menü FAB ─────────────────────────────────────────────────────────────

class _ProMenuFab extends StatelessWidget {
  const _ProMenuFab({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isPremium =
        context.watch<AuthProvider>().user?.premiumTier == 'premium';

    return GestureDetector(
      onTap: onPressed ??
          () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PremiumHubScreen()),
              ),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isPremium
                ? [const Color(0xFFD97706), const Color(0xFFB45309)]
                : [const Color(0xFF2A2A2E), const Color(0xFF1A1A1E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isPremium
                ? const Color(0xFFD97706).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: isPremium
              ? [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Icon(
          isPremium
              ? Icons.workspace_premium_rounded
              : Icons.lock_rounded,
          color: isPremium
              ? const Color(0xFFFBBF24)
              : Colors.white.withValues(alpha: 0.4),
          size: 20,
        ),
      ),
    );
  }
}
