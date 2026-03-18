import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Merkezi log yardımcısı.
/// - Debug modda konsola yazar.
/// - Production'da hatalar Sentry'ye gönderilir (DSN ayarlıysa).
class AppLogger {
  AppLogger._();

  /// Genel debug logu — yalnızca debug modda yazdırılır.
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Hata logu — debug'da konsola, production'da Sentry'ye gider.
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ $message');
      if (error != null) debugPrint('   Error: $error');
      if (stackTrace != null) debugPrint('   $stackTrace');
    } else {
      Sentry.captureException(
        error ?? Exception(message),
        stackTrace: stackTrace,
        hint: Hint.withMap({'message': message}),
      );
    }
  }

  /// Ağ / API logu — yalnızca debug modda.
  static void network(String message) {
    if (kDebugMode) {
      debugPrint('🌐 $message');
    }
  }

  /// Uyarı logu — debug'da konsola, production'da Sentry breadcrumb olarak.
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ $message');
    } else {
      Sentry.addBreadcrumb(
        Breadcrumb(message: message, level: SentryLevel.warning),
      );
    }
  }
}
