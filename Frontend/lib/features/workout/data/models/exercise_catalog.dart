/// Katalog hareketi: detay sayfasında gösterilecek tüm alanlar.
class ExerciseCatalog {
  final String id;
  final String regionId;
  final String name;
  /// Hedef kas(lar), virgülle ayrılmış veya liste.
  final List<String> primaryMuscles;
  /// Ekipman: dumbbell, barbell, bodyweight, cable, kettlebell, band, vb.
  final List<String> equipment;
  /// Zorluk: Başlangıç, Orta, İleri
  final String difficulty;
  /// Video/GIF URL veya local asset; boşsa placeholder.
  final String? mediaUrl;
  /// Numaralı adımlar (nasıl yapılır).
  final List<String> steps;
  /// Yaygın hatalar (bullet list).
  final List<String> commonMistakes;
  /// İpuçları (bullet list).
  final List<String> tips;
  /// Kısa güvenlik uyarısı.
  final String? safetyWarning;

  const ExerciseCatalog({
    required this.id,
    required this.regionId,
    required this.name,
    this.primaryMuscles = const [],
    this.equipment = const [],
    this.difficulty = 'Orta',
    this.mediaUrl,
    this.steps = const [],
    this.commonMistakes = const [],
    this.tips = const [],
    this.safetyWarning,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'regionId': regionId,
        'name': name,
        'primaryMuscles': primaryMuscles,
        'equipment': equipment,
        'difficulty': difficulty,
        'mediaUrl': mediaUrl,
        'steps': steps,
        'commonMistakes': commonMistakes,
        'tips': tips,
        'safetyWarning': safetyWarning,
      };

  factory ExerciseCatalog.fromJson(Map<String, dynamic>? json) {
    if (json == null) throw ArgumentError('ExerciseCatalog.fromJson: json null');
    return ExerciseCatalog(
      id: json['id']?.toString() ?? '',
      regionId: json['regionId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      primaryMuscles: _listFrom(json['primaryMuscles']),
      equipment: _listFrom(json['equipment']),
      difficulty: json['difficulty']?.toString() ?? 'Orta',
      mediaUrl: json['mediaUrl']?.toString(),
      steps: _listFrom(json['steps']),
      commonMistakes: _listFrom(json['commonMistakes']),
      tips: _listFrom(json['tips']),
      safetyWarning: json['safetyWarning']?.toString(),
    );
  }

  static List<String> _listFrom(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return [];
  }
}
