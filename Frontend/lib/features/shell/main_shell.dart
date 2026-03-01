import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../home/screens/dashboard_screen.dart';
import '../nutrition/presentation/pages/diet_tab_container.dart';
import '../tracking/screens/tracking_screen.dart';
import '../workout/presentation/workout_tab_container.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070809),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(
            onAddMeal: () => _onTabSelected(3),
            onStartWorkout: () => _onTabSelected(1),
            onNavigateToTab: _onTabSelected,
          ),
          _visitedTabs.contains(1)
              ? const WorkoutTabContainer()
              : const SizedBox.shrink(),
          _visitedTabs.contains(2)
              ? const TrackingScreen()
              : const SizedBox.shrink(),
          _visitedTabs.contains(3)
              ? const DietTabContainer()
              : const SizedBox.shrink(),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'daily_tasks_fab',
              tooltip: 'Gunluk Gorevler',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.dailyTasks),
              backgroundColor: _warmAccent,
              child: const Icon(Icons.checklist_rounded, color: Colors.white),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.small(
              heroTag: 'ai_coach_fab',
              tooltip: 'AI Koc',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.aiCoach),
              backgroundColor: _freshGreen,
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
              ),
            ),
          ],
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

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
