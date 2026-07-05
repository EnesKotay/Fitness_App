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

  /// Bildirime tıklanınca kullanılacak global navigator key (main.dart'tan set edilir)
  GlobalKey<NavigatorState>? navigatorKey;

  // Bildirim ID aralıkları — çakışmaması için sabit ayrılmış
  static const int _waterBaseId = 100; // 100-115
  static const int _maxWaterReminders = 16;
  static const int _mealBreakfastId = 200;
  static const int _mealLunchId = 201;
  static const int _mealDinnerId = 202;
  static const int _mealSnackId = 203;
  static const int _workoutReminderId = 300;
  static const int _dailySummaryReminderId = 301;
  static const int _morningRecoveryId = 302;

  static const _androidChannel = AndroidNotificationChannel(
    'fitness_reminders',
    'Fitness Hatırlatıcıları',
    description: 'Su içme, öğün, antrenman ve gün sonu hatırlatmaları',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      debugPrint(
        'LocalNotificationService: Timezone tespit hatası, varsayılan İstanbul yapılıyor: $e',
      );
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 8+ kanal oluştur
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_androidChannel);

    _initialized = true;
  }

  /// Bildirime tıklanınca çağrılır
  void _onNotificationTapped(NotificationResponse response) {
    if (navigatorKey?.currentState == null) return;

    final id = response.id;
    if (id == null) return;

    // Bildirim türüne göre yönlendirme
    if (id >= _waterBaseId && id < _waterBaseId + _maxWaterReminders) {
      // Su hatırlatıcısı → Ana sayfa / Tracking
      navigatorKey!.currentState!.pushNamed('/home');
    } else if (id >= _mealBreakfastId && id <= _mealSnackId) {
      // Öğün hatırlatıcısı → Beslenme tab'ı
      navigatorKey!.currentState!.pushNamed('/home');
      // Not: Tab değiştirme için ek aksiyon gerekebilir
    } else if (id == _workoutReminderId) {
      // Antrenman hatırlatıcısı → Antrenman sayfası
      navigatorKey!.currentState!.pushNamed('/home');
    } else if (id == _dailySummaryReminderId) {
      // Gün sonu özeti → Ana sayfa
      navigatorKey!.currentState!.pushNamed('/home');
    } else if (id == _morningRecoveryId) {
      // Sabah toparlanma → Tracking
      navigatorKey!.currentState!.pushNamed('/home');
    } else if (id >= 40000) {
      // Remote notification (backend'den gelen)
      navigatorKey!.currentState!.pushNamed('/home');
    }
  }

  /// Bildirim izni iste (iOS + Android 13+)
  Future<bool> requestPermission() async {
    await init();

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

  Future<bool> areNotificationsEnabled() async {
    await init();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    // iOS izin durumu bu plugin API'sinde doğrudan okunmadığı için izin isteme
    // akışını kullanıyoruz; daha önce izin verildiyse kullanıcıya tekrar sormaz.
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await requestPermission();
    }

    return true;
  }

  Future<bool> ensurePermission() async {
    if (await areNotificationsEnabled()) return true;
    return requestPermission();
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

    final quotes = [
      {
        'title': '🌟 Bugün harika bir adım attın!',
        'body': 'Yarın daha da güçlü olacaksın, harika ilerliyorsun, durma! 💪',
      },
      {
        'title': '🔥 İstikrar başarının anahtarıdır.',
        'body':
            'Küçük adımlar, büyük sonuçlar doğurur. Günlük özetini kontrol et ve devam et!',
      },
      {
        'title': '⚡ Sınırlarını aşmaya hazır mısın?',
        'body':
            'Kasların yorulur ama hedeflerin asla. Bugünkü durumunu hemen gör!',
      },
      {
        'title': '📈 Harika bir gün daha bitti!',
        'body':
            'Bugünkü çabaların yarınki seni inşa ediyor. Gününü değerlendirmek için tıkla.',
      },
      {
        'title': '🙏 Başarı disiplinle gelir.',
        'body':
            'Bugün gösterdiğin kararlılık için kendine teşekkür et ve özetini incele.',
      },
      {
        'title': '🚀 Güçlenmek zaman alır.',
        'body':
            'Her gün %1 daha iyi olmak, seni zirveye taşıyacak. İlerlemeni hemen kaydet!',
      },
    ];
    final index = DateTime.now().second % quotes.length;
    final randomQuote = quotes[index];

    await _scheduleDaily(
      id: _dailySummaryReminderId,
      title: randomQuote['title']!,
      body: randomQuote['body']!,
      hour: time.hour,
      minute: time.minute,
    );
    debugPrint('LocalNotificationService: Gün sonu motivasyon özeti planlandı');
  }

  Future<void> cancelDailySummaryReminder() async {
    await _plugin.cancel(_dailySummaryReminderId);
  }

  Future<void> scheduleMorningRecoveryReminder({
    TimeOfDay time = const TimeOfDay(hour: 8, minute: 0),
  }) async {
    await init();
    await _plugin.cancel(_morningRecoveryId);

    final quotes = [
      {
        'title': '🌅 Günaydın! Vücudun bugün ne kadar hazır?',
        'body':
            'Uyku ve toparlanma durumunu kontrol et, antrenman planını ona göre yap.',
      },
      {
        'title': '🔋 Enerjini nasıl hissediyorsun?',
        'body':
            'Toparlanma skorunu kontrol et ve güne güçlü bir başlangıç yap!',
      },
      {
        'title': '☀️ Yeni gün, yeni hedefler.',
        'body':
            'Kasların yeterince dinlendi mi? Öğrenmek için uygulamaya göz at.',
      },
    ];
    final index = DateTime.now().day % quotes.length;
    final quote = quotes[index];

    await _scheduleDaily(
      id: _morningRecoveryId,
      title: quote['title']!,
      body: quote['body']!,
      hour: time.hour,
      minute: time.minute,
    );
    debugPrint(
      'LocalNotificationService: Sabah toparlanma hatırlatıcısı planlandı',
    );
  }

  Future<void> cancelMorningRecoveryReminder() async {
    await _plugin.cancel(_morningRecoveryId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// iOS app badge sayısını sıfırla (kırmızı badge'i kaldır)
  Future<void> clearAppBadge() async {
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showRemoteNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    if (!await ensurePermission()) {
      debugPrint(
        'LocalNotificationService: Remote bildirim gösterilemedi, izin yok',
      );
      return;
    }
    await _plugin.show(
      40000 + id,
      title,
      body,
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
    );
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

    try {
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // her gün tekrar et
      );
    } catch (e) {
      debugPrint('LocalNotificationService: zonedSchedule hatası ($id): $e');
    }
  }

  /// Anında test bildirimi gönderir
  Future<bool> sendTestNotificationImmediate() async {
    await init();
    if (!await ensurePermission()) {
      debugPrint('LocalNotificationService: Test bildirimi için izin yok');
      return false;
    }
    try {
      await _plugin.show(
        999,
        '🔔 Bildirim Testi',
        'Harika! PusulaFit bildirimleri cihazınızda başarıyla çalışıyor. 💪',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      debugPrint('LocalNotificationService: Test bildirimi tetiklendi');
      return true;
    } catch (e) {
      debugPrint('LocalNotificationService: Test bildirimi hatası: $e');
      return false;
    }
  }
}
