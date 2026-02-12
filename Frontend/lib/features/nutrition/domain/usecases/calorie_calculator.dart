import '../entities/user_profile.dart';

/// BMR (Mifflin–St Jeor), TDEE ve günlük hedef kalori hesaplama.
class CalorieCalculator {
  /// BMR: Erkek 10*kg + 6.25*cm − 5*yaş + 5; Kadın: ... − 161
  static double calculateBmr(UserProfile p) {
    final base = 10 * p.weight + 6.25 * p.height - 5 * p.age;
    return p.gender == Gender.male ? base + 5 : base - 161;
  }

  /// Aktivite katsayısı (TDEE = BMR * katsayı)
  static double activityMultiplier(ActivityLevel level) => level.multiplier;

  /// TDEE = BMR * aktivite katsayısı
  static double calculateTdee(UserProfile p) {
    return calculateBmr(p) * activityMultiplier(p.activityLevel);
  }

  /// Hedef: Koru = TDEE; Kilo ver = TDEE*0.85; Kilo al = TDEE*1.10
  static double calculateDailyTarget(UserProfile p) {
    final tdee = calculateTdee(p);
    switch (p.goal) {
      case Goal.maintainWeight:
        return tdee;
      case Goal.loseWeight:
        return tdee * 0.85;
      case Goal.gainWeight:
        return tdee * 1.10;
    }
  }
}
