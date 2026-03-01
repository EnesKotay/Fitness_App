import 'dart:io' show Platform;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  /// Backend base URL - Ortama gore otomatik secim
  ///
  /// Oncelik: .env API_BASE_URL > dart-define > platform varsayilani
  /// - Fiziksel iPhone/Android: .env'de API_BASE_URL=http://MAC_IP:8080 (telefon ve Mac ayni WiFi)
  /// - iOS Simulator: 127.0.0.1:8080
  /// - Android Emulator: 10.0.2.2:8080
  static String get baseUrl {
    // 1) .env (runtime) - fiziksel cihazda Mac IP yazilir
    final dotenvUrl = dotenv.env['API_BASE_URL']?.trim();
    if (dotenvUrl != null && dotenvUrl.isNotEmpty) {
      return dotenvUrl.endsWith('/') ? dotenvUrl.substring(0, dotenvUrl.length - 1) : dotenvUrl;
    }
    // 2) dart-define (build time)
    const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envUrl.isNotEmpty) {
      return envUrl.endsWith('/') ? envUrl.substring(0, envUrl.length - 1) : envUrl;
    }
    // 3) Platform varsayilanlari
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
  static const String getUser = '$apiPrefix/auth/user';

  // Tracking Endpoints
  static const String weightRecords = '$apiPrefix/tracking/me/weight-records';
  static String weightRecord(int recordId) =>
      '$apiPrefix/tracking/me/weight-records/$recordId';

  // Workout Endpoints
  static const String workouts = '$apiPrefix/workouts/me';
  static String workout(int workoutId) => '$apiPrefix/workouts/me/$workoutId';

  // Nutrition Endpoints
  static const String meals = '$apiPrefix/nutrition/me/meals';
  static const String mealsByDate = '$apiPrefix/nutrition/me/meals/date';
  static const String dailyCalories = '$apiPrefix/nutrition/me/calories';
  static String meal(int mealId) => '$apiPrefix/nutrition/me/meals/$mealId';

  // AI Endpoints
  static const String aiCoach = '$apiPrefix/ai/coach';
  static const String aiNutrition = '$apiPrefix/ai/nutrition';

  // Exercise Endpoints (bolge / egzersiz listesi)
  static const String exerciseGroups = '$apiPrefix/exercises/groups';
  static String exercisesByGroup(String muscleGroup) =>
      '$apiPrefix/exercises?muscleGroup=$muscleGroup';
}
