class Exercise {
  final int id;
  final String muscleGroup;
  final String name;
  final String? description;
  final String? instructions;

  Exercise({
    required this.id,
    required this.muscleGroup,
    required this.name,
    this.description,
    this.instructions,
  });

  factory Exercise.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError('Exercise.fromJson: json null');
    }
    final id = json['id'];
    return Exercise(
      id: id is num ? id.toInt() : int.tryParse(id?.toString() ?? '0') ?? 0,
      muscleGroup: json['muscleGroup']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      instructions: json['instructions']?.toString(),
    );
  }
}
