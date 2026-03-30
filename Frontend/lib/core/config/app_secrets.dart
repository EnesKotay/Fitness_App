/// Uygulama gizli yapılandırması.
///
/// Production build komutu:
///   flutter build ipa \
///     --dart-define=SENTRY_DSN=https://xxxx@oXXX.ingest.sentry.io/YYYY \
///     --dart-define=API_BASE_URL=https://api.fitnessapp.com
///
/// DSN'i almak için: https://sentry.io → Your Project → Settings → Client Keys
///
/// Bu dosya kaynak kontrolüne dahil edilmelidir (gerçek DSN içermez).
/// Gerçek DSN --dart-define ile build sırasında enjekte edilir.
class AppSecrets {
  AppSecrets._();

  /// Sentry DSN — build sırasında --dart-define=SENTRY_DSN=... ile set edilir.
  /// Boş bırakılırsa Sentry devre dışı kalır (geliştirme ortamı için OK).
  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Backend base URL — build sırasında --dart-define=API_BASE_URL=... ile set edilir.
  /// Boş bırakılırsa ApiConstants.baseUrl kendi mantığını kullanır.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
}
