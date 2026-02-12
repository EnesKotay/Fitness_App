import '../../domain/entities/food_item.dart';
import '../../domain/repositories/food_repository.dart';
import '../datasources/asset_food_loader.dart';
import '../datasources/hive_diet_storage.dart';

/// Local yiyecek listesi: JSON asset + kullanıcının eklediği özel yemekler (Hive).
/// Arama: name, aliases, tags, category tarar; Türkçe normalizasyon + basit fuzzy.
class LocalFoodRepository implements FoodRepository {
  List<FoodItem>? _assetCache;
  List<FoodItem>? _customCache;
  Map<String, List<String>>? _synonyms;
  final HiveDietStorage _hive = HiveDietStorage();

  Future<void> _ensureLoaded() async {
    _assetCache ??= await AssetFoodLoader.loadFoods();
    _customCache ??= await _hive.getCustomFoods();
    _synonyms ??= await AssetFoodLoader.loadSynonyms();
  }

  /// Türkçe karakterleri normalize eder, özel karakterleri temizler
  static String normalize(String input) {
    return input.toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }

  /// Kelime sınırında sorgu eşleşmesi (örn. "tavuk" -> "Tavuklu pilav" içinde kelime başı)
  static bool _wordStartsWith(String text, String query) {
    if (query.isEmpty) return false;
    final idx = text.indexOf(query);
    if (idx < 0) return false;
    if (idx == 0) return true;
    return text[idx - 1] == ' ' || text[idx - 1] == '\t';
  }

  /// Levenshtein mesafesi 1 veya 2 (kısa kelimelerde 1, uzunlarda 2)
  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length, n = b.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) d[i][0] = i;
    for (var j = 0; j <= n; j++) d[0][j] = j;
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return d[m][n];
  }

  /// Tek kelime için fuzzy eşleşme: 1–2 harf hatası kabul (makrna -> makarna)
  static bool _fuzzyMatch(String normalizedQuery, String token) {
    if (token.isEmpty || normalizedQuery.isEmpty) return false;
    if (token == normalizedQuery) return true;
    if (token.contains(normalizedQuery) || normalizedQuery.contains(token)) return true;
    final len = normalizedQuery.length;
    if (len < 3) return false;
    final dist = _levenshtein(normalizedQuery, token);
    return (len <= 5 && dist <= 1) || (len > 5 && dist <= 2);
  }

  void invalidateCache() {
    _customCache = null;
  }

  @override
  Future<List<FoodItem>> searchFoods(String query, {String? category}) async {
    await _ensureLoaded();

    List<FoodItem> pool = [..._customCache!, ..._assetCache!];
    if (category != null && category != 'Tümü') {
      pool = pool.where((f) => f.category == category).toList();
    }

    if (query.trim().isEmpty) {
      return pool.take(280).toList();
    }

    final normalizedQuery = normalize(query);
    final queryTokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();

    final searchTerms = {normalizedQuery};
    _synonyms?.forEach((key, values) {
      if (normalize(key).contains(normalizedQuery)) {
        searchTerms.addAll(values.map(normalize));
      }
      for (final v in values) {
        if (normalize(v).contains(normalizedQuery)) {
          searchTerms.add(normalize(key));
        }
      }
    });

    final scoredItems = <_ScoredFood>[];

    for (final food in pool) {
      int score = 0;
      final nName = normalize(food.name);
      final nCategory = normalize(food.category);

      // 1) İsim: tam > başlangıç > kelime başı > içerik
      if (nName == normalizedQuery) {
        score += 100;
      } else if (nName.startsWith(normalizedQuery)) {
        score += 60;
      } else if (_wordStartsWith(nName, normalizedQuery)) {
        score += 50;
      } else if (nName.contains(normalizedQuery)) {
        score += 20;
      }

      // 2) Token bazlı (çok kelimeli sorgu): her token isimde geçiyorsa
      for (final token in queryTokens) {
        if (nName.contains(token)) score += 5;
        if (_wordStartsWith(nName, token)) score += 8;
      }

      // 3) Aliases: tam > başlangıç > içerik
      for (final alias in food.aliases) {
        final nAlias = normalize(alias);
        if (nAlias == normalizedQuery) {
          score += 40;
        } else if (nAlias.startsWith(normalizedQuery)) {
          score += 35;
        } else if (nAlias.contains(normalizedQuery)) {
          score += 15;
        } else if (_wordStartsWith(nAlias, normalizedQuery)) {
          score += 25;
        }
      }

      // 4) Tags: tam > içerik (tavuk yazınca "tavuk" tag'li tüm yemekler)
      for (final tag in food.tags) {
        final nTag = normalize(tag);
        if (nTag == normalizedQuery) {
          score += 30;
        } else if (nTag.contains(normalizedQuery) || normalizedQuery.contains(nTag)) {
          score += 15;
        }
      }

      // 5) Category: tam > içerik
      if (nCategory == normalizedQuery) {
        score += 25;
      } else if (nCategory.contains(normalizedQuery)) {
        score += 10;
      }

      // 6) Marka
      if (food.brand != null && normalize(food.brand!).contains(normalizedQuery)) {
        score += 15;
      }

      // 7) Eş anlamlı (synonym)
      if (score == 0) {
        for (final term in searchTerms) {
          if (nName.contains(term)) {
            score += 10;
            break;
          }
          for (final alias in food.aliases) {
            if (normalize(alias).contains(term)) {
              score += 10;
              break;
            }
          }
        }
      }

      // 8) Basit fuzzy: 1–2 harf hatası (makrna -> makarna)
      if (score == 0 && queryTokens.length == 1 && normalizedQuery.length >= 3) {
        final words = [...nName.split(RegExp(r'\s+'))];
        for (final a in food.aliases) {
          words.addAll(normalize(a).split(RegExp(r'\s+')));
        }
        for (final t in food.tags) {
          words.addAll(normalize(t).split(RegExp(r'\s+')));
        }
        for (final w in words) {
          if (w.length >= 2 && _fuzzyMatch(normalizedQuery, w)) {
            score += 12;
            break;
          }
        }
      }

      if (score > 0) {
        scoredItems.add(_ScoredFood(food, score));
      }
    }

    scoredItems.sort((a, b) => b.score.compareTo(a.score));
    return scoredItems.map((s) => s.item).toList();
  }

  @override
  Future<FoodItem?> getFoodById(String id) async {
    await _ensureLoaded();
    try {
      return _customCache!.firstWhere((f) => f.id == id, orElse: () {
        return _assetCache!.firstWhere((f) => f.id == id);
      });
    } catch (_) {
      return null;
    }
  }
}

class _ScoredFood {
  final FoodItem item;
  final int score;
  _ScoredFood(this.item, this.score);
}
