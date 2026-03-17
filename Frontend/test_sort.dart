void main() {
  String normalize(String input) {
    return input
        .toLowerCase()
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

  bool _wordStartsWith(String text, String query) {
    if (query.isEmpty) return false;
    final idx = text.indexOf(query);
    if (idx < 0) return false;
    if (idx == 0) return true;
    return text[idx - 1] == ' ' || text[idx - 1] == '\t';
  }

  int scoreFood(String name, String? brand, List<String> aliases, List<String> tags, String query) {
     int score = 0;
      final normalizedQuery = normalize(query);
      final queryTokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
      final nName = normalize(name);
      final nBrand = brand == null ? null : normalize(brand);

      if (nName == normalizedQuery) {
        score += 100;
      } else if (nName.startsWith(normalizedQuery)) {
        score += 60;
      } else if (_wordStartsWith(nName, normalizedQuery)) {
        score += 50;
      } else if (nName.contains(normalizedQuery)) {
        score += 20;
      }

      for (final token in queryTokens) {
        if (nName.contains(token)) score += 5;
        if (_wordStartsWith(nName, token)) score += 8;
      }

      int maxAliasScore = 0;
      for (final alias in aliases) {
        int currentAliasScore = 0;
        final nAlias = normalize(alias);
        if (nAlias == normalizedQuery) {
          currentAliasScore = 40;
        } else if (nAlias.startsWith(normalizedQuery)) {
          currentAliasScore = 35;
        } else if (nAlias.contains(normalizedQuery)) {
          currentAliasScore = 15;
        } else if (_wordStartsWith(nAlias, normalizedQuery)) {
          currentAliasScore = 25;
        }
        if (currentAliasScore > maxAliasScore) {
            maxAliasScore = currentAliasScore;
        }
      }
      score += maxAliasScore;

      int maxTagScore = 0;
      for (final tag in tags) {
        int currentTagScore = 0;
        final nTag = normalize(tag);
        if (nTag == normalizedQuery) {
          currentTagScore = 30;
        } else if (nTag.contains(normalizedQuery) ||
            normalizedQuery.contains(nTag)) {
          currentTagScore = 15;
        }
        if (currentTagScore > maxTagScore) {
            maxTagScore = currentTagScore;
        }
      }
      score += maxTagScore;

      if (nBrand != null && nBrand.contains(normalizedQuery)) {
        score += 15;
      }

      final queryMentionsBrand = nBrand != null && normalizedQuery.contains(nBrand);
      final isGenericQuery = !queryMentionsBrand;

      if (score > 0 && isGenericQuery) {
        if (brand == null || brand.trim().isEmpty) {
          score += 18;
          if (nName.startsWith(normalizedQuery)) {
            score += 14;
          }
        } else {
          score -= 22;
        }
      }
      return score;
  }

  final scoreUstaDonerci = scoreFood("Usta Dönerci Et Döner Dürüm", "Usta Dönerci", ["et döner dürüm", "döner dürüm", "döner"], ["et", "döner", "dürüm", "fastfood"], "döner");
  final scoreEtDoner = scoreFood("Et Döner", null, ["döner", "yaprak döner"], ["et", "türk mutfağı"], "döner");
  final scoreDonerPorsiyon = scoreFood("Döner (Porsiyon)", null, ["döner"], ["et", "türk mutfağı"], "döner");
  
  print("Usta Donerci Score: $scoreUstaDonerci");
  print("Et Doner Score: $scoreEtDoner");
  print("Doner Porsiyon Score: $scoreDonerPorsiyon");
}
