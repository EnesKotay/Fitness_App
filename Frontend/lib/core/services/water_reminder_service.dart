import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/storage_helper.dart';
import 'local_notification_service.dart';

/// Su hatırlatıcı servisi.
/// Kaydedilen aralığa göre cihaz içi su hatırlatıcılarını planlar.
class WaterReminderService {
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
    return StorageHelper.getNotifWater();
  }

  /// Hatırlatıcıyı aç/kapat.
  Future<void> setEnabled(bool enabled) async {
    await StorageHelper.saveNotifWater(enabled);
    if (enabled && StorageHelper.getNotifEnabled()) {
      final hours = await getIntervalHours();
      await LocalNotificationService.instance.scheduleWaterReminders(hours);
      debugPrint(
        'WaterReminderService: Hatırlatıcı açıldı ($hours saatte bir)',
      );
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
  Future<void> setIntervalHours(int hours, {bool sync = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = hours.clamp(1, 6);
    await prefs.setInt(_userKey(_intervalKey), clamped);
    final enabled = await isEnabled();
    if (sync && enabled && StorageHelper.getNotifEnabled()) {
      await LocalNotificationService.instance.scheduleWaterReminders(clamped);
    }
    debugPrint('WaterReminderService: Aralık ${clamped}s olarak ayarlandı');
  }
}
