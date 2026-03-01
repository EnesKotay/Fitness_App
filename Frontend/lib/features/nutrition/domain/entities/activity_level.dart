/// Aktivite seviyesi (TDEE katsayısı için).
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  very,
  extra,
}

extension ActivityLevelX on ActivityLevel {
  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedanter (hareketsiz)';
      case ActivityLevel.light:
        return 'Hafif aktif';
      case ActivityLevel.moderate:
        return 'Orta aktif';
      case ActivityLevel.very:
        return 'Çok aktif';
      case ActivityLevel.extra:
        return 'Aşırı aktif';
    }
  }

  double get multiplier {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.very:
        return 1.725;
      case ActivityLevel.extra:
        return 1.9;
    }
  }
}
