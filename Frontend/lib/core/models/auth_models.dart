
import 'user.dart';

// Login Request
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() {
    return {'email': email, 'password': password};
  }
}

// Register Request
class RegisterRequest {
  final String email;
  final String password;
  final String name;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
  });

  Map<String, dynamic> toJson() {
    return {'email': email, 'password': password, 'name': name};
  }
}

class ChangePasswordRequest {
  final String currentPassword;
  final String newPassword;

  ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {'currentPassword': currentPassword, 'newPassword': newPassword};
  }
}

// Auth Response
class AuthResponse {
  final String token;
  final User user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final token = json['token']?.toString();
    final userJson = json['user'];
    if (token == null || token.isEmpty) {
      throw FormatException('Token bulunamadı');
    }
    if (userJson == null || userJson is! Map<String, dynamic>) {
      throw FormatException('Kullanıcı bilgisi bulunamadı');
    }
    return AuthResponse(
      token: token,
      user: User.fromJson(Map<String, dynamic>.from(userJson)),
    );
  }
}

// Forgot Password Models
class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() {
    return {'email': email};
  }
}

class VerifyResetCodeRequest {
  final String email;
  final String code;

  VerifyResetCodeRequest({required this.email, required this.code});

  Map<String, dynamic> toJson() {
    return {'email': email, 'code': code};
  }
}

class ResetPasswordRequest {
  final String email;
  final String code;
  final String newPassword;

  ResetPasswordRequest({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {'email': email, 'code': code, 'newPassword': newPassword};
  }
}
