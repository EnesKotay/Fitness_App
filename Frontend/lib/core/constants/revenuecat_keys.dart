/// RevenueCat public SDK API anahtarları.
///
/// Bu anahtarlar "public" anahtarlardır — client'a gömülmesi güvenlidir
/// (RevenueCat dashboard → Project Settings → API Keys).
///
/// Öncelik: dart-define > buradaki sabit.
///   flutter build ipa --dart-define=REVENUECAT_IOS_API_KEY=appl_XXXX
///
/// iOS anahtarı "appl_", Android anahtarı "goog_" ile başlar.
class RevenueCatKeys {
  RevenueCatKeys._();

  // Gerçek App Store anahtarı (TestFlight/yayın için).
  // Simülatörde IAP testi gerekirse geçici olarak Test Store anahtarına dön:
  // static const String _iosFallback = 'test_ntMvZbiceLEPeJoiYmRhAoyvyvJ';
  static const String _iosFallback = 'appl_SXerbFAEFBLzXOwCzMKoSRrbXFc';
  static const String _androidFallback = 'goog_REPLACE_ME';

  static const String ios = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: _iosFallback,
  );

  static const String android = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: _androidFallback,
  );

  /// RevenueCat dashboard'da tanımlı entitlement identifier.
  static const String premiumEntitlementId = 'premium';
}
