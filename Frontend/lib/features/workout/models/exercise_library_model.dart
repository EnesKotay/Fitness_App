class ExerciseLibrary {
  final String id;
  final String name;
  final String category;
  final String bodyPart;
  final String equipment;
  final String? instructions;
  final List<String> instructionSteps;
  final String? muscleGroup;
  final List<String> secondaryMuscles;
  final String? target;
  final String? mediaId;

  const ExerciseLibrary({
    required this.id,
    required this.name,
    required this.category,
    required this.bodyPart,
    required this.equipment,
    this.instructions,
    this.instructionSteps = const [],
    this.muscleGroup,
    this.secondaryMuscles = const [],
    this.target,
    this.mediaId,
  });

  factory ExerciseLibrary.fromJson(Map<String, dynamic> json) {
    return ExerciseLibrary(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      bodyPart: json['bodyPart'] as String,
      equipment: json['equipment'] as String,
      instructions: json['instructions'] as String?,
      instructionSteps: json['instructionSteps'] != null
          ? List<String>.from(json['instructionSteps'] as List)
          : [],
      muscleGroup: json['muscleGroup'] as String?,
      secondaryMuscles: json['secondaryMuscles'] != null
          ? List<String>.from(json['secondaryMuscles'] as List)
          : [],
      target: json['target'] as String?,
      mediaId: json['mediaId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'bodyPart': bodyPart,
      'equipment': equipment,
      'instructions': instructions,
      'instructionSteps': instructionSteps,
      'muscleGroup': muscleGroup,
      'secondaryMuscles': secondaryMuscles,
      'target': target,
      'mediaId': mediaId,
    };
  }
}

/// Filter options for exercise library
class ExerciseFilter {
  final String? category;
  final String? equipment;
  final String? target;
  final String? search;

  const ExerciseFilter({
    this.category,
    this.equipment,
    this.target,
    this.search,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (category != null) params['category'] = category!;
    if (equipment != null) params['equipment'] = equipment!;
    if (target != null) params['target'] = target!;
    if (search != null) params['search'] = search!;
    return params;
  }
}

/// Exercise categories (body parts)
class ExerciseCategory {
  static const String waist = 'waist';
  static const String upperArms = 'upper arms';
  static const String upperLegs = 'upper legs';
  static const String back = 'back';
  static const String chest = 'chest';
  static const String shoulders = 'shoulders';
  static const String lowerLegs = 'lower legs';
  static const String lowerArms = 'lower arms';
  static const String cardio = 'cardio';
  static const String neck = 'neck';

  static const List<String> all = [
    waist,
    upperArms,
    upperLegs,
    back,
    chest,
    shoulders,
    lowerLegs,
    lowerArms,
    cardio,
    neck,
  ];

  static String getDisplayName(String category) {
    return switch (category) {
      'waist' => 'Karın',
      'upper arms' => 'Kollar (Üst)',
      'upper legs' => 'Bacaklar (Üst)',
      'back' => 'Sırt',
      'chest' => 'Göğüs',
      'shoulders' => 'Omuzlar',
      'lower legs' => 'Bacaklar (Alt)',
      'lower arms' => 'Kollar (Alt)',
      'cardio' => 'Kardio',
      'neck' => 'Boyun',
      _ => category,
    };
  }
}

/// Equipment types
class ExerciseEquipment {
  static const String bodyWeight = 'body weight';
  static const String dumbbell = 'dumbbell';
  static const String cable = 'cable';
  static const String barbell = 'barbell';
  static const String leverageMachine = 'leverage machine';
  static const String band = 'band';
  static const String smithMachine = 'smith machine';
  static const String kettlebell = 'kettlebell';
  static const String weighted = 'weighted';
  static const String stabilityBall = 'stability ball';
  static const String ezBarbell = 'ez barbell';

  static const List<String> all = [
    bodyWeight,
    dumbbell,
    cable,
    barbell,
    leverageMachine,
    band,
    smithMachine,
    kettlebell,
    weighted,
    stabilityBall,
    ezBarbell,
  ];

  static String getDisplayName(String equipment) {
    return switch (equipment) {
      'body weight' => 'Ekipmansız',
      'dumbbell' => 'Dumbbell',
      'cable' => 'Cable',
      'barbell' => 'Barbell',
      'leverage machine' => 'Makine',
      'band' => 'Bant',
      'smith machine' => 'Smith Makine',
      'kettlebell' => 'Kettlebell',
      'weighted' => 'Ağırlıklı',
      'stability ball' => 'Pilates Topu',
      'ez barbell' => 'EZ Barbell',
      _ => equipment,
    };
  }
}
