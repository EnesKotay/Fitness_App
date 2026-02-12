import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/ai_service.dart';
import 'core/utils/storage_helper.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_text_styles.dart';
import 'core/widgets/app_gradient_background.dart';
import 'core/widgets/app_hero_card.dart';
import 'core/widgets/stat_chip.dart';
import 'core/widgets/section_header.dart';
import 'core/widgets/empty_state.dart';
import 'core/widgets/app_card.dart';
import 'core/widgets/app_button.dart';
import 'features/nutrition/data/datasources/hive_diet_storage.dart';
import 'features/nutrition/presentation/state/diet_provider.dart';
import 'features/nutrition/presentation/pages/diet_tab_container.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/tracking/providers/tracking_provider.dart';
import 'features/workout/providers/workout_provider.dart';
import 'features/workout/presentation/providers/workout_catalog_provider.dart';
import 'features/nutrition/providers/nutrition_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/tracking/screens/tracking_screen.dart';
import 'features/weight/presentation/providers/weight_provider.dart';
import 'features/workout/presentation/workout_tab_container.dart';
import 'core/theme/app_theme.dart';
import 'features/nutrition/presentation/pages/profile_setup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('dotenv load error: $e');
  }

  // Zorunlu: Token ve prefs init edilmeden getToken() kullanılmamalı; yoksa null döner ve login'e atar.
  await StorageHelper.init();

  try {
    await HiveDietStorage.init();
  } catch (_) {}

  // Türkçe tarih formatı - arka planda yükle (main thread bloklamasın)
  unawaited(initializeDateFormatting('tr_TR'));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => WeightProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => NutritionProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutCatalogProvider()),
        Provider(create: (_) => AIService()),
        ChangeNotifierProxyProvider3<WeightProvider, WorkoutProvider, AIService, DietProvider>(
          create: (_) => DietProvider(),
          update: (_, weightProvider, workoutProvider, aiService, dietProvider) =>
              dietProvider!
                ..setWeightProvider(weightProvider)
                ..setWorkoutProvider(workoutProvider)
                ..setAIService(aiService),
        ),
      ],
      child: MaterialApp(
        title: 'Fitness Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const MainShell(),
          '/profile': (context) => const ProfileScreen(),
          '/profile-setup': (context) => const ProfileSetupPage(),
        },
      ),
    );
  }
}

/// Splash Screen - Uygulama başlangıcında oturum kontrolü yapar
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Provider'lar (özellikle ProxyProvider) ilk build'den sonra hazır olur;
    // build sırasında Navigator çağrısı yapılmamalı (setState during build hatası önlenir).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    DietProvider? dietProvider;
    WeightProvider? weightProvider;
    try {
      dietProvider = Provider.of<DietProvider>(context, listen: false);
      weightProvider = Provider.of<WeightProvider>(context, listen: false);
    } catch (e) {
      debugPrint('Splash provider error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      await authProvider.checkAuthStatus().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('Splash auth error: $e');
    }

    if (!mounted) return;
    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      unawaited(weightProvider!.loadEntries());
      await dietProvider!.init().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Splash: DietProvider.init timeout, devam ediliyor.');
          return;
        },
      );
    } catch (e) {
      debugPrint('Splash init error: $e');
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    if (dietProvider!.profile == null) {
      Navigator.of(context).pushReplacementNamed('/profile-setup');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Fitness Tracker',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Ana kabuk: Bottom Navigation Bar ile tab geçişi
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  // Lazy load: Antrenman, Takip, Beslenme ilk seçildiğinde build edilir
  final Set<int> _visitedTabs = {0};

  // Alt navigasyon bar sekmeleri
  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Ana Sayfa'),
    _NavItem(icon: Icons.fitness_center_rounded, label: 'Antrenman'),
    _NavItem(icon: Icons.trending_up_rounded, label: 'Takip'),
    _NavItem(icon: Icons.restaurant_rounded, label: 'Beslenme'),
  ];

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            onAddMeal: () => _onTabSelected(3),
            onStartWorkout: () => _onTabSelected(1),
            onNavigateToTab: _onTabSelected,
          ),
          _visitedTabs.contains(1) ? const WorkoutTabContainer() : const SizedBox.shrink(),
          _visitedTabs.contains(2) ? const TrackingScreen() : const SizedBox.shrink(),
          _visitedTabs.contains(3) ? const DietTabContainer() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
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
                    ? const Color(0xFFCC7A4A)
                    : Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFFCC7A4A)
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
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

/// Placeholder ekran: Henüz geliştirilmemiş sekmeler için
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 64,
                color: const Color(0xFFCC7A4A).withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yakında...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ana sayfa (Dashboard) içeriği - gerçek veri: NutritionProvider, WorkoutProvider
class HomeScreen extends StatefulWidget {
  final VoidCallback? onAddMeal;
  final VoidCallback? onStartWorkout;
  /// Profil sayfasından "Hızlı erişim" ile dönüldüğünde açılacak sekme (0=Ana, 1=Antrenman, 2=Takip, 3=Beslenme)
  final void Function(int index)? onNavigateToTab;

  const HomeScreen({
    super.key,
    this.onAddMeal,
    this.onStartWorkout,
    this.onNavigateToTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final now = DateTime.now();
    await Future.wait([
      nutritionProvider.loadMealsByDate(userId, now),
      workoutProvider.loadWorkouts(userId),
    ]);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static const _mealTypeLabels = {
    'BREAKFAST': 'Kahvaltı',
    'LUNCH': 'Öğle',
    'DINNER': 'Akşam',
    'SNACK': 'Ara öğün',
  };

  static const _mealTypeIcons = {
    'BREAKFAST': Icons.wb_sunny_outlined,
    'LUNCH': Icons.wb_cloudy_outlined,
    'DINNER': Icons.nightlight_round_outlined,
    'SNACK': Icons.apple,
  };

  Widget _buildMealItem(IconData icon, String mealType, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.secondary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              children: [
                TextSpan(text: '$mealType: ', style: AppTextStyles.labelLarge.copyWith(color: AppColors.secondary)),
                TextSpan(text: content),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetCalories = StorageHelper.getTargetCalories() ?? 2000;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppGradientBackground(
        imagePath: 'assets/images/home_bg.jpg',
        child: SafeArea(
          child: Consumer4<AuthProvider, NutritionProvider, WorkoutProvider, DietProvider>(
          builder: (context, authProvider, nutritionProvider, workoutProvider, dietProvider, child) {
            final dailyCalories = nutritionProvider.dailyCalories;
            final progress = (dailyCalories / targetCalories).clamp(0.0, 1.0);
            final todayMeals = nutritionProvider.meals;
            final now = DateTime.now();
            final todayWorkouts = workoutProvider.workouts
                .where((w) => _isSameDay(w.workoutDate, now))
                .toList();
            final firstWorkout = todayWorkouts.isNotEmpty ? todayWorkouts.first : null;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Merhaba, ${dietProvider.profile?.name ?? authProvider.user?.name ?? 'Kullanıcı'} 👋',
                              style: AppTextStyles.titleMedium
                            ),
                            const SizedBox(height: 4),
                            Text('Bugün hedeflerine ne kadar yaklaştın?', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                        InkWell(
                          onTap: () async {
                            final result = await Navigator.pushNamed(context, '/profile');
                            if (result is int && widget.onNavigateToTab != null) {
                              widget.onNavigateToTab!(result);
                            }
                          },
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary,
                            child: const Icon(Icons.person, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  AppHeroCard(
                    title: 'Günlük hedef',
                    subtitle: 'Kalori ilerlemesi',
                    accentColor: AppColors.primary,
                    progress: progress,
                    progressLabel: '%${(progress * 100).round()}',
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.m),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          StatChip(icon: Icons.directions_walk, iconColor: AppColors.primary, value: '—', label: 'Adım'),
                          StatChip(icon: Icons.local_fire_department, iconColor: AppColors.secondary, value: '$dailyCalories / $targetCalories', label: 'Kalori'),
                          StatChip(icon: Icons.water_drop, iconColor: Colors.blue, value: '—', label: 'Su'),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          accentColor: AppColors.secondary,
                          onTap: widget.onAddMeal,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l, horizontal: AppSpacing.m),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                                child: Icon(Icons.restaurant_menu, color: AppColors.secondary, size: 28),
                              ),
                              const SizedBox(height: AppSpacing.s),
                              Text('Yemek Ekle', style: AppTextStyles.sectionSubtitle),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 50.ms, duration: 200.ms).slideX(begin: -0.03, end: 0, duration: 200.ms, curve: Curves.easeOut),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: AppCard(
                          accentColor: AppColors.primary,
                          onTap: widget.onStartWorkout,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l, horizontal: AppSpacing.m),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                                child: Icon(Icons.fitness_center, color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(height: AppSpacing.s),
                              Text('Antrenmana Başla', style: AppTextStyles.sectionSubtitle),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 200.ms).slideX(begin: 0.03, end: 0, duration: 200.ms, curve: Curves.easeOut),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Bugün ne yedin?',
                          subtitle: todayMeals.isEmpty ? 'İlk öğününü ekleyerek başla' : null,
                          action: AppButton.text(onPressed: widget.onAddMeal, text: 'Ekle', icon: Icons.add),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        if (todayMeals.isEmpty)
                          EmptyState(
                            icon: Icons.restaurant_outlined,
                            title: 'Henüz yemek yok',
                            message: 'Bugün yediklerini ekleyerek kalori hedefini takip et.',
                            ctaText: 'Yemek ekle',
                            onCtaPressed: widget.onAddMeal,
                            iconColor: AppColors.secondary,
                          )
                        else
                          ...todayMeals.map((m) {
                            final label = _mealTypeLabels[m.mealType] ?? m.mealType;
                            final icon = _mealTypeIcons[m.mealType] ?? Icons.restaurant;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildMealItem(icon, label, '${m.name} (${m.calories} kcal)'),
                            );
                          }),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: 200.ms).slideY(begin: 0.03, end: 0, duration: 200.ms, curve: Curves.easeOut),
                  const SizedBox(height: AppSpacing.m),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Bugünün antrenmanı',
                          action: AppButton.text(onPressed: widget.onStartWorkout, text: 'Başla', icon: Icons.play_arrow),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        if (firstWorkout == null)
                          EmptyState(
                            icon: Icons.fitness_center_outlined,
                            title: 'Henüz antrenman yok',
                            message: 'Bugün çalıştığın bölgeyi seçip antrenmanı kaydet.',
                            ctaText: 'Antrenmana başla',
                            onCtaPressed: widget.onStartWorkout,
                            iconColor: AppColors.primary,
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.fitness_center, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(firstWorkout.name, style: AppTextStyles.sectionSubtitle),
                                    if (firstWorkout.durationMinutes != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                                          const SizedBox(width: 4),
                                          Text('${firstWorkout.durationMinutes} dk', style: AppTextStyles.bodySmall),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 200.ms).slideY(begin: 0.03, end: 0, duration: 200.ms, curve: Curves.easeOut),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  }
}
