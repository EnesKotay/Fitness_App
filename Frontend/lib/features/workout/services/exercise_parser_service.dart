import '../../../core/models/exercise.dart';
import '../data/workout_catalog_data.dart';

class ExerciseParserService {
  /// Normalizes a raw muscle group string into a standard code.
  static String normalizeMuscleGroupCode(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final upper = value.toUpperCase();

    if (kMuscleGroupInfo.containsKey(upper)) return upper;

    const aliases = <String, String>{
      'GÖĞÜS': 'CHEST',
      'GOGUS': 'CHEST',
      'CHEST': 'CHEST',
      'SIRT': 'BACK',
      'BACK': 'BACK',
      'BACAK': 'LEGS',
      'QUADS': 'LEGS',
      'HAMSTRING': 'LEGS',
      'CALF': 'LEGS',
      'LEG': 'LEGS',
      'LEGS': 'LEGS',
      'OMUZ': 'SHOULDERS',
      'DELT': 'SHOULDERS',
      'TRAP': 'SHOULDERS',
      'SHOULDER': 'SHOULDERS',
      'SHOULDERS': 'SHOULDERS',
      'BİSEPS': 'BICEPS',
      'BISEPS': 'BICEPS',
      'BICEP': 'BICEPS',
      'BICEPS': 'BICEPS',
      'TRİCEPS': 'TRICEPS',
      'TRICEP': 'TRICEPS',
      'TRICEPS': 'TRICEPS',
      'KARIN': 'CORE',
      'CORE': 'CORE',
      'ABS': 'CORE',
      'KALÇA': 'GLUTES',
      'KALCA': 'GLUTES',
      'GLUTE': 'GLUTES',
      'GLUTES': 'GLUTES',
      'KARDİYO': 'CARDIO',
      'KARDIYO': 'CARDIO',
      'CARDIO': 'CARDIO',
      'HIIT': 'CARDIO',
      'ÖN KOL': 'FOREARMS',
      'ON KOL': 'FOREARMS',
      'FOREARM': 'FOREARMS',
      'FOREARMS': 'FOREARMS',
    };

    final direct = aliases[upper];
    if (direct != null) return direct;

    if (upper.contains('GÖĞ') || upper.contains('GOG')) return 'CHEST';
    if (upper.contains('SIRT') || upper.contains('BACK')) return 'BACK';
    if (upper.contains('BACAK') ||
        upper.contains('LEG') ||
        upper.contains('QUAD') ||
        upper.contains('HAMSTRING') ||
        upper.contains('CALF') ||
        upper.contains('BALDIR')) {
      return 'LEGS';
    }
    if (upper.contains('OMUZ') ||
        upper.contains('SHOUL') ||
        upper.contains('DELT') ||
        upper.contains('TRAP')) {
      return 'SHOULDERS';
    }
    if (upper.contains('BİS') ||
        upper.contains('BIS') ||
        upper.contains('BICEP')) {
      return 'BICEPS';
    }
    if (upper.contains('TRİ') ||
        upper.contains('TRI') ||
        upper.contains('TRICEP')) {
      return 'TRICEPS';
    }
    if (upper.contains('KARIN') ||
        upper.contains('ABS') ||
        upper.contains('CORE')) {
      return 'CORE';
    }
    if (upper.contains('KALÇ') ||
        upper.contains('KALC') ||
        upper.contains('GLUTE')) {
      return 'GLUTES';
    }
    if (upper.contains('KARD') ||
        upper.contains('HIIT') ||
        upper.contains('CARDIO')) {
      return 'CARDIO';
    }
    if (upper.contains('FOREARM') ||
        upper.contains('ÖN KOL') ||
        upper.contains('ON KOL')) {
      return 'FOREARMS';
    }

    return upper;
  }

  /// Normalizes search text for accurate matching
  static String normalizeSearchText(String input) {
    return input
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static bool containsToken(String text, String token) {
    final t = token.trim();
    if (t.isEmpty) return false;
    if (t.contains(' ')) return text.contains(t);
    final escaped = RegExp.escape(t);
    const suffix = r'([^a-z0-9]|$)';
    final pattern = RegExp('(^|[^a-z0-9])$escaped$suffix');
    return pattern.hasMatch(text);
  }

  static bool containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (containsToken(text, normalizeSearchText(n))) return true;
    }
    return false;
  }

  /// Detects the sub-region label for a given exercise and muscle group
  static String detectSubRegionLabel(Exercise exercise, String muscleGroup) {
    final text = normalizeSearchText(
      '${exercise.name} ${exercise.description ?? ''} ${exercise.instructions ?? ''}',
    );

    switch (muscleGroup) {
      case 'CHEST':
        if (containsAny(text, ['incline', 'upper', 'ust', 'clavicular'])) {
          return 'Üst Göğüs';
        }
        if (containsAny(text, ['decline', 'dip', 'alt', 'lower'])) {
          return 'Alt Göğüs';
        }
        if (containsAny(text, [
          'fly',
          'crossover',
          'pec deck',
          'pec fly',
          'svend',
        ])) {
          return 'İç Göğüs';
        }
        return 'Orta Göğüs';
      case 'BACK':
        if (containsAny(text, ['lat', 'pulldown', 'pull-up', 'pullup'])) {
          return 'Lat';
        }
        if (containsAny(text, [
          'lower back',
          'hip hinge',
          'deadlift',
          'back extension',
          'bel',
          'lumbar',
          'erector',
          'spinal',
          'hyperextension',
        ])) {
          return 'Alt Sırt';
        }
        if (containsAny(text, [
          'face pull',
          'rear',
          'upper back',
          'trap',
          'shrug',
          'scapula',
          'ust sirt',
          'trapez',
        ])) {
          return 'Üst Sırt';
        }
        return 'Orta Sırt';
      case 'LEGS':
        if (containsAny(text, [
          'curl',
          'romanian',
          'rdl',
          'hamstring',
          'arka',
        ])) {
          return 'Arka Bacak';
        }
        if (containsAny(text, ['calf', 'baldir'])) return 'Baldır';
        return 'Ön Bacak';
      case 'SHOULDERS':
        if (containsAny(text, ['front raise', 'front', 'on'])) {
          return 'Ön Omuz';
        }
        if (containsAny(text, ['rear', 'face pull', 'arka'])) {
          return 'Arka Omuz';
        }
        return 'Yan Omuz';
      case 'BICEPS':
        if (containsAny(text, [
          'hammer',
          'brachialis',
          'reverse',
          'neutral',
          'pronated',
        ])) {
          return 'Brachialis';
        }
        if (containsAny(text, [
          'incline',
          'narrow',
          'outer',
          'long head',
          'uzun',
          'drag',
        ])) {
          return 'Uzun Baş';
        }
        return 'Kısa Baş';
      case 'TRICEPS':
        if (containsAny(text, ['overhead', 'long head', 'uzun'])) {
          return 'Uzun Baş';
        }
        if (containsAny(text, ['pushdown', 'rope'])) return 'Lateral Baş';
        return 'Medial Baş';
      case 'CORE':
        if (containsAny(text, [
          'leg raise',
          'lower abs',
          'alt',
          'mountain',
          'scissor',
          'pulse',
          'hanging knee',
        ])) {
          return 'Alt Karın';
        }
        if (containsAny(text, [
          'twist',
          'oblique',
          'oblik',
          'wiper',
          'heel',
          'side crunch',
          'woodchopper',
          'side bend',
        ])) {
          return 'Oblik';
        }
        if (containsAny(text, [
          'plank',
          'dead bug',
          'stabil',
          'hollow',
          'l-sit',
          'bird dog',
          'suitcase',
        ])) {
          return 'Core Stabilite';
        }
        return 'Üst Karın';
      case 'GLUTES':
        if (containsAny(text, [
          'med',
          'abduction',
          'yan',
          'fire hydrant',
          'side lying',
          'abduction',
        ])) {
          return 'Glute Med';
        }
        if (containsAny(text, [
          'min',
          'mini',
          'clamshell',
          'lateral',
          'monster',
          'kickstand',
        ])) {
          return 'Glute Min';
        }
        return 'Glute Max';
      default:
        return 'Tümü';
    }
  }
}
