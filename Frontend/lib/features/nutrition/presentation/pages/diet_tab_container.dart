import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/diet_provider.dart';
import 'diet_dashboard_page.dart';
import 'profile_setup_page.dart';
import 'food_search_page.dart';
import 'portion_add_page.dart';
import 'food_detail_page.dart';
import 'add_custom_food_page.dart';
import 'diet_chat_page.dart';
import 'test_mode_page.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';

/// Diyet sekmesi: kendi Navigator'ı ile Dashboard → Profil / Arama / Porsiyon / Detay.
class DietTabContainer extends StatelessWidget {
  const DietTabContainer({super.key});

  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      initialRoute: 'dashboard',
      onGenerateRoute: (settings) {
        try {
          switch (settings.name) {
            case 'dashboard':
              return MaterialPageRoute(builder: (_) => const DietDashboardPage());
            case 'profile':
              final provider = Provider.of<DietProvider>(context, listen: false);
              return MaterialPageRoute(
                builder: (_) => ProfileSetupPage(initial: provider.profile),
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
              if (food == null) return MaterialPageRoute(builder: (_) => const DietDashboardPage());
              return MaterialPageRoute(
                builder: (_) => PortionAddPage(
                  food: food,
                  selectedMealType: mealType,
                  initialGrams: initialGrams,
                ),
              );
            case 'detail':
              final args = settings.arguments as Map<String, dynamic>?;
              final food = args?['food'] as FoodItem?;
              final mealType = args?['mealType'] as MealType?;
              if (food == null) return MaterialPageRoute(builder: (_) => const DietDashboardPage());
              return MaterialPageRoute(
                builder: (_) => FoodDetailPage(food: food, selectedMealType: mealType),
              );
            case 'add_custom_food':
              return MaterialPageRoute(builder: (_) => const AddCustomFoodPage());
            case 'diet_chat':
              return MaterialPageRoute(builder: (_) => const DietChatPage());
            case 'test_mode':
              return MaterialPageRoute(builder: (_) => const TestModePage());
            default:
              return MaterialPageRoute(builder: (_) => const DietDashboardPage());
          }
        } catch (e) {
          debugPrint('DietTabContainer route generation hatası: $e, route: ${settings.name}');
          return MaterialPageRoute(builder: (_) => const DietDashboardPage());
        }
      },
    );
  }
}
