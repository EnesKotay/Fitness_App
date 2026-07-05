import '../../../core/models/exercise.dart';
import '../data/workout_catalog_data.dart';

/// Yerel egzersiz kataloğu üzerinde ad eşleştirme indeksi.
///
/// AI Coach mesajlarındaki egzersiz adlarını (ör. "Barbell Squat",
/// "Romanian Deadlift (RDL)") uygulamanın yerel antrenman veritabanıyla
/// (workout_catalog_data.dart) eşleştirir ve markdown metnindeki adları
/// tıklanabilir hale getirmek için `**...**` ile sarar.
class ExerciseCatalogMatch {
  final Exercise exercise;
  final String group; // ör. 'LEGS'

  const ExerciseCatalogMatch(this.exercise, this.group);

  MuscleGroupInfo? get groupInfo => kMuscleGroupInfo[group];
}

class ExerciseCatalogIndex {
  ExerciseCatalogIndex._() {
    _build();
  }

  static final ExerciseCatalogIndex instance = ExerciseCatalogIndex._();

  /// normalize(ad) -> eşleşme
  final Map<String, ExerciseCatalogMatch> _byName = {};

  /// Uzunluğa göre (uzun önce) sıralı normalize adlar — containment için.
  late final List<String> _namesByLengthDesc;

  late final RegExp _namePattern;

  /// Yaygın takma adlar / Türkçe karşılıklar → katalogtaki normalize ad.
  static const Map<String, String> _aliases = {
    'rdl': 'romanian deadlift',
    'barbell squat': 'squat',
    'back squat': 'squat',
    'sinav': 'push-up',
    'push up': 'push-up',
    'pushup': 'push-up',
    'barfiks': 'pull-up',
    'pull up': 'pull-up',
    'pullup': 'pull-up',
    'mekik': 'crunch',
    'ip atlama': 'jump rope',
  };

  void _build() {
    for (final group in kMuscleGroupInfo.keys) {
      for (final exercise in buildExerciseCatalogForGroup(group)) {
        final key = normalize(exercise.name);
        if (key.isEmpty) continue;
        // İlk giren kazanır (fallback listesi extras'tan önce gelir).
        _byName.putIfAbsent(key, () => ExerciseCatalogMatch(exercise, group));
      }
    }
    _namesByLengthDesc = _byName.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    // Regex: katalog adları + alias yüzey biçimleri, uzun olan önce.
    final surfaces = <String>{
      ..._byName.values.map((m) => m.exercise.name),
      'Barbell Squat',
      'Back Squat',
      'RDL',
      'Şınav',
      'Sınav',
      'Barfiks',
      'Mekik',
      'Push Up',
      'Pull Up',
    }.toList()..sort((a, b) => b.length.compareTo(a.length));

    final body = surfaces.map(RegExp.escape).join('|');
    // Harf/rakam bitişikse eşleşme (kelime ortası) engellenir.
    _namePattern = RegExp(
      '(?<![A-Za-z0-9ıİğĞüÜşŞöÖçÇ])($body)(?![A-Za-z0-9ıİğĞüÜşŞöÖçÇ])',
      caseSensitive: false,
    );
  }

  /// Türkçe karakterleri sadeleştirip küçük harfe indirir.
  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('̇', '') // 'İ'.toLowerCase() → 'i' + combining dot
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\- ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Serbest metin etiketini (ör. "Romanian Deadlift (RDL): 3 set")
  /// katalogtaki bir egzersize çözümler; bulunamazsa null döner.
  ExerciseCatalogMatch? resolve(String label) {
    var text = label.trim();
    if (text.isEmpty) return null;

    // Set/tekrar kuyruklarını ve parantezleri at.
    final withoutParens = text.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    final candidates = <String>[
      withoutParens,
      text,
      ...RegExp(r'\(([^)]+)\)')
          .allMatches(text)
          .map((m) => m.group(1) ?? '')
          .where((s) => s.isNotEmpty),
    ];

    for (final candidate in candidates) {
      final n = normalize(candidate);
      if (n.length < 3) continue;

      // 1) Alias
      final aliased = _aliases[n];
      if (aliased != null && _byName.containsKey(aliased)) {
        return _byName[aliased];
      }
      // 2) Birebir ad
      final exact = _byName[n];
      if (exact != null) return exact;
      // 3) Katalog adı etiketin içinde geçiyor (en uzun ad kazanır)
      for (final name in _namesByLengthDesc) {
        if (name.length < 4) continue;
        if (_containsWord(n, name)) return _byName[name];
      }
    }
    return null;
  }

  bool _containsWord(String haystack, String needle) {
    final idx = haystack.indexOf(needle);
    if (idx < 0) return false;
    final before = idx - 1;
    final after = idx + needle.length;
    final okBefore = before < 0 || haystack[before] == ' ';
    final okAfter = after >= haystack.length || haystack[after] == ' ';
    return okBefore && okAfter;
  }

  /// Mesaj metnindeki katalogla eşleşen egzersiz adlarını `**...**` ile
  /// sararak tıklanabilir hale getirir. Halihazırda kalın olan bölümlere
  /// dokunmaz.
  String linkify(String text) {
    if (text.isEmpty) return text;

    // Mevcut **...** aralıklarını işaretle.
    final boldRanges = RegExp(r'\*\*.*?\*\*', dotAll: true)
        .allMatches(text)
        .map((m) => (m.start, m.end))
        .toList();

    bool insideBold(int start, int end) {
      for (final (bs, be) in boldRanges) {
        if (start < be && end > bs) return true;
      }
      return false;
    }

    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in _namePattern.allMatches(text)) {
      if (insideBold(match.start, match.end)) continue;
      // Katalogda gerçekten çözümlenemiyorsa sarma.
      if (resolve(match.group(0)!) == null) continue;
      buffer
        ..write(text.substring(cursor, match.start))
        ..write('**')
        ..write(match.group(0))
        ..write('**');
      cursor = match.end;
    }
    if (cursor == 0) return text;
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }
}
