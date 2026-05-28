import '../domain/entities/meal_type.dart';
import '../domain/entities/nutrition_preferences.dart';

class SmartPlanTargets {
  final double kcal;
  final double protein;
  final double carb;
  final double fat;

  const SmartPlanTargets({
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
  });
}

class SmartPlanProgress {
  final double kcal;
  final double protein;
  final double carb;
  final double fat;

  const SmartPlanProgress({
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
  });
}

class SmartPlanInput {
  final String goalKey;
  final SmartPlanTargets targets;
  final SmartPlanProgress consumed;
  final NutritionPreferences preferences;
  final Set<MealType> loggedMealTypes;
  final int currentHour;
  final bool hasWorkoutToday;
  final bool isPreWorkoutWindow;
  final bool isPostWorkoutWindow;
  final bool useUsFoods;
  final List<String> availableIngredients;
  final List<String> dislikedKeywords;
  final Map<String, int> slotVariantIndexes;
  final int maxPrepMinutes;
  final String budgetLevel;

  const SmartPlanInput({
    required this.goalKey,
    required this.targets,
    required this.consumed,
    required this.preferences,
    this.loggedMealTypes = const {},
    this.currentHour = 12,
    this.hasWorkoutToday = false,
    this.isPreWorkoutWindow = false,
    this.isPostWorkoutWindow = false,
    this.useUsFoods = false,
    this.availableIngredients = const [],
    this.dislikedKeywords = const [],
    this.slotVariantIndexes = const {},
    this.maxPrepMinutes = 30,
    this.budgetLevel = 'normal',
  });
}

class SmartDailyPlan {
  final List<SmartPlanMeal> meals;
  final SmartPlanTargets remainingTargets;
  final String reason;

  const SmartDailyPlan({
    required this.meals,
    required this.remainingTargets,
    required this.reason,
  });
}

class SmartPlanMeal {
  final String time;
  final String label;
  final MealType mealType;
  final String slotKey;
  final String food;
  final int kcal;
  final int protein;
  final int carb;
  final int fat;
  final List<String> ingredients;
  final List<String> tags;
  final String reason;

  const SmartPlanMeal({
    required this.time,
    required this.label,
    required this.mealType,
    required this.slotKey,
    required this.food,
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
    this.ingredients = const [],
    this.tags = const [],
    this.reason = '',
  });

  String get macroText => '~$kcal kcal · ${protein}g pro';
}

class SmartNutritionPlanEngine {
  const SmartNutritionPlanEngine();

  SmartDailyPlan build(SmartPlanInput input) {
    final remaining = _remainingTargets(input);
    if (_targetsAreMet(remaining)) {
      return SmartDailyPlan(
        meals: const [],
        remainingTargets: remaining,
        reason:
            'Bugünkü hedefler büyük ölçüde tamamlandı; gerekirse sadece su ve hafif toparlanma ekle.',
      );
    }

    final slots = _remainingSlots(input);
    if (slots.isEmpty) {
      return SmartDailyPlan(
        meals: const [],
        remainingTargets: remaining,
        reason:
            'Bugünkü ana öğünlerin girildi; kalan hedefleri küçük eklemelerle takip et.',
      );
    }

    final totalWeight = slots.fold<double>(0, (sum, slot) => sum + slot.weight);
    final meals = <SmartPlanMeal>[];
    for (final slot in slots) {
      final ratio = totalWeight <= 0
          ? 1 / slots.length
          : slot.weight / totalWeight;
      final target = SmartPlanTargets(
        kcal: remaining.kcal * ratio,
        protein: remaining.protein * ratio,
        carb: remaining.carb * ratio,
        fat: remaining.fat * ratio,
      );
      final candidate = _bestCandidate(input, slot, target);
      meals.add(_scaleCandidate(candidate, slot, target, input));
    }

    return SmartDailyPlan(
      meals: meals,
      remainingTargets: remaining,
      reason: _reasonFor(input, remaining),
    );
  }

  SmartPlanTargets _remainingTargets(SmartPlanInput input) {
    final hasConsumed =
        input.consumed.kcal > 20 ||
        input.consumed.protein > 3 ||
        input.consumed.carb > 3 ||
        input.consumed.fat > 3;
    final rawKcal = input.targets.kcal - input.consumed.kcal;
    final rawProtein = input.targets.protein - input.consumed.protein;
    final rawCarb = input.targets.carb - input.consumed.carb;
    final rawFat = input.targets.fat - input.consumed.fat;

    return SmartPlanTargets(
      kcal: rawKcal
          .clamp(
            hasConsumed ? 0.0 : input.targets.kcal * 0.75,
            input.targets.kcal,
          )
          .toDouble(),
      protein: rawProtein
          .clamp(
            hasConsumed ? 0.0 : input.targets.protein * 0.7,
            input.targets.protein,
          )
          .toDouble(),
      carb: rawCarb.clamp(0.0, input.targets.carb).toDouble(),
      fat: rawFat.clamp(0.0, input.targets.fat).toDouble(),
    );
  }

  bool _targetsAreMet(SmartPlanTargets remaining) {
    return remaining.kcal <= 40 &&
        remaining.protein <= 4 &&
        remaining.carb <= 8 &&
        remaining.fat <= 3;
  }

  List<_PlanSlot> _remainingSlots(SmartPlanInput input) {
    final all = <_PlanSlot>[
      const _PlanSlot(
        key: 'breakfast',
        label: 'Kahvaltı',
        mealType: MealType.breakfast,
        time: '07:30',
        weight: 0.24,
        cutoffHour: 11,
      ),
      const _PlanSlot(
        key: 'lunch',
        label: 'Öğle',
        mealType: MealType.lunch,
        time: '13:00',
        weight: 0.30,
        cutoffHour: 16,
      ),
      _PlanSlot(
        key: input.isPreWorkoutWindow ? 'preWorkout' : 'snack',
        label: input.isPreWorkoutWindow ? 'Antrenman Öncesi' : 'Ara Öğün',
        mealType: MealType.snack,
        time: input.isPreWorkoutWindow ? 'Antrenman -90 dk' : '16:30',
        weight: input.hasWorkoutToday ? 0.18 : 0.14,
        cutoffHour: 19,
      ),
      const _PlanSlot(
        key: 'dinner',
        label: 'Akşam',
        mealType: MealType.dinner,
        time: '20:00',
        weight: 0.30,
        cutoffHour: 23,
      ),
    ];

    final slots = all.where((slot) {
      if (input.loggedMealTypes.contains(slot.mealType) &&
          slot.mealType != MealType.snack) {
        return false;
      }
      return input.currentHour < slot.cutoffHour;
    }).toList();

    if (input.isPostWorkoutWindow) {
      slots.insert(
        0,
        const _PlanSlot(
          key: 'postWorkout',
          label: 'Toparlanma',
          mealType: MealType.snack,
          time: 'Şimdi',
          weight: 0.16,
          cutoffHour: 24,
        ),
      );
    }

    if ((input.goalKey == 'bulk' || input.goalKey == 'gain') &&
        input.currentHour < 22) {
      slots.add(
        const _PlanSlot(
          key: 'snack2',
          label: 'Gece',
          mealType: MealType.snack,
          time: '22:00',
          weight: 0.10,
          cutoffHour: 24,
        ),
      );
    }

    if (slots.isEmpty && input.targets.kcal > input.consumed.kcal) {
      return const [
        _PlanSlot(
          key: 'snack',
          label: 'Hafif Tamamlama',
          mealType: MealType.snack,
          time: 'Şimdi',
          weight: 1,
          cutoffHour: 24,
        ),
      ];
    }
    return slots;
  }

  _MealCandidate _bestCandidate(
    SmartPlanInput input,
    _PlanSlot slot,
    SmartPlanTargets target,
  ) {
    final candidates = _catalog.where((candidate) {
      if (candidate.locale == 'us' && !input.useUsFoods) return false;
      if (candidate.locale == 'tr' && input.useUsFoods) return false;
      if (candidate.mealType != slot.mealType &&
          candidate.slotKey != slot.key) {
        return false;
      }
      return _allowed(candidate, input);
    }).toList();

    final fallback = candidates.isNotEmpty
        ? candidates
        : _catalog.where((candidate) => _allowed(candidate, input)).toList();
    if (fallback.isEmpty) {
      return const _MealCandidate(
        name: 'Pirinç + bakliyat + salata',
        mealType: MealType.lunch,
        kcal: 520,
        protein: 22,
        carb: 82,
        fat: 10,
        ingredients: ['Pirinç', 'Bakliyat', 'Salata'],
        tags: ['vegan', 'budget'],
      );
    }
    fallback.sort((a, b) {
      final aScore = _score(a, input, slot, target);
      final bScore = _score(b, input, slot, target);
      return bScore.compareTo(aScore);
    });
    final variantIndex = input.slotVariantIndexes[slot.key] ?? 0;
    return fallback[variantIndex % fallback.length];
  }

  SmartPlanMeal _scaleCandidate(
    _MealCandidate candidate,
    _PlanSlot slot,
    SmartPlanTargets target,
    SmartPlanInput input,
  ) {
    final factor = _portionFactor(candidate, target, input);
    final kcal = (candidate.kcal * factor).round();
    return SmartPlanMeal(
      time: slot.time,
      label: slot.label,
      mealType: slot.mealType,
      slotKey: slot.key,
      food: candidate.name,
      kcal: kcal,
      protein: (candidate.protein * factor).round(),
      carb: (candidate.carb * factor).round(),
      fat: (candidate.fat * factor).round(),
      ingredients: candidate.ingredients,
      tags: candidate.tags,
      reason: _mealReason(input, candidate, target),
    );
  }

  double _portionFactor(
    _MealCandidate candidate,
    SmartPlanTargets target,
    SmartPlanInput input,
  ) {
    final kcalFactor = target.kcal <= 0 ? null : target.kcal / candidate.kcal;
    final proteinFactor = target.protein <= 0
        ? null
        : target.protein / candidate.protein;

    final double rawFactor;
    if (kcalFactor == null && proteinFactor == null) {
      rawFactor = 0.45;
    } else if (kcalFactor == null) {
      rawFactor = proteinFactor!;
    } else if (proteinFactor == null) {
      rawFactor = kcalFactor;
    } else if (target.kcal < 160 && target.protein >= 8) {
      rawFactor = (kcalFactor * 0.35) + (proteinFactor * 0.65);
    } else {
      rawFactor = (kcalFactor * 0.7) + (proteinFactor * 0.3);
    }

    final minFactor = target.kcal < 160 ? 0.35 : 0.65;
    final maxFactor = input.goalKey == 'bulk' || input.goalKey == 'gain'
        ? 1.75
        : 1.45;
    return rawFactor.clamp(minFactor, maxFactor).toDouble();
  }

  double _score(
    _MealCandidate candidate,
    SmartPlanInput input,
    _PlanSlot slot,
    SmartPlanTargets target,
  ) {
    var score = 100.0;
    score -= ((candidate.kcal - target.kcal).abs() / 18)
        .clamp(0, 24)
        .toDouble();
    score -= ((candidate.protein - target.protein).abs() / 2)
        .clamp(0, 18)
        .toDouble();
    if (input.goalKey == 'cut' && candidate.tags.contains('highProtein')) {
      score += 12;
    }
    if ((input.goalKey == 'bulk' || input.goalKey == 'gain') &&
        candidate.tags.contains('calorieDense')) {
      score += 12;
    }
    if (slot.key == 'preWorkout' && candidate.tags.contains('preWorkout')) {
      score += 16;
    }
    if (slot.key == 'postWorkout' && candidate.tags.contains('postWorkout')) {
      score += 16;
    }
    if (input.budgetLevel == 'low' && candidate.tags.contains('budget')) {
      score += 8;
    }
    if (candidate.prepMinutes <= input.maxPrepMinutes) score += 6;
    final pantry = input.availableIngredients.map(_normalize).toSet();
    if (pantry.isNotEmpty &&
        candidate.ingredients.any(
          (item) => pantry.contains(_normalize(item)),
        )) {
      score += 10;
    }
    return score;
  }

  bool _allowed(_MealCandidate candidate, SmartPlanInput input) {
    final text = _normalize(
      '${candidate.name} ${candidate.ingredients.join(' ')}',
    );
    if (input.dislikedKeywords.any((item) => text.contains(_normalize(item)))) {
      return false;
    }
    if (input.preferences.vegan && candidate.restrictions.contains('animal')) {
      return false;
    }
    if (input.preferences.vegetarian &&
        candidate.restrictions.contains('meat')) {
      return false;
    }
    if (input.preferences.lactoseFree &&
        candidate.restrictions.contains('dairy')) {
      return false;
    }
    if (input.preferences.glutenFree &&
        candidate.restrictions.contains('gluten')) {
      return false;
    }
    return true;
  }

  String _mealReason(
    SmartPlanInput input,
    _MealCandidate candidate,
    SmartPlanTargets target,
  ) {
    if (input.isPreWorkoutWindow && candidate.tags.contains('preWorkout')) {
      return 'Antrenman öncesi sindirimi kolay karbonhidrat desteği.';
    }
    if (input.isPostWorkoutWindow && candidate.tags.contains('postWorkout')) {
      return 'Antrenman sonrası protein ve karbonhidratı dengeler.';
    }
    if (target.protein > 30) return 'Kalan protein açığını kapatmaya odaklı.';
    if (input.goalKey == 'cut') return 'Tokluk ve protein öncelikli seçildi.';
    if (input.goalKey == 'bulk' || input.goalKey == 'gain') {
      return 'Kalori hedefini temiz kaynaklarla tamamlamaya odaklı.';
    }
    return 'Kalan makrolara göre dengeli seçildi.';
  }

  String _reasonFor(SmartPlanInput input, SmartPlanTargets remaining) {
    if (input.consumed.kcal <= 20) {
      return 'Günlük hedefin öğünlere dağıtıldı.';
    }
    return '${remaining.kcal.round()} kcal ve ${remaining.protein.round()}g protein kalanına göre yeniden planlandı.';
  }
}

class _PlanSlot {
  final String key;
  final String label;
  final MealType mealType;
  final String time;
  final double weight;
  final int cutoffHour;

  const _PlanSlot({
    required this.key,
    required this.label,
    required this.mealType,
    required this.time,
    required this.weight,
    required this.cutoffHour,
  });
}

class _MealCandidate {
  final String name;
  final MealType mealType;
  final String slotKey;
  final int kcal;
  final int protein;
  final int carb;
  final int fat;
  final int prepMinutes;
  final String locale;
  final List<String> ingredients;
  final List<String> tags;
  final List<String> restrictions;

  const _MealCandidate({
    required this.name,
    required this.mealType,
    this.slotKey = '',
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
    this.prepMinutes = 20,
    this.locale = 'tr',
    this.ingredients = const [],
    this.tags = const [],
    this.restrictions = const [],
  });
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

const _catalog = <_MealCandidate>[
  _MealCandidate(
    name: 'Yulaf + yumurta + meyve',
    mealType: MealType.breakfast,
    kcal: 420,
    protein: 28,
    carb: 46,
    fat: 13,
    ingredients: ['Yulaf', 'Yumurta', 'Meyve'],
    tags: ['balanced', 'budget'],
    restrictions: ['animal', 'gluten'],
  ),
  _MealCandidate(
    name: 'Tofu scramble + sebze + avokado',
    mealType: MealType.breakfast,
    kcal: 390,
    protein: 26,
    carb: 22,
    fat: 22,
    ingredients: ['Tofu', 'Sebze', 'Avokado'],
    tags: ['vegan', 'highProtein'],
  ),
  _MealCandidate(
    name: 'Süzme yoğurt + yulaf + meyve',
    mealType: MealType.breakfast,
    kcal: 360,
    protein: 30,
    carb: 42,
    fat: 6,
    ingredients: ['Süzme yoğurt', 'Yulaf', 'Meyve'],
    tags: ['highProtein', 'quick'],
    restrictions: ['animal', 'dairy', 'gluten'],
  ),
  _MealCandidate(
    name: 'Tavuk + pirinç + salata',
    mealType: MealType.lunch,
    kcal: 560,
    protein: 45,
    carb: 62,
    fat: 12,
    ingredients: ['Tavuk', 'Pirinç', 'Salata'],
    tags: ['highProtein', 'budget'],
    restrictions: ['animal', 'meat'],
  ),
  _MealCandidate(
    name: 'Mercimek + pirinç + bol salata',
    mealType: MealType.lunch,
    kcal: 520,
    protein: 25,
    carb: 82,
    fat: 10,
    ingredients: ['Mercimek', 'Pirinç', 'Salata'],
    tags: ['vegan', 'budget'],
  ),
  _MealCandidate(
    name: 'Nohut bowl + tahinli salata',
    mealType: MealType.lunch,
    kcal: 610,
    protein: 24,
    carb: 72,
    fat: 24,
    ingredients: ['Nohut', 'Tahin', 'Salata'],
    tags: ['vegan', 'calorieDense'],
  ),
  _MealCandidate(
    name: 'Muz + kefir + pirinç patlağı',
    mealType: MealType.snack,
    slotKey: 'preWorkout',
    kcal: 260,
    protein: 12,
    carb: 44,
    fat: 4,
    ingredients: ['Muz', 'Kefir', 'Pirinç patlağı'],
    tags: ['preWorkout', 'quick'],
    restrictions: ['animal', 'dairy'],
  ),
  _MealCandidate(
    name: 'Muz + fıstık ezmesi + pirinç patlağı',
    mealType: MealType.snack,
    slotKey: 'preWorkout',
    kcal: 310,
    protein: 9,
    carb: 48,
    fat: 10,
    ingredients: ['Muz', 'Fıstık ezmesi', 'Pirinç patlağı'],
    tags: ['preWorkout', 'vegan', 'quick'],
  ),
  _MealCandidate(
    name: 'Protein + muz',
    mealType: MealType.snack,
    slotKey: 'postWorkout',
    kcal: 270,
    protein: 28,
    carb: 32,
    fat: 3,
    ingredients: ['Protein', 'Muz'],
    tags: ['postWorkout', 'highProtein', 'quick'],
    restrictions: ['animal', 'dairy'],
  ),
  _MealCandidate(
    name: 'Soya yoğurdu + muz + yulaf',
    mealType: MealType.snack,
    slotKey: 'postWorkout',
    kcal: 330,
    protein: 18,
    carb: 55,
    fat: 6,
    ingredients: ['Soya yoğurdu', 'Muz', 'Yulaf'],
    tags: ['postWorkout', 'vegan'],
    restrictions: ['gluten'],
  ),
  _MealCandidate(
    name: 'Fırın balık + sebze + patates',
    mealType: MealType.dinner,
    kcal: 560,
    protein: 42,
    carb: 48,
    fat: 18,
    ingredients: ['Balık', 'Sebze', 'Patates'],
    tags: ['highProtein'],
    restrictions: ['animal', 'meat'],
  ),
  _MealCandidate(
    name: 'Hindi/tavuk + patates + salata',
    mealType: MealType.dinner,
    kcal: 620,
    protein: 52,
    carb: 56,
    fat: 16,
    ingredients: ['Hindi', 'Patates', 'Salata'],
    tags: ['highProtein'],
    restrictions: ['animal', 'meat'],
  ),
  _MealCandidate(
    name: 'Kuru fasulye + pirinç + salata',
    mealType: MealType.dinner,
    kcal: 640,
    protein: 26,
    carb: 94,
    fat: 12,
    ingredients: ['Kuru fasulye', 'Pirinç', 'Salata'],
    tags: ['vegan', 'budget'],
  ),
  _MealCandidate(
    name: 'Yoğurt + meyve + badem',
    mealType: MealType.snack,
    kcal: 260,
    protein: 18,
    carb: 24,
    fat: 10,
    ingredients: ['Yoğurt', 'Meyve', 'Badem'],
    tags: ['quick'],
    restrictions: ['animal', 'dairy'],
  ),
  _MealCandidate(
    name: 'Meyve + badem',
    mealType: MealType.snack,
    kcal: 210,
    protein: 6,
    carb: 22,
    fat: 11,
    prepMinutes: 5,
    ingredients: ['Meyve', 'Badem'],
    tags: ['vegan', 'quick'],
  ),
  _MealCandidate(
    name: 'Oatmeal + eggs + berries',
    mealType: MealType.breakfast,
    kcal: 430,
    protein: 29,
    carb: 48,
    fat: 14,
    locale: 'us',
    ingredients: ['Oatmeal', 'Eggs', 'Berries'],
    tags: ['balanced'],
    restrictions: ['animal', 'gluten'],
  ),
  _MealCandidate(
    name: 'Chicken rice bowl',
    mealType: MealType.lunch,
    kcal: 590,
    protein: 48,
    carb: 68,
    fat: 12,
    locale: 'us',
    ingredients: ['Chicken', 'Rice', 'Greens'],
    tags: ['highProtein'],
    restrictions: ['animal', 'meat'],
  ),
  _MealCandidate(
    name: 'Bean rice bowl + avocado',
    mealType: MealType.dinner,
    kcal: 650,
    protein: 24,
    carb: 88,
    fat: 20,
    locale: 'us',
    ingredients: ['Beans', 'Rice', 'Avocado'],
    tags: ['vegan', 'calorieDense'],
  ),
  _MealCandidate(
    name: 'Greek yogurt + berries',
    mealType: MealType.snack,
    kcal: 220,
    protein: 22,
    carb: 22,
    fat: 4,
    locale: 'us',
    ingredients: ['Greek yogurt', 'Berries'],
    tags: ['highProtein', 'quick'],
    restrictions: ['animal', 'dairy'],
  ),
];
