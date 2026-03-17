class BodyMeasurement {
  final int id;
  final int userId;
  final DateTime date;
  final double? chest;
  final double? waist;
  final double? hips;
  final double? leftArm;
  final double? rightArm;
  final double? leftLeg;
  final double? rightLeg;

  BodyMeasurement({
    required this.id,
    required this.userId,
    required this.date,
    this.chest,
    this.waist,
    this.hips,
    this.leftArm,
    this.rightArm,
    this.leftLeg,
    this.rightLeg,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      id: json['id'] as int,
      userId: json['userId'] as int,
      date: DateTime.parse(json['date'] as String),
      chest: (json['chest'] as num?)?.toDouble(),
      waist: (json['waist'] as num?)?.toDouble(),
      hips: (json['hips'] as num?)?.toDouble(),
      leftArm: (json['leftArm'] as num?)?.toDouble(),
      rightArm: (json['rightArm'] as num?)?.toDouble(),
      leftLeg: (json['leftLeg'] as num?)?.toDouble(),
      rightLeg: (json['rightLeg'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String().split('T').first,
      'chest': chest,
      'waist': waist,
      'hips': hips,
      'leftArm': leftArm,
      'rightArm': rightArm,
      'leftLeg': leftLeg,
      'rightLeg': rightLeg,
    };
  }
}

class BodyMeasurementRequest {
  final DateTime date;
  final double? chest;
  final double? waist;
  final double? hips;
  final double? leftArm;
  final double? rightArm;
  final double? leftLeg;
  final double? rightLeg;

  BodyMeasurementRequest({
    required this.date,
    this.chest,
    this.waist,
    this.hips,
    this.leftArm,
    this.rightArm,
    this.leftLeg,
    this.rightLeg,
  });

  factory BodyMeasurementRequest.fromJson(Map<String, dynamic> json) {
    return BodyMeasurementRequest(
      date: DateTime.parse(json['date'] as String),
      chest: (json['chest'] as num?)?.toDouble(),
      waist: (json['waist'] as num?)?.toDouble(),
      hips: (json['hips'] as num?)?.toDouble(),
      leftArm: (json['leftArm'] as num?)?.toDouble(),
      rightArm: (json['rightArm'] as num?)?.toDouble(),
      leftLeg: (json['leftLeg'] as num?)?.toDouble(),
      rightLeg: (json['rightLeg'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T').first,
      'chest': chest,
      'waist': waist,
      'hips': hips,
      'leftArm': leftArm,
      'rightArm': rightArm,
      'leftLeg': leftLeg,
      'rightLeg': rightLeg,
    };
  }
}
