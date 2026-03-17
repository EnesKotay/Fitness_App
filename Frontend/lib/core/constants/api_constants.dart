import 'dart:io' show Platform;

class ApiConstants {
  /// Backend base URL - Ortama gore otomatik secim
  ///
  /// Oncelik: dart-define > platform varsayilani
  /// - Fiziksel iPhone/Android: --dart-define=API_BASE_URL=http://MAC_IP:8080
  /// - iOS Simulator: 127.0.0.1:8080
  /// - Android Emulator: 10.0.2.2:8080
  /// Production URL — build sırasında dart-define ile geçilir:
  ///   flutter build ipa --dart-define=API_BASE_URL=https://api.fitnessapp.com
  ///   flutter build appbundle --dart-define=API_BASE_URL=https://api.fitnessapp.com
  ///
  /// Geliştirme ortamında dart-define verilmezse platform varsayılanları kullanılır.
  static const String _productionUrl = 'https://api.fitnessapp.com'; // ← kendi domain'in

  static String get baseUrl {
    // 1) Build-time dart-define (production build için)
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl.endsWith('/')
          ? envUrl.substring(0, envUrl.length - 1)
          : envUrl;
    }
    // 2) Release modda production URL'i kullan
    const bool isRelease = bool.fromEnvironment('dart.vm.product');
    if (isRelease) return _productionUrl;

    // 3) Debug/geliştirme ortamı platform varsayılanları
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    if (Platform.isIOS) return 'http://127.0.0.1:8080'; // Simulator
    return 'http://localhost:8080'; // macOS/Windows desktop
  }

  /// Baglanti test endpoint'i (GET /api/auth/test)
  static const String healthTest = '/api/auth/test';

  // API Endpoints
  static const String apiPrefix = '/api';

  // Auth Endpoints
  static const String register = '$apiPrefix/auth/register';
  static const String login = '$apiPrefix/auth/login';
  static const String getMe = '$apiPrefix/auth/me';
  static const String updateMeProfile = '$apiPrefix/auth/me/profile';
  static const String updateMePassword = '$apiPrefix/auth/me/password';
  static const String getUser = '$apiPrefix/auth/user';

  // Tracking Endpoints
  static const String weightRecords = '$apiPrefix/tracking/me/weight-records';
  static String weightRecord(int recordId) =>
      '$apiPrefix/tracking/me/weight-records/$recordId';

  static const String bodyMeasurements = '$apiPrefix/tracking/me/measurements';
  static String bodyMeasurement(int id) =>
      '$apiPrefix/tracking/me/measurements/$id';

  // Workout Endpoints
  static const String workouts = '$apiPrefix/workouts/me';
  static String workout(int workoutId) => '$apiPrefix/workouts/me/$workoutId';
  static String exerciseHistory(String name) =>
      '$apiPrefix/workouts/me/exercise/${Uri.encodeComponent(name)}/history';
  static const String personalRecords = '$apiPrefix/workouts/me/personal-records';
  static const String workoutStats    = '$apiPrefix/workouts/me/stats';


  // Nutrition Endpoints
  static const String meals = '$apiPrefix/nutrition/me/meals';
  static const String mealsByDate = '$apiPrefix/nutrition/me/meals/date';
  static const String dailyCalories = '$apiPrefix/nutrition/me/calories';
  static String meal(int mealId) => '$apiPrefix/nutrition/me/meals/$mealId';

  // AI Endpoints
  static const String aiCoach = '$apiPrefix/ai/coach';
  static const String aiNutrition = '$apiPrefix/ai/nutrition';
  static const String aiScanLabel = '$apiPrefix/ai/nutrition/scan-label';
  static const String aiAnalyzeImage = '$apiPrefix/ai/nutrition/analyze-image';

  // Premium Endpoints
  static const String premiumStatus = '$apiPrefix/user/premium-status';
  static const String upgradePremium = '$apiPrefix/user/upgrade-premium';
  static const String verifyIapPurchase = '$apiPrefix/user/upgrade-premium/iap';
  static const String downgradePremium = '$apiPrefix/user/downgrade-premium';

  // Exercise Endpoints (bolge / egzersiz listesi)
  static const String exerciseGroups = '$apiPrefix/exercises/groups';
  static String exercisesByGroup(String muscleGroup) =>
      '$apiPrefix/exercises?muscleGroup=$muscleGroup';
}
