import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/storage_helper.dart';
import 'local_notification_service.dart';

/// Öğün hatırlatıcı ayarları.
class MealReminderSettings {
  final bool enabled;
  final TimeOfDay breakfastTime;
  final TimeOfDay lunchTime;
  final TimeOfDay dinnerTime;
  final TimeOfDay snackTime;

  const MealReminderSettings({
    required this.enabled,
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
    required this.snackTime,
  });

  MealReminderSettings copyWith({
    bool? enabled,
    TimeOfDay? breakfastTime,
    TimeOfDay? lunchTime,
    TimeOfDay? dinnerTime,
    TimeOfDay? snackTime,
  }) {
    return MealReminderSettings(
      enabled: enabled ?? this.enabled,
      breakfastTime: breakfastTime ?? this.breakfastTime,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      snackTime: snackTime ?? this.snackTime,
    );
  }
}

/// Öğün hatırlatıcı servisi.
/// Gerçek bildirim göndermez; sadece ayarları SharedPreferences'a kaydeder.
/// flutter_local_notifications ile gerçek bildirimler ileride eklenecek.
class MealReminderService {
  static const String _enabledKey = 'meal_reminder_enabled';
  static const String _breakfastHhKey = 'meal_reminder_breakfast_hh';
  static const String _breakfastMmKey = 'meal_reminder_breakfast_mm';
  static const String _lunchHhKey = 'meal_reminder_lunch_hh';
  static const String _lunchMmKey = 'meal_reminder_lunch_mm';
  static const String _dinnerHhKey = 'meal_reminder_dinner_hh';
  static const String _dinnerMmKey = 'meal_reminder_dinner_mm';
  static const String _snackHhKey = 'meal_reminder_snack_hh';
  static const String _snackMmKey = 'meal_reminder_snack_mm';

  String _userKey(String base) =>
      '${base}_${StorageHelper.getUserStorageSuffix()}';

  static MealReminderService? _instance;
  static MealReminderService get instance {
    _instance ??= MealReminderService._();
    return _instance!;
  }

  MealReminderService._();

  /// Tüm öğün hatırlatıcı ayarlarını döndürür.
  Future<MealReminderSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_userKey(_enabledKey)) ?? false;
    final breakfastHh = prefs.getInt(_userKey(_breakfastHhKey)) ?? 8;
    final breakfastMm = prefs.getInt(_userKey(_breakfastMmKey)) ?? 0;
    final lunchHh = prefs.getInt(_userKey(_lunchHhKey)) ?? 12;
    final lunchMm = prefs.getInt(_userKey(_lunchMmKey)) ?? 30;
    final dinnerHh = prefs.getInt(_userKey(_dinnerHhKey)) ?? 19;
    final dinnerMm = prefs.getInt(_userKey(_dinnerMmKey)) ?? 0;
    final snackHh = prefs.getInt(_userKey(_snackHhKey)) ?? 16;
    final snackMm = prefs.getInt(_userKey(_snackMmKey)) ?? 0;

    return MealReminderSettings(
      enabled: enabled,
      breakfastTime: TimeOfDay(hour: breakfastHh, minute: breakfastMm),
      lunchTime: TimeOfDay(hour: lunchHh, minute: lunchMm),
      dinnerTime: TimeOfDay(hour: dinnerHh, minute: dinnerMm),
      snackTime: TimeOfDay(hour: snackHh, minute: snackMm),
    );
  }

  /// Hatırlatıcıyı aç/kapat.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey(_enabledKey), enabled);
    if (enabled) {
      final settings = await getSettings();
      await LocalNotificationService.instance.scheduleMealReminders(
        breakfast: settings.breakfastTime,
        lunch: settings.lunchTime,
        dinner: settings.dinnerTime,
        snack: settings.snackTime,
      );
      debugPrint('MealReminderService: Öğün hatırlatıcıları açıldı');
    } else {
      await LocalNotificationService.instance.cancelMealReminders();
      debugPrint('MealReminderService: Öğün hatırlatıcıları kapatıldı');
    }
  }

  /// Belirli bir öğün için saati kaydet.
  /// [meal]: 'breakfast', 'lunch', 'dinner', 'snack'
  Future<void> setMealTime(String meal, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    String hhKey;
    String mmKey;
    switch (meal) {
      case 'breakfast':
        hhKey = _breakfastHhKey;
        mmKey = _breakfastMmKey;
        break;
      case 'lunch':
        hhKey = _lunchHhKey;
        mmKey = _lunchMmKey;
        break;
      case 'dinner':
        hhKey = _dinnerHhKey;
        mmKey = _dinnerMmKey;
        break;
      case 'snack':
        hhKey = _snackHhKey;
        mmKey = _snackMmKey;
        break;
      default:
        debugPrint('MealReminderService: Bilinmeyen öğün: $meal');
        return;
    }
    await prefs.setInt(_userKey(hhKey), time.hour);
    await prefs.setInt(_userKey(mmKey), time.minute);
    debugPrint(
      'MealReminderService: $meal saati ${time.hour}:${time.minute.toString().padLeft(2, '0')} olarak ayarlandı',
    );
    // Eğer hatırlatıcı açıksa bildirimleri yeniden planla
    final enabled = prefs.getBool(_userKey(_enabledKey)) ?? false;
    if (enabled) {
      final settings = await getSettings();
      await LocalNotificationService.instance.scheduleMealReminders(
        breakfast: settings.breakfastTime,
        lunch: settings.lunchTime,
        dinner: settings.dinnerTime,
        snack: settings.snackTime,
      );
    }
  }
}
