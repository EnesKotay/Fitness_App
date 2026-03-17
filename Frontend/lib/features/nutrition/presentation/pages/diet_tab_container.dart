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

/// Diyet sekmesi: kendi Navigator'ı ile Dashboard → Profil / Arama / Porsiyon / Detay.
class DietTabContainer extends StatelessWidget {
  const DietTabContainer({super.key});

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  /// Logout sonrası nested navigator'ı dashboard'a sıfırla.
  static void reset() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      initialRoute: 'dashboard',
      onGenerateRoute: (settings) {
        try {
          switch (settings.name) {
            case 'dashboard':
              return MaterialPageRoute(
                builder: (_) => const DietDashboardPage(),
              );
            case 'profile':
              final provider = Provider.of<DietProvider>(
                context,
                listen: false,
              );
              return MaterialPageRoute(
                builder: (_) => ProfileSetupPage(
                  initial: provider.profile,
                  navigateToHomeOnSave: false,
                ),
              );
            case 'search':
              final mealType = settings.arguments as MealType?;
              return MaterialPageRoute(
                builder: (_) => FoodSearchPage(selectedMealType: mealType),
              );
            case 'portion':
              final args = settings.arguments as Map<String, dynamic>?;
              final food = args?['food'] as FoodItem?;
              final mealType = args?['mealType'] as MealType?;
              final initialGrams = (args?['initialGrams'] as num?)?.toDouble();
              if (food == null) {
                return MaterialPageRoute(
                  builder: (_) => const DietDashboardPage(),
                );
              }
              return MaterialPageRoute(
                builder: (_) => PortionAddPage(
                  food: food,
                  selectedMealType: mealType,
                  initialGrams: initialGrams,
                ),
              );
            case 'add_custom_food':
              return MaterialPageRoute(
                builder: (_) => const AddCustomFoodPage(),
              );
            case 'diet_chat':
              return MaterialPageRoute(builder: (_) => const DietChatPage());
            case 'nutrition_trends':
              return MaterialPageRoute(
                builder: (_) => const NutritionTrendsPage(),
              );
            case 'nutrition_guide':
              return MaterialPageRoute(
                builder: (_) => const NutritionGuidePage(),
              );
            case 'weekly_meal_plan':
              return MaterialPageRoute(
                builder: (_) => const WeeklyMealPlanPage(),
              );
            case 'smart_grocery_list':
              final args = settings.arguments as Map<String, dynamic>?;
              final seedItems =
                  (args?['seedItems'] as List?)?.whereType<String>().toList() ??
                  const <String>[];
              final seedReason = args?['seedReason'] as String?;
              final seedMealName = args?['seedMealName'] as String?;
              return MaterialPageRoute(
                builder: (_) => SmartGroceryListPage(
                  seedItems: seedItems,
                  seedReason: seedReason,
                  seedMealName: seedMealName,
                ),
              );
            default:
              return MaterialPageRoute(
                builder: (_) => const DietDashboardPage(),
              );
          }
        } catch (e) {
          debugPrint(
            'DietTabContainer route generation hatası: $e, route: ${settings.name}',
          );
          return MaterialPageRoute(builder: (_) => const DietDashboardPage());
        }
      },
    );
  }
}
