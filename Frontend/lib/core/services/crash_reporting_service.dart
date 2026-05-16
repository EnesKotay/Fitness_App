import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_secrets.dart';
import '../utils/storage_helper.dart';

class CrashReportingService {
  CrashReportingService._();

  static bool get isEnabledByPreference =>
      StorageHelper.getPrivacyCrashReports();

  static bool get canInitialize =>
      AppSecrets.sentryDsn.isNotEmpty && isEnabledByPreference;

  static Future<void> disableForCurrentSession() async {
    try {
      await Sentry.close();
    } catch (_) {
      // Sentry may be uninitialized in some sessions; ignore safely.
    }
  }
}
