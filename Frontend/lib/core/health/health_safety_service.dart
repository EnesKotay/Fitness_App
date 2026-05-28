enum NutritionSafetyLevel { info, warning, danger }

class NutritionSafetyWarning {
  final String code;
  final NutritionSafetyLevel level;
  final String title;
  final String message;
  final String action;

  const NutritionSafetyWarning({
    required this.code,
    required this.level,
    required this.title,
    required this.message,
    required this.action,
  });
}

class HealthSafetyService {
  HealthSafetyService._();

  static List<NutritionSafetyWarning> evaluateNutrition({
    required double targetKcal,
    required double consumedKcal,
    required double proteinTarget,
    required double proteinCurrent,
    required double waterLiters,
    double? weeklyWeightChangeKg,
  }) {
    final warnings = <NutritionSafetyWarning>[];
    final remaining = targetKcal - consumedKcal;
    final proteinRatio = proteinTarget <= 0
        ? 1.0
        : proteinCurrent / proteinTarget;

    if (targetKcal > 0 && targetKcal < 1200) {
      warnings.add(
        const NutritionSafetyWarning(
          code: 'very_low_calorie_target',
          level: NutritionSafetyLevel.danger,
          title: 'Kalori hedefi çok düşük görünüyor',
          message:
              'Bu hedef uzun süre sürdürülebilir olmayabilir ve performansı düşürebilir.',
          action: 'Profili ve hedef hızını tekrar kontrol et.',
        ),
      );
    } else if (targetKcal > 0 && targetKcal < 1500) {
      warnings.add(
        const NutritionSafetyWarning(
          code: 'low_calorie_target',
          level: NutritionSafetyLevel.warning,
          title: 'Düşük kalori bölgesindesin',
          message:
              'Protein, lif ve suyu korumadan kalori kısmak kas kaybı ve açlığı artırabilir.',
          action: 'Bugünkü öğünlerde protein ve sebzeyi önceliklendir.',
        ),
      );
    }

    if (remaining < -350) {
      warnings.add(
        NutritionSafetyWarning(
          code: 'large_surplus_today',
          level: NutritionSafetyLevel.warning,
          title: 'Bugün hedefin üstüne çıktın',
          message:
              '${remaining.abs().round()} kcal fazlan var. Bunu telafi için aşırı kısma yapma.',
          action: 'Yarın normal plana dön; akşamı hafif ve proteinli kapat.',
        ),
      );
    }

    if (proteinRatio < 0.55 && consumedKcal > targetKcal * 0.45) {
      warnings.add(
        const NutritionSafetyWarning(
          code: 'protein_lagging',
          level: NutritionSafetyLevel.info,
          title: 'Protein geride kalıyor',
          message:
              'Kalorinin önemli kısmı dolmuş ama protein hedefi geride. Sonraki öğün daha yalın protein olmalı.',
          action: 'Tavuk, balık, yoğurt, lor, yumurta veya whey ekle.',
        ),
      );
    }

    if (waterLiters > 0 && waterLiters < 1.2) {
      warnings.add(
        const NutritionSafetyWarning(
          code: 'low_water',
          level: NutritionSafetyLevel.info,
          title: 'Su ritmi düşük',
          message:
              'Az su iştahı ve antrenman performansını gereksiz zorlaştırabilir.',
          action:
              'Şimdi 1 bardak su ekle; günü 2-3 küçük hatırlatmayla tamamla.',
        ),
      );
    }

    final weekly = weeklyWeightChangeKg;
    if (weekly != null && weekly.abs() >= 1.5) {
      warnings.add(
        NutritionSafetyWarning(
          code: 'fast_weight_change',
          level: NutritionSafetyLevel.warning,
          title: 'Haftalık kilo değişimi hızlı',
          message:
              'Son 7 günde ${weekly > 0 ? '+' : ''}${weekly.toStringAsFixed(1)} kg değişim var.',
          action:
              'Kalori hedefini ve sodyum/su dalgalanmalarını birlikte değerlendir.',
        ),
      );
    }

    return warnings.take(3).toList(growable: false);
  }
}
