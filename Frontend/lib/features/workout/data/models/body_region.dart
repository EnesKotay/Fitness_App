/// Vücut bölgesi (Göğüs, Sırt, Omuz, Kol, Bacak, Karın, Kardiyo, Full Body).
class BodyRegion {
  final String id;
  final String name;
  /// Asset path veya URL; boşsa ikon kullanılır.
  final String? imagePath;
  /// imagePath yoksa kullanılacak Material ikon kodu (Icons.xxx için index/name).
  final String? iconName;

  const BodyRegion({
    required this.id,
    required this.name,
    this.imagePath,
    this.iconName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'iconName': iconName,
      };

  factory BodyRegion.fromJson(Map<String, dynamic>? json) {
    if (json == null) throw ArgumentError('BodyRegion.fromJson: json null');
    return BodyRegion(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imagePath: json['imagePath']?.toString(),
      iconName: json['iconName']?.toString(),
    );
  }
}
