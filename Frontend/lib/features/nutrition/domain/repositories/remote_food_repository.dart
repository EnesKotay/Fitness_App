import '../entities/food_item.dart';

/// Uzaktan yiyecek araması (örn. Open Food Facts) için arayüz.
abstract class RemoteFoodRepository {
  /// Sorgu ile ürün arar.
  Future<List<FoodItem>> searchRemoteFoods(String query);

  /// Barkod ile tek ürün getirir.
  Future<FoodItem?> getByBarcode(String barcode);
}
