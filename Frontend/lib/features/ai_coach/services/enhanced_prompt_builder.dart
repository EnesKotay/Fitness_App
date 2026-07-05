import '../models/ai_coach_models.dart';

/// Enhanced prompt builder with rich context and examples
class EnhancedPromptBuilder {
  static String buildPrompt({
    required String userQuestion,
    required DailySummary summary,
    required CoachPersonality personality,
    required CoachTaskMode taskMode,
    required List<CoachConversationTurn> history,
    String? userMemory,
  }) {
    final buffer = StringBuffer();

    // 1. Role & Personality (detaylı)
    buffer.writeln('# ROLÜN VE KİŞİLİĞİN');
    buffer.writeln(_getDetailedPersonality(personality));
    buffer.writeln();

    // 2. Current Context (detaylı metrics)
    buffer.writeln('# KULLANICININ BUGÜNKÜ VERİLERİ');
    buffer.writeln(_formatDailySummary(summary));
    buffer.writeln();

    // 3. User Memory (long-term facts)
    if (userMemory != null && userMemory.isNotEmpty) {
      buffer.writeln('# KULLANICI HAKKINDA BİLİNEN');
      buffer.writeln(userMemory);
      buffer.writeln();
    }

    // 4. Recent Conversation (context)
    if (history.isNotEmpty) {
      buffer.writeln('# SON KONUŞMA (${history.length} mesaj)');
      for (final turn in history.takeLast(6)) {
        // Son 6 mesaj yeterli, daha fazlası token israfı
        final speaker = turn.role == 'user' ? 'Kullanıcı' : 'Sen';
        final content = turn.content.length > 150
            ? '${turn.content.substring(0, 150)}...'
            : turn.content;
        buffer.writeln('$speaker: $content');
      }
      buffer.writeln();
    }

    // 5. Task-specific guidance
    buffer.writeln('# GÖREV: ${taskMode.label}');
    buffer.writeln(_getTaskGuidance(taskMode, summary));
    buffer.writeln();

    // 6. Output format (structured JSON)
    buffer.writeln('# YANIT FORMATI');
    buffer.writeln(_getOutputFormat(taskMode));
    buffer.writeln();

    // 7. Quality constraints
    buffer.writeln('# YANIT KURALLARI');
    buffer.writeln(_getQualityConstraints());
    buffer.writeln();

    // 8. User's actual question
    buffer.writeln('# KULLANICININ SORUSU');
    buffer.writeln(userQuestion.trim());

    return buffer.toString();
  }

  static String _getDetailedPersonality(CoachPersonality personality) {
    switch (personality) {
      case CoachPersonality.motivator:
        return '''
Sen **David Goggins** tarzında sert, disiplinli bir fitness antrenörüsün.
- Bahaneleri ASLA kabul etme
- Kısa, net ve emir tarzında konuş
- "Yapabilir misin?" değil, "NE ZAMAN yapacaksın?" de
- Zayıf noktalara odaklan, rahatlatma
- Örnek: "Kalori hedefini tutturamadın. Bugün 3 öğün tam kaydet, yoksa yarın 2 kat zor olacak."
''';

      case CoachPersonality.scientist:
        return '''
Sen **Peter Attia** tarzında bilimsel verilere dayanan bir mentorsun.
- Her tavsiyeni araştırmalarla destekle
- Sayısal metrikler ver (örn: "Protein 1.8g/kg hedefine %85'tesindesin")
- Mekanizmaları açıkla (örn: "Yüksek protein termal etkisi sayesinde metabolik avantaj sağlar")
- Teknik terimleri kullan ama açıkla
- Örnek: "Günlük protein alımın 120g, bu vücut ağırlığına göre 1.5g/kg. Kas sentezi için 1.8-2g/kg ideal."
''';

      case CoachPersonality.supportive:
        return '''
Sen **nazik ve destekleyici bir arkadaşsın**, kullanıcıyı cesaretlendiriyorsun.
- Olumlu dille konuş, küçük başarıları kutla
- "Henüz başaramadın" yerine "İlerlemişsin, bir adım daha" de
- Emoji kullanabilirsin (💪🔥✨ gibi)
- Empati göster
- Örnek: "Bu hafta 3 gün antrenman yapmışsın, harika! 💪 Hedefine bir adım daha yaklaştın."
''';
    }
  }

  static String _formatDailySummary(DailySummary summary) {
    final buffer = StringBuffer();

    // Kalori dengesi
    if (summary.targetCalories != null) {
      final diff = summary.targetCalories! - summary.calories;
      final percentage = ((summary.calories / summary.targetCalories!) * 100)
          .toStringAsFixed(0);
      buffer.writeln(
        '📊 Kalori: ${summary.calories}/${summary.targetCalories} kcal ($percentage%)',
      );
      if (diff > 0) {
        buffer.writeln('   → Hedefe $diff kcal kaldı');
      } else if (diff < 0) {
        buffer.writeln('   → Hedefin ${diff.abs()} kcal üzerinde');
      }
    } else {
      buffer.writeln('📊 Kalori: ${summary.calories} kcal (hedef belirsiz)');
    }

    // Makrolar
    buffer.writeln('🍗 Protein: ${summary.proteinGrams ?? 0}g');
    buffer.writeln('🍚 Karbonhidrat: ${summary.carbsGrams ?? 0}g');
    buffer.writeln('🥑 Yağ: ${summary.fatGrams ?? 0}g');

    // Antrenman
    if (summary.workouts > 0) {
      buffer.writeln(
        '💪 Antrenman: ${summary.workoutMinutes} dakika (${summary.workouts} seans)',
      );
      if (summary.workoutHighlights.isNotEmpty) {
        buffer.writeln('   → ${summary.workoutHighlights.join(", ")}');
      }
    } else {
      buffer.writeln('💪 Antrenman: Henüz yok');
    }

    // Su
    final waterStatus = summary.waterLiters >= 2.5
        ? '✅ İyi'
        : summary.waterLiters >= 1.5
        ? '⚠️ Orta'
        : '❌ Düşük';
    buffer.writeln(
      '💧 Su: ${summary.waterLiters.toStringAsFixed(1)}L $waterStatus',
    );

    // Kilo
    if (summary.currentWeightKg != null && summary.targetWeightKg != null) {
      final diff = (summary.targetWeightKg! - summary.currentWeightKg!).abs();
      buffer.writeln(
        '⚖️ Kilo: ${summary.currentWeightKg}kg → ${summary.targetWeightKg}kg (${diff.toStringAsFixed(1)}kg fark)',
      );
    }

    return buffer.toString();
  }

  static String _getTaskGuidance(CoachTaskMode mode, DailySummary summary) {
    switch (mode) {
      case CoachTaskMode.nutrition:
        return '''
BESLENME MODUNDA SEN:
- Makro dengesini analiz et (protein/karb/yağ oranları)
- Eksik kalan besin gruplarını belirt
- Somut öğün önerileri ver (örn: "200g tavuk göğsü + 150g pirinç + salata")
- Timing önemli: sabah/öğle/akşam önerileri farklı olmalı
${summary.calories < (summary.targetCalories ?? 2000) * 0.7 ? '⚠️ ÖNEMLİ: Kalori çok düşük, yetersiz beslenme riski!' : ''}
''';

      case CoachTaskMode.workout:
        return '''
ANTRENMAN MODUNDA SEN:
- Hangi kas grubunu çalışacağını sor (varsa son antrenmanına bak)
- Hacim/set/tekrar öner (örn: "Göğüs için 3x10 bench press")
- Isınma/soğuma dahil et
- Form uyarıları ver
${summary.workouts == 0 ? '⚠️ ÖNEMLİ: Bugün henüz antrenman yok, öncelik bu!' : ''}
''';

      case CoachTaskMode.recovery:
        return '''
TOPARLANMA MODUNDA SEN:
- Uyku, su, beslenme üçgenini kontrol et
- Aktif dinlenme öner (yürüyüş, stretching)
- Yorgunluk belirtilerine duyarlı ol
${summary.waterLiters < 1.5 ? '⚠️ ÖNEMLİ: Su tüketimi düşük, toparlanmayı yavaşlatır!' : ''}
''';

      case CoachTaskMode.analysis:
        return '''
ANALİZ MODUNDA SEN:
- Trendleri gör (iyiye/kötüye gidiyor mu?)
- Sayısal metrikler ver (örn: "Son 7 günde ortalama 1900 kcal")
- Güçlü/zayıf yönleri listele
- Bir sonraki adımı öner
''';

      case CoachTaskMode.plan:
        return '''
PLAN MODUNDA SEN:
- Bugün için net bir program oluştur (saat bazlı)
- Öncelik sırası belirle (en önemli görev en üstte)
- Gerçekçi ol, aşırı yükleme yapma
- Kontrol noktaları ekle (örn: "Akşam tekrar gel, günü değerlendirelim")
''';
    }
  }

  static String _getOutputFormat(CoachTaskMode mode) {
    return '''
Şu JSON formatında yanıt ver (MUTLAKA geçerli JSON):
{
  "todayFocus": "Ana tavsiye (2-3 cümle, NET ve EYLEME DÖNÜK, genel laflar yok)",
  "actionItems": [
    "Somut adım 1 (sayısal hedef içermeli, örn: '30 dk yürüyüş')",
    "Somut adım 2 (ölçülebilir olmalı)",
    "Somut adım 3 (zaman sınırlı)"
  ],
  "nutritionNote": "${mode == CoachTaskMode.nutrition ? 'Beslenme özeti/önerisi (varsa)' : 'Boş bırak'}",
  "suggestedPrompts": [
    "İlgili takip sorusu 1",
    "İlgili takip sorusu 2",
    "İlgili takip sorusu 3"
  ],
  "dataInsights": {
    "caloricBalance": "Örn: '+200 (hafif fazla)' veya '-300 (açıkta)'",
    "proteinStatus": "Örn: 'İdeal aralıkta' veya '20g eksik'",
    "trend": "Örn: 'Son 3 günde tutarlı' veya 'Düşüş trendinde'"
  }
}

ÖNEMLİ: Sadece JSON yanıtla, başka hiçbir şey yazma!
''';
  }

  static String _getQualityConstraints() {
    return '''
YANIT KALİTE KURALLARI:
✅ YAPILMASI GEREKENLER:
- todayFocus en az 30, en fazla 150 karakter olsun
- actionItems'da en az 2, en fazla 4 madde olsun
- Her actionItem sayısal veya ölçülebilir olsun (örn: "daha fazla su iç" ❌, "500ml su iç" ✅)
- Kullanıcının verilerine özel konuş (genel tavsiyeler değil)
- Türkçe olsun, imla kurallarına uy

❌ YAPILMAMASI GEREKENLER:
- Genel laflar (örn: "Sağlıklı beslenmek önemlidir" ❌)
- Belirsiz tavsiyeler (örn: "Biraz daha çalış" ❌)
- Çok uzun paragraflar (200+ karakter ❌)
- JSON dışında metin (açıklama, yorum vb. ❌)
- Tekrar (aynı şeyi farklı şekilde söyleme ❌)
''';
  }
}

extension _ListExtension<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
