import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/api/services/auth_service.dart';
import '../../../core/models/auth_models.dart';
import '../../../core/models/user.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/services/social_auth_service.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/domain/entities/user_profile.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SocialAuthService _socialAuthService = SocialAuthService();

  // State
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  /// Logout / hesap silme sırasında diğer provider'ların state'ini temizlemek
  /// için kayıt edilen callback'ler. Genellikle app_providers.dart'ta set edilir.
  final List<VoidCallback> _logoutCallbacks = [];

  void addLogoutCallback(VoidCallback cb) {
    if (!_logoutCallbacks.contains(cb)) _logoutCallbacks.add(cb);
  }

  void removeLogoutCallback(VoidCallback cb) => _logoutCallbacks.remove(cb);

  void _runLogoutCallbacks() {
    for (final cb in _logoutCallbacks) {
      try {
        cb();
      } catch (e) {
        debugPrint('AuthProvider logoutCallback hatası: $e');
      }
    }
  }

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
      await _applyAuthResponse(response);
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
      await _applyAuthResponse(response);
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

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final identity = await _socialAuthService.signInWithGoogle();
      final response = await _authService.socialLogin(
        SocialLoginRequest(
          provider: identity.provider,
          idToken: identity.idToken,
          name: identity.name,
          authorizationCode: identity.authorizationCode,
        ),
      );
      await _applyAuthResponse(response);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } on StateError catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Google login unexpected error: $e');
      _errorMessage = e.toString().trim().isNotEmpty
          ? e.toString()
          : 'Google ile giriş başarısız oldu';
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final identity = await _socialAuthService.signInWithApple();
      final response = await _authService.socialLogin(
        SocialLoginRequest(
          provider: identity.provider,
          idToken: identity.idToken,
          name: identity.name,
          authorizationCode: identity.authorizationCode,
        ),
      );
      await _applyAuthResponse(response);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } on StateError catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Apple login unexpected error: $e');
      _errorMessage = e.toString().trim().isNotEmpty
          ? e.toString()
          : 'Apple ile giriş başarısız oldu';
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Çıkış yap
  Future<void> logout() async {
    _runLogoutCallbacks();
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
      _runLogoutCallbacks();
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

  /// JWT payload'ından exp alanını parse eder. Token süresi dolmuşsa true döner.
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      var payload = parts[1];
      // Base64 padding
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(
        base64.decode(payload.replaceAll('-', '+').replaceAll('_', '/')),
      );
      final json = decoded;
      final expMatch = RegExp(r'"exp"\s*:\s*(\d+)').firstMatch(json);
      if (expMatch == null) return true;
      final exp = int.parse(expMatch.group(1)!);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return now >= exp;
    } catch (_) {
      return true;
    }
  }

  /// Oturum kontrolü (uygulama başlangıcında). User bilgisi token'dan GET /me ile alınır; local cache güncellenir.
  Future<void> checkAuthStatus() async {
    final token = StorageHelper.getToken();
    if (token == null || token.isEmpty) return;

    if (_isTokenExpired(token)) {
      await logout();
      return;
    }

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
      'activityLevel': profile.activityLevel.name,
      'goal': profile.goal.name,
      'workoutLocation': StorageHelper.getWorkoutLocation(),
      'equipmentType': StorageHelper.getEquipmentType(),
    };
    final nutritionPreferences = StorageHelper.getNutritionPreferences();
    if (nutritionPreferences != null) {
      payload['nutritionPreferencesJson'] = jsonEncode(nutritionPreferences);
    }
    final updated = await _authService.updateMeProfile(payload);
    _user = updated;
    await StorageHelper.saveUserName(updated.name);
    notifyListeners();
  }

  Future<void> updateMotivationStats(Map<String, dynamic> stats) async {
    final current = _user;
    if (current == null || current.id <= 0) return;
    final encoded = jsonEncode(stats);
    final updated = await _authService.updateMeProfile({
      'motivationStatsJson': encoded,
    });
    _user = updated;
    notifyListeners();
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _applyAuthResponse(AuthResponse response) async {
    _user = response.user;
    _isAuthenticated = true;
    _isLoading = false;
    await StorageHelper.saveUserEmail(response.user.email);
    await StorageHelper.saveUserId(response.user.id);
    await StorageHelper.saveUserName(response.user.name);
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
        weight: current.weight,
        targetWeight: current.targetWeight,
        birthDate: current.birthDate,
        gender: current.gender,
        activityLevel: current.activityLevel,
        goal: current.goal,
        goalHistoryJson: current.goalHistoryJson,
        workoutLocation: current.workoutLocation,
        equipmentType: current.equipmentType,
        nutritionPreferencesJson: current.nutritionPreferencesJson,
        aiMemorySummary: current.aiMemorySummary,
        motivationStatsJson: current.motivationStatsJson,
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
