import 'package:flutter/foundation.dart';
import '../../../core/api/services/auth_service.dart';
import '../../../core/models/auth_models.dart';
import '../../../core/models/user.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/storage_helper.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  // State
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;

  /// Kullanıcı kaydı
  Future<bool> register(String email, String password, String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = RegisterRequest(
        email: email,
        password: password,
        name: name,
      );

      final response = await _authService.register(request);
      _user = response.user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Beklenmeyen bir hata oluştu';
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Kullanıcı girişi
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = LoginRequest(
        email: email,
        password: password,
      );

      final response = await _authService.login(request);
      _user = response.user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Beklenmeyen bir hata oluştu';
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Çıkış yap
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Oturum kontrolü (uygulama başlangıcında). User bilgisi token'dan GET /me ile alınır; local cache güncellenir.
  Future<void> checkAuthStatus() async {
    final token = StorageHelper.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final user = await _authService.getMe();
      _user = user;
      _isAuthenticated = true;
      await StorageHelper.saveUserId(user.id);
      await StorageHelper.saveUserEmail(user.email ?? '');
      await StorageHelper.saveUserName(user.name);
      notifyListeners();
    } catch (e) {
      await logout();
    }
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
