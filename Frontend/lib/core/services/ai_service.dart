import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class AIService {
  late final GenerativeModel _model;
  bool _isInitialized = false;

  AIService() {
    _init();
  }

  void _init() {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('AIService: GEMINI_API_KEY not found in .env');
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );
      _isInitialized = true;
    } catch (e) {
      // .env yüklenmemişse (NotInitializedError) veya başka hata - uygulama açılsın, AI devre dışı kalsın
      debugPrint('AIService: .env yok veya key okunamadı: $e');
    }
  }

  bool get isReady => _isInitialized;

  /// Serbest metinden yemek araması yapar. 
  /// Örn: "Bir tabak pilav ve tavuk sote yedim" -> ['pilav', 'tavuk sote']
  Future<List<String>> extractFoodItems(String text) async {
    if (!_isInitialized) return [];

    final prompt = '''
Sen bir beslenme asistanısın. Aşağıdaki doğal dildeki metinden yenilen besinleri/yemekleri ayıkla.
Kurallar:
1. Sadece yemek isimlerini virgülle ayırarak yaz.
2. Miktar bilgilerini (gram, adet, dilim vb.) temizle, sadece besin ismini bırak.
3. Çoğul eklerini temizle (yumurtalar -> yumurta).
4. Örnek: "2 yumurta, bir dilim tam buğday ekmeği ve peynir yedim" -> "yumurta, tam buğday ekmeği, peynir"
5. Metin: "$text"
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final result = response.text;
      if (result == null) return [];
      
      return result.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (e) {
      debugPrint('AIService.extractFoodItems: $e');
      return [];
    }
  }

  /// Sohbet asistanı için genel yanıt üretir.
  Future<String> getChatResponse(String message, String context) async {
    if (!_isInitialized) return 'Üzgünüm, şu an servis dışıyım. (API Anahtarı eksik olabilir)';

    final prompt = '''
Sen bir fitness ve beslenme asistanısın. Kullanıcıya yardımcı ol.
Kullanıcının bugünkü beslenme verileri: $context
Kullanıcı mesajı: "$message"
Yanıtını kısa, öz ve motive edici tut. Türkçe konuş.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Bir hata oluştu.';
    } catch (e) {
      debugPrint('AIService.getChatResponse: $e');
      return 'Bağlantı sorunu yaşandı.';
    }
  }

  /// Önerilen yemekler için kısa bir açıklama üretir.
  Future<String> getSuggestionReasoning(String foodNames, String context) async {
    if (!_isInitialized) return '';

    final prompt = '''
Kullanıcının durumu: $context
Önerilen yemekler: $foodNames
Neden bu yemeklerin önerildiğini (protein/karb dengesi vb.) bir cümleyle, motive edici şekilde açıkla.
Yanıt sadece bir cümle olsun.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      debugPrint('AIService.getSuggestionReasoning: $e');
      return '';
    }
  }
}
