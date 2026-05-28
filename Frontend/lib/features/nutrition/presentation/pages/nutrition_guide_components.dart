part of 'nutrition_guide_page.dart';

Goal _profileGoalForGuideGoal(_Goal goal) {
  switch (goal.key) {
    case 'cut':
      return Goal.cut;
    case 'gain':
    case 'bulk':
      return Goal.bulk;
    case 'strength':
      return Goal.strength;
    case 'maintain':
    default:
      return Goal.maintain;
  }
}

bool _isSyncedWithProfileGoal(_Goal goal, UserProfile? profile) {
  if (profile == null) return false;
  return _profileGoalForGuideGoal(goal) == profile.goal;
}

String _normalizeFoodText(String value) {
  return value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

bool _containsAnyFoodToken(String normalized, List<String> tokens) {
  return tokens.any((token) => normalized.contains(token));
}

bool _allowedFoodText(String text, NutritionPreferences prefs) {
  final normalized = _normalizeFoodText(text);
  const meatAndFish = [
    'tavuk',
    'balik',
    'ton baligi',
    'somon',
    'levrek',
    'cipura',
    'hindi',
    'kofte',
    'kiyma',
    'kirmizi et',
    'et ',
    'sucuk',
  ];
  const animalProducts = [
    ...meatAndFish,
    'yumurta',
    'yogurt',
    'suzme',
    'sut',
    'peynir',
    'lor',
    'kefir',
    'ayran',
    'whey',
  ];
  const dairy = [
    'yogurt',
    'suzme',
    'sut',
    'peynir',
    'lor',
    'kefir',
    'ayran',
    'whey',
  ];
  const glutenLikely = [
    'ekmek',
    'tost',
    'sandvic',
    'wrap',
    'durum',
    'makarna',
    'bulgur',
    'kraker',
    'granola',
    'yulaf',
  ];

  if (prefs.vegan && _containsAnyFoodToken(normalized, animalProducts)) {
    return false;
  }
  if (prefs.vegetarian && _containsAnyFoodToken(normalized, meatAndFish)) {
    return false;
  }
  if (prefs.lactoseFree && _containsAnyFoodToken(normalized, dairy)) {
    return false;
  }
  if (prefs.glutenFree && _containsAnyFoodToken(normalized, glutenLikely)) {
    return false;
  }
  return true;
}

String _fallbackFoodFor({
  required String label,
  required String goalKey,
  required NutritionPreferences prefs,
}) {
  final lower = _normalizeFoodText(label);
  final isGain = goalKey == 'gain' || goalKey == 'bulk';
  if (prefs.vegan) {
    if (lower.contains('kahvalti')) {
      return isGain
          ? 'Glutensiz yulaf + soya sütü + muz + fıstık ezmesi'
          : 'Tofu scramble + sebze + meyve';
    }
    if (lower.contains('ogle') || lower.contains('aksam')) {
      return isGain
          ? 'Nohut + pirinç + zeytinyağlı sebze'
          : 'Mercimek salatası + bol sebze + avokado';
    }
    return isGain ? 'Hurma + fıstık ezmesi + soya sütü' : 'Meyve + badem';
  }
  if (prefs.vegetarian) {
    if (lower.contains('kahvalti')) return 'Yumurta + sebze + meyve';
    if (lower.contains('ogle') || lower.contains('aksam')) {
      return 'Mercimek köftesi + salata + yoğurt';
    }
    return 'Yoğurt + meyve + kuruyemiş';
  }
  if (prefs.lactoseFree) {
    if (lower.contains('kahvalti')) return 'Yumurta + zeytin + sebze';
    if (lower.contains('ogle') || lower.contains('aksam')) {
      return 'Izgara tavuk + pirinç + salata';
    }
    return 'Meyve + badem';
  }
  if (prefs.glutenFree) {
    if (lower.contains('kahvalti')) return 'Yumurta + patates + söğüş';
    if (lower.contains('ogle') || lower.contains('aksam')) {
      return 'Pirinç + protein + salata';
    }
    return 'Yoğurt + meyve';
  }
  return isGain ? 'Pirinç + protein + zeytinyağlı sebze' : 'Protein + salata';
}

// ─── Smart Now Card ───────────────────────────────────────────────────────────

class _SmartNowCard extends StatelessWidget {
  final _Goal goal;
  final DietProvider provider;
  final VoidCallback onFoodSearch;
  final WorkoutProvider? workoutProvider;

  const _SmartNowCard({
    required this.goal,
    required this.provider,
    required this.onFoodSearch,
    this.workoutProvider,
  });

  // Bugün antrenman var mı ve saat ne zaman?
  ({bool isPreWorkout, bool isPostWorkout, int? workoutHour}) _workoutTiming() {
    final wp = workoutProvider;
    if (wp == null) {
      return (isPreWorkout: false, isPostWorkout: false, workoutHour: null);
    }

    final now = DateTime.now();
    final todayWorkouts = wp.workouts.where((w) {
      final d = w.workoutDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();

    if (todayWorkouts.isEmpty) {
      return (isPreWorkout: false, isPostWorkout: false, workoutHour: null);
    }

    final mostRecent = todayWorkouts.reduce(
      (a, b) => a.workoutDate.isAfter(b.workoutDate) ? a : b,
    );
    final diff = now.difference(mostRecent.workoutDate);
    final isPost = diff.inMinutes >= 0 && diff.inHours < 2;
    // Önceden planlanmış (gelecekte) antrenman kontrolü
    final upcoming = todayWorkouts.where(
      (w) =>
          w.workoutDate.isAfter(now) &&
          w.workoutDate.difference(now).inHours <= 2,
    );
    final isPre = upcoming.isNotEmpty;
    return (
      isPreWorkout: isPre,
      isPostWorkout: isPost && !isPre,
      workoutHour: mostRecent.workoutDate.hour,
    );
  }

  ({
    String label,
    String title,
    String suggestion,
    String avoid,
    IconData icon,
    String buttonLabel,
    List<(String, String)> foods,
  })
  _nowContext(
    int hour,
    double remaining,
    double proteinGap,
    double carbGap,
    String goalKey,
    bool currentMealLogged,
  ) {
    final isCut = goalKey == 'cut';
    final isGain = goalKey == 'gain' || goalKey == 'bulk';
    final isStrength = goalKey == 'strength';
    final lowBudget = remaining < 180;
    final highProteinGap = proteinGap > 25;

    if (lowBudget) {
      return (
        label: 'Kalori alanı çok az',
        title: 'Yeni büyük öğün ekleme; günü hafif kapat.',
        suggestion:
            'Hedefe çok yaklaşmışsın. Açlık gerçekse sebze, yoğurt veya sade protein gibi düşük kalorili bir seçim yap.',
        avoid: 'Kuru yemiş, yağlı sos, tatlı ve büyük porsiyon karbonhidrat.',
        icon: Icons.balance_rounded,
        buttonLabel: 'Hafif Ekle',
        foods: const [
          ('🥗', 'Bol salata'),
          ('🫙', 'Süzme yoğurt'),
          ('🥚', 'Yumurta beyazı'),
        ],
      );
    }

    if (hour < 9) {
      return (
        label: currentMealLogged
            ? 'Kahvaltı girildi'
            : 'Sıradaki öğün: Kahvaltı',
        title: currentMealLogged
            ? 'Kahvaltı tamam; su ve öğlene kadar hafif kal.'
            : highProteinGap
            ? 'Kahvaltıda protein tabanını kur.'
            : isCut
            ? 'Tok tutan, kontrollü kahvaltı seç.'
            : 'Protein + kompleks karbonhidratla güne başla.',
        suggestion: currentMealLogged
            ? 'Bir sonraki ana öğüne alan bırak. Çok acıkırsan küçük bir protein ara öğünü yeterli.'
            : highProteinGap
            ? '25-35g protein içeren kahvaltı günün geri kalanını kolaylaştırır.'
            : isGain
            ? 'Kalori artırman gerekiyorsa yulaf, süt, muz ve yumurtayı birlikte kullan.'
            : 'Kan şekerini zıplatmayan dengeli bir kahvaltı daha mantıklı.',
        avoid: isCut
            ? 'Şekerli gevrek, poğaça ve meyve suyuyla güne başlama.'
            : 'Sadece kahveyle geçiştirme; günün kalorisi arkaya yığılır.',
        icon: Icons.wb_sunny_rounded,
        buttonLabel: currentMealLogged ? 'Ara Öğün' : 'Kahvaltı Ekle',
        foods: isGain
            ? [('🌾', 'Yulaf + süt'), ('🍌', 'Muz'), ('🥚', 'Yumurta')]
            : [('🥚', 'Yumurta'), ('🫙', 'Süzme yoğurt'), ('🌾', 'Yulaf')],
      );
    } else if (hour < 12) {
      return (
        label: currentMealLogged
            ? 'Sabah arası girildi'
            : 'Sıradaki öğün: Ara öğün',
        title: currentMealLogged
            ? 'Öğlene kadar ekstra yemene gerek yok.'
            : highProteinGap
            ? 'Küçük ama proteinli ara öğün ekle.'
            : 'Öğleye alan bırakacak hafif ara öğün seç.',
        suggestion: highProteinGap
            ? 'Yoğurt, kefir veya hindi gibi proteinli küçük seçim öğleye kadar dengeler.'
            : 'Büyük porsiyon yerine kan şekerini sabit tutan küçük bir öğün yeterli.',
        avoid: 'Tatlı kahve, paketli atıştırmalık ve büyük sandviç.',
        icon: Icons.wb_cloudy_outlined,
        buttonLabel: 'Ara Öğün Ekle',
        foods: const [('🫙', 'Yoğurt'), ('🥛', 'Kefir'), ('🍎', 'Elma')],
      );
    } else if (hour < 15) {
      final budget = (remaining * 0.38).round().clamp(200, 700);
      return (
        label: currentMealLogged
            ? 'Öğle yemeği girildi'
            : 'Sıradaki öğün: Öğle • ~$budget kcal',
        title: currentMealLogged
            ? 'Öğle tamam; ikindiye kadar su ve yürüyüş iyi olur.'
            : highProteinGap
            ? 'Öğlede protein açığını kapat.'
            : isStrength
            ? 'Öğlede performans yakıtı koy.'
            : 'Dengeli ana öğün ekle.',
        suggestion: currentMealLogged
            ? 'Kalan kaloriyi akşam için sakla. Protein hâlâ açıksa ikindide küçük destek ekle.'
            : highProteinGap
            ? 'Bu öğünde 35-50g protein hedefle; yanına sebze ve kontrollü karbonhidrat ekle.'
            : isGain
            ? 'Kalori hedefi için pirinç/bulgur + protein + zeytinyağı mantıklı.'
            : 'Protein + kompleks karbonhidrat + sebze üçlüsü öğleden sonra düşüşünü azaltır.',
        avoid: isCut
            ? 'Kızartma, kremalı sos ve sınırsız ekmek.'
            : 'Sadece salata yiyip kaloriyi akşama bırakma.',
        icon: Icons.restaurant_rounded,
        buttonLabel: currentMealLogged ? 'İkindi Ekle' : 'Öğle Ekle',
        foods: highProteinGap
            ? [('🍗', 'Tavuk'), ('🐟', 'Ton/Somon'), ('🫘', 'Mercimek')]
            : [('🍚', 'Bulgur/Pirinç'), ('🥗', 'Sebze'), ('🫙', 'Yoğurt')],
      );
    } else if (hour < 18) {
      return (
        label: currentMealLogged ? 'İkindi girildi' : 'Sıradaki öğün: İkindi',
        title: currentMealLogged
            ? 'Akşama kadar bekle; sadece su/şekersiz içecek.'
            : highProteinGap
            ? 'Akşamı beklemeden protein desteği ekle.'
            : carbGap > 40 && (isStrength || isGain)
            ? 'Antrenman/enerji için karbonhidrat ekle.'
            : 'Akşamı bozmayacak küçük ara öğün seç.',
        suggestion: highProteinGap
            ? '20-30g proteinli küçük öğün akşam aşırı açlığı azaltır.'
            : 'Hedefe göre küçük porsiyon: çok açsan protein, antrenman varsa karbonhidrat.',
        avoid: 'Kuruyemişi avuç avuç yemek ve tatlı atıştırmalık.',
        icon: Icons.wb_cloudy_rounded,
        buttonLabel: 'Ara Öğün Ekle',
        foods: isStrength || isGain
            ? [('🍌', 'Muz'), ('🥛', 'Kefir'), ('🌾', 'Yulaf')]
            : [('🫙', 'Yoğurt'), ('🥚', 'Yumurta'), ('🍎', 'Meyve')],
      );
    } else if (hour < 21) {
      final budget = remaining.round().clamp(0, 700);
      return (
        label: budget > 150
            ? currentMealLogged
                  ? 'Akşam yemeği girildi'
                  : 'Sıradaki öğün: Akşam • ~$budget kcal'
            : 'Akşam: kalori alanı az',
        title: currentMealLogged
            ? 'Bugünü kapat; ekstra öğün ekleme.'
            : budget > 200
            ? isCut
                  ? 'Akşamı protein + sebze ile hafif bitir.'
                  : 'Akşamda protein ağırlıklı toparlanma öğünü seç.'
            : 'Çok hafif kal; hedefi taşırma.',
        suggestion: currentMealLogged
            ? 'Açlık değil alışkanlıksa bitki çayı/su daha mantıklı. Protein açığı büyükse küçük yoğurt eklenebilir.'
            : budget > 200
            ? isGain
                  ? 'Protein + karbonhidrat + sağlıklı yağ ekleyebilirsin; kaloriyi temiz tamamla.'
                  : 'Sindirimi kolay, proteinli ve sebzeli bir tabak geceyi rahat geçirir.'
            : 'Kalori hedefine yaklaştın. Büyük öğün yerine küçük protein veya sebze seç.',
        avoid: 'Geceye yakın kızartma, tatlı, büyük makarna/pilav porsiyonu.',
        icon: Icons.dinner_dining_rounded,
        buttonLabel: currentMealLogged ? 'Hafif Ekle' : 'Akşam Ekle',
        foods: budget > 150
            ? [('🍗', 'Tavuk/Balık'), ('🥦', 'Sebze'), ('🫙', 'Yoğurt')]
            : [('🥗', 'Salata'), ('🫙', 'Yoğurt'), ('🍵', 'Bitki çayı')],
      );
    } else {
      return (
        label: 'Gece kontrolü',
        title: remaining > 250 && proteinGap > 15
            ? 'Açsan küçük gece proteini ekle.'
            : 'Bugünü kapat; ağır yemek yok.',
        suggestion: remaining > 250 && proteinGap > 15
            ? 'Yavaş sindirilen protein iyi olur. Porsiyonu küçük tut; uyku kalitesini bozma.'
            : 'Yatmadan önce büyük öğün sindirimi zorlar. Su veya bitki çayı yeterli.',
        avoid: 'Tatlı, cips, büyük sandviç ve yağlı yemek.',
        icon: Icons.nights_stay_rounded,
        buttonLabel: 'Hafif Ekle',
        foods: const [
          ('🫙', 'Süzme yoğurt'),
          ('🥛', 'Kefir'),
          ('🍵', 'Bitki çayı'),
        ],
      );
    }
  }

  MealType _mealTypeForHour(int hour) {
    if (hour < 10) return MealType.breakfast;
    if (hour < 12) return MealType.snack;
    if (hour < 15) return MealType.lunch;
    if (hour < 18) return MealType.snack;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final projectedGoal = _profileGoalForGuideGoal(goal);
    final simulated = provider.getSimulatedTargets(projectedGoal);
    final remaining = simulated.targetKcal - provider.totals.totalKcal;
    final proteinGap = (simulated.proteinTarget - provider.totals.totalProtein)
        .clamp(0.0, double.infinity);
    final carbGap = (simulated.carbTarget - provider.totals.totalCarb).clamp(
      0.0,
      double.infinity,
    );
    final progressPct = simulated.targetKcal > 0
        ? ((provider.totals.totalKcal / simulated.targetKcal) * 100)
              .round()
              .clamp(0, 100)
        : 0;

    final fatGap = (simulated.fatTarget - provider.totals.totalFat)
        .clamp(0.0, double.infinity);
    final currentMealType = _mealTypeForHour(hour);
    final currentMealLogged = provider
        .entriesForMeal(currentMealType)
        .isNotEmpty;
    final timing = _workoutTiming();

    // Antrenman zamanlaması varsa özel bağlam kullan
    final ctx = timing.isPreWorkout
        ? (
            label: 'Antrenman öncesi pencere',
            title: 'Antrenman öncesi yakıtını koy.',
            suggestion:
                '1–2 saat içinde antrenman var. Hızlı karbonhidrat + orta protein hedefle. Çok yağlı yeme — sindirimi yavaşlatır.',
            avoid: 'Bol yağlı yemek, çiğ salata, büyük porsiyon süt ürünleri.',
            icon: Icons.bolt_rounded,
            buttonLabel: 'Karbonhidrat Ekle',
            foods: const [
              ('🍌', 'Muz'),
              ('🍚', 'Pirinç'),
              ('🧃', 'Meyve suyu'),
            ],
          )
        : timing.isPostWorkout
        ? (
            label: 'Antrenman sonrası pencere',
            title: 'Kas onarımı için hızlı toparlanma öğünü.',
            suggestion:
                'Son 2 saat içinde antrenman yaptın. Protein + karbonhidrat toparlanmayı destekleyebilir; porsiyonu kalan hedeflerine göre ayarla.',
            avoid:
                'Yağlı ve çok büyük porsiyonlar toparlanma öğününü ağırlaştırabilir.',
            icon: Icons.autorenew_rounded,
            buttonLabel: 'Toparlanma Öğünü',
            foods: [
              ('🥛', 'Protein tozu'),
              ('🍌', 'Muz'),
              ('🍚', 'Pirinç/Bulgur'),
            ],
          )
        : _nowContext(
            hour,
            remaining,
            proteinGap,
            carbGap,
            goal.key,
            currentMealLogged,
          );
    final prefs = context.watch<DietProvider>().nutritionPreferences;
    final nowFoods = ctx.foods
        .where((food) => _allowedFoodText(food.$2, prefs))
        .toList();
    final visibleNowFoods = nowFoods.isNotEmpty
        ? nowFoods
        : [
            (
              '🍽️',
              _fallbackFoodFor(
                label: ctx.label,
                goalKey: goal.key,
                prefs: prefs,
              ),
            ),
          ];

    final activeColor = timing.isPreWorkout
        ? const Color(0xFFFFD60A)
        : timing.isPostWorkout
        ? const Color(0xFF30D158)
        : goal.color;

    final barColor = progressPct >= 100
        ? const Color(0xFFFF453A)
        : progressPct >= 85
        ? const Color(0xFFFFD60A)
        : activeColor;
    final safetyWarnings = HealthSafetyService.evaluateNutrition(
      targetKcal: simulated.targetKcal,
      consumedKcal: provider.totals.totalKcal,
      proteinTarget: simulated.proteinTarget,
      proteinCurrent: provider.totals.totalProtein,
      waterLiters: provider.waterLiters,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık + Öğün Ekle butonu ──
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  activeColor.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Öğün ikonu (dolu daire)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(ctx.icon, color: activeColor, size: 18),
                ),
                const SizedBox(width: 10),
                // 2 satırlı başlık
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sıradaki mantıklı hamle',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ctx.label,
                        style: TextStyle(
                          color: activeColor.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Dolu gradient buton
                GestureDetector(
                  onTap: onFoodSearch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          activeColor,
                          activeColor.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctx.buttonLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tavsiye + progress ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        ctx.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: barColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        '%$progressPct',
                        style: TextStyle(
                          color: barColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progressPct / 100.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCirc,
                    builder: (context, val, child) => LinearProgressIndicator(
                      value: val,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
                if (safetyWarnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _NutritionSafetyHint(warning: safetyWarnings.first),
                ],
              ],
            ),
          ),

          // ── Kalan makro chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _NowStatChip(
                  icon: Icons.local_fire_department_rounded,
                  label: remaining > 0
                      ? '${remaining.round()} kcal kaldı'
                      : 'Kalori doldu',
                  color: remaining > 0
                      ? AppColors.secondary
                      : const Color(0xFFFF453A),
                ),
                _NowStatChip(
                  icon: Icons.fitness_center_rounded,
                  label: proteinGap > 2
                      ? '${proteinGap.round()}g protein kaldı'
                      : 'Protein tamam ✓',
                  color: proteinGap > 2
                      ? const Color(0xFF30D158)
                      : Colors.white38,
                ),
                if (carbGap > 15)
                  _NowStatChip(
                    icon: Icons.bolt_rounded,
                    label: '${carbGap.round()}g karb kaldı',
                    color: const Color(0xFF0A84FF),
                  ),
                if (fatGap > 10)
                  _NowStatChip(
                    icon: Icons.water_drop_rounded,
                    label: '${fatGap.round()}g yağ kaldı',
                    color: const Color(0xFFFF9F0A),
                  ),
              ],
            ),
          ),

          // ── Öneri kutusu ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3,
                        color: activeColor.withValues(alpha: 0.55),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Text(
                            ctx.suggestion,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Kaçın notu ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF453A).withValues(alpha: 0.06),
                  border: Border.all(
                    color: const Color(0xFFFF453A).withValues(alpha: 0.18),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3,
                        color: const Color(0xFFFF453A).withValues(alpha: 0.50),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.do_not_disturb_on_rounded,
                                color: const Color(
                                  0xFFFF453A,
                                ).withValues(alpha: 0.75),
                                size: 13,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  ctx.avoid,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Yemek fikirleri ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                Text(
                  'Fikir:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: visibleNowFoods
                        .map(
                          (f) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: activeColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: activeColor.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              '${f.$1} ${f.$2}',
                              style: TextStyle(
                                color: activeColor.withValues(alpha: 0.9),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionSafetyHint extends StatelessWidget {
  final NutritionSafetyWarning warning;

  const _NutritionSafetyHint({required this.warning});

  @override
  Widget build(BuildContext context) {
    final color = switch (warning.level) {
      NutritionSafetyLevel.danger => const Color(0xFFFF453A),
      NutritionSafetyLevel.warning => const Color(0xFFFFD60A),
      NutritionSafetyLevel.info => const Color(0xFF64D2FF),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${warning.title}: ${warning.action}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _NowStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  const _SectionHeader({required this.title, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.secondary;
    return Row(
      children: [
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: c, size: 16),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ─── Goal Selector ────────────────────────────────────────────────────────────

class _GoalSelector extends StatelessWidget {
  final List<_Goal> goals;
  final int selectedIndex;
  final int? profileGoalIndex;
  final ValueChanged<int> onSelected;
  const _GoalSelector({
    required this.goals,
    required this.selectedIndex,
    required this.onSelected,
    this.profileGoalIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: goals.length,
        itemBuilder: (_, i) {
          final g = goals[i];
          final sel = i == selectedIndex;
          final isProfile = i == profileGoalIndex;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? g.color.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: sel
                          ? g.color.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.08),
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: g.color.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(g.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        g.label,
                        style: GoogleFonts.dmSans(
                          color: sel ? g.color : Colors.white54,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Profil hedefi rozeti
                if (isProfile)
                  Positioned(
                    top: 2,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.background,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _CalorieRing extends StatelessWidget {
  final DietProvider provider;
  final Color color;
  final int? targetKcal;
  final double size;
  const _CalorieRing({
    required this.provider,
    required this.color,
    this.targetKcal,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final current = provider.totals.totalKcal;
    final target = (targetKcal ?? (current + provider.remainingKcal))
        .toDouble();
    final remaining = target - current;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final exceeded = remaining < 0;
    final ringColor = exceeded ? const Color(0xFFFF453A) : color;
    final strokeWidth = size * 0.075;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCirc,
              builder: (context, val, child) {
                return CircularProgressIndicator(
                  value: val,
                  strokeWidth: strokeWidth,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(ringColor),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current.round().toString(),
                style: TextStyle(
                  color: ringColor,
                  fontSize: size * 0.195,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'kcal',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: size * 0.115,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: ringColor.withValues(alpha: 0.65),
                  fontSize: size * 0.10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final _Goal goal;
  final DietProvider provider;
  const _HeroBanner({required this.goal, required this.provider});

  @override
  Widget build(BuildContext context) {
    final profile = provider.profile;
    final projectedGoal = _profileGoalForGuideGoal(goal);
    final simulated = provider.getSimulatedTargets(projectedGoal);
    final targetKcal = simulated.targetKcal.round();
    final currentKcal = provider.totals.totalKcal.round();
    final remaining = targetKcal - currentKcal;
    final proteinGap = (simulated.proteinTarget - provider.totals.totalProtein)
        .round();
    final profileLabel = profile == null
        ? 'Rehber modunda'
        : _isSyncedWithProfileGoal(goal, profile)
        ? 'Profil hedefin'
        : 'Alternatif senaryo';
    final dynamicRule = profile == null
        ? goal.calorieRule
        : '$targetKcal kcal/gün hedef';
    final remainingLabel = remaining >= 0
        ? '$remaining kcal alan'
        : '${remaining.abs()} kcal fazla';
    final proteinLabel = proteinGap > 0
        ? '${proteinGap}g protein kaldı'
        : 'Protein tamam';

    final now = DateTime.now();
    final weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    final dateLabel =
        '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            goal.color.withValues(alpha: 0.22),
            AppColors.surfaceElevated,
            goal.color.withValues(alpha: 0.06),
          ],
          stops: const [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: goal.color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: goal.color.withValues(alpha: 0.14),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: tarih + profil etiketi
          Row(
            children: [
              Icon(
                Icons.today_rounded,
                color: goal.color.withValues(alpha: 0.7),
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                dateLabel,
                style: TextStyle(
                  color: goal.color.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: goal.color.withValues(alpha: 0.25)),
                ),
                child: Text(
                  profileLabel,
                  style: TextStyle(
                    color: goal.color.withValues(alpha: 0.9),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Ana satır: emoji + isim + kalori halkası
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: goal.color.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: goal.color.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(goal.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      goal.subtitle,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CalorieRing(
                provider: provider,
                color: goal.color,
                targetKcal: targetKcal,
                size: 88,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Divider
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 12),
          // Stat pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroStatPill(
                icon: Icons.flag_rounded,
                label: dynamicRule,
                color: goal.color,
              ),
              _HeroStatPill(
                icon: remaining >= 0
                    ? Icons.local_fire_department_rounded
                    : Icons.balance_rounded,
                label: remainingLabel,
                color: remaining >= 0 ? AppColors.secondary : AppColors.warning,
              ),
              _HeroStatPill(
                icon: Icons.fitness_center_rounded,
                label: proteinLabel,
                color: const Color(0xFF30D158),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeroStatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalSummaryCard extends StatelessWidget {
  final _Goal goal;
  final DietProvider provider;
  final List<_PersonalInsight> insights;

  const _PersonalSummaryCard({
    required this.goal,
    required this.provider,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    final simulated = provider.getSimulatedTargets(
      _profileGoalForGuideGoal(goal),
    );
    final targetKcal = simulated.targetKcal.round();
    final proteinTarget = simulated.proteinTarget.round();

    final currentKcal = provider.totals.totalKcal.round();
    final proteinCurrent = provider.totals.totalProtein.round();
    final remaining = targetKcal - currentKcal;
    final carbTarget = simulated.carbTarget.round();
    final fatTarget = simulated.fatTarget.round();
    final carbCurrent = provider.totals.totalCarb.round();
    final fatCurrent = provider.totals.totalFat.round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: goal.color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Bugün İçin Akıllı Özet',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Kalori',
                      value: '$currentKcal / $targetKcal',
                      helper: remaining >= 0
                          ? '$remaining kcal alan'
                          : '${remaining.abs()} kcal fazla',
                      color: goal.color,
                      ratio: targetKcal > 0
                          ? (currentKcal / targetKcal).clamp(0.0, 1.0)
                          : 0.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Protein',
                      value: '$proteinCurrent / $proteinTarget g',
                      helper: proteinCurrent >= proteinTarget
                          ? 'Hedefe ulaştın'
                          : '${proteinTarget - proteinCurrent}g kaldı',
                      color: const Color(0xFF30D158),
                      ratio: proteinTarget > 0
                          ? (proteinCurrent / proteinTarget).clamp(0.0, 1.0)
                          : 0.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Karb',
                      value: '$carbCurrent / $carbTarget g',
                      helper: carbCurrent >= carbTarget
                          ? 'Hedefe ulaştın'
                          : '${carbTarget - carbCurrent}g kaldı',
                      color: goal.macros[1].color,
                      ratio: carbTarget > 0
                          ? (carbCurrent / carbTarget).clamp(0.0, 1.0)
                          : 0.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Yağ',
                      value: '$fatCurrent / $fatTarget g',
                      helper: fatCurrent >= fatTarget
                          ? 'Hedefe ulaştın'
                          : '${fatTarget - fatCurrent}g kaldı',
                      color: goal.macros[2].color,
                      ratio: fatTarget > 0
                          ? (fatCurrent / fatTarget).clamp(0.0, 1.0)
                          : 0.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...insights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InsightRow(insight: insight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideActionsCard extends StatelessWidget {
  final VoidCallback onFoodSearch;
  final VoidCallback onWeeklyPlan;
  final VoidCallback onGroceryList;

  const _GuideActionsCard({
    required this.onFoodSearch,
    required this.onWeeklyPlan,
    required this.onGroceryList,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.052),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.085)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: AppColors.secondary,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hızlı Erişim',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Planla, ara, alışveriş yap',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Öğün Ara',
                      icon: Icons.search_rounded,
                      color: AppColors.secondary,
                      onTap: onFoodSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Haftalık Plan',
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF4FACFE),
                      onTap: onWeeklyPlan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Alışveriş',
                      icon: Icons.shopping_cart_rounded,
                      color: const Color(0xFF30D158),
                      onTap: onGroceryList,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color color;
  final double? ratio;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
    this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (ratio != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: ratio!),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (_, val, _) => LinearProgressIndicator(
                  value: val,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final _PersonalInsight insight;

  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: insight.color.withValues(alpha: 0.07),
          border: Border.all(color: insight.color.withValues(alpha: 0.12)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: insight.color.withValues(alpha: 0.55)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: insight.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: insight.color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          insight.icon,
                          color: insight.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: TextStyle(
                                color: insight.color,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              insight.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Macro Card ───────────────────────────────────────────────────────────────

class _MacroCard extends StatelessWidget {
  final _Goal goal;
  final DietProvider provider;
  const _MacroCard({required this.goal, required this.provider});

  @override
  Widget build(BuildContext context) {
    final targets = provider.macroTargets;
    final proteinProgress =
        (provider.totals.totalProtein /
                (targets.protein == 0 ? 1 : targets.protein))
            .clamp(0.0, 1.0);
    final carbProgress =
        (provider.totals.totalCarb / (targets.carb == 0 ? 1 : targets.carb))
            .clamp(0.0, 1.0);
    final fatProgress =
        (provider.totals.totalFat / (targets.fat == 0 ? 1 : targets.fat)).clamp(
          0.0,
          1.0,
        );
    final dynamicMacros = [
      _Macro(
        name: 'Protein',
        amount:
            '${provider.totals.totalProtein.round()} / ${targets.protein.round()} g',
        ratio: proteinProgress,
        color: goal.macros[0].color,
      ),
      _Macro(
        name: 'Karbonhidrat',
        amount:
            '${provider.totals.totalCarb.round()} / ${targets.carb.round()} g',
        ratio: carbProgress,
        color: goal.macros[1].color,
      ),
      _Macro(
        name: 'Yağ',
        amount:
            '${provider.totals.totalFat.round()} / ${targets.fat.round()} g',
        ratio: fatProgress,
        color: goal.macros[2].color,
      ),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst: başlık + pasta özeti
              Row(
                children: [
                  const Icon(
                    Icons.pie_chart_rounded,
                    color: Colors.white54,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Makro Hedefler',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // Küçük renk legend
                  Row(
                    children: dynamicMacros
                        .map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: m.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  switch (m.name) {
                                    'Protein' => 'P',
                                    'Karbonhidrat' => 'K',
                                    'Yağ' => 'Y',
                                    _ => m.name[0],
                                  },
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Birleşik bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: dynamicMacros
                      .map(
                        (m) => Expanded(
                          flex: (m.ratio * 100).round(),
                          child: Container(height: 10, color: m.color),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              // Her makro satırı
              ...dynamicMacros.asMap().entries.map(
                (e) => Padding(
                  padding: EdgeInsets.only(
                    bottom: e.key < dynamicMacros.length - 1 ? 10 : 0,
                  ),
                  child: _MacroRow(macro: e.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final _Macro macro;
  const _MacroRow({required this.macro});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: macro.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          macro.name,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const Spacer(),
        Text(
          macro.amount,
          style: TextStyle(
            color: macro.color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 68,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: macro.ratio,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(macro.color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 30,
          child: Text(
            '${(macro.ratio * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: macro.color.withValues(alpha: 0.85),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.07),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meal List ────────────────────────────────────────────────────────────────

class _MealList extends StatelessWidget {
  final _Goal goal;
  final VoidCallback? onTap;
  const _MealList({required this.goal, this.onTap});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<DietProvider>().nutritionPreferences;
    final meals = goal.meals
        .where((meal) => _allowedFoodText(meal.name, prefs))
        .toList();
    final visibleMeals = meals.isNotEmpty
        ? meals
        : [
            _MealIdea(
              name: _fallbackFoodFor(
                label: 'Öğün',
                goalKey: goal.key,
                prefs: prefs,
              ),
              detail: goal.meals.first.detail,
              icon: Icons.restaurant_rounded,
              accent: goal.color,
            ),
          ];
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      itemCount: visibleMeals.length,
      itemBuilder: (_, i) =>
          _MealCard(meal: visibleMeals[i], onTap: onTap),
    );
  }
}

class _MealCard extends StatelessWidget {
  final _MealIdea meal;
  final VoidCallback? onTap;
  const _MealCard({required this.meal, this.onTap});

  (String kcal, String protein) _parseMacros(String detail) {
    final kcalMatch = RegExp(r'~?(\d+)\s*kcal').firstMatch(detail);
    final proMatch = RegExp(r'(\d+g)\s*pro').firstMatch(detail);
    return (kcalMatch?.group(1) ?? '', proMatch?.group(1) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final (kcal, protein) = _parseMacros(meal.detail);
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 164,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            meal.accent.withValues(alpha: 0.18),
            meal.accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: meal.accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: meal.accent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: meal.accent.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: meal.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: meal.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(meal.icon, color: meal.accent, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    meal.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (kcal.isNotEmpty)
                        _MacroPill(
                          value: kcal,
                          unit: 'kcal',
                          color: Colors.orange,
                        ),
                      if (kcal.isNotEmpty && protein.isNotEmpty)
                        const SizedBox(width: 5),
                      if (protein.isNotEmpty)
                        _MacroPill(
                          value: protein,
                          unit: 'P',
                          color: meal.accent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String value, unit;
  final Color color;
  const _MacroPill({
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$value $unit',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlanTotalChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _PlanTotalChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.72),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanLogicPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlanLogicPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Daily Plan Card ──────────────────────────────────────────────────────────

class _DailyPlanCard extends StatefulWidget {
  final _Goal goal;
  final Future<void> Function(_Goal goal, List<PlannedMeal> meals) onCopyTap;
  final VoidCallback? onAiCustomizeTap;
  final bool isAiPremiumUnlocked;

  const _DailyPlanCard({
    required this.goal,
    required this.onCopyTap,
    this.onAiCustomizeTap,
    this.isAiPremiumUnlocked = false,
  });

  @override
  State<_DailyPlanCard> createState() => _DailyPlanCardState();
}

class _DailyPlanCardState extends State<_DailyPlanCard> {
  static const _smartPlanEngine = SmartNutritionPlanEngine();
  final Map<String, int> _shuffleIndexes = {};

  /// Bir makro string'ini ölçek faktörüyle çarp ve yeni string döndür.
  /// Örnek: "~380 kcal · 28g pro" → "~304 kcal · 22g pro" (factor 0.8)
  String _scaleMacroString(String macros, double factor) {
    if (factor == 1.0 || macros.isEmpty) return macros;
    var result = macros;

    // kcal ölçekle
    final kcalMatch = RegExp(r'~?(\d+)\s*kcal').firstMatch(result);
    if (kcalMatch != null) {
      final original = int.parse(kcalMatch.group(1)!);
      final scaled = (original * factor).round();
      // 10'a yuvarla (daha temiz görünüm)
      final rounded = ((scaled + 5) ~/ 10) * 10;
      result = result.replaceFirst(kcalMatch.group(0)!, '~$rounded kcal');
    }

    // protein ölçekle
    final proMatch = RegExp(r'(\d+)g\s*pro').firstMatch(result);
    if (proMatch != null) {
      final original = int.parse(proMatch.group(1)!);
      final scaled = (original * factor).round();
      result = result.replaceFirst(proMatch.group(0)!, '${scaled}g pro');
    }

    return result;
  }

  bool get _isCut => widget.goal.key == 'cut';
  bool get _isGain => widget.goal.key == 'gain';
  bool get _isBulk => widget.goal.key == 'bulk';
  bool get _isStrength => widget.goal.key == 'strength';

  SmartDailyPlan _buildSmartPlan(BuildContext context) {
    final diet = context.watch<DietProvider>();
    final simulated = diet.getSimulatedTargets(
      _profileGoalForGuideGoal(widget.goal),
    );
    final workoutTiming = _workoutTiming(context);
    final appPrefs = context.read<AppPreferences>();
    return _smartPlanEngine.build(
      SmartPlanInput(
        goalKey: widget.goal.key,
        targets: SmartPlanTargets(
          kcal: simulated.targetKcal,
          protein: simulated.proteinTarget,
          carb: simulated.carbTarget,
          fat: simulated.fatTarget,
        ),
        consumed: SmartPlanProgress(
          kcal: diet.totals.totalKcal,
          protein: diet.totals.totalProtein,
          carb: diet.totals.totalCarb,
          fat: diet.totals.totalFat,
        ),
        preferences: diet.nutritionPreferences,
        loggedMealTypes: diet.entries.map((entry) => entry.mealType).toSet(),
        currentHour: DateTime.now().hour,
        hasWorkoutToday: workoutTiming.hasWorkoutToday,
        isPreWorkoutWindow: workoutTiming.isPreWorkout,
        isPostWorkoutWindow: workoutTiming.isPostWorkout,
        useUsFoods: appPrefs.isUsExperience,
        availableIngredients: diet.entries
            .map((entry) => entry.foodName)
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList(),
        slotVariantIndexes: Map<String, int>.from(_shuffleIndexes),
        maxPrepMinutes: DateTime.now().hour >= 18 ? 20 : 30,
      ),
    );
  }

  ({bool hasWorkoutToday, bool isPreWorkout, bool isPostWorkout})
  _workoutTiming(BuildContext context) {
    WorkoutProvider? workoutProvider;
    try {
      workoutProvider = context.read<WorkoutProvider>();
    } catch (_) {
      workoutProvider = null;
    }
    final wp = workoutProvider;
    if (wp == null) {
      return (
        hasWorkoutToday: false,
        isPreWorkout: false,
        isPostWorkout: false,
      );
    }

    final now = DateTime.now();
    final todayWorkouts = wp.workouts.where((workout) {
      final date = workout.workoutDate;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    if (todayWorkouts.isEmpty) {
      return (
        hasWorkoutToday: false,
        isPreWorkout: false,
        isPostWorkout: false,
      );
    }

    final isPreWorkout = todayWorkouts.any(
      (workout) =>
          workout.workoutDate.isAfter(now) &&
          workout.workoutDate.difference(now).inMinutes <= 120,
    );
    final isPostWorkout = todayWorkouts.any((workout) {
      final diff = now.difference(workout.workoutDate);
      return !diff.isNegative && diff.inMinutes <= 120;
    });
    return (
      hasWorkoutToday: true,
      isPreWorkout: isPreWorkout,
      isPostWorkout: isPostWorkout && !isPreWorkout,
    );
  }

  _DayMeal _dayMealFromSmart(SmartPlanMeal meal) {
    return _DayMeal(
      time: meal.time,
      label: meal.label,
      food: meal.food,
      macros: meal.macroText,
      icon: _iconForSmartMeal(meal),
      slotKey: meal.slotKey,
    );
  }

  IconData _iconForSmartMeal(SmartPlanMeal meal) {
    if (meal.slotKey == 'preWorkout' || meal.slotKey == 'postWorkout') {
      return Icons.fitness_center_rounded;
    }
    switch (meal.mealType) {
      case MealType.breakfast:
        return Icons.free_breakfast_rounded;
      case MealType.lunch:
        return Icons.lunch_dining_rounded;
      case MealType.dinner:
        return Icons.dinner_dining_rounded;
      case MealType.snack:
        return Icons.bakery_dining_rounded;
    }
  }

  List<PlannedMeal> _plannedMealsFromSmart(SmartDailyPlan plan) {
    return plan.meals.map((meal) {
      return PlannedMeal(
        name: meal.food,
        kcal: meal.kcal,
        portionGrams: _defaultGuidePortion(meal.mealType),
        mealType: meal.mealType,
        category: meal.slotKey,
        ingredients: meal.ingredients,
      );
    }).toList();
  }

  double _defaultGuidePortion(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 120;
      case MealType.lunch:
      case MealType.dinner:
        return 180;
      case MealType.snack:
        return 80;
    }
  }

  void _shuffleMeal(String slotKey) {
    setState(() {
      _shuffleIndexes[slotKey] = (_shuffleIndexes[slotKey] ?? 0) + 1;
    });
  }

  void _shuffleAll() {
    setState(() {
      for (final slotKey in const [
        'breakfast',
        'lunch',
        'snack',
        'preWorkout',
        'postWorkout',
        'dinner',
        'snack2',
      ]) {
        _shuffleIndexes[slotKey] = (_shuffleIndexes[slotKey] ?? 0) + 1;
      }
    });
  }

  _DayMeal _postWorkoutStop() {
    if (_isCut) {
      return const _DayMeal(
        time: '',
        label: 'Toparlanma',
        food: 'Su + 20-30g protein; karbonhidratı kalan kaloriye göre ekle',
        macros: '',
        icon: Icons.water_drop_rounded,
        isMiniStop: true,
      );
    }
    if (_isGain || _isBulk) {
      return const _DayMeal(
        time: '',
        label: 'Toparlanma',
        food: '30g protein + hızlı karbonhidrat; glikojeni doldur',
        macros: '',
        icon: Icons.local_drink_rounded,
        isMiniStop: true,
      );
    }
    if (_isStrength) {
      return const _DayMeal(
        time: '',
        label: 'Toparlanma',
        food: 'Protein + kolay sindirilen karbonhidrat; kreatin opsiyonel',
        macros: '',
        icon: Icons.bolt_rounded,
        isMiniStop: true,
      );
    }
    return const _DayMeal(
      time: '',
      label: 'Toparlanma',
      food: 'Su + normal öğünde protein; ekstra kalori şart değil',
      macros: '',
      icon: Icons.medication_liquid_rounded,
      isMiniStop: true,
    );
  }

  List<_DayMeal> _buildExtendedPlan(SmartDailyPlan smartPlan) {
    final list = <_DayMeal>[];

    // 1. Sabah Suyu (Mini Durak)
    list.add(
      const _DayMeal(
        time: '07:00',
        label: 'Güne Başlarken',
        food: 'Uyanınca 500ml Su',
        macros: '',
        icon: Icons.water_drop_rounded,
        isMiniStop: true,
      ),
    );

    for (final meal in smartPlan.meals.map(_dayMealFromSmart)) {
      list.add(meal);
      // Antrenman Sonrası Takviye (Mini Durak)
      if (meal.label.toLowerCase().contains('antrenman') &&
          !meal.label.toLowerCase().contains('sonras')) {
        list.add(_postWorkoutStop());
      }
    }
    return list;
  }

  (int kcal, int protein) _calculateTotals(
    List<_DayMeal> extendedPlan,
    double scaleFactor,
  ) {
    int totalKcal = 0;
    int totalPro = 0;

    for (int i = 0; i < extendedPlan.length; i++) {
      final item = extendedPlan[i];
      if (item.isMiniStop) continue;

      final scaled = _scaleMacroString(item.macros, scaleFactor);

      final kcalMatch = RegExp(r'(\d+)\s*kcal').firstMatch(scaled);
      if (kcalMatch != null) totalKcal += int.parse(kcalMatch.group(1)!);

      final proMatch = RegExp(r'(\d+)g\s*pro').firstMatch(scaled);
      if (proMatch != null) totalPro += int.parse(proMatch.group(1)!);
    }
    return (totalKcal, totalPro);
  }

  ({IconData icon, String label}) _logicForMeal(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('antrenman')) {
      if (_isCut) return (icon: Icons.speed_rounded, label: 'Hafif enerji');
      if (_isGain || _isBulk) {
        return (icon: Icons.bolt_rounded, label: 'Glikojen desteği');
      }
      if (_isStrength) {
        return (icon: Icons.fitness_center_rounded, label: 'Performans');
      }
      return (icon: Icons.bolt_rounded, label: 'Egzersiz desteği');
    }
    if (lower.contains('gece')) {
      return (icon: Icons.bedtime_rounded, label: 'Gece proteini');
    }
    if (_isCut) return (icon: Icons.restaurant_rounded, label: 'Tok tutar');
    if (_isGain || _isBulk) {
      return (icon: Icons.trending_up_rounded, label: 'Kalori yoğun');
    }
    if (_isStrength) return (icon: Icons.bolt_rounded, label: 'Güç yakıtı');
    return (icon: Icons.balance_rounded, label: 'Dengeli tabak');
  }

  @override
  Widget build(BuildContext context) {
    final scaleFactor = 1.0;
    final smartPlan = _buildSmartPlan(context);
    final extendedPlan = _buildExtendedPlan(smartPlan);
    final totals = _calculateTotals(extendedPlan, scaleFactor);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.085)),
          ),
          child: Column(
            children: [
              // ── Toplam Özet (Canlı Matematik) ──
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.075),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: widget.goal.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.today_rounded,
                            color: widget.goal.color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bugünün planı',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                smartPlan.reason,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _shuffleAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.09),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shuffle_rounded,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tümünü Yenile',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Wrap(
                          key: ValueKey('${totals.$1}-${totals.$2}'),
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: [
                            _PlanTotalChip(
                              icon: Icons.local_fire_department_rounded,
                              value: '${totals.$1}',
                              label: 'kcal',
                              color: AppColors.secondary,
                            ),
                            _PlanTotalChip(
                              icon: Icons.fitness_center_rounded,
                              value: '${totals.$2}g',
                              label: 'pro',
                              color: widget.goal.color,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              const SizedBox(height: 8),

              // ── Timeline ──
              ...extendedPlan.asMap().entries.map((e) {
                final meal = e.value;
                final isFirst = e.key == 0;
                final isLast = e.key == extendedPlan.length - 1;

                // Mini Durak Render
                if (meal.isMiniStop) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 56,
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              if (meal.time.isNotEmpty)
                                Text(
                                  meal.time,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              Container(
                                width: 2,
                                height: 12,
                                color: isFirst
                                    ? Colors.transparent
                                    : widget.goal.color.withValues(alpha: 0.25),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  meal.icon,
                                  color: widget.goal.color.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 11,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: isLast
                                      ? Colors.transparent
                                      : widget.goal.color.withValues(
                                          alpha: 0.25,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              top: 10,
                              bottom: 16,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: widget.goal.color.withValues(
                                  alpha: 0.06,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.goal.color.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: widget.goal.color.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      meal.label,
                                      style: TextStyle(
                                        color: widget.goal.color.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      meal.food,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Normal Öğün Render
                final isWorkout = meal.label.toLowerCase().contains(
                  'antrenman',
                );
                final scaledMacros = _scaleMacroString(
                  meal.macros,
                  scaleFactor,
                );

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Column(
                          children: [
                            const SizedBox(height: 15),
                            Text(
                              meal.time,
                              style: GoogleFonts.inter(
                                color: isWorkout
                                    ? widget.goal.color
                                    : Colors.white70,
                                fontSize: 11.5,
                                fontWeight: isWorkout
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Column(
                          children: [
                            Container(
                              width: 2,
                              height: 15,
                              color: isFirst
                                  ? Colors.transparent
                                  : widget.goal.color.withValues(alpha: 0.25),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isWorkout
                                    ? widget.goal.color.withValues(alpha: 0.2)
                                    : AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isWorkout
                                      ? widget.goal.color
                                      : widget.goal.color.withValues(
                                          alpha: 0.3,
                                        ),
                                  width: isWorkout ? 1.5 : 1,
                                ),
                                boxShadow: isWorkout
                                    ? [
                                        BoxShadow(
                                          color: widget.goal.color.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                meal.icon,
                                color: isWorkout
                                    ? widget.goal.color
                                    : Colors.white70,
                                size: 14,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isLast
                                    ? Colors.transparent
                                    : widget.goal.color.withValues(alpha: 0.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.035),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isWorkout
                                  ? widget.goal.color.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      meal.label,
                                      style: GoogleFonts.inter(
                                        color: isWorkout
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.95,
                                              ),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _shuffleMeal(meal.slotKey),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: widget.goal.color.withValues(
                                          alpha: 0.09,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: widget.goal.color.withValues(
                                            alpha: 0.22,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.sync_rounded,
                                            size: 13,
                                            color: widget.goal.color.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Değiştir',
                                            style: TextStyle(
                                              color: widget.goal.color
                                                  .withValues(alpha: 0.85),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.0, 0.1),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  key: ValueKey<String>(meal.food),
                                  width: double.infinity,
                                  child: Text(
                                    meal.food,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: Wrap(
                                  key: ValueKey<String>(scaledMacros),
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: widget.goal.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: widget.goal.color.withValues(
                                            alpha: 0.15,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        scaledMacros
                                            .replaceAll('~', '')
                                            .replaceAll('·', '•'),
                                        style: GoogleFonts.inter(
                                          color: widget.goal.color.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    _PlanLogicPill(
                                      icon: _logicForMeal(meal.label).icon,
                                      label: _logicForMeal(meal.label).label,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // ── AI Özelleştir + Kopyalama Butonları ──
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // AI ile Özelleştir Butonu
                    if (widget.onAiCustomizeTap != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onAiCustomizeTap,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 54),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFD66B), Color(0xFFFF9F0A)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF9F0A,
                                  ).withValues(alpha: 0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.isAiPremiumUnlocked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2A1800,
                                          ).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'AI',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF2A1800),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      )
                                    else
                                      const ProBadge(compact: true),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI Özelleştir',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF2A1800),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (!widget.isAiPremiumUnlocked) ...[
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.lock_rounded,
                                        color: Color(0xFF2A1800),
                                        size: 13,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Ayırıcı
                    if (widget.onAiCustomizeTap != null)
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    // Kopyala Butonu
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onCopyTap(
                          widget.goal,
                          _plannedMealsFromSmart(smartPlan),
                        ),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 54),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          color: widget.goal.color.withValues(alpha: 0.08),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.content_copy_rounded,
                                    color: widget.goal.color,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Kopyala',
                                    style: GoogleFonts.inter(
                                      color: widget.goal.color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Timing Card ─────────────────────────────────────────────────────────────

class _TimingCard extends StatelessWidget {
  final _Goal goal;
  const _TimingCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    const postColor = Color(0xFF30D158);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: [
          // ── Timeline görsel ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Öncesi',
                      style: TextStyle(
                        color: goal.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            goal.color.withValues(alpha: 0.1),
                            goal.color.withValues(alpha: 0.55),
                          ],
                        ),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Center(
                  child: Text('🏋️', style: TextStyle(fontSize: 20)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sonrası',
                      style: TextStyle(
                        color: postColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 3,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x8D30D158), Color(0x1A30D158)],
                        ),
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── İki detay kutusu ──
          Row(
            children: [
              Expanded(
                child: _TimingBox(
                  label: goal.timing.preMeal,
                  detail: goal.timing.preDetail,
                  color: goal.color,
                  icon: Icons.north_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimingBox(
                  label: goal.timing.postMeal,
                  detail: goal.timing.postDetail,
                  color: postColor,
                  icon: Icons.south_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimingBox extends StatelessWidget {
  final String label, detail;
  final Color color;
  final IconData icon;
  const _TimingBox({
    required this.label,
    required this.detail,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 12),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Foods Grid ───────────────────────────────────────────────────────────

class _TopFoodsGrid extends StatelessWidget {
  final _Goal goal;
  const _TopFoodsGrid({required this.goal});

  static String _emoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('tavuk') || n.contains('hindi')) return '🍗';
    if (n.contains('somon')) return '🐟';
    if (n.contains('ton')) return '🐡';
    if (n.contains('hamsi') ||
        n.contains('palamut') ||
        n.contains('levrek') ||
        n.contains('balık')) {
      return '🐠';
    }
    if (n.contains('yumurta')) return '🥚';
    if (n.contains('yoğurt') || n.contains('kefir')) return '🥛';
    if (n.contains('süt')) return '🥛';
    if (n.contains('peynir')) return '🧀';
    if (n.contains('et') ||
        n.contains('kıyma') ||
        n.contains('biftek') ||
        n.contains('kuzu') ||
        n.contains('köfte')) {
      return '🥩';
    }
    if (n.contains('pirinç') || n.contains('pilav')) return '🍚';
    if (n.contains('makarna')) return '🍝';
    if (n.contains('ekmek') || n.contains('bulgur')) return '🌾';
    if (n.contains('muz')) return '🍌';
    if (n.contains('elma')) return '🍎';
    if (n.contains('portakal')) return '🍊';
    if (n.contains('çilek')) return '🍓';
    if (n.contains('brokoli') || n.contains('ıspanak') || n.contains('sebze')) {
      return '🥦';
    }
    if (n.contains('patates')) return '🥔';
    if (n.contains('avokado')) return '🥑';
    if (n.contains('nohut') ||
        n.contains('fasulye') ||
        n.contains('mercimek')) {
      return '🫘';
    }
    if (n.contains('badem') ||
        n.contains('ceviz') ||
        n.contains('fındık') ||
        n.contains('fıstık')) {
      return '🥜';
    }
    if (n.contains('yulaf')) return '🌾';
    if (n.contains('protein')) return '💪';
    if (n.contains('zeytinyağ') || n.contains('yağ')) return '🫒';
    if (n.contains('quinoa') || n.contains('tahıl')) return '🌱';
    return '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<DietProvider>().nutritionPreferences;
    final foods = goal.topFoods
        .where((food) => _allowedFoodText(food.name, prefs))
        .toList();
    final visibleFoods = foods.isNotEmpty
        ? foods
        : [
            _TopFood(
              name: _fallbackFoodFor(
                label: 'Öğle',
                goalKey: goal.key,
                prefs: prefs,
              ),
              highlight: 'Tercihlerine uygun alternatif',
              color: goal.color,
            ),
          ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.05,
      children: visibleFoods
          .map(
            (f) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: f.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: f.color.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _emoji(f.name),
                        style: const TextStyle(fontSize: 20),
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
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.highlight,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontSize: 10.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Rules Card ───────────────────────────────────────────────────────────────

class _RulesCard extends StatelessWidget {
  final _Goal goal;
  const _RulesCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: goal.rules.asMap().entries.map((e) {
          final isLast = e.key == goal.rules.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: goal.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        color: goal.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Avoid Card ───────────────────────────────────────────────────────────────

class _AvoidCard extends StatelessWidget {
  final _Goal goal;
  const _AvoidCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF453A).withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: goal.avoid
            .asMap()
            .entries
            .map(
              (e) => Padding(
                padding: EdgeInsets.only(
                  bottom: e.key < goal.avoid.length - 1 ? 8 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3, right: 10),
                      child: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: Color(0xFFFF453A),
                        size: 15,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          color: Color(0xFFB0A0A0),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Supplement Chips ─────────────────────────────────────────────────────────

class _SupplementChips extends StatelessWidget {
  final _Goal goal;
  const _SupplementChips({required this.goal});

  static IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('whey') || n.contains('protein')) {
      return Icons.fitness_center_rounded;
    }
    if (n.contains('kreatin')) return Icons.bolt_rounded;
    if (n.contains('vitamin') ||
        n.contains('d3') ||
        n.contains('b12') ||
        n.contains('c vitamini')) {
      return Icons.eco_rounded;
    }
    if (n.contains('omega') || n.contains('balık yağı')) {
      return Icons.water_drop_rounded;
    }
    if (n.contains('magnezyum') ||
        n.contains('çinko') ||
        n.contains('mineral')) {
      return Icons.diamond_rounded;
    }
    if (n.contains('zma') || n.contains('uyku')) return Icons.bedtime_rounded;
    if (n.contains('kafein') ||
        n.contains('pre-workout') ||
        n.contains('enerji')) {
      return Icons.local_fire_department_rounded;
    }
    if (n.contains('bcaa') || n.contains('amino') || n.contains('eaa')) {
      return Icons.scatter_plot_rounded;
    }
    if (n.contains('glutamin')) return Icons.healing_rounded;
    if (n.contains('demir') || n.contains('kalsiyum')) {
      return Icons.opacity_rounded;
    }
    return Icons.science_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Takviyeler temel beslenmenin yerine geçmez; ilaç kullanıyorsan, kronik rahatsızlığın varsa veya emin değilsen uzman görüşü al.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: goal.supplements
              .map(
                (s) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: goal.color.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconFor(s), color: goal.color, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        s,
                        style: TextStyle(
                          color: goal.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─── General Tips Card ────────────────────────────────────────────────────────

class _GeneralTipsCard extends StatelessWidget {
  const _GeneralTipsCard();

  static const _tips = [
    (
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0A84FF),
      text:
          'Günde en az 2–2.5 litre su iç. Açlık hissi çoğu zaman susuzluktur.',
    ),
    (
      icon: Icons.schedule_rounded,
      color: Color(0xFF30D158),
      text: 'Düzenli öğün saatleri tutmak metabolizmayı dengede tutar.',
    ),
    (
      icon: Icons.no_food_rounded,
      color: Color(0xFFFF453A),
      text: 'İşlenmiş gıda, hazır meyve suyu ve şekerli içeceklerden kaçın.',
    ),
    (
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFF9F0A),
      text:
          'Tabağının yarısı sebze, çeyreği protein, çeyreği karbonhidrat olsun.',
    ),
    (
      icon: Icons.bedtime_rounded,
      color: Color(0xFFBF5AF2),
      text: 'Uyku kalitesi beslenme kadar önemlidir; 7–8 saat hedefle.',
    ),
    (
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFFF6B35),
      text: 'Direnç egzersizi + yeterli protein = kas korumanın anahtarı.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: _tips.asMap().entries.map((e) {
              final tip = e.value;
              final isLast = e.key == _tips.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 12, top: 1),
                      decoration: BoxDecoration(
                        color: tip.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(tip.icon, color: tip.color, size: 16),
                    ),
                    Expanded(
                      child: Text(
                        tip.text,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Body Profile Card ────────────────────────────────────────────────────────

class _BmiBar extends StatelessWidget {
  final double bmi;
  final Color bmiColor;
  final String bmiLabel;
  const _BmiBar({
    required this.bmi,
    required this.bmiColor,
    required this.bmiLabel,
  });

  @override
  Widget build(BuildContext context) {
    final position = ((bmi - 15) / (40 - 15)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BMI',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${bmi.toStringAsFixed(1)}  ·  $bmiLabel',
              style: TextStyle(
                color: bmiColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            const ms = 10.0;
            return SizedBox(
              height: 18,
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        height: 10,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0A84FF),
                              Color(0xFF30D158),
                              Color(0xFFFF9F0A),
                              Color(0xFFFF453A),
                            ],
                            stops: [0.0, 0.27, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: (position * (w - ms)).clamp(0.0, w - ms),
                    child: Container(
                      width: ms,
                      height: 18,
                      decoration: BoxDecoration(
                        color: bmiColor,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: bmiColor.withValues(alpha: 0.55),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('15', style: TextStyle(color: Colors.white24, fontSize: 9)),
            Text('18.5', style: TextStyle(color: Colors.white24, fontSize: 9)),
            Text('25', style: TextStyle(color: Colors.white24, fontSize: 9)),
            Text('30', style: TextStyle(color: Colors.white24, fontSize: 9)),
            Text('40', style: TextStyle(color: Colors.white24, fontSize: 9)),
          ],
        ),
      ],
    );
  }
}

class _BodyProfileCard extends StatelessWidget {
  final UserProfile profile;
  const _BodyProfileCard({required this.profile});

  static (String, Color) _bmiInfo(double bmi) {
    if (bmi < 18.5) return ('Düşük Kilo', const Color(0xFF0A84FF));
    if (bmi < 25.0) return ('Normal', const Color(0xFF30D158));
    if (bmi < 30.0) return ('Hafif Fazla', const Color(0xFFFF9F0A));
    return ('Obez', const Color(0xFFFF453A));
  }

  static String _activityLabel(ActivityLevel level) => switch (level) {
    ActivityLevel.sedentary => 'Az hareketli',
    ActivityLevel.lightlyActive => 'Hafif aktif',
    ActivityLevel.moderatelyActive => 'Orta aktif',
    ActivityLevel.veryActive => 'Çok aktif',
    ActivityLevel.extraActive => 'Ekstra aktif',
  };

  Widget _statCell(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    ),
  );

  Widget _vDivider() => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.08),
  );

  Widget _infoTile(String label, String value, String sub, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bmi =
        profile.weight / ((profile.height / 100) * (profile.height / 100));
    final (bmiLabel, bmiColor) = _bmiInfo(bmi);
    final targetW = profile.targetWeight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white60,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _activityLabel(profile.activityLevel),
                          style: GoogleFonts.dmSans(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bmiColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bmiLabel,
                      style: TextStyle(
                        color: bmiColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _statCell('${profile.weight.toStringAsFixed(1)} kg', 'Kilo'),
                  _vDivider(),
                  _statCell('${profile.height.toStringAsFixed(0)} cm', 'Boy'),
                  _vDivider(),
                  _statCell('${profile.age}', 'Yaş'),
                  _vDivider(),
                  _statCell(
                    profile.gender == Gender.male ? 'Erkek' : 'Kadın',
                    'Cinsiyet',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _BmiBar(bmi: bmi, bmiColor: bmiColor, bmiLabel: bmiLabel),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _infoTile(
                      'BMR',
                      '${profile.bmr.round()} kcal',
                      'Bazal metabolizma',
                      const Color(0xFF0A84FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoTile(
                      'TDEE',
                      '${profile.tdee.round()} kcal',
                      'Günlük harcama',
                      const Color(0xFF30D158),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoTile(
                      'Hedef',
                      '${profile.targetCalories.round()} kcal',
                      'Günlük hedef',
                      const Color(0xFFFF9F0A),
                    ),
                  ),
                ],
              ),
              if (targetW != null) ...[
                const SizedBox(height: 12),
                _WeightProgressRow(current: profile.weight, target: targetW),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightProgressRow extends StatelessWidget {
  final double current;
  final double target;
  const _WeightProgressRow({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final diff = target - current;
    final color = diff < 0 ? const Color(0xFFFF453A) : const Color(0xFF30D158);
    final icon = diff < 0
        ? Icons.trending_down_rounded
        : Icons.trending_up_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '${current.toStringAsFixed(1)} kg',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white38,
              size: 14,
            ),
          ),
          Text(
            '${target.toStringAsFixed(1)} kg',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Personal Tips Section ────────────────────────────────────────────────────

class _PersonalTipsSection extends StatelessWidget {
  final UserProfile profile;
  const _PersonalTipsSection({required this.profile});

  List<({IconData icon, Color color, String text})> _buildTips() {
    final tips = <({IconData icon, Color color, String text})>[];
    final bmi =
        profile.weight / ((profile.height / 100) * (profile.height / 100));

    if (profile.gender == Gender.female) {
      tips.add((
        icon: Icons.favorite_rounded,
        color: const Color(0xFFFF6B9D),
        text:
            'Kadınlarda günlük demir ihtiyacı 18 mg. Kırmızı et, mercimek ve ıspanak ile destekle. Kalsiyum alımına da dikkat et.',
      ));
    }

    if (profile.age >= 40) {
      tips.add((
        icon: Icons.self_improvement_rounded,
        color: const Color(0xFFBF5AF2),
        text:
            '40+ yaşta toparlanma ve kas korunumu daha önemli hale gelir. Protein hedefini düzenli takip et; D vitamini ve kalsiyumu gerekirse uzmanla değerlendir.',
      ));
    } else if (profile.age < 25) {
      tips.add((
        icon: Icons.bolt_rounded,
        color: const Color(0xFFFFD60A),
        text:
            'Genç metabolizman kas geliştirme için büyük avantaj. Bu dönemi düzenli antrenman ve yeterli proteinle değerlendir.',
      ));
    }

    if (profile.activityLevel == ActivityLevel.sedentary) {
      tips.add((
        icon: Icons.directions_walk_rounded,
        color: const Color(0xFF4FACFE),
        text:
            'Az hareketli yaşamda TDEE\'n düşük — küçük kalori açıkları bile etkili olur. Günde 8.000 adım metabolizmayı canlandırır.',
      ));
    } else if (profile.activityLevel == ActivityLevel.veryActive ||
        profile.activityLevel == ActivityLevel.extraActive) {
      tips.add((
        icon: Icons.sports_score_rounded,
        color: const Color(0xFF30D158),
        text:
            'Yoğun aktivitede karbonhidrat zamanlaması performansı destekler: antrenman öncesi 1–2 saat, sonrasında protein + karbonhidrat iyi bir başlangıçtır.',
      ));
    }

    if (bmi >= 25 && bmi < 30) {
      tips.add((
        icon: Icons.monitor_weight_rounded,
        color: const Color(0xFFFF9F0A),
        text:
            'Kalori açığını −300 ile −500 arasında tut. Daha sert kısıtlamalar kas kaybına ve metabolizma yavaşlamasına neden olur.',
      ));
    } else if (bmi < 18.5) {
      tips.add((
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF0A84FF),
        text:
            'Kilo almak için kalori fazlasını sağlıklı kaynaklardan al: fındık ezmesi, avokado, zeytinyağı, tam tahıllı ürünler.',
      ));
    }

    switch (profile.goal) {
      case Goal.cut:
        tips.add((
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF453A),
          text:
              'Haftada 1 refeed günü (TDEE kadar ye) metabolizmayı ve leptin seviyesini dengede tutar. Formdan çıkmaz.',
        ));
      case Goal.bulk:
        tips.add((
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF43E97B),
          text:
              'Temiz bulk için aylık 0.5–1 kg hedefle. Daha hızlı kilo alımı yağ birikimini artırabilir; kreatini ancak sana uygunsa değerlendir.',
        ));
      case Goal.strength:
        tips.add((
          icon: Icons.fitness_center_rounded,
          color: const Color(0xFFFF9F0A),
          text:
              'Kuvvet performansı için yeterli uyku, düzenli karbonhidrat ve uygun protein alımı önceliklidir; kreatin opsiyonel destek olarak değerlendirilebilir.',
        ));
      case Goal.maintain:
        tips.add((
          icon: Icons.balance_rounded,
          color: const Color(0xFF64D2FF),
          text:
              'Kilo koruma da hedef sabittir. Haftalık varyasyonlar normal — 3 günlük trende bak, tek güne bakma.',
        ));
    }

    return tips.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tips = _buildTips();
    if (tips.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: tips.asMap().entries.map((e) {
              final tip = e.value;
              final isLast = e.key == tips.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 12, top: 1),
                      decoration: BoxDecoration(
                        color: tip.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(tip.icon, color: tip.color, size: 16),
                    ),
                    Expanded(
                      child: Text(
                        tip.text,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── AI Customize Sheet ───────────────────────────────────────────────────────

class _AiCustomizeSheet extends StatefulWidget {
  final _Goal goal;
  const _AiCustomizeSheet({required this.goal});

  @override
  State<_AiCustomizeSheet> createState() => _AiCustomizeSheetState();
}

class _AiCustomizeSheetState extends State<_AiCustomizeSheet>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  NutritionAiResponseModel? _lastResponse;
  String? _aiResponse;
  String _displayedResponse = '';
  bool _isTyping = false;

  static const _quickChips = <(String label, String prompt, IconData icon)>[
    (
      '🌱 Vegan Yap',
      'Bu planı tamamen vegan hale getir, hayvansal ürün olmasın.',
      Icons.eco_rounded,
    ),
    (
      '🥚 Evdeki Malzeme',
      'Evde sadece yumurta, yulaf ve süt var. Planı buna göre güncelle.',
      Icons.kitchen_rounded,
    ),
    (
      '💰 Bütçe Dostu',
      'Bu planı daha ekonomik malzemelerle yeniden düzenle.',
      Icons.savings_rounded,
    ),
    (
      '⏱️ Hızlı Hazırla',
      'Tüm öğünleri 15 dakikada hazırlanabilir şekilde değiştir.',
      Icons.timer_rounded,
    ),
    (
      '🚫 Glutensiz',
      'Planı glutensiz alternatifleriyle güncelle.',
      Icons.no_food_rounded,
    ),
    (
      '🥩 Yüksek Protein',
      'Protein oranını artır, her öğüne daha fazla protein ekle.',
      Icons.fitness_center_rounded,
    ),
  ];

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRequest(String prompt) async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _lastResponse = null;
      _aiResponse = null;
      _displayedResponse = '';
      _isTyping = false;
    });

    try {
      final provider = context.read<DietProvider>();
      final aiService = provider.aiService;
      if (aiService == null) {
        setState(() {
          _aiResponse =
              'AI servisi şu an kullanılamıyor. Lütfen daha sonra tekrar dene.';
          _isLoading = false;
        });
        _startTypingAnimation();
        return;
      }

      // Build context about the current plan
      final smartPlan = _buildSmartPlan(provider);
      final planMeals = smartPlan.meals
          .map((m) => '${m.label}: ${m.food} (${m.macroText})')
          .join('\n');

      final contextMsg =
          '''
Mevcut ${widget.goal.label} planı:
$planMeals

Hedef: ${widget.goal.subtitle}
Kalori kuralı: ${widget.goal.calorieRule}

Kullanıcı isteği: $prompt
''';

      final nutritionContext = _buildNutritionContext(provider, smartPlan);
      final response = await aiService.getStructuredNutritionResponse(
        prompt,
        contextMsg,
        task: 'plan_customization',
        nutritionContext: nutritionContext,
      );

      if (!mounted) return;
      setState(() {
        _lastResponse = response;
        _aiResponse = response.reply ?? 'Yanıt alınamadı.';
        _isLoading = false;
      });
      _startTypingAnimation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastResponse = null;
        _aiResponse = 'Bir hata oluştu. Lütfen tekrar dene.';
        _isLoading = false;
      });
      _startTypingAnimation();
    }
  }

  SmartDailyPlan _buildSmartPlan(DietProvider provider) {
    final simulated = provider.getSimulatedTargets(
      _profileGoalForGuideGoal(widget.goal),
    );
    final appPrefs = context.read<AppPreferences>();
    return const SmartNutritionPlanEngine().build(
      SmartPlanInput(
        goalKey: widget.goal.key,
        targets: SmartPlanTargets(
          kcal: simulated.targetKcal,
          protein: simulated.proteinTarget,
          carb: simulated.carbTarget,
          fat: simulated.fatTarget,
        ),
        consumed: SmartPlanProgress(
          kcal: provider.totals.totalKcal,
          protein: provider.totals.totalProtein,
          carb: provider.totals.totalCarb,
          fat: provider.totals.totalFat,
        ),
        preferences: provider.nutritionPreferences,
        loggedMealTypes: provider.entries
            .map((entry) => entry.mealType)
            .toSet(),
        currentHour: DateTime.now().hour,
        useUsFoods: appPrefs.isUsExperience,
        availableIngredients: provider.entries
            .map((entry) => entry.foodName)
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList(),
      ),
    );
  }

  Map<String, dynamic> _buildNutritionContext(
    DietProvider provider,
    SmartDailyPlan smartPlan,
  ) {
    final context = Map<String, dynamic>.from(provider.getNutritionAiContext());
    context['currentPlan'] = smartPlan.meals
        .map(
          (meal) => {
            'time': meal.time,
            'label': meal.label,
            'mealType': meal.mealType.name.toUpperCase(),
            'food': meal.food,
            'macros': meal.macroText,
          },
        )
        .toList();

    final dietaryRestrictions = {
      ...?((context['dietaryRestrictions'] as List?)?.whereType<String>()),
      ..._dietaryRestrictionsFromPreferences(provider),
    }.toList();

    if (dietaryRestrictions.isNotEmpty) {
      context['dietaryRestrictions'] = dietaryRestrictions;
    }

    return context;
  }

  List<String> _dietaryRestrictionsFromPreferences(DietProvider provider) {
    final prefs = provider.nutritionPreferences;
    final restrictions = <String>[];
    if (prefs.vegan) restrictions.add('vegan');
    if (prefs.vegetarian) restrictions.add('vegetarian');
    if (prefs.glutenFree) restrictions.add('gluten-free');
    if (prefs.lactoseFree) restrictions.add('lactose-free');
    return restrictions;
  }

  Future<void> _applySuggestedPlan() async {
    final plan = _lastResponse?.dailyPlan;
    if (plan == null || plan.isEmpty) return;
    Navigator.of(context).pop(plan);
  }

  void _startTypingAnimation() async {
    final text = _aiResponse ?? '';
    if (text.isEmpty) return;
    setState(() => _isTyping = true);

    for (int i = 0; i <= text.length; i++) {
      if (!mounted || !_isTyping) return;
      await Future.delayed(const Duration(milliseconds: 12));
      if (!mounted) return;
      setState(() => _displayedResponse = text.substring(0, i));
    }
    if (mounted) setState(() => _isTyping = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle ──
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // ── Title ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFBF5AF2), Color(0xFF5E5CE6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI ile Planı Özelleştir',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.goal.emoji} ${widget.goal.label} planını sana özel hale getir',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),

                // ── Scrollable Content ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isLoading &&
                            _displayedResponse.isEmpty &&
                            !(_lastResponse?.hasDailyPlan ?? false))
                          _buildAssistantIntro(),
                        if (!_isLoading &&
                            _displayedResponse.isEmpty &&
                            !(_lastResponse?.hasDailyPlan ?? false))
                          const SizedBox(height: 18),
                        // Quick Chips
                        Text(
                          'Hızlı Öneriler',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _quickChips.map((chip) {
                            return GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => _sendRequest(chip.$2),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      chip.$1,
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // AI Response Area
                        if (_isLoading)
                          _buildLoadingState()
                        else ...[
                          if (_displayedResponse.isNotEmpty)
                            _buildResponseCard(),
                          if (_lastResponse?.hasDailyPlan ?? false) ...[
                            const SizedBox(height: 16),
                            _buildPlanPreviewCard(),
                          ],
                          if (_lastResponse?.hasShoppingList ?? false) ...[
                            const SizedBox(height: 16),
                            _buildShoppingListCard(),
                          ],
                          if (_lastResponse?.hasFollowUpQuestions ?? false) ...[
                            const SizedBox(height: 16),
                            _buildFollowUpCard(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Input Area ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Planı nasıl değiştireyim?',
                              hintStyle: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                _sendRequest(value.trim());
                                _controller.clear();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                final text = _controller.text.trim();
                                if (text.isNotEmpty) {
                                  _sendRequest(text);
                                  _controller.clear();
                                }
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: _isLoading
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFFBF5AF2),
                                      Color(0xFF5E5CE6),
                                    ],
                                  ),
                            color: _isLoading
                                ? Colors.white.withValues(alpha: 0.06)
                                : null,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _isLoading
                                ? Icons.hourglass_top_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
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
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: const [
                      Color(0xFFBF5AF2),
                      Color(0xFF5E5CE6),
                      Color(0xFFBF5AF2),
                    ],
                    stops: [
                      (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                      _shimmerCtrl.value,
                      (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds);
                },
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'AI planını hazırlıyor...',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFBF5AF2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFBF5AF2).withValues(alpha: 0.14),
            const Color(0xFF5E5CE6).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Planı birlikte kişiselleştirelim',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '“Bu planı vegan yap” veya “Evde sadece yumurta ve yulaf var” gibi bir istek yaz. Sana uygulanabilir yeni bir günlük plan hazırlayayım.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFBF5AF2).withValues(alpha: 0.08),
            const Color(0xFF5E5CE6).withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBF5AF2).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFBF5AF2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFBF5AF2),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Önerisi',
                style: GoogleFonts.inter(
                  color: const Color(0xFFBF5AF2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isTyping) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFFBF5AF2).withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _displayedResponse,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPreviewCard() {
    final response = _lastResponse;
    if (response == null || response.dailyPlan.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Yeni Günlük Plan',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF32D74B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${response.dailyPlan.length} öğün',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF32D74B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...response.dailyPlan.map(_buildPlanPreviewTile),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _isLoading ? null : _applySuggestedPlan,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD66B), Color(0xFFFF9F0A)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9F0A).withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_fix_high_rounded,
                    color: Color(0xFF2A1800),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bugünün Planına Uygula',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF2A1800),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPreviewTile(CustomizedDailyPlanMealModel meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E5CE6).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  meal.time.isEmpty
                      ? meal.label
                      : '${meal.time} • ${meal.label}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (meal.kcal > 0)
                Text(
                  '${meal.kcal} kcal',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFD66B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            meal.food,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (meal.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meal.reason,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          if (meal.proteinG > 0 || meal.carbsG > 0 || meal.fatG > 0) ...[
            const SizedBox(height: 8),
            Text(
              'P ${meal.proteinG}g  •  K ${meal.carbsG}g  •  Y ${meal.fatG}g',
              style: GoogleFonts.inter(
                color: const Color(0xFFBF5AF2),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShoppingListCard() {
    final items = _lastResponse?.shoppingList ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eksik Malzemeler',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard() {
    final questions = _lastResponse?.followUpQuestions ?? const [];
    if (questions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Devam Etmek İçin',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: questions
                .map(
                  (question) => GestureDetector(
                    onTap: _isLoading ? null : () => _sendRequest(question),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        question,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
