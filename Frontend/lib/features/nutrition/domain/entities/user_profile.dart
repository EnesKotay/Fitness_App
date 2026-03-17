import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 2) // Hive için benzersiz ID
enum Gender {
  @HiveField(0)
  male,
  @HiveField(1)
  female,
}

@HiveType(typeId: 3)
enum ActivityLevel {
  @HiveField(0)
  sedentary, // Hareketsiz
  @HiveField(1)
  lightlyActive, // Az Hareketli
  @HiveField(2)
  moderatelyActive, // Orta Hareketli
  @HiveField(3)
  veryActive, // Çok Hareketli
  @HiveField(4)
  extraActive, // Ekstra Hareketli
}

/// CalorieCalculator ve TDEE hesabı için aktivite katsayısı.
extension ActivityLevelMultiplier on ActivityLevel {
  double get multiplier {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.lightlyActive:
        return 1.375;
      case ActivityLevel.moderatelyActive:
        return 1.55;
      case ActivityLevel.veryActive:
        return 1.725;
      case ActivityLevel.extraActive:
        return 1.9;
    }
  }
}

@HiveType(typeId: 4)
enum Goal {
  @HiveField(0)
  bulk, // Kas Gelişimi ve Kilo Alma (Hacim)
  @HiveField(1)
  cut, // Yağ Yakımı ve Kilo Verme (Definasyon)
  @HiveField(2)
  maintain, // Kilo Koruma
  @HiveField(3)
  strength, // Güç Artışı (Kuvvet)
}

@HiveType(typeId: 5) // UserProfile 1 idi, buna 5 verdik çakışmasın diye
class UserProfile {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int age;

  @HiveField(2)
  final double weight; // kg

  @HiveField(3)
  final double height; // cm

  @HiveField(4)
  final Gender gender;

  @HiveField(5)
  final ActivityLevel activityLevel;

  @HiveField(6)
  final Goal goal;

  @HiveField(7)
  final double? customKcalTarget; // Elle girilen hedef (varsa)

  @HiveField(8)
  final double? targetWeight; // Hedef kilo (takip ekranı için, isteğe bağlı)

  UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.activityLevel,
    required this.goal,
    this.customKcalTarget,
    this.targetWeight,
  });

  /// Uyumluluk getter'ları (weightKg / heightCm kullanan yerler için)
  double get weightKg => weight;
  double get heightCm => height;

  // BMR (Bazal Metabolizma Hızı) Hesabı - Mifflin-St Jeor Formülü
  double get bmr {
    // Mifflin-St Jeor Equation
    double base = (10 * weight) + (6.25 * height) - (5 * age);
    if (gender == Gender.male) {
      return base + 5;
    } else {
      return base - 161;
    }
  }

  // TDEE (Günlük Toplam Enerji Harcaması)
  double get tdee {
    double multiplier;
    switch (activityLevel) {
      case ActivityLevel.sedentary:
        multiplier = 1.2;
        break;
      case ActivityLevel.lightlyActive:
        multiplier = 1.375;
        break;
      case ActivityLevel.moderatelyActive:
        multiplier = 1.55;
        break;
      case ActivityLevel.veryActive:
        multiplier = 1.725;
        break;
      case ActivityLevel.extraActive:
        multiplier = 1.9;
        break;
    }
    return bmr * multiplier;
  }

  // Hedefe Göre Günlük Kalori İhtiyacı
  double get targetCalories {
    if (customKcalTarget != null) return customKcalTarget!;

    // TDEE üzerinden hesapla
    double dailyNeed = tdee;

    switch (goal) {
      case Goal.cut:
        return dailyNeed - 500; // Günde 500 kalori açık
      case Goal.bulk:
        return dailyNeed + 300; // Günde 300 kalori fazla
      case Goal.strength:
        return dailyNeed + 100; // Maksimum performans için hafif kalori fazlası
      case Goal.maintain:
        return dailyNeed; // TDEE kadar ye
    }
  }

  // İdeal Kilo Hesabı (Devine Formülü)
  double get idealWeight {
    // Boyu inç cinsine çevir
    double heightInInches = height / 2.54;

    if (heightInInches <= 60) {
      return gender == Gender.male ? 50.0 : 45.5;
    }

    // Devine Formülü
    if (gender == Gender.male) {
      return 50.0 + (2.3 * (heightInInches - 60.0));
    } else {
      return 45.5 + (2.3 * (heightInInches - 60.0));
    }
  }

  // Sağlıklı kilo aralığı (BMI 20-25) ve merkez hedef (BMI 22)
  ({double min, double target, double max}) get healthyWeightRange {
    final heightM = height / 100.0;
    final square = heightM * heightM;
    return (min: 20.0 * square, target: 22.0 * square, max: 25.0 * square);
  }
}
