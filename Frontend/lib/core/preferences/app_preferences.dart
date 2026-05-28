import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../analytics/app_analytics.dart';
import '../utils/storage_helper.dart';

enum AppLanguage { system, en, tr }

enum AppUnitSystem { system, metric, imperial }

enum AppMarketRegion { system, us, tr }

class AppPreferences with ChangeNotifier {
  AppLanguage _language = AppLanguage.system;
  AppUnitSystem _unitSystem = AppUnitSystem.system;
  AppMarketRegion _marketRegion = AppMarketRegion.system;

  AppLanguage get language => _language;
  AppUnitSystem get unitSystem => _unitSystem;
  AppMarketRegion get marketRegion => _marketRegion;

  String get effectiveLanguageCode {
    if (_language == AppLanguage.en) return 'en';
    if (_language == AppLanguage.tr) return 'tr';
    return _deviceLocale.countryCode == 'US' ? 'en' : 'tr';
  }

  Locale get effectiveLocale => Locale(effectiveLanguageCode);

  bool get usesImperial {
    if (_unitSystem == AppUnitSystem.imperial) return true;
    if (_unitSystem == AppUnitSystem.metric) return false;
    return _deviceLocale.countryCode == 'US';
  }

  String get effectiveMarketRegion {
    if (_marketRegion == AppMarketRegion.us) return 'US';
    if (_marketRegion == AppMarketRegion.tr) return 'TR';
    return _deviceLocale.countryCode == 'US' ? 'US' : 'TR';
  }

  bool get isUsExperience =>
      effectiveLanguageCode == 'en' || effectiveMarketRegion == 'US';

  Locale get _deviceLocale => PlatformDispatcher.instance.locale;

  Future<void> init() async {
    _language = _parseLanguage(StorageHelper.getAppLanguageCode());
    _unitSystem = _parseUnitSystem(StorageHelper.getAppUnitSystem());
    _marketRegion = _parseMarketRegion(StorageHelper.getAppMarketRegion());
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    await StorageHelper.saveAppLanguageCode(value.name);
    await AppAnalytics.track(
      'preference_language_changed',
      properties: {'language': value.name},
    );
    notifyListeners();
  }

  Future<void> setUnitSystem(AppUnitSystem value) async {
    if (_unitSystem == value) return;
    _unitSystem = value;
    await StorageHelper.saveAppUnitSystem(value.name);
    await AppAnalytics.track(
      'preference_unit_system_changed',
      properties: {'unitSystem': value.name},
    );
    notifyListeners();
  }

  Future<void> setMarketRegion(AppMarketRegion value) async {
    if (_marketRegion == value) return;
    _marketRegion = value;
    await StorageHelper.saveAppMarketRegion(value.name);
    await AppAnalytics.track(
      'preference_market_region_changed',
      properties: {'marketRegion': value.name},
    );
    notifyListeners();
  }

  static AppLanguage _parseLanguage(String? value) {
    return AppLanguage.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppLanguage.system,
    );
  }

  static AppUnitSystem _parseUnitSystem(String? value) {
    return AppUnitSystem.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppUnitSystem.system,
    );
  }

  static AppMarketRegion _parseMarketRegion(String? value) {
    return AppMarketRegion.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppMarketRegion.system,
    );
  }
}

class AppUnits {
  AppUnits._();

  static const double _kgToLb = 2.2046226218;
  static const double _cmToIn = 0.3937007874;
  static const double _literToFluidOz = 33.8140227;
  static const double _gramToOz = 0.03527396195;

  static double kgToDisplay(double kg, AppPreferences prefs) =>
      prefs.usesImperial ? kg * _kgToLb : kg;

  static double kgFromDisplay(double value, AppPreferences prefs) =>
      prefs.usesImperial ? value / _kgToLb : value;

  static double cmToDisplay(double cm, AppPreferences prefs) =>
      prefs.usesImperial ? cm * _cmToIn : cm;

  static double cmFromDisplay(double value, AppPreferences prefs) =>
      prefs.usesImperial ? value / _cmToIn : value;

  static double litersToDisplay(double liters, AppPreferences prefs) =>
      prefs.usesImperial ? liters * _literToFluidOz : liters;

  static double gramsToDisplay(double grams, AppPreferences prefs) =>
      prefs.usesImperial ? grams * _gramToOz : grams;

  static String get weightUnit => 'kg';

  static String weightUnitFor(AppPreferences prefs) =>
      prefs.usesImperial ? 'lb' : 'kg';

  static String heightUnitFor(AppPreferences prefs) =>
      prefs.usesImperial ? 'in' : 'cm';

  static String waterUnitFor(AppPreferences prefs) =>
      prefs.usesImperial ? 'fl oz' : 'L';

  static String foodWeightUnitFor(AppPreferences prefs) =>
      prefs.usesImperial ? 'oz' : 'g';

  static String formatWeight(double kg, AppPreferences prefs) {
    final value = kgToDisplay(kg, prefs);
    return '${value.toStringAsFixed(1)} ${weightUnitFor(prefs)}';
  }

  static String formatHeight(double cm, AppPreferences prefs) {
    final value = cmToDisplay(cm, prefs);
    return prefs.usesImperial ? '${value.round()} in' : '${value.round()} cm';
  }

  static String formatWater(double liters, AppPreferences prefs) {
    final value = litersToDisplay(liters, prefs);
    return prefs.usesImperial
        ? '${value.round()} fl oz'
        : '${value.toStringAsFixed(1)} L';
  }
}
