import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/storage_helper.dart';
import 'local_notification_service.dart';

/// Öğün hatırlatıcı ayarları.
class MealReminderSettings {
  final bool enabled;
  final bool breakfastEnabled;
  final bool lunchEnabled;
  final bool dinnerEnabled;
  final bool snackEnabled;
  final TimeOfDay breakfastTime;
  final TimeOfDay lunchTime;
  final TimeOfDay dinnerTime;
  final TimeOfDay snackTime;

  const MealReminderSettings({
    required this.enabled,
    required this.breakfastEnabled,
    required this.lunchEnabled,
    required this.dinnerEnabled,
    required this.snackEnabled,
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
    required this.snackTime,
  });

  MealReminderSettings copyWith({
    bool? enabled,
    bool? breakfastEnabled,
    bool? lunchEnabled,
    bool? dinnerEnabled,
    bool? snackEnabled,
    TimeOfDay? breakfastTime,
    TimeOfDay? lunchTime,
    TimeOfDay? dinnerTime,
    TimeOfDay? snackTime,
  }) {
    return MealReminderSettings(
      enabled: enabled ?? this.enabled,
      breakfastEnabled: breakfastEnabled ?? this.breakfastEnabled,
      lunchEnabled: lunchEnabled ?? this.lunchEnabled,
      dinnerEnabled: dinnerEnabled ?? this.dinnerEnabled,
      snackEnabled: snackEnabled ?? this.snackEnabled,
      breakfastTime: breakfastTime ?? this.breakfastTime,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      snackTime: snackTime ?? this.snackTime,
    );
  }
}

/// Öğün hatırlatıcı servisi.
class MealReminderService {
  static const String _enabledKey = 'meal_reminder_enabled';

  static const String _breakfastEnabledKey = 'meal_reminder_breakfast_enabled';
  static const String _breakfastHhKey = 'meal_reminder_breakfast_hh';
  static const String _breakfastMmKey = 'meal_reminder_breakfast_mm';

  static const String _lunchEnabledKey = 'meal_reminder_lunch_enabled';
  static const String _lunchHhKey = 'meal_reminder_lunch_hh';
  static const String _lunchMmKey = 'meal_reminder_lunch_mm';

  static const String _dinnerEnabledKey = 'meal_reminder_dinner_enabled';
  static const String _dinnerHhKey = 'meal_reminder_dinner_hh';
  static const String _dinnerMmKey = 'meal_reminder_dinner_mm';

  static const String _snackEnabledKey = 'meal_reminder_snack_enabled';
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

    final breakfastEnabled =
        prefs.getBool(_userKey(_breakfastEnabledKey)) ?? true;
    final breakfastHh = prefs.getInt(_userKey(_breakfastHhKey)) ?? 8;
    final breakfastMm = prefs.getInt(_userKey(_breakfastMmKey)) ?? 0;

    final lunchEnabled = prefs.getBool(_userKey(_lunchEnabledKey)) ?? true;
    final lunchHh = prefs.getInt(_userKey(_lunchHhKey)) ?? 12;
    final lunchMm = prefs.getInt(_userKey(_lunchMmKey)) ?? 30;

    final dinnerEnabled = prefs.getBool(_userKey(_dinnerEnabledKey)) ?? true;
    final dinnerHh = prefs.getInt(_userKey(_dinnerHhKey)) ?? 19;
    final dinnerMm = prefs.getInt(_userKey(_dinnerMmKey)) ?? 0;

    final snackEnabled = prefs.getBool(_userKey(_snackEnabledKey)) ?? true;
    final snackHh = prefs.getInt(_userKey(_snackHhKey)) ?? 16;
    final snackMm = prefs.getInt(_userKey(_snackMmKey)) ?? 0;

    return MealReminderSettings(
      enabled: enabled,
      breakfastEnabled: breakfastEnabled,
      lunchEnabled: lunchEnabled,
      dinnerEnabled: dinnerEnabled,
      snackEnabled: snackEnabled,
      breakfastTime: TimeOfDay(hour: breakfastHh, minute: breakfastMm),
      lunchTime: TimeOfDay(hour: lunchHh, minute: lunchMm),
      dinnerTime: TimeOfDay(hour: dinnerHh, minute: dinnerMm),
      snackTime: TimeOfDay(hour: snackHh, minute: snackMm),
    );
  }

  /// Genel hatırlatıcıyı aç/kapat.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey(_enabledKey), enabled);
    await _syncNotifications();
  }

  /// Belirli bir öğün için aktiflik durumunu kaydet.
  Future<void> setMealEnabled(String meal, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    String key;
    switch (meal) {
      case 'breakfast':
        key = _breakfastEnabledKey;
        break;
      case 'lunch':
        key = _lunchEnabledKey;
        break;
      case 'dinner':
        key = _dinnerEnabledKey;
        break;
      case 'snack':
        key = _snackEnabledKey;
        break;
      default:
        return;
    }
    await prefs.setBool(_userKey(key), enabled);
    await _syncNotifications();
  }

  /// Belirli bir öğün için saati kaydet.
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
        return;
    }
    await prefs.setInt(_userKey(hhKey), time.hour);
    await prefs.setInt(_userKey(mmKey), time.minute);
    await _syncNotifications();
  }

  /// Bildirimleri güncel ayarlara göre yeniden planlar.
  Future<void> _syncNotifications() async {
    final settings = await getSettings();
    if (!settings.enabled || !StorageHelper.getNotifEnabled()) {
      await LocalNotificationService.instance.cancelMealReminders();
      debugPrint('MealReminderService: Tüm öğün hatırlatıcıları kapatıldı');
      return;
    }

    await LocalNotificationService.instance.scheduleMealReminders(
      breakfast: settings.breakfastEnabled ? settings.breakfastTime : null,
      lunch: settings.lunchEnabled ? settings.lunchTime : null,
      dinner: settings.dinnerEnabled ? settings.dinnerTime : null,
      snack: settings.snackEnabled ? settings.snackTime : null,
    );
    debugPrint('MealReminderService: Öğün hatırlatıcıları güncellendi');
  }
}
