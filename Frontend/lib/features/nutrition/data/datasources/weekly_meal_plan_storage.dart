import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/storage_helper.dart';
import '../../domain/entities/planned_meal.dart';

typedef WeeklyMealPlan = Map<int, Map<String, PlannedMeal?>>;

class WeeklyMealPlanStorage {
  String storageKeyForWeek(DateTime weekStart) {
    final normalized = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final suffix = StorageHelper.getUserStorageSuffix();
    final year = normalized.year;
    final weekNum = _isoWeek(normalized);
    return 'weekly_meal_plan_${year}_${weekNum.toString().padLeft(2, '0')}_$suffix';
  }

  Future<WeeklyMealPlan> load(DateTime weekStart) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKeyForWeek(weekStart));
    final loaded = <int, Map<String, PlannedMeal?>>{};
    if (raw == null || raw.isEmpty) return loaded;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final dayEntry in decoded.entries) {
        final dayIndex = int.tryParse(dayEntry.key);
        if (dayIndex == null) continue;
        final slots = dayEntry.value as Map<String, dynamic>?;
        if (slots == null) continue;
        loaded[dayIndex] = {};
        for (final slotEntry in slots.entries) {
          final value = slotEntry.value;
          loaded[dayIndex]![slotEntry.key] = value == null
              ? null
              : PlannedMeal.fromJson(Map<String, dynamic>.from(value as Map));
        }
      }
    } catch (_) {
      return {};
    }
    return loaded;
  }

  Future<void> save(DateTime weekStart, WeeklyMealPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{};
    plan.forEach((dayIndex, slots) {
      encoded[dayIndex.toString()] = slots.map(
        (slotKey, meal) => MapEntry(slotKey, meal?.toJson()),
      );
    });
    await prefs.setString(storageKeyForWeek(weekStart), jsonEncode(encoded));
  }

  int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 1);
    final offset = firstThursday.weekday <= 4
        ? 1 - firstThursday.weekday
        : 8 - firstThursday.weekday;
    final firstWeekStart = firstThursday.add(Duration(days: offset));
    return ((thursday.difference(firstWeekStart).inDays) ~/ 7) + 1;
  }
}
