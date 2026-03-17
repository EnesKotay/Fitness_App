import '../../features/nutrition/domain/entities/food_entry.dart';

class DailyDietLog {
  final DateTime date;
  final double totalKcal;
  final double totalProtein;
  final double totalCarb;
  final double totalFat;
  final List<FoodEntry>? entries;

  const DailyDietLog({
    required this.date,
    double? totalKcal,
    required this.totalProtein,
    double? totalCarb,
    required this.totalFat,
    double? totalCalories,
    double? totalCarbs,
    this.entries,
  }) : totalKcal = totalKcal ?? totalCalories ?? 0,
       totalCarb = totalCarb ?? totalCarbs ?? 0;

  double get totalCalories => totalKcal;
  double get totalCarbs => totalCarb;
}
