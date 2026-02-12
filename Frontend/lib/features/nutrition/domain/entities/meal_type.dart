/// Öğün tipi.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
}

extension MealTypeX on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Kahvaltı';
      case MealType.lunch:
        return 'Öğle';
      case MealType.dinner:
        return 'Akşam';
      case MealType.snack:
        return 'Atıştırma';
    }
  }
}
