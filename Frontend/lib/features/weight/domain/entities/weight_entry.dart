/// Kilo kaydı (Hive'da Map olarak saklanır, TypeAdapter yok).
class WeightEntry {
  final String id;
  final DateTime date;
  final double weightKg;
  final String? note;

  WeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'weightKg': weightKg,
        'note': note,
      };

  factory WeightEntry.fromJson(Map<dynamic, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      weightKg: (json['weightKg'] as num).toDouble(),
      note: json['note'] as String?,
    );
  }
}
