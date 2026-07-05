import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/diet_provider.dart';
import 'diet_dashboard_page.dart';
import 'weekly_meal_plan_page.dart';
import 'profile_setup_page.dart';
import 'food_search_page.dart';
import 'portion_add_page.dart';
import 'add_custom_food_page.dart';
import 'diet_chat_page.dart';
import 'nutrition_trends_page.dart';
import 'smart_grocery_list_page.dart';
import 'nutrition_guide_page.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/grocery_item.dart';
import '../../../recipes/presentation/pages/recipe_list_page.dart';
import '../../../recipes/presentation/pages/recipe_detail_page.dart';
import '../../../recipes/domain/entities/recipe.dart';

/// Diyet sekmesi: kendi Navigator'ı ile Dashboard → Profil / Arama / Porsiyon / Detay.
class DietTabContainer extends StatelessWidget {
  const DietTabContainer({super.key});

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  /// Logout sonrası nested navigator'ı dashboard'a sıfırla.
  static void reset() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  PageRoute<T> _buildRoute<T>(
    Widget page,
    RouteSettings settings, {
    bool animate = true,
  }) {
    if (!animate) {
      return MaterialPageRoute<T>(builder: (_) => page, settings: settings);
    }

    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final secondaryCurved = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-0.03, 0),
              ).animate(secondaryCurved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Navigator(
        key: _navigatorKey,
        initialRoute: 'dashboard',
        onGenerateRoute: (settings) {
          try {
            switch (settings.name) {
              case 'dashboard':
                return _buildRoute(
                  const DietDashboardPage(),
                  settings,
                  animate: false,
                );
              case 'profile':
                final provider = Provider.of<DietProvider>(
                  context,
                  listen: false,
                );
                return _buildRoute(
                  ProfileSetupPage(
                    initial: provider.profile,
                    navigateToHomeOnSave: false,
                  ),
                  settings,
                );
              case 'search':
                final mealType = settings.arguments as MealType?;
                return _buildRoute(
                  FoodSearchPage(selectedMealType: mealType),
                  settings,
                );
              case 'portion':
                final args = settings.arguments as Map<String, dynamic>?;
                final food = args?['food'] as FoodItem?;
                final mealType = args?['mealType'] as MealType?;
                final initialGrams = (args?['initialGrams'] as num?)
                    ?.toDouble();
                if (food == null) {
                  return _buildRoute(
                    const DietDashboardPage(),
                    settings,
                    animate: false,
                  );
                }
                return _buildRoute(
                  PortionAddPage(
                    food: food,
                    selectedMealType: mealType,
                    initialGrams: initialGrams,
                  ),
                  settings,
                );
              case 'add_custom_food':
                return _buildRoute(const AddCustomFoodPage(), settings);
              case 'diet_chat':
                final initialMessage = settings.arguments as String?;
                return _buildRoute(DietChatPage(initialMessage: initialMessage), settings);
              case 'nutrition_trends':
                return _buildRoute(const NutritionTrendsPage(), settings);
              case 'nutrition_guide':
                return _buildRoute(const NutritionGuidePage(), settings);
              case 'weekly_meal_plan':
                return _buildRoute(const WeeklyMealPlanPage(), settings);
              case 'smart_grocery_list':
                final args = settings.arguments as Map<String, dynamic>?;
                final seedItems =
                    (args?['seedItems'] as List?)
                        ?.whereType<String>()
                        .toList() ??
                    const <String>[];
                final seedGroceryItems =
                    (args?['seedGroceryItems'] as List?)
                        ?.whereType<GroceryItem>()
                        .toList() ??
                    const <GroceryItem>[];
                final seedReason = args?['seedReason'] as String?;
                final seedMealName = args?['seedMealName'] as String?;
                return _buildRoute(
                  SmartGroceryListPage(
                    seedItems: seedItems,
                    seedGroceryItems: seedGroceryItems,
                    seedReason: seedReason,
                    seedMealName: seedMealName,
                  ),
                  settings,
                );
              case 'recipes':
                return _buildRoute(const RecipeListPage(), settings);
              case 'recipe_detail':
                final recipe = settings.arguments as Recipe?;
                if (recipe == null) {
                  return _buildRoute(const RecipeListPage(), settings);
                }
                return _buildRoute(RecipeDetailPage(recipe: recipe), settings);
              default:
                return _buildRoute(
                  const DietDashboardPage(),
                  settings,
                  animate: false,
                );
            }
          } catch (e) {
            debugPrint(
              'DietTabContainer route generation hatası: $e, route: ${settings.name}',
            );
            return _buildRoute(
              const DietDashboardPage(),
              settings,
              animate: false,
            );
          }
        },
      ),
    );
  }
}
