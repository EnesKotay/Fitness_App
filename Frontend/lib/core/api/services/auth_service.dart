import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../api_exception.dart';
import '../../constants/api_constants.dart';
import '../../models/auth_models.dart';
import '../../models/user.dart';
import '../../utils/storage_helper.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  /// Kullanıcı kaydı
  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.register,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Sıra önemli: token → userId → email → name. Sonraki API istekleri ve getUserStorageSuffix() doğru çalışsın.
      await StorageHelper.saveToken(authResponse.token);
      await StorageHelper.saveUserId(authResponse.user.id);
      await StorageHelper.saveUserEmail(request.email.trim().toLowerCase());
      await StorageHelper.saveUserName(authResponse.user.name);
      if (kDebugMode) {
        debugPrint('Auth(register): saved userId=${authResponse.user.id} email=${request.email.trim().toLowerCase()} suffix=${StorageHelper.getUserStorageSuffix()}');
      }

      return authResponse;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Kayıt işlemi başarısız oldu');
    }
  }

  /// Kullanıcı girişi. Login başarılı olunca mutlaka yeni userId/email/token yazılır.
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.login,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      await StorageHelper.saveToken(authResponse.token);
      await StorageHelper.saveUserId(authResponse.user.id);
      await StorageHelper.saveUserEmail(request.email.trim().toLowerCase());
      await StorageHelper.saveUserName(authResponse.user.name);
      if (kDebugMode) {
        debugPrint('Auth(login): saved userId=${authResponse.user.id} email=${request.email.trim().toLowerCase()} suffix=${StorageHelper.getUserStorageSuffix()}');
      }

      return authResponse;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Giriş işlemi başarısız oldu');
    }
  }

  /// Mevcut kullanıcıyı token'dan döner (GET /api/auth/me). userId path'te değil, token'dan alınır.
  Future<User> getMe() async {
    try {
      final response = await _apiClient
          .get(ApiConstants.getMe)
          .timeout(const Duration(seconds: 5));
      return User.fromJson(response.data as Map<String, dynamic>);
    } on TimeoutException {
      throw ApiException(message: 'Bağlantı zaman aşımı');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Kullanıcı bilgileri alınamadı');
    }
  }

  /// Kullanıcı bilgilerini getir (GET /api/auth/user/{userId}). Backend path userId == token userId doğrular.
  Future<User> getUser(int userId) async {
    try {
      final response = await _apiClient
          .get('${ApiConstants.getUser}/$userId')
          .timeout(const Duration(seconds: 5));
      return User.fromJson(response.data as Map<String, dynamic>);
    } on TimeoutException {
      throw ApiException(message: 'Bağlantı zaman aşımı');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Kullanıcı bilgileri alınamadı');
    }
  }

  /// Çıkış yap
  Future<void> logout() async {
    await StorageHelper.clearUserData();
  }

  /// Oturum kontrolü
  Future<bool> isLoggedIn() async {
    final token = StorageHelper.getToken();
    return token != null && token.isNotEmpty;
  }
}
