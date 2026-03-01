import 'package:hive/hive.dart';

class BarcodeFoodRepository {
  static const String boxName = 'barcode_map';
  Box<String>? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      _box = await Hive.openBox<String>(boxName);
    } else {
      _box = Hive.box<String>(boxName);
    }
  }

  /// Barkod string'ine karşılık gelen foodId'yi döndürür
  String? getFoodId(String barcode) {
    final box = _box;
    if (box == null || !box.isOpen) return null;
    return box.get(barcode);
  }

  /// Barkod -> foodId eşleşmesini kaydeder
  Future<void> saveMapping(String barcode, String foodId) async {
    if (_box == null || !_box!.isOpen) await init();
    await _box!.put(barcode, foodId);
  }

  /// Eşleşmeyi siler
  Future<void> removeMapping(String barcode) async {
    if (_box == null || !_box!.isOpen) await init();
    await _box!.delete(barcode);
  }
}
