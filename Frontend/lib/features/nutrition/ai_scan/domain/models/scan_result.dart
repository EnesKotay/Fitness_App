
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class BarcodeScanResult {
  final String value;
  final BarcodeFormat format;
  final DateTime timestamp;

  BarcodeScanResult({
    required this.value,
    this.format = BarcodeFormat.unknown,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  @override
  String toString() => 'BarcodeScanResult(value: $value, format: $format)';
}

class OcrNutritionResult {
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbPer100g;
  final double? fatPer100g;
  final String rawText;

  OcrNutritionResult({
    this.kcalPer100g,
    this.proteinPer100g,
    this.carbPer100g,
    this.fatPer100g,
    required this.rawText,
  });

  bool get hasValues => 
    kcalPer100g != null || 
    proteinPer100g != null || 
    carbPer100g != null || 
    fatPer100g != null;
    
  @override
  String toString() => 
    'OcrNutritionResult(kcal: $kcalPer100g, p: $proteinPer100g, c: $carbPer100g, f: $fatPer100g)';
}
