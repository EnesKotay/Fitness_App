import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  static const int _waterBaseId = 100; // 100-115
  static const int _maxWaterReminders = 16;
  static const int _mealBreakfastId = 200;
  static const int _mealLunchId = 201;
  static const int _mealDinnerId = 202;
  static const int _mealSnackId = 203;
  static const int _workoutReminderId = 300;
  static const int _dailySummaryReminderId = 301;

  static const _androidChannel = AndroidNotificationChannel(
    'fitness_reminders',
    'Fitness Hatırlatıcıları',
    description: 'Su içme, öğün, antrenman ve gün sonu hatırlatmaları',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final String tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Android 8+ kanal oluştur
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_androidChannel);

    _initialized = true;
  }

  /// Bildirim izni iste (iOS + Android 13+)
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
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
          AndroidFlutterLocalNotificationsPlugin
        >();
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

    const startHour = 7;
    const endHour = 22;
    var scheduledCount = 0;
    for (int i = 0; i < _maxWaterReminders; i++) {
      final hour = startHour + (i * intervalHours);
      if (hour > endHour) break; // gece bildirimi yok
      await _scheduleDaily(
        id: _waterBaseId + i,
        title: '💧 Su içme vakti!',
        body: 'Günlük su hedefinize ulaşmak için bir bardak su için.',
        hour: hour,
        minute: 0,
      );
      scheduledCount++;
    }
    debugPrint(
      'LocalNotificationService: $scheduledCount su hatırlatıcısı planlandı',
    );
  }

  Future<void> cancelWaterReminders() async {
    for (int i = 0; i < _maxWaterReminders; i++) {
      await _plugin.cancel(_waterBaseId + i);
    }
  }

  // ── Öğün hatırlatıcıları ──────────────────────────────────────────────────

  Future<void> scheduleMealReminders({
    TimeOfDay? breakfast,
    TimeOfDay? lunch,
    TimeOfDay? dinner,
    TimeOfDay? snack,
  }) async {
    await cancelMealReminders();
    await init();

    if (breakfast != null) {
      await _scheduleDaily(
        id: _mealBreakfastId,
        title: '🍳 Kahvaltı vakti!',
        body: 'Güne sağlıklı bir başlangıç için kahvaltını yapma zamanı.',
        hour: breakfast.hour,
        minute: breakfast.minute,
      );
    }
    if (lunch != null) {
      await _scheduleDaily(
        id: _mealLunchId,
        title: '🥗 Öğle yemeği vakti!',
        body: 'Enerjini korumak için öğle yemeğini atlamayı unutma.',
        hour: lunch.hour,
        minute: lunch.minute,
      );
    }
    if (dinner != null) {
      await _scheduleDaily(
        id: _mealDinnerId,
        title: '🍽️ Akşam yemeği vakti!',
        body: 'Günün son öğününü sağlıklı tut.',
        hour: dinner.hour,
        minute: dinner.minute,
      );
    }
    if (snack != null) {
      await _scheduleDaily(
        id: _mealSnackId,
        title: '🍎 Atıştırmalık vakti!',
        body: 'Kan şekerini dengelemek için hafif bir atıştırma yap.',
        hour: snack.hour,
        minute: snack.minute,
      );
    }
    debugPrint(
      'LocalNotificationService: Aktif öğün hatırlatıcıları planlandı',
    );
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

  // ── Antrenman ve gün sonu hatırlatıcıları ───────────────────────────────

  Future<void> scheduleWorkoutReminder({
    TimeOfDay time = const TimeOfDay(hour: 18, minute: 30),
  }) async {
    await init();
    await _plugin.cancel(_workoutReminderId);
    await _scheduleDaily(
      id: _workoutReminderId,
      title: '🏋️ Antrenman zamanı!',
      body: 'Bugünkü hareket planına kısa bir antrenman ekleyelim.',
      hour: time.hour,
      minute: time.minute,
    );
    debugPrint('LocalNotificationService: Antrenman hatırlatıcısı planlandı');
  }

  Future<void> cancelWorkoutReminder() async {
    await _plugin.cancel(_workoutReminderId);
  }

  Future<void> scheduleDailySummaryReminder({
    TimeOfDay time = const TimeOfDay(hour: 21, minute: 30),
  }) async {
    await init();
    await _plugin.cancel(_dailySummaryReminderId);
    await _scheduleDaily(
      id: _dailySummaryReminderId,
      title: '📊 Gün sonu özeti',
      body: 'Bugünkü kalori, su ve hareket durumunu hızlıca kontrol et.',
      hour: time.hour,
      minute: time.minute,
    );
    debugPrint('LocalNotificationService: Gün sonu özeti planlandı');
  }

  Future<void> cancelDailySummaryReminder() async {
    await _plugin.cancel(_dailySummaryReminderId);
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
