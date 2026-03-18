import 'package:flutter/foundation.dart';
import '../../../core/api/services/auth_service.dart';
import '../../../core/models/auth_models.dart';
import '../../../core/models/user.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/domain/entities/user_profile.dart';

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
      // Hive suffix'i için kullanıcı kimliğini hemen kaydet.
      await StorageHelper.saveUserEmail(response.user.email);
      await StorageHelper.saveUserId(response.user.id);
      await StorageHelper.saveUserName(response.user.name);
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
      final request = LoginRequest(email: email, password: password);

      final response = await _authService.login(request);
      _user = response.user;
      _isAuthenticated = true;
      _isLoading = false;
      // Hive suffix'i için kullanıcı kimliğini hemen kaydet.
      await StorageHelper.saveUserEmail(response.user.email);
      await StorageHelper.saveUserId(response.user.id);
      await StorageHelper.saveUserName(response.user.name);
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

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.deleteMyAccount();
      await StorageHelper.clearDeletedAccountData();
      _user = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Hesap silinemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Oturum kontrolü (uygulama başlangıcında). User bilgisi token'dan GET /me ile alınır; local cache güncellenir.
  Future<void> checkAuthStatus() async {
    final token = StorageHelper.getToken();
    if (token == null || token.isEmpty) return;

    // Token varsa hemen authenticated say — ağ olmasa da kullanıcı giriş yapmış sayılır.
    // Cached kullanıcı bilgilerini yükle (varsa).
    final cachedName = StorageHelper.getUserName();
    final cachedEmail = StorageHelper.getUserEmail();
    final cachedId = StorageHelper.getUserId();
    if (cachedId != null || cachedName != null || cachedEmail != null) {
      _user = User(
        id: cachedId ?? 0,
        name: cachedName ?? '',
        email: cachedEmail ?? '',
      );
    }
    _isAuthenticated = true;
    notifyListeners();

    // Arka planda server'dan güncel kullanıcı bilgilerini al.
    try {
      final user = await _authService.getMe();
      _user = user;
      await StorageHelper.saveUserId(user.id);
      await StorageHelper.saveUserEmail(user.email);
      await StorageHelper.saveUserName(user.name);
      notifyListeners();
    } on ApiException catch (e) {
      // Sadece token geçersizse (401) oturumu kapat.
      if (e.statusCode == 401) {
        await logout();
      }
      // Diğer hatalar (ağ yok, timeout vb.) sessizce görmezden gelinir.
    } catch (_) {
      // Beklenmeyen hata: oturumu kapatma, sadece devam et.
    }
  }

  /// Diet profilini backend'deki /api/auth/me/profile endpoint'ine senkronize eder.
  Future<void> updateProfileFromDiet(UserProfile profile) async {
    final now = DateTime.now();
    final safeYear = (now.year - profile.age).clamp(1900, now.year).toInt();
    final birthDate = DateTime(
      safeYear,
      now.month,
      now.day.clamp(1, 28).toInt(),
    );
    final payload = <String, dynamic>{
      'name': profile.name,
      'height': profile.height,
      'weight': profile.weight,
      'targetWeight': profile.targetWeight,
      'birthDate': birthDate.toIso8601String(),
      'gender': profile.gender == Gender.female ? 'FEMALE' : 'MALE',
    };
    final updated = await _authService.updateMeProfile(payload);
    _user = updated;
    await StorageHelper.saveUserName(updated.name);
    notifyListeners();
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setPremiumActive(
    bool isPremium, {
    String? premiumPlan,
    DateTime? premiumExpiresAt,
    bool? premiumCancelAtPeriodEnd,
    DateTime? premiumCanceledAt,
  }) {
    final current = _user;
    if (current == null) return;

    if (!isPremium) {
      // copyWith cannot null out fields (null ?? existing = existing), so we
      // construct a fresh User to properly clear all premium fields.
      _user = User(
        id: current.id,
        email: current.email,
        name: current.name,
        createdAt: current.createdAt,
        height: current.height,
        targetWeight: current.targetWeight,
        birthDate: current.birthDate,
        gender: current.gender,
        premiumTier: 'free',
      );
    } else {
      _user = current.copyWith(
        premiumTier: 'premium',
        premiumPlan: premiumPlan ?? current.premiumPlan,
        premiumExpiresAt: premiumExpiresAt ?? current.premiumExpiresAt,
        premiumCancelAtPeriodEnd:
            premiumCancelAtPeriodEnd ?? current.premiumCancelAtPeriodEnd,
        premiumCanceledAt: premiumCanceledAt ?? current.premiumCanceledAt,
      );
    }
    notifyListeners();
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final req = ChangePasswordRequest(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await _authService.changeMyPassword(req);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Şifre değiştirilemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = ForgotPasswordRequest(email: email);
      await _authService.forgotPassword(request);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'E-posta gönderilirken hata oluştu';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyResetCode(String email, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = VerifyResetCodeRequest(email: email, code: code);
      await _authService.verifyResetCode(request);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Kod doğrulanamadı';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = ResetPasswordRequest(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      await _authService.resetPassword(request);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Şifre sıfırlanamadı';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
