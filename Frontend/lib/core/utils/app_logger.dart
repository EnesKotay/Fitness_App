import 'package:flutter/foundation.dart';

/// Merkezi log yardımcısı — Release modda hiçbir log yazdırılmaz.
/// `debugPrint` zaten release'de no-op olsa da, bu sınıf sayesinde
/// gelecekte Sentry/Crashlytics gibi servislere yönlendirme yapılabilir.
class AppLogger {
  AppLogger._();

  /// Genel debug logu
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Hata logu (opsiyonel stackTrace ile)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ $message');
      if (error != null) debugPrint('   Error: $error');
      if (stackTrace != null) debugPrint('   $stackTrace');
    }
    // TODO: Production'da Crashlytics / Sentry'ye gönder
  }

  /// Ağ / API logu
  static void network(String message) {
    if (kDebugMode) {
      debugPrint('🌐 $message');
    }
  }

  /// Uyarı logu
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ $message');
    }
  }
}
