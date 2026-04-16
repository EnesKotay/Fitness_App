/// Kas grubu kodlarını normalize eden ortak yardımcı fonksiyon.
/// workout_screen.dart ve add_workout_page.dart'ta tekrar tanımalanmaması için buraya taşındı.
String normalizeMuscleGroupCode(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  final upper = value.toUpperCase();

  const knownCodes = {
    'CHEST', 'BACK', 'LEGS', 'SHOULDERS', 'BICEPS', 'TRICEPS', 'CORE', 'GLUTES',
  };
  if (knownCodes.contains(upper)) return upper;

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

  return upper;
}
