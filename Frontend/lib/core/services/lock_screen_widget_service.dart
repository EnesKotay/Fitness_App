import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../features/nutrition/presentation/state/diet_provider.dart';
import '../utils/storage_helper.dart';

/// iOS Kilit Ekranı / Ana Ekran widget'ına günlük beslenme verilerini yazar.
///
/// Veri, App Group (group.com.eneskotay.fitnessapp) üzerinden
/// PusulaFitWidget extension'ına aktarılır. Widget tarafı Swift'te
/// aynı anahtarları okur (bkz. ios/PusulaFitWidget/PusulaFitWidget.swift).
///
/// Ek özellikler:
/// - Derin bağlantı: widget'a dokununca Beslenme sekmesi açılır
///   (homeWidget://nutrition → [onSwitchTab] callback'i, main.dart'ta bağlanır).
/// - Etkileşimli +Su butonu senkronu: widget'taki AppIntent App Group'a
///   `pending_water_ml` yazar; uygulama açılınca/öne gelince
///   [syncPendingWater] bu miktarı günlüğe işler.
class LockScreenWidgetService {
  LockScreenWidgetService._();

  static const String appGroupId = 'group.com.eneskotay.fitnessapp';
  static const String iosWidgetName = 'PusulaFitWidget';

  static bool _initialized = false;
  static Timer? _debounce;
  static String _lastPayload = '';

  /// Widget tap'inde sekme değiştirmek için main.dart'ta atanır
  /// (ör. MainShell.tabSwitchRequest.value = index).
  static void Function(int tabIndex)? onSwitchTab;

  static StreamSubscription<Uri?>? _clickSub;
  static bool _pendingWaterSyncScheduled = false;
  static DietProvider? _lastDiet;
  static _WidgetLifecycleObserver? _lifecycleObserver;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Uygulama açılışında bir kez çağrılır (main.dart).
  static Future<void> init() async {
    if (_initialized || !_isIos) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('LockScreenWidgetService.init hata: $e');
    }
  }

  /// Widget derin bağlantılarını dinlemeye başlar (main.dart'tan çağrılır).
  static Future<void> registerDeepLinks() async {
    if (!_isIos) return;
    try {
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initial != null) {
        // MainShell henüz kurulmamış olabilir; kısa gecikmeyle işle.
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleWidgetUri(initial);
        });
      }
      _clickSub ??= HomeWidget.widgetClicked.listen(_handleWidgetUri);
    } catch (e) {
      debugPrint('LockScreenWidgetService.registerDeepLinks hata: $e');
    }
  }

  static void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    final target = '${uri.host}${uri.path}'.toLowerCase();
    if (target.contains('nutrition')) {
      onSwitchTab?.call(3); // Beslenme sekmesi
    }
  }

  /// DietProvider her değiştiğinde çağrılır; 2 sn debounce ile
  /// yalnızca veri gerçekten değiştiyse widget'ı günceller.
  static void scheduleUpdate(DietProvider diet) {
    if (!_isIos) return;
    _lastDiet = diet;

    // Uygulama öne geldiğinde widget'tan eklenen suyu senkronize et.
    if (_lifecycleObserver == null) {
      _lifecycleObserver = _WidgetLifecycleObserver();
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }
    // İlk veri geldiğinde bir kez bekleyen suyu işle.
    if (!_pendingWaterSyncScheduled) {
      _pendingWaterSyncScheduled = true;
      unawaited(syncPendingWater(diet));
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(_push(diet));
    });
  }

  /// Widget'ın +Su butonuyla (AppIntent) App Group'a yazdığı bekleyen su
  /// miktarını uygulamanın günlüğüne işler.
  static Future<void> syncPendingWater(DietProvider diet) async {
    if (!_isIos) return;
    if (!_initialized) await init();
    if (!_initialized) return;
    try {
      final pending =
          await HomeWidget.getWidgetData<int>('pending_water_ml',
              defaultValue: 0) ??
              0;
      if (pending <= 0) return;
      final pendingDate =
          await HomeWidget.getWidgetData<String>('pending_water_date',
              defaultValue: '') ??
              '';
      // Tekrar işlenmesin diye hemen sıfırla.
      await HomeWidget.saveWidgetData<int>('pending_water_ml', 0);

      final now = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);
      if (pendingDate != todayKey) return; // Dünden kalan; yok say.

      // Kaynak-of-truth storage'dır; provider'ın yüklenme durumundan bağımsız.
      final savedMl = StorageHelper.getWaterForDate(todayKey);
      final totalMl = (savedMl + pending).clamp(0, 6000).toInt();

      final sel = diet.selectedDate;
      final selIsToday = sel.year == now.year &&
          sel.month == now.month &&
          sel.day == now.day;
      if (selIsToday) {
        diet.setWaterMlForSelectedDate(totalMl);
      } else {
        await StorageHelper.saveWaterForDate(todayKey, totalMl);
      }
      debugPrint('Widget su senkronu: +$pending ml → $totalMl ml');
    } catch (e) {
      debugPrint('LockScreenWidgetService.syncPendingWater hata: $e');
    }
  }

  static Future<void> _push(DietProvider diet) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    // Kullanıcı günlükte geçmiş/gelecek bir tarihe bakıyorsa widget'a yazma;
    // kilit ekranı her zaman BUGÜNÜN verisini göstermeli.
    final now = DateTime.now();
    final sel = diet.selectedDate;
    if (sel.year != now.year || sel.month != now.month || sel.day != now.day) {
      return;
    }

    final remaining = diet.remainingKcal.round();
    final target = diet.effectiveTargetKcal.round();
    final consumedKcal = diet.totals.totalKcal.round();
    final protein = diet.totals.totalProtein.round();
    final proteinTarget = diet.macroTargets.protein.round();
    final waterL = double.parse(diet.waterLiters.toStringAsFixed(2));
    final waterTargetL =
        double.parse((StorageHelper.getWaterGoalML() / 1000.0).toStringAsFixed(2));

    final payload =
        '$remaining|$target|$consumedKcal|$protein|$proteinTarget|$waterL|$waterTargetL';
    if (payload == _lastPayload) return; // Değişiklik yok
    _lastPayload = payload;

    try {
      await HomeWidget.saveWidgetData<int>('remaining_kcal', remaining);
      await HomeWidget.saveWidgetData<int>('target_kcal', target);
      await HomeWidget.saveWidgetData<int>('consumed_kcal', consumedKcal);
      await HomeWidget.saveWidgetData<int>('protein_g', protein);
      await HomeWidget.saveWidgetData<int>('protein_target_g', proteinTarget);
      await HomeWidget.saveWidgetData<double>('water_l', waterL);
      await HomeWidget.saveWidgetData<double>('water_target_l', waterTargetL);
      await HomeWidget.saveWidgetData<String>(
        'updated_at',
        DateTime.now().toIso8601String(),
      );
      await HomeWidget.updateWidget(iOSName: iosWidgetName);
      debugPrint('LockScreenWidget güncellendi: $payload');
    } catch (e) {
      debugPrint('LockScreenWidgetService._push hata: $e');
    }
  }
}

/// Uygulama öne geldiğinde widget'tan eklenen bekleyen suyu senkronize eder.
class _WidgetLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final diet = LockScreenWidgetService._lastDiet;
      if (diet != null) {
        unawaited(LockScreenWidgetService.syncPendingWater(diet));
      }
    }
  }
}
