class User {
  final int id;
  final String email;
  final String name;
  final DateTime? createdAt;
  final double? height;
  final DateTime? birthDate;
  final String? gender;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.createdAt,
    this.height,
    this.birthDate,
    this.gender,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email']?.toString();
    final name = json['name']?.toString();
    if (id == null || email == null || email.isEmpty || name == null || name.isEmpty) {
      throw FormatException('Geçersiz kullanıcı verisi: id=$id, email=$email, name=$name');
    }
    return User(
      id: (id is num) ? id.toInt() : int.tryParse(id.toString()) ?? 0,
      email: email,
      name: name,
      createdAt: _parseDateTime(json['createdAt']),
      height: json['height'] != null
          ? (json['height'] is num
              ? (json['height'] as num).toDouble()
              : double.tryParse(json['height'].toString()))
          : null,
      birthDate: _parseDateTime(json['birthDate']),
      gender: json['gender']?.toString(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    // Jackson bazen LocalDateTime'ı [y,m,d,h,min,s] array olarak serialize eder
    if (value is List && value.length >= 3) {
      try {
        final y = (value[0] as num).toInt();
        final m = (value.length > 1 ? (value[1] as num).toInt() : 1).clamp(1, 12);
        final d = (value.length > 2 ? (value[2] as num).toInt() : 1).clamp(1, 31);
        final h = value.length > 3 ? (value[3] as num).toInt() : 0;
        final min = value.length > 4 ? (value[4] as num).toInt() : 0;
        final sec = value.length > 5 ? (value[5] as num).toInt() : 0;
        return DateTime(y, m, d, h, min, sec);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'createdAt': createdAt?.toIso8601String(),
      'height': height,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender,
    };
  }
}
