class ExerciseGuideMedia {
  final String startAsset;
  final String endAsset;
  final String attribution;

  const ExerciseGuideMedia({
    required this.startAsset,
    required this.endAsset,
    this.attribution = openTrainingAttribution,
  });

  List<String> get stageAssets => [
    startAsset,
    startAsset,
    endAsset,
    endAsset,
    startAsset,
  ];
}

const String openTrainingAttribution =
    'Açık lisanslı illüstrasyonlar: Everkinetic / OpenTraining (CC BY-SA 3.0).';

ExerciseGuideMedia? getExerciseGuideMedia(String normalizedExerciseName) {
  return _exerciseMediaCatalog[normalizedExerciseName];
}

ExerciseGuideMedia _pair(String startFile, String endFile) {
  const basePath = 'assets/exercise_guides/open_training/';
  return ExerciseGuideMedia(
    startAsset: '$basePath$startFile',
    endAsset: '$basePath$endFile',
  );
}

final Map<String, ExerciseGuideMedia> _exerciseMediaCatalog = {
  'arnold press': _pair('Arnold-press-1.png', 'Arnold-press-2.png'),
  'barbell curl': _pair('Biceps-curl-1.png', 'Biceps-curl-2.png'),
  'barbell row': _pair('T-bar-row-1.png', 'T-bar-row-2.png'),
  'bench dip': _pair('Bench-dips-1.png', 'Bench-dips-2.png'),
  'bench press': _pair('Bench-press-1.png', 'Bench-press-2.png'),
  'bulgarian split squat': _pair('Lunges-1.png', 'Lunges-2.png'),
  'cable crossover': _pair(
    'Incline-cable-flyes-1.png',
    'Incline-cable-flyes-2.png',
  ),
  'cable crunch': _pair('Crunches-1.png', 'Crunches-2.png'),
  'cable curl': _pair('High-cable-curls-1.png', 'High-cable-curls-2.png'),
  'cable kickback': _pair('Triceps-kickback-1.png', 'Triceps-kickback-2.png'),
  'cable lateral raise': _pair(
    'Dumbbell-lateral-raises-1.png',
    'Dumbbell-lateral-raises-2.png',
  ),
  'calf raise': _pair('Calf-raises-1.png', 'Calf-raises-2.png'),
  'chest supported row': _pair(
    'Cable-seated-rows-1.png',
    'Cable-seated-rows-2.png',
  ),
  'close grip bench press': _pair(
    'Narrow-grip-bench-press-1.png',
    'Narrow-grip-bench-press-2.png',
  ),
  'concentration curl': _pair(
    'Concentration-curls-1.png',
    'Concentration-curls-2.png',
  ),
  'crunch': _pair('Crunches-1.png', 'Crunches-2.png'),
  'dead bug': _pair('Bent-knee-hip-raise-1.png', 'Bent-knee-hip-raise-2.png'),
  'dips': _pair('Tricep-dips-1.png', 'Tricep-dips-2.png'),
  'dumbbell front raise': _pair(
    'Dumbbell-front-raises-1.png',
    'Dumbbell-front-raises-2.png',
  ),
  'face pull': _pair('Rear-deltoid-row-1.png', 'Rear-deltoid-row-2.png'),
  'frog pump': _pair('Bridge-1.png', 'Bridge-2.png'),
  'glute bridge': _pair('Bridge-1.png', 'Bridge-2.png'),
  'hammer curl': _pair('Bicep-hammer-curl-1.png', 'Bicep-hammer-curl-2.png'),
  'hip thrust': _pair('Bridge-1.png', 'Bridge-2.png'),
  'incline bench press': _pair('Bench-press-1.png', 'Bench-press-2.png'),
  'incline dumbbell curl': _pair(
    'Alternate-incline-curl-1.png',
    'Alternate-incline-curl-2.png',
  ),
  'incline dumbbell press': _pair('Bench-press-1.png', 'Bench-press-2.png'),
  'lat pulldown': _pair(
    'Close-grip-front-lat-pull-down-1.png',
    'Close-grip-front-lat-pull-down-2.png',
  ),
  'lateral raise': _pair(
    'Dumbbell-lateral-raises-1.png',
    'Dumbbell-lateral-raises-2.png',
  ),
  'leg curl': _pair('Standing-leg-curl-1.png', 'Standing-leg-curl-2.png'),
  'leg extension': _pair(
    'Leg-extensions-1-672x1024.png',
    'Leg-extensions-2-672x1024.png',
  ),
  'leg press': _pair('Leg-press-1-1024x670.png', 'Leg-press-2-1024x670.png'),
  'leg raise': _pair('Leg-raises-1.png', 'Leg-raises-2.png'),
  'machine chest press': _pair('Bench-press-1.png', 'Bench-press-2.png'),
  'mountain climber': _pair(
    'Exercise-ball-pull-in-1.png',
    'Exercise-ball-pull-in-2.png',
  ),
  'overhead cable extension': _pair(
    'One-arm-triceps-extension-1.png',
    'One-arm-triceps-extension-2.png',
  ),
  'overhead press': _pair(
    'One-arm-shoulder-press-1.png',
    'One-arm-shoulder-press-2.png',
  ),
  'pec fly': _pair('Dumbbell-flys-1.png', 'Dumbbell-flys-2.png'),
  'plank': _pair('Side-plank-1.png', 'Side-plank-2.png'),
  'preacher curl': _pair('Preacher-curl-3-1.png', 'Preacher-curl-3-2.png'),
  'pull up': _pair(
    'Gironda-sternum-chins-1.png',
    'Gironda-sternum-chins-2.png',
  ),
  'push up': _pair('Push-up-1.png', 'Push-up-2.png'),
  'rear delt fly': _pair(
    'Lying-rear-lateral-raise-1.png',
    'Lying-rear-lateral-raise-2.png',
  ),
  'reverse lunge': _pair('Lunges-1.png', 'Lunges-2.png'),
  'romanian deadlift': _pair(
    'Romanian-deadlift-1.png',
    'Romanian-deadlift-2.png',
  ),
  'russian twist': _pair('Cross-body-crunch-1.png', 'Cross-body-crunch-2.png'),
  'seated cable row': _pair(
    'Cable-seated-rows-1.png',
    'Cable-seated-rows-2.png',
  ),
  'single arm dumbbell extension': _pair(
    'One-arm-triceps-extension-1.png',
    'One-arm-triceps-extension-2.png',
  ),
  'single arm dumbbell row': _pair('T-bar-row-1.png', 'T-bar-row-2.png'),
  'skull crusher': _pair(
    'Lying-close-grip-triceps-press-to-chin-1.png',
    'Lying-close-grip-triceps-press-to-chin-2.png',
  ),
  'squat': _pair('Squats-1.png', 'Squats-2.png'),
  'step up': _pair('Step-ups-1-801x1024.png', 'Step-ups-2-801x1024.png'),
  'straight arm pulldown': _pair(
    'Close-grip-front-lat-pull-down-1.png',
    'Close-grip-front-lat-pull-down-2.png',
  ),
  'sumo squat': _pair('Squats-1.png', 'Squats-2.png'),
  't bar row': _pair('T-bar-row-1.png', 'T-bar-row-2.png'),
  'triceps pushdown': _pair(
    'Low-triceps-extension-1.png',
    'Low-triceps-extension-2.png',
  ),
  'upright row': _pair('Cable-upright-rows-1.png', 'Cable-upright-rows-2.png'),
  'walking lunge': _pair('Lunges-1.png', 'Lunges-2.png'),
};
