import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/app_secrets.dart';

class SocialAuthIdentity {
  final String provider;
  final String idToken;
  final String? name;
  final String? authorizationCode;

  const SocialAuthIdentity({
    required this.provider,
    required this.idToken,
    this.name,
    this.authorizationCode,
  });
}

class SocialAuthService {
  static bool _googleInitialized = false;

  Future<SocialAuthIdentity> signInWithGoogle() async {
    if (kIsWeb) {
      throw StateError(
        'Google ile giriş şu anda yalnızca mobil uygulamada açık.',
      );
    }

    final serverClientId = AppSecrets.googleServerClientId.trim();
    final iosClientId = AppSecrets.googleIosClientId.trim();

    // iOS: GIDClientID / GIDServerClientID plist'ten okunur, dart-define gerekmez.
    // Android: serverClientId zorunlu.
    if (!Platform.isIOS && serverClientId.isEmpty) {
      throw StateError(
        'Google giriş yapılandırması eksik. GOOGLE_SERVER_CLIENT_ID tanımlanmalı.',
      );
    }

    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId: iosClientId.isNotEmpty ? iosClientId : null,
        serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
      );
      _googleInitialized = true;
    }

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('Bu cihaz Google ile girişi desteklemiyor.');
    }

    try {
      // Hesap değişimini kolaylaştırmak için seçim ekranını tekrar açtır.
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google kimlik tokenı alınamadı.');
      }

      return SocialAuthIdentity(
        provider: 'google',
        idToken: idToken,
        name: account.displayName?.trim(),
      );
    } on GoogleSignInException catch (e) {
      throw StateError(_mapGoogleError(e));
    }
  }

  Future<SocialAuthIdentity> signInWithApple() async {
    if (kIsWeb) {
      throw StateError(
        'Apple ile giriş şu anda yalnızca mobil uygulamada açık.',
      );
    }

    final isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      throw StateError('Apple ile giriş bu cihazda kullanılamıyor.');
    }

    WebAuthenticationOptions? webAuthenticationOptions;
    if (Platform.isAndroid) {
      final serviceId = AppSecrets.appleServiceId.trim();
      final redirectUri = AppSecrets.appleRedirectUri.trim();
      if (serviceId.isEmpty || redirectUri.isEmpty) {
        throw StateError(
          'Apple giriş yapılandırması eksik. APPLE_SERVICE_ID ve APPLE_REDIRECT_URI tanımlanmalı.',
        );
      }

      webAuthenticationOptions = WebAuthenticationOptions(
        clientId: serviceId,
        redirectUri: Uri.parse(redirectUri),
      );
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: webAuthenticationOptions,
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Apple kimlik tokenı alınamadı.');
      }

      final name = _composeName(credential.givenName, credential.familyName);

      return SocialAuthIdentity(
        provider: 'apple',
        idToken: idToken,
        name: name,
        authorizationCode: credential.authorizationCode,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      throw StateError(_mapAppleError(e));
    }
  }

  String? _composeName(String? givenName, String? familyName) {
    final parts = <String>[
      if (givenName != null && givenName.trim().isNotEmpty) givenName.trim(),
      if (familyName != null && familyName.trim().isNotEmpty) familyName.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String _mapGoogleError(GoogleSignInException error) {
    final description = error.description?.trim();
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google giriş işlemi iptal edildi.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google giriş yapılandırması hatalı. OAuth istemci ayarlarını kontrol edin.';
      default:
        return description != null && description.isNotEmpty
            ? description
            : 'Google ile giriş başarısız oldu.';
    }
  }

  String _mapAppleError(SignInWithAppleAuthorizationException error) {
    switch (error.code) {
      case AuthorizationErrorCode.canceled:
        return 'Apple giriş işlemi iptal edildi.';
      case AuthorizationErrorCode.failed:
      case AuthorizationErrorCode.invalidResponse:
        return 'Apple ile giriş başarısız oldu.';
      case AuthorizationErrorCode.notHandled:
        return 'Apple giriş isteği tamamlanamadı.';
      case AuthorizationErrorCode.notInteractive:
        return 'Apple giriş işlemi için kullanıcı etkileşimi gerekiyor.';
      case AuthorizationErrorCode.credentialExport:
        return 'Apple giriş anahtarı dışa aktarılamadı.';
      case AuthorizationErrorCode.credentialImport:
        return 'Apple giriş anahtarı içe aktarılamadı.';
      case AuthorizationErrorCode.unknown:
        return error.message.isNotEmpty
            ? error.message
            : 'Apple ile giriş başarısız oldu.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'Apple ile giriş başarısız oldu.';
    }
  }
}
