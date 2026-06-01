import '../../../core/models/workout.dart';

/// Bir egzersiz için son seyirden ağırlık/tekrar ilerleme önerisini hesaplar.
class ProgressionEngine {
  /// [history]: Son N antrenmanı (en yeniden eskiye)
  /// [targetReps]: Planlanan tekrar sayısı
  /// [userWeight]: Kullanıcının vücut ağırlığı (baseline için)
  static ProgressionHint compute({
    required List<Workout> history,
    required String exerciseName,
    int targetReps = 10,
    double userWeight = 70,
  }) {
    // Sadece bu egzersizin kayıtları
    final relevant = history
        .where((w) => w.name.toLowerCase() == exerciseName.toLowerCase())
        .toList()
      ..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));

    if (relevant.isEmpty) {
      return ProgressionHint(
        suggestedWeight: 0,
        suggestedReps: targetReps,
        trendDirection: TrendDirection.neutral,
        reason: 'Daha önce kayıt yok. Hafif başla, formu otur.',
        readilyProgressed: false,
        lastWeight: null,
        lastReps: null,
      );
    }

    final last = relevant.last;
    final lastWeight = _extractWeight(last);
    final lastReps = last.reps;
    final avgRpe = _extractAvgRpe(last);

    // Son 3 antrenmanın ağırlıklarını al
    final recentWeights = relevant
        .reversed
        .take(3)
        .toList()
        .reversed
        .map(_extractWeight)
        .where((w) => w != null && w > 0)
        .cast<double>()
        .toList();

    if (recentWeights.isEmpty) {
      return ProgressionHint(
        suggestedWeight: lastWeight ?? 0,
        suggestedReps: targetReps,
        trendDirection: TrendDirection.neutral,
        reason: 'Ağırlık kaydı bulunamadı. Önceki düzeyde devam et.',
        readilyProgressed: false,
        lastWeight: lastWeight,
        lastReps: lastReps,
      );
    }

    // Trend: Son 2 antrenman arasında artış var mı?
    TrendDirection trend = TrendDirection.neutral;
    if (recentWeights.length >= 2) {
      final diff = recentWeights[recentWeights.length - 1] -
          recentWeights[recentWeights.length - 2];
      if (diff > 0) trend = TrendDirection.up;
      if (diff < 0) trend = TrendDirection.down;
    }

    final avgWeight = recentWeights.reduce((a, b) => a + b) / recentWeights.length;

    double suggested = avgWeight;
    String reason;
    bool progressed = false;

    // RPE tabanlı Auto-Regulation
    if (avgRpe >= 9.0) {
      // Çok zorlanılmış (RPE 9-10)
      if (lastReps != null && lastReps < targetReps) {
        suggested = _round(avgWeight - 2.5);
        reason = 'Son antrenman çok zorlamış (RPE $avgRpe). Ağırlığı düşürüp formu koruyoruz.';
      } else {
        suggested = _round(avgWeight);
        reason = 'Son idman sınırdaydı (RPE $avgRpe). Aynı ağırlıkla gücünü pekiştir.';
      }
    } else if (avgRpe > 0 && avgRpe <= 7.0) {
      // Kolay geçmiş (RPE <= 7)
      suggested = _round(avgWeight + 2.5);
      reason = 'Son antrenman rahat geçmiş (RPE $avgRpe). Ağırlık artırıyoruz! 🚀';
      progressed = true;
    } else {
      // Normal kurallar (RPE girilmemiş veya RPE 7-9 arası)
      if (trend == TrendDirection.down) {
        suggested = _round(avgWeight - 2.5);
        reason = 'Son antrenmanda düşüş var. Formu oturt, sonra ilerle.';
      } else if (lastReps != null && lastReps >= targetReps && trend != TrendDirection.down) {
        suggested = _round(avgWeight + 2.5);
        reason = 'Son sette $lastReps tekrar tamamladın. +2.5 kg dene! 💪';
        progressed = true;
      } else if (lastReps != null && lastReps < targetReps - 2) {
        suggested = _round(avgWeight);
        reason = 'Tekrar sayını önce ${targetReps}e çıkar, sonra ağırlık artır.';
      } else {
        suggested = _round(avgWeight);
        reason = 'Aynı ağırlıkta devam et, formu mükemmelleştir.';
      }
    }

    return ProgressionHint(
      suggestedWeight: suggested.clamp(0, 500),
      suggestedReps: targetReps,
      trendDirection: trend,
      reason: reason,
      readilyProgressed: progressed,
      lastWeight: lastWeight,
      lastReps: lastReps,
    );
  }

  static double _extractAvgRpe(Workout w) {
    if (w.setDetails != null && w.setDetails!.isNotEmpty) {
      final rpes = w.setDetails!
          .map((s) => s.rpe)
          .whereType<double>()
          .where((v) => v > 0)
          .toList();
      if (rpes.isNotEmpty) {
        return rpes.reduce((a, b) => a + b) / rpes.length;
      }
    }
    return 0.0;
  }

  static double? _extractWeight(Workout w) {
    if (w.setDetails != null && w.setDetails!.isNotEmpty) {
      final weights = w.setDetails!
          .map((s) => s.weight)
          .whereType<double>()
          .where((v) => v > 0)
          .toList();
      if (weights.isNotEmpty) {
        return weights.reduce((a, b) => a > b ? a : b);
      }
    }
    return w.weight;
  }

  static double _round(double v) {
    return (v / 2.5).round() * 2.5;
  }

  /// Epley Formülü ile 1RM (Tek Tekrar Maksimum) hesaplar.
  /// 1RM = Weight * (1 + (Reps / 30))
  static double calculate1RM(double weight, int reps) {
    if (reps <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + (reps / 30.0));
  }

  /// 1RM değerine göre 3 aşamalı (Hafif, Orta, Ağır) ısınma setleri üretir.
  static List<Map<String, dynamic>> generateWarmupSets(double oneRepMax) {
    if (oneRepMax <= 0) return [];
    
    // Set 1: %50 1RM x 10 tekrar
    // Set 2: %70 1RM x 5 tekrar
    // Set 3: %80 1RM x 3 tekrar
    return [
      {
        'weight': _round(oneRepMax * 0.5),
        'reps': 10,
        'setType': 'WARMUP',
      },
      {
        'weight': _round(oneRepMax * 0.7),
        'reps': 5,
        'setType': 'WARMUP',
      },
      {
        'weight': _round(oneRepMax * 0.8),
        'reps': 3,
        'setType': 'WARMUP',
      },
    ];
  }
}

class ProgressionHint {
  final double suggestedWeight;
  final int suggestedReps;
  final TrendDirection trendDirection;
  final String reason;
  final bool readilyProgressed; // +2.5 kg önerisinde true
  final double? lastWeight;
  final int? lastReps;

  const ProgressionHint({
    required this.suggestedWeight,
    required this.suggestedReps,
    required this.trendDirection,
    required this.reason,
    required this.readilyProgressed,
    required this.lastWeight,
    required this.lastReps,
  });

  String get trendEmoji {
    return switch (trendDirection) {
      TrendDirection.up => '📈',
      TrendDirection.down => '📉',
      TrendDirection.neutral => '➡️',
    };
  }

  String get weightLabel {
    if (suggestedWeight == 0) return 'Vücut ağırlığı';
    final d = suggestedWeight % 1 == 0
        ? suggestedWeight.toStringAsFixed(0)
        : suggestedWeight.toStringAsFixed(1);
    return '$d kg';
  }
}

enum TrendDirection { up, down, neutral }
