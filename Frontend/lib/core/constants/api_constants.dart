import 'dart:io' show Platform;

class ApiConstants {
  /// Backend base URL - Ortama göre otomatik seçim
  ///
  /// Öncelik: API_BASE_URL env > platform bazlı varsayılan
  ///
  /// - Android Emulator: 10.0.2.2:8080 (localhost'a erişim)
  /// - iOS Simulator: 127.0.0.1:8080
  /// - Fiziksel cihaz: API_BASE_URL env ile veya --dart-define=API_BASE_URL=http://192.168.1.100:8080
  /// - Windows/macOS: localhost:8080
  static String get baseUrl {
    const envUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    if (envUrl.isNotEmpty) {
      return envUrl.endsWith('/') ? envUrl.substring(0, envUrl.length - 1) : envUrl;
    }
    if (Platform.isAndroid) {
      // Fiziksel cihaz: PC IP'sini yazın (ipconfig). Emulator: http://10.0.2.2:8080
      return 'http://192.168.1.20:8080';
    }
    if (Platform.isIOS) {
      return 'http://127.0.0.1:8080'; // iOS Simulator
    }
    return 'http://localhost:8080'; // Windows, macOS
  }

  /// Bağlantı test endpoint'i (GET /api/auth/test)
  static const String healthTest = '/api/auth/test';

  // API Endpoints
  static const String apiPrefix = '/api';

  // Auth Endpoints
  static const String register = '$apiPrefix/auth/register';
  static const String login = '$apiPrefix/auth/login';
  static const String getMe = '$apiPrefix/auth/me';
  static const String getUser = '$apiPrefix/auth/user';

  // Tracking Endpoints
  static String weightRecords(int userId) =>
      '$apiPrefix/tracking/users/$userId/weight-records';
  static String weightRecord(int userId, int recordId) =>
      '$apiPrefix/tracking/users/$userId/weight-records/$recordId';

  // Workout Endpoints
  static String workouts(int userId) => '$apiPrefix/workouts/users/$userId';
  static String workout(int userId, int workoutId) =>
      '$apiPrefix/workouts/users/$userId/$workoutId';

  // Nutrition Endpoints
  static String meals(int userId) => '$apiPrefix/nutrition/users/$userId/meals';
  static String mealsByDate(int userId) =>
      '$apiPrefix/nutrition/users/$userId/meals/date';
  static String dailyCalories(int userId) =>
      '$apiPrefix/nutrition/users/$userId/calories';
  static String meal(int userId, int mealId) =>
      '$apiPrefix/nutrition/users/$userId/meals/$mealId';

  // Exercise Endpoints (bölge / egzersiz listesi)
  static const String exerciseGroups = '$apiPrefix/exercises/groups';
  static String exercisesByGroup(String muscleGroup) =>
      '$apiPrefix/exercises?muscleGroup=$muscleGroup';
}
