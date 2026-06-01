import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_secrets.dart';
import '../utils/storage_helper.dart';
import '../utils/app_logger.dart';

class CrashReportingService {
  CrashReportingService._();

  static bool get isEnabledByPreference =>
      StorageHelper.getPrivacyCrashReports();

  static bool get canInitialize =>
      AppSecrets.sentryDsn.isNotEmpty && isEnabledByPreference;

  static void captureFlutterError(
    FlutterErrorDetails details, {
    String source = 'flutter_error',
  }) {
    captureException(details.exception, details.stack, source: source);
  }

  static void captureException(
    Object error,
    StackTrace? stackTrace, {
    String source = 'unhandled_error',
  }) {
    AppLogger.e('CrashReportingService[$source]', error, stackTrace);

    if (!canInitialize) return;
    try {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    } catch (e, s) {
      AppLogger.e('CrashReportingService capture failed', e, s);
    }
  }

  static Future<void> disableForCurrentSession() async {
    try {
      await Sentry.close();
    } catch (_) {
      // Sentry may be uninitialized in some sessions; ignore safely.
    }
  }
}
