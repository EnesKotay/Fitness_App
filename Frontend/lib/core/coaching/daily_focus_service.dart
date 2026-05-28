class DailyFocus {
  final String title;
  final String message;
  final String actionLabel;
  final String pillar;
  final int priority;

  const DailyFocus({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.pillar,
    required this.priority,
  });
}

class DailyFocusService {
  DailyFocusService._();

  static DailyFocus build({
    required double remainingKcal,
    required double proteinGap,
    required double waterLiters,
    required int weeklyWorkoutCount,
    required int weeklyWorkoutTarget,
    required double weeklyWeightChangeKg,
    required bool isPremium,
    bool isEn = false,
  }) {
    final options = <DailyFocus>[
      if (waterLiters < 1.3)
        DailyFocus(
          title: isEn
              ? 'First small win today: water'
              : 'Bugünün ilk küçük kazanımı: su',
          message: isEn
              ? 'Fix hydration first so food decisions feel easier.'
              : 'Öğün kararları daha kolay olsun diye hidrasyonu önce toparla.',
          actionLabel: isEn ? 'Log water' : '1 bardak su ekle',
          pillar: 'nutrition',
          priority: 92,
        ),
      if (proteinGap > 25)
        DailyFocus(
          title: isEn ? 'Close the protein gap' : 'Protein açığını kapat',
          message: isEn
              ? '${proteinGap.round()}g protein left. Build the next meal around lean protein.'
              : '${proteinGap.round()}g protein kalmış. Bir sonraki öğünü yalın protein etrafında kur.',
          actionLabel: isEn ? 'Find protein meal' : 'Proteinli öğün bul',
          pillar: 'nutrition',
          priority: 88,
        ),
      if (weeklyWorkoutCount < weeklyWorkoutTarget)
        DailyFocus(
          title: isEn
              ? 'Weekly workout target is close'
              : 'Haftalık antrenman hedefi yakında',
          message: isEn
              ? '$weeklyWorkoutCount/$weeklyWorkoutTarget done. Even a short session strengthens the rhythm.'
              : '$weeklyWorkoutCount/$weeklyWorkoutTarget tamamlandı. Kısa bir seans bile seriyi güçlendirir.',
          actionLabel: isEn ? 'Plan workout' : 'Antrenman planla',
          pillar: 'workout',
          priority: 78,
        ),
      if (weeklyWeightChangeKg.abs() >= 1.5)
        DailyFocus(
          title: isEn
              ? 'Read the weight trend calmly'
              : 'Kilo trendini sakin yorumla',
          message: isEn
              ? 'This week moved fast. Use the weekly average, not one weigh-in.'
              : 'Bu hafta hızlı değişim var. Tek güne değil, haftalık ortalamaya bak.',
          actionLabel: isEn ? 'Check trend' : 'Trend kontrol et',
          pillar: 'tracking',
          priority: 86,
        ),
      if (!isPremium)
        DailyFocus(
          title: isEn ? 'Clarify the plan with AI' : 'Planı AI ile netleştir',
          message: isEn
              ? 'Let AI read today’s gaps and training together so decisions get lighter.'
              : 'Bugünkü açıkları ve antrenmanı birlikte yorumlatmak karar yükünü azaltır.',
          actionLabel: isEn ? 'Try AI Coach' : 'AI Koçu dene',
          pillar: 'premium',
          priority: 54,
        ),
    ];

    if (options.isEmpty) {
      return DailyFocus(
        title: remainingKcal > 250
            ? (isEn ? 'Finish the day balanced' : 'Günü dengeli tamamla')
            : (isEn ? 'Keep the plan' : 'Planı koru'),
        message: remainingKcal > 250
            ? (isEn
                  ? 'You still have room. Protein + vegetables + controlled carbs is a good close.'
                  : 'Kalori alanın var; protein + sebze + kontrollü karbonhidrat iyi kapanış olur.')
            : (isEn
                  ? 'Core targets look good. Separate habit hunger from real hunger before adding food.'
                  : 'Bugün ana hedefleri yakalamışsın. Ekstra yemeği alışkanlık mı açlık mı diye ayır.'),
        actionLabel: remainingKcal > 250
            ? (isEn ? 'Add meal' : 'Öğün ekle')
            : (isEn ? 'Close day' : 'Günü kapat'),
        pillar: 'daily',
        priority: 40,
      );
    }

    options.sort((a, b) => b.priority.compareTo(a.priority));
    return options.first;
  }
}
