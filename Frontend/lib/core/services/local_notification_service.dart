import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Uygulama genelinde yerel bildirimleri yöneten singleton servis.
class LocalNotificationService {
  static LocalNotificationService? _instance;
  static LocalNotificationService get instance {
    _instance ??= LocalNotificationService._();
    return _instance!;
  }
  LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Bildirim ID aralıkları — çakışmaması için sabit ayrılmış
  static const int _waterBaseId = 100;       // 100-105
  static const int _mealBreakfastId = 200;
  static const int _mealLunchId = 201;
  static const int _mealDinnerId = 202;
  static const int _mealSnackId = 203;

  static const _androidChannel = AndroidNotificationChannel(
    'fitness_reminders',
    'Fitness Hatırlatıcıları',
    description: 'Su içme ve öğün hatırlatmaları',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Android 8+ kanal oluştur
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_androidChannel);

    _initialized = true;
  }

  /// Bildirim izni iste (iOS + Android 13+)
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  // ── Su hatırlatıcıları ─────────────────────────────────────────────────────

  /// [intervalHours] saatte bir su hatırlatması ayarla.
  Future<void> scheduleWaterReminders(int intervalHours) async {
    await cancelWaterReminders();
    await init();

    // Günde 6 farklı saatte bildirim planla (sabah 7'den itibaren)
    const startHour = 7;
    for (int i = 0; i < 6; i++) {
      final hour = startHour + (i * intervalHours);
      if (hour > 22) break; // gece bildirimi yok
      await _scheduleDaily(
        id: _waterBaseId + i,
        title: '💧 Su içme vakti!',
        body: 'Günlük su hedefinize ulaşmak için bir bardak su için.',
        hour: hour,
        minute: 0,
      );
    }
    debugPrint('LocalNotificationService: ${(22 - startHour) ~/ intervalHours + 1} su hatırlatıcısı planlandı');
  }

  Future<void> cancelWaterReminders() async {
    for (int i = 0; i < 6; i++) {
      await _plugin.cancel(_waterBaseId + i);
    }
  }

  // ── Öğün hatırlatıcıları ──────────────────────────────────────────────────

  Future<void> scheduleMealReminders({
    required TimeOfDay breakfast,
    required TimeOfDay lunch,
    required TimeOfDay dinner,
    required TimeOfDay snack,
  }) async {
    await cancelMealReminders();
    await init();

    await _scheduleDaily(
      id: _mealBreakfastId,
      title: '🍳 Kahvaltı vakti!',
      body: 'Güne sağlıklı bir başlangıç için kahvaltını yapma zamanı.',
      hour: breakfast.hour,
      minute: breakfast.minute,
    );
    await _scheduleDaily(
      id: _mealLunchId,
      title: '🥗 Öğle yemeği vakti!',
      body: 'Enerjini korumak için öğle yemeğini atlamayı unutma.',
      hour: lunch.hour,
      minute: lunch.minute,
    );
    await _scheduleDaily(
      id: _mealDinnerId,
      title: '🍽️ Akşam yemeği vakti!',
      body: 'Günün son öğününü sağlıklı tut.',
      hour: dinner.hour,
      minute: dinner.minute,
    );
    await _scheduleDaily(
      id: _mealSnackId,
      title: '🍎 Atıştırmalık vakti!',
      body: 'Kan şekerini dengelemek için hafif bir atıştırma yap.',
      hour: snack.hour,
      minute: snack.minute,
    );
    debugPrint('LocalNotificationService: 4 öğün hatırlatıcısı planlandı');
  }

  Future<void> cancelMealReminders() async {
    for (final id in [
      _mealBreakfastId,
      _mealLunchId,
      _mealDinnerId,
      _mealSnackId,
    ]) {
      await _plugin.cancel(id);
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Yardımcı ──────────────────────────────────────────────────────────────

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // her gün tekrar et
    );
  }
}
