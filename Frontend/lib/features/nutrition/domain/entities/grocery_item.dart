class GroceryItem {
  final String name;
  final String normalizedName;
  final String category;
  final double totalGrams;
  final String? quantityLabel;
  final List<String> linkedMeals;
  final String source;

  const GroceryItem({
    required this.name,
    required this.normalizedName,
    required this.category,
    required this.totalGrams,
    required this.linkedMeals,
    required this.source,
    this.quantityLabel,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      name: (json['name'] as String?)?.trim() ?? '',
      normalizedName: (json['normalizedName'] as String?)?.trim() ?? '',
      category: (json['category'] as String?)?.trim() ?? '',
      totalGrams: (json['totalGrams'] as num?)?.toDouble() ?? 0,
      quantityLabel: (json['quantityLabel'] as String?)?.trim(),
      linkedMeals: (json['linkedMeals'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      source: (json['source'] as String?)?.trim() ?? 'local',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'normalizedName': normalizedName,
      'category': category,
      'totalGrams': totalGrams,
      'quantityLabel': quantityLabel,
      'linkedMeals': linkedMeals,
      'source': source,
    };
  }

  String get displayAmount {
    if (quantityLabel != null && quantityLabel!.isNotEmpty) {
      return quantityLabel!;
    }
    if (totalGrams <= 0) return '';
    return totalGrams == totalGrams.roundToDouble()
        ? '${totalGrams.toInt()}g'
        : '${totalGrams.toStringAsFixed(1)}g';
  }
}
