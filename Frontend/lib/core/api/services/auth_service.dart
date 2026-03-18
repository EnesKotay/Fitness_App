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

  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.register,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      await _persistSession(
        token: authResponse.token,
        userId: authResponse.user.id,
        email: request.email.trim().toLowerCase(),
        name: authResponse.user.name,
      );

      if (kDebugMode) {
        debugPrint(
          'Auth(register): saved userId=${authResponse.user.id} email=${request.email.trim().toLowerCase()} suffix=${StorageHelper.getUserStorageSuffix()}',
        );
      }

      return authResponse;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Kayit islemi basarisiz oldu');
    }
  }

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.login,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      await _persistSession(
        token: authResponse.token,
        userId: authResponse.user.id,
        email: request.email.trim().toLowerCase(),
        name: authResponse.user.name,
      );

      if (kDebugMode) {
        debugPrint(
          'Auth(login): saved userId=${authResponse.user.id} email=${request.email.trim().toLowerCase()} suffix=${StorageHelper.getUserStorageSuffix()}',
        );
      }

      return authResponse;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Giris islemi basarisiz oldu');
    }
  }

  Future<User> getMe() async {
    try {
      final response = await _apiClient
          .get(ApiConstants.getMe)
          .timeout(const Duration(seconds: 5));
      return User.fromJson(response.data as Map<String, dynamic>);
    } on TimeoutException {
      throw ApiException(message: 'Baglanti zaman asimi');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Kullanici bilgileri alinamadi');
    }
  }

  Future<User> getUser(int userId) async {
    try {
      final response = await _apiClient
          .get('${ApiConstants.getUser}/$userId')
          .timeout(const Duration(seconds: 5));
      return User.fromJson(response.data as Map<String, dynamic>);
    } on TimeoutException {
      throw ApiException(message: 'Baglanti zaman asimi');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Kullanici bilgileri alinamadi');
    }
  }

  Future<User> updateMeProfile(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient
          .put(ApiConstants.updateMeProfile, data: payload)
          .timeout(const Duration(seconds: 5));
      return User.fromJson(response.data as Map<String, dynamic>);
    } on TimeoutException {
      throw ApiException(message: 'Baglanti zaman asimi');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Profil guncellenemedi');
    }
  }

  Future<void> changeMyPassword(ChangePasswordRequest request) async {
    try {
      await _apiClient
          .put(ApiConstants.updateMePassword, data: request.toJson())
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw ApiException(message: 'Baglanti zaman asimi');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Sifre guncellenemedi');
    }
  }

  Future<void> deleteMyAccount() async {
    try {
      await _apiClient
          .delete(ApiConstants.deleteMeAccount)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw ApiException(message: 'Baglanti zaman asimi');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Hesap silinemedi');
    }
  }

  Future<void> logout() async {
    await StorageHelper.clearUserData();
  }

  Future<bool> isLoggedIn() async {
    final token = StorageHelper.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    try {
      await _apiClient
          .post('/api/auth/forgot-password', data: request.toJson())
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw ApiException(message: 'Bağlantı zaman aşımı');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'E-posta gönderilemedi');
    }
  }

  Future<void> verifyResetCode(VerifyResetCodeRequest request) async {
    try {
      await _apiClient
          .post('/api/auth/verify-reset-code', data: request.toJson())
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw ApiException(message: 'Bağlantı zaman aşımı');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Kod doğrulanamadı');
    }
  }

  Future<void> resetPassword(ResetPasswordRequest request) async {
    try {
      await _apiClient
          .post('/api/auth/reset-password', data: request.toJson())
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw ApiException(message: 'Bağlantı zaman aşımı');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Şifreniz sıfırlanamadı');
    }
  }

  Future<void> _persistSession({
    required String token,
    required int userId,
    required String email,
    required String name,
  }) async {
    final tokenOk = await StorageHelper.saveToken(token);
    final idOk = await StorageHelper.saveUserId(userId);
    final emailOk = await StorageHelper.saveUserEmail(email);
    final nameOk = await StorageHelper.saveUserName(name);

    if (!tokenOk || !idOk || !emailOk || !nameOk) {
      await StorageHelper.clearUserData();
      throw ApiException(
        message: 'Oturum bilgileri kaydedilemedi. Lutfen tekrar dene.',
      );
    }
  }
}
