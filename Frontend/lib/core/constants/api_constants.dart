class ApiConstants {
  /// Backend base URL - Ortama gore otomatik secim
  ///
  /// Oncelik: dart-define > Supabase varsayilani
  /// Local backend denemek istersen:
  ///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8081
  /// Production URL — build sırasında dart-define ile de geçilebilir:
  ///   flutter build ipa --dart-define=API_BASE_URL=https://ibbwfkjrmxdksnalivum.supabase.co/functions/v1
  ///   flutter build appbundle --dart-define=API_BASE_URL=https://ibbwfkjrmxdksnalivum.supabase.co/functions/v1
  ///
  /// Geliştirme ortamında dart-define verilmezse platform varsayılanları kullanılır.
  static const String _productionUrl =
      'https://ibbwfkjrmxdksnalivum.supabase.co/functions/v1';

  static String get baseUrl {
    // 1) Build-time dart-define (production build için)
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl.endsWith('/')
          ? envUrl.substring(0, envUrl.length - 1)
          : envUrl;
    }
    // 2) Varsayilan olarak Render/local yerine Supabase Edge Function kullan.
    return _productionUrl;
  }

  /// Baglanti test endpoint'i (GET /api/auth/test)
  static const String healthTest = '/api/auth/test';

  // API Endpoints
  static const String apiPrefix = '/api';

  // Auth Endpoints
  static const String register = '$apiPrefix/auth/register';
  static const String login = '$apiPrefix/auth/login';
  static const String socialLogin = '$apiPrefix/auth/social';
  static const String getMe = '$apiPrefix/auth/me';
  static const String deleteMeAccount = '$apiPrefix/auth/me';
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
  static const String workoutSessions = '$apiPrefix/workouts/me/sessions';
  static String workout(int workoutId) => '$apiPrefix/workouts/me/$workoutId';
  static String exerciseHistory(String name) =>
      '$apiPrefix/workouts/me/exercise/${Uri.encodeComponent(name)}/history';
  static const String personalRecords =
      '$apiPrefix/workouts/me/personal-records';
  static const String workoutStats = '$apiPrefix/workouts/me/stats';

  // Nutrition Endpoints
  static const String meals = '$apiPrefix/nutrition/me/meals';
  static const String mealsByDate = '$apiPrefix/nutrition/me/meals/date';
  static const String dailyCalories = '$apiPrefix/nutrition/me/calories';
  static String meal(int mealId) => '$apiPrefix/nutrition/me/meals/$mealId';

  // AI Endpoints
  static const String aiCoach = '$apiPrefix/ai/coach';
  static const String aiCoachQuota = '$apiPrefix/ai/coach/quota';
  static const String aiInsights = '$apiPrefix/ai/insights';
  static const String aiSummarize = '$apiPrefix/ai/summarize';
  static const String aiNutrition = '$apiPrefix/ai/nutrition';
  static const String aiNutritionWeeklyPlan =
      '$apiPrefix/ai/nutrition/weekly-plan';
  static const String aiScanLabel = '$apiPrefix/ai/nutrition/scan-label';
  static const String aiAnalyzeImage = '$apiPrefix/ai/nutrition/analyze-image';

  // Recipe Endpoints
  static const String recipes = '$apiPrefix/recipes';

  // Premium Endpoints
  static const String premiumStatus = '$apiPrefix/user/premium-status';
  static const String upgradePremium = '$apiPrefix/user/upgrade-premium';
  /// RevenueCat üzerinden abonelik durumunu backend ile senkronlar.
  static const String premiumSync = '$apiPrefix/user/premium/sync';
  static const String downgradePremium = '$apiPrefix/user/downgrade-premium';

  // Exercise Endpoints (bolge / egzersiz listesi)
  static const String exerciseGroups = '$apiPrefix/exercises/groups';
  static String exercisesByGroup(String muscleGroup) =>
      '$apiPrefix/exercises?muscleGroup=$muscleGroup';

  // Exercise Library Endpoints
  static const String exerciseLibrary = '$apiPrefix/exercises';
  static String exerciseLibraryItem(String exerciseId) =>
      '$apiPrefix/exercises/$exerciseId';
  static const String exerciseLibraryBodyweight =
      '$apiPrefix/exercises/bodyweight';
  static const String exerciseLibraryCategories =
      '$apiPrefix/exercises/categories';
  static const String exerciseLibraryEquipment =
      '$apiPrefix/exercises/equipment';
}
