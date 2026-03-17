import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/storage_helper.dart';
import 'local_notification_service.dart';

/// Su hatırlatıcı servisi.
/// flutter_local_notifications paketi gerektirmeden basit bir zamanlayıcı mantığı kurar.
/// Bildirim gönderme, uygulamanın arka plan yeteneklerine bağlıdır.
/// Şu an için sadece ayar saklama / okuma yapar. Gerçek bildirimler ileride eklenecek.
class WaterReminderService {
  static const String _enabledKey = 'water_reminder_enabled';
  static const String _intervalKey = 'water_reminder_interval_hours';

  String _userKey(String base) =>
      '${base}_${StorageHelper.getUserStorageSuffix()}';
  
  static WaterReminderService? _instance;
  static WaterReminderService get instance {
    _instance ??= WaterReminderService._();
    return _instance!;
  }
  
  WaterReminderService._();
  
  /// Hatırlatıcı açık mı?
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userKey(_enabledKey)) ?? false;
  }
  
  /// Hatırlatıcıyı aç/kapat.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey(_enabledKey), enabled);
    if (enabled) {
      final hours = await getIntervalHours();
      await LocalNotificationService.instance.scheduleWaterReminders(hours);
      debugPrint('WaterReminderService: Hatırlatıcı açıldı ($hours saatte bir)');
    } else {
      await LocalNotificationService.instance.cancelWaterReminders();
      debugPrint('WaterReminderService: Hatırlatıcı kapatıldı');
    }
  }
  
  /// Hatırlatma aralığı (saat).
  Future<int> getIntervalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userKey(_intervalKey)) ?? 2;
  }
  
  /// Hatırlatma aralığını değiştir.
  Future<void> setIntervalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = hours.clamp(1, 6);
    await prefs.setInt(_userKey(_intervalKey), clamped);
    final enabled = await isEnabled();
    if (enabled) {
      await LocalNotificationService.instance.scheduleWaterReminders(clamped);
    }
    debugPrint('WaterReminderService: Aralık ${clamped}s olarak ayarlandı');
  }
}
