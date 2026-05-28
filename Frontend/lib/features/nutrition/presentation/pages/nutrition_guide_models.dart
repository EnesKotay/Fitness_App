part of 'nutrition_guide_page.dart';

// ─── Veri Modelleri ────────────────────────────────────────────────────────────

class _Goal {
  final String key;
  final String label;
  final String emoji;
  final Color color;
  final String subtitle;
  final String calorieRule;
  final List<_Macro> macros;
  final List<_MealIdea> meals;
  final List<String> rules;
  final List<String> avoid;
  final List<_DayMeal> dailyPlan;
  final List<_TopFood> topFoods;
  final _Timing timing;
  final List<String> supplements;

  const _Goal({
    required this.key,
    required this.label,
    required this.emoji,
    required this.color,
    required this.subtitle,
    required this.calorieRule,
    required this.macros,
    required this.meals,
    required this.rules,
    required this.avoid,
    required this.dailyPlan,
    required this.topFoods,
    required this.timing,
    required this.supplements,
  });
}

class _Macro {
  final String name;
  final String amount;
  final double ratio;
  final Color color;
  const _Macro({
    required this.name,
    required this.amount,
    required this.ratio,
    required this.color,
  });
}

class _MealIdea {
  final String name;
  final String detail;
  final IconData icon;
  final Color accent;
  const _MealIdea({
    required this.name,
    required this.detail,
    required this.icon,
    required this.accent,
  });
}

class _DayMeal {
  final String time;
  final String label;
  final String food;
  final String macros;
  final IconData icon;
  final String slotKey;
  final bool isMiniStop;

  const _DayMeal({
    required this.time,
    required this.label,
    required this.food,
    required this.macros,
    required this.icon,
    this.slotKey = '',
    this.isMiniStop = false,
  });
}

class _TopFood {
  final String name;
  final String highlight;
  final Color color;
  const _TopFood({
    required this.name,
    required this.highlight,
    required this.color,
  });
}

class _Timing {
  final String preMeal;
  final String postMeal;
  final String preDetail;
  final String postDetail;
  const _Timing({
    required this.preMeal,
    required this.postMeal,
    required this.preDetail,
    required this.postDetail,
  });
}

class _PersonalInsight {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _PersonalInsight({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ─── Statik Veri ──────────────────────────────────────────────────────────────
