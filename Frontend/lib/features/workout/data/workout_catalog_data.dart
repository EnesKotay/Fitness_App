import 'package:flutter/material.dart';

import '../../../core/models/exercise.dart';

typedef MuscleGroupInfo = ({
  String label,
  Color color,
  IconData icon,
  String imageUrl,
});

const Map<String, MuscleGroupInfo> kMuscleGroupInfo = {
  'CHEST': (
    label: 'Göğüs',
    color: Color(0xFFE53935),
    icon: Icons.fitness_center,
    imageUrl: 'assets/images/workout_chest.png',
  ),
  'BACK': (
    label: 'Sırt',
    color: Color(0xFF7B1FA2),
    icon: Icons.back_hand,
    imageUrl: 'assets/images/workout_back.png',
  ),
  'LEGS': (
    label: 'Bacak',
    color: Color(0xFF1976D2),
    icon: Icons.directions_walk,
    imageUrl: 'assets/images/workout_legs.png',
  ),
  'SHOULDERS': (
    label: 'Omuz',
    color: Color(0xFF00897B),
    icon: Icons.accessibility_new,
    imageUrl: 'assets/images/region_shoulders.jpg',
  ),
  'BICEPS': (
    label: 'Biseps',
    color: Color(0xFF43A047),
    icon: Icons.sports_martial_arts,
    imageUrl: 'assets/images/region_arms.jpg',
  ),
  'TRICEPS': (
    label: 'Triceps',
    color: Color(0xFFFB8C00),
    icon: Icons.sports,
    imageUrl: 'assets/images/region_arms.jpg',
  ),
  'CORE': (
    label: 'Karın',
    color: Color(0xFF00ACC1),
    icon: Icons.self_improvement,
    imageUrl: 'assets/images/region_core.jpg',
  ),
  'GLUTES': (
    label: 'Kalça',
    color: Color(0xFFE91E63),
    icon: Icons.directions_run,
    imageUrl: 'assets/images/region_legs.jpg',
  ),
};

const Map<String, List<String>> kSubRegionFilters = {
  'CHEST': ['Tümü', 'Üst Göğüs', 'Orta Göğüs', 'Alt Göğüs', 'İç Göğüs'],
  'BACK': ['Tümü', 'Üst Sırt', 'Orta Sırt', 'Alt Sırt', 'Lat'],
  'LEGS': ['Tümü', 'Ön Bacak', 'Arka Bacak', 'Baldır'],
  'SHOULDERS': ['Tümü', 'Ön Omuz', 'Yan Omuz', 'Arka Omuz'],
  'BICEPS': ['Tümü', 'Uzun Baş', 'Kısa Baş', 'Brachialis'],
  'TRICEPS': ['Tümü', 'Uzun Baş', 'Lateral Baş', 'Medial Baş'],
  'CORE': ['Tümü', 'Üst Karın', 'Alt Karın', 'Oblik', 'Core Stabilite'],
  'GLUTES': ['Tümü', 'Glute Max', 'Glute Med', 'Glute Min'],
};

const Map<String, List<String>> kMassExerciseNames = {
  'CHEST': [
    'Floor Press',
    'Spoto Press',
    'Landmine Chest Press',
    'Weighted Push-Up',
    'Archer Push-Up',
    'High-to-Low Cable Fly',
    'Low-to-High Cable Crossover',
    'Smith Machine Incline Press',
    'Pause Bench Press',
    'Single Arm Chest Press',
    'Incline Machine Press',
    'Guillotine Press',
    'Svend Press',
    'Incline Dumbbell Fly',
    'Decline Dumbbell Press',
    'Decline Cable Fly',
    'Decline Push-Up',
    'Push-Up Plus',
    'Deficit Push-Up',
    'Hex Press',
  ],
  'BACK': [
    'Kelso Shrug',
    'Barbell Pullover',
    'Gorilla Row',
    'Meadows Row',
    'Reverse Grip Barbell Row',
    'Inverted Row',
    'Pendlay Row',
    'Machine High Row',
    'Straight Arm Rope Pulldown',
    'Seal Row',
    'Barbell Shrug (Ust Sirt)',
    'Dumbbell Shrug (Ust Sirt)',
    'Snatch Grip High Pull (Ust Sirt)',
    "Farmer's Walk (Ust Sirt)",
    'Upright Row (Ust Sirt)',
    'Deadlift (Alt Sirt)',
    'Deficit Deadlift (Alt Sirt)',
    'Rack Pull (Alt Sirt)',
    'Back Extension (Alt Sirt)',
    'Superman (Alt Sirt)',
    'Reverse Hyper (Alt Sirt)',
    'Jefferson Curl (Alt Sirt)',
    'Neutral Grip Pull-Up',
    'Underhand Pulldown',
    'Wide Grip Lat Pulldown',
    'Close Grip Cable Row',
    'Dumbbell Row',
    'Kroc Row',
    'Yates Row',
    'Good Morning',
    'Prone Cobra',
    'Single Arm Cable Row',
    'Helms Row',
  ],
  'LEGS': [
    'Zercher Squat',
    'Spanish Squat',
    'Cossack Squat',
    'Heel Elevated Squat',
    'Hack Squat',
    'Seated Calf Raise',
    'Front Squat',
    'Sissy Squat',
    'Good Morning',
    'Nordic Curl',
    'Standing Calf Raise',
    'Split Squat',
    'Goblet Squat',
    'Box Squat',
    'Jefferson Squat',
    'Step Down',
    'Cyclist Squat',
    'Pistol Squat',
    'Lying Leg Curl',
    'Seated Leg Curl',
    'Single Leg Romanian Deadlift',
    'Glute Ham Raise',
    'Donkey Calf Raise',
    'Calf Press',
    'Pendulum Squat',
  ],
  'SHOULDERS': [
    'Z-Press',
    'Klokov Press',
    'Push Press',
    'Viking Press',
    'Bus Driver',
    'Seated Dumbbell Press',
    'Pec Deck Rear Delt Fly',
    'Machine Shoulder Press',
    'Lean Away Lateral Raise',
    'Rear Delt Cable Fly',
    'Landmine Press',
    'Y-Raise',
    'Bradford Press',
    'Cable Front Raise',
    'Cable Upright Row',
    'Plate Front Raise',
    'Dumbbell Cuban Press',
    'Machine Rear Delt Fly',
    'Barbell Overhead Press',
    'Alternating Front Raise',
    'Leaning Cable Lateral Raise',
    'Rear Delt Row',
    'Bent Over Rear Delt Raise',
    'Reverse Pec Deck',
    'Egyptian Lateral Raise',
    'Lu Raise',
  ],
  'BICEPS': [
    'Drag Curl (Uzun Bas)',
    'Narrow Grip Barbell Curl (Uzun Bas)',
    'Incline Dumbbell Curl (Uzun Bas)',
    'Outer Head Cable Curl (Uzun Bas)',
    'Hammer Curl (Brachialis)',
    'Reverse Grip EZ Bar Curl (Brachialis)',
    'Cross Body Hammer Curl (Brachialis)',
    'Pinwheel Curl (Brachialis)',
    'Zottman Curl (Brachialis)',
    'Waiters Curl',
  ],
  'TRICEPS': [
    'California Press',
    'French Press',
    'Katana Extension',
    'Tate Press',
    'JM Press',
    'Rope Pushdown',
    'Reverse Grip Pushdown',
    'Overhead Dumbbell Extension',
    'Cable Kickback',
    'Dip Machine',
    'Diamond Push-Up',
    'Single Arm Rope Pushdown',
    'Lying Dumbbell Extension',
    'Cable Overhead Rope Extension',
    'Machine Triceps Extension',
    'Straight Bar Pushdown',
    'V-Bar Pushdown',
    'Overhead Rope Extension',
    'Single Arm Overhead Extension',
    'Lying EZ Extension',
    'Parallel Bar Dip',
    'Cross-Body Cable Extension',
  ],
  'CORE': [
    'Dragon Flag (Core Stabilite)',
    'L-Sit (Core Stabilite)',
    'Hollow Body Hold (Core Stabilite)',
    'Suitcase Carry (Core Stabilite)',
    'Pallof Press (Core Stabilite)',
    'Ab Wheel Rollout (Core Stabilite)',
    'Bird Dog (Core Stabilite)',
    'Stir the Pot (Core Stabilite)',
    'Hanging Leg Raise (Alt Karin)',
    "Captain's Chair Leg Raise (Alt Karin)",
    'Scissor Kicks (Alt Karin)',
    'Mountain Climbers (Alt Karin)',
    'Pulse Up (Alt Karin)',
    'Reverse Crunch (Alt Karin)',
    'Hanging Knee Raise (Alt Karin)',
    'Flutter Kick (Alt Karin)',
    'Russian Twist (Oblik)',
    'Windshield Wipers (Oblik)',
    'Side Crunch (Oblik)',
    'Heel Touch (Oblik)',
    'Cable Woodchopper (Oblik)',
    'Side Plank (Oblik)',
    'Side Bend (Oblik)',
    'Bicycle Crunch (Oblik)',
    'Toe Touch Crunch',
    'Sit-Up',
    'V-Up',
    'Weighted Crunch',
    'Machine Crunch',
    'Decline Sit-Up',
  ],
  'GLUTES': [
    'Barbell Hip Thrust (Glute Max)',
    'Barbell Glute Bridge (Glute Max)',
    'Romanian Deadlift (Glute Max)',
    'Sumo Deadlift (Glute Max)',
    'Kas Glute Bridge (Glute Max)',
    'Single Leg Hip Thrust (Glute Max)',
    'B-Stance Hip Thrust (Glute Max)',
    'Fire Hydrant (Glute Med)',
    'Side Lying Leg Abduction (Glute Med)',
    'Cable Hip Abduction (Glute Med)',
    'Glute Medius Kickback (Glute Med)',
    'Curtsy Lunge (Glute Med)',
    'Side Plank Leg Lift (Glute Med)',
    'Banded Clamshell (Glute Min)',
    'Lateral Band Walk (Glute Min)',
    'Monster Walk (Glute Min)',
    'Kickstand Romanian Deadlift (Glute Min)',
    'Frog Bridge',
    'Step-Up to Knee Drive',
    'Deficit Reverse Lunge',
    'Quadruped Kickback',
    'Cable Kickback',
    'Deficit Split Squat',
  ],
};

List<Exercise> buildExerciseCatalogForGroup(String group) {
  final fallbacks = fallbackExercisesForGroup(group);
  final extras = extraExercisesForGroup(group);
  final combined = <Exercise>[...fallbacks];
  final seenNames = {for (final e in fallbacks) e.name.toLowerCase().trim()};

  for (final exercise in extras) {
    final name = exercise.name.toLowerCase().trim();
    if (seenNames.add(name)) {
      combined.add(exercise);
    }
  }
  return combined;
}

List<Exercise> extraExercisesForGroup(String group) {
  final names = kMassExerciseNames[group] ?? const [];
  final baseId = switch (group) {
    'CHEST' => 9300,
    'BACK' => 9400,
    'LEGS' => 9500,
    'SHOULDERS' => 9600,
    'BICEPS' => 9700,
    'TRICEPS' => 9800,
    'CORE' => 9900,
    'GLUTES' => 10000,
    _ => 10100,
  };
  return List<Exercise>.generate(names.length, (index) {
    final name = names[index];
    final meta = specificExerciseMetadata(name);
    return Exercise(
      id: baseId + index,
      muscleGroup: group,
      name: name,
      description: meta['desc'] ?? defaultExerciseDescriptionForGroup(group),
      instructions: meta['inst'] ?? defaultExerciseInstruction(name),
    );
  });
}

Map<String, String> specificExerciseMetadata(String name) {
  final n = name.toLowerCase();
  if (n.contains('floor press')) {
    return {
      'desc': 'Yerde yapilan, triceps ve orta gogus odakli pres hareketidir.',
      'inst':
          'Sirt ustu yere yat. Dirsekler yere degerken kontrol kur ve barı yukari it. 3 set 8-12 tekrar.',
    };
  }
  if (n.contains('spoto press')) {
    return {
      'desc': 'Gogse degmeden beklemeli bench press varyasyonudur.',
      'inst':
          'Bari gogsun 2-3 cm uzerinde 1 saniye bekletip kontrollu sekilde it. 3 set 6-8 tekrar.',
    };
  }
  if (n.contains('shrug')) {
    return {
      'desc': 'Ust trapez kaslarini izole eden temel harekettir.',
      'inst':
          'Omuzlarini kulaklara dogru cek, zirvede kisa bir sure bekle ve yavas birak. 4 set 12-15 tekrar.',
    };
  }
  if (n.contains('deadlift')) {
    return {
      'desc': 'Tum vucut kuvveti ve alt sirt icin temel bilesik harekettir.',
      'inst':
          'Sirtini notr tut, kalcadan menteşelen ve agirligi yerden kontrollu kaldir. 3 set 5-8 tekrar.',
    };
  }
  if (n.contains('superman')) {
    return {
      'desc': 'Alt sirt ve erector spinae kaslarini guclendirir.',
      'inst':
          'Yuz ustu yat, kol ve bacaklarini ayni anda yukari kaldirip 2 sn bekle. 3 set 15 tekrar.',
    };
  }
  if (n.contains("farmer's walk")) {
    return {
      'desc': 'Grip kuvveti, core ve ust sirt stabilitesi saglar.',
      'inst':
          'Agir dumbbelllari iki eline al ve dik posturle 30-45 saniye yuru. 3 set.',
    };
  }
  if (n.contains('reverse hyper')) {
    return {
      'desc':
          'Alt sirti dekomprese ederken glute ve hamstringleri de calistirir.',
      'inst':
          'Govdeyi sabitle, bacaklarini kalcani sikip geriye-yukari kaldir. 3 set 12-15 tekrar.',
    };
  }
  if (n.contains('zercher squat')) {
    return {
      'desc':
          'Barin dirsek iclerinde tasindigi, core ve bacak odakli squat varyasyonudur.',
      'inst':
          'Bari dirseklerine al, govde dikligini koruyarak kontrollu squat yap. 3 set 8-10 tekrar.',
    };
  }
  if (n.contains('nordic curl')) {
    return {
      'desc':
          'Arka bacak eksantrik kuvveti icin en etkili hareketlerden biridir.',
      'inst':
          'Diz cok, ayaklarini sabitle. Govdeni mumkun oldugunca yavas one birak. 3 set 5-8 tekrar.',
    };
  }
  if (n.contains('cossack squat')) {
    return {
      'desc': 'Kalca mobilitesi ve bacak kuvveti icin yanal squat hareketidir.',
      'inst':
          'Genis dur, bir bacagin uzerine cokerken digerini duz tut. 3 set 10 tekrar/yan.',
    };
  }
  if (n.contains('zottman curl')) {
    return {
      'desc':
          'Biceps ve on kolu ayni anda hedefleyen ozel kivirma hareketidir.',
      'inst':
          'Yukari normal curl yap, tepede bileklerini cevirip yavas indir. 3 set 10-12 tekrar.',
    };
  }
  if (n.contains('katana extension')) {
    return {
      'desc': 'Triceps uzun basini maksimum gerimde calistirir.',
      'inst':
          'Kabloyu bas arkasindan capraz aciyla yukari-disa uzat. 3 set 12-15 tekrar.',
    };
  }
  if (n.contains('tate press')) {
    return {
      'desc': 'Triceps lateral basini hedefleyen izolasyon presidir.',
      'inst':
          'Dumbbelllari gogus hizasinda birbirine bakacak sekilde tut ve yukari it. 3 set 12 tekrar.',
    };
  }
  if (n.contains('drag curl')) {
    return {
      'desc':
          'Biceps uzun basini hedeflemek icin barin vucuda surtulerek cekildigi harekettir.',
      'inst':
          'Bari vucuduna yakin tut, dirseklerini geriye cekerek yukari surukle. 3 set 10-12 tekrar.',
    };
  }
  if (n.contains('narrow grip barbell curl')) {
    return {
      'desc': 'Dar tutus sayesinde biceps dis basini daha fazla hedefler.',
      'inst':
          'Bari omuz genisliginden dar tut, dirseklerini sabitleyip kivir. 3 set 8-12 tekrar.',
    };
  }
  if (n.contains('incline dumbbell curl')) {
    return {
      'desc':
          'Biceps uzun basini maksimum gerimde calistiran etkili harekettir.',
      'inst':
          'Eğimli benchte otur, kollarini tam sarkit ve dirsekleri oynatmadan curl yap. 4 set 10-12 tekrar.',
    };
  }
  if (n.contains('hammer curl')) {
    return {
      'desc':
          'Biceps ve brachialis kaslarini hedefleyen notr tutuslu harekettir.',
      'inst':
          'Avuc icleri birbirine bakacak sekilde dumbbelllari omuzlara dogru kivir. 3 set 12-15 tekrar.',
    };
  }
  if (n.contains('reverse grip ez bar curl')) {
    return {
      'desc': 'On kol ve brachialis kaslarini ustten tutusla calistirir.',
      'inst':
          'EZ bari ustten tut, kontrollu sekilde yukari kaldirip yavas indir. 3 set 12-15 tekrar.',
    };
  }
  if (n.contains('pinwheel curl')) {
    return {
      'desc': 'Brachialis icin hammer curlun capraz varyasyonudur.',
      'inst':
          'Dumbbelli capraz sekilde karsi omuza dogru cek. 3 set 12 tekrar.',
    };
  }
  if (n.contains('dragon flag')) {
    return {
      'desc':
          'Ileri seviye core kuvveti gerektiren premium bir karın hareketidir.',
      'inst':
          'Banktan destek al, vucudunu duz bir sopa gibi yukari kaldirip kontrollu indir. 3 set.',
    };
  }
  if (n.contains('l-sit')) {
    return {
      'desc': 'Izometrik core kuvveti ve omuz stabilitesi saglar.',
      'inst':
          'Ellerinle destek al, bacaklarini duz sekilde one uzatip bekle. 3 set.',
    };
  }
  if (n.contains('suitcase carry')) {
    return {
      'desc': 'Oblikler ve rotasyonel stabilite icin tek tarafli tasimadir.',
      'inst':
          'Tek eline agir bir yuk al, vucudun yana egilmeden dik yuru. 3 set 40 sn/taraf.',
    };
  }
  if (n.contains("captain's chair leg raise")) {
    return {
      'desc':
          'Alt karin kaslarini izole eden, beli destekleyen hareketlerden biridir.',
      'inst':
          'Sirtini destege yasla, dirsekleri sabitle ve bacaklarini kontrollu sekilde yukari kaldir. 3 set 12-15 tekrar.',
    };
  }
  if (n.contains('scissor kicks')) {
    return {
      'desc': 'Alt karin ve merkez bolgesini ritmik sekilde calistirir.',
      'inst':
          'Yere yat, bacaklarini sira ile makas gibi yukari-asagi hareket ettir. 3 set 45 sn.',
    };
  }
  if (n.contains('mountain climbers')) {
    return {
      'desc': 'Hem core kuvveti hem nabiz artisi saglayan dinamik harekettir.',
      'inst':
          'Push-up pozisyonunda basla, dizleri sirayla gogse hizla cek. 3 set 45 sn.',
    };
  }
  if (n.contains('pulse up')) {
    return {
      'desc':
          'Alt karin kaslarinin alt kisimlarini hedefleyen dikey itis hareketidir.',
      'inst':
          'Sirt ustu yat, bacaklarini havaya kaldir ve kalcani yerden kisaca yukari it. 3 set 15 tekrar.',
    };
  }
  if (n.contains('russian twist')) {
    return {
      'desc': 'Yan karin kaslarini ve rotasyonel kuvveti gelistirir.',
      'inst':
          'Yere otur, govdeyi hafif geri al ve agirligi saga-sola kontrollu dokundur. 3 set 20-30 tekrar.',
    };
  }
  if (n.contains('windshield wipers')) {
    return {
      'desc': 'Oblikler icin ileri seviye yanal bacak hareketidir.',
      'inst':
          'Bacaklarini havaya kaldirip kontrolle saga sola yatir. 3 set 10-12 tekrar.',
    };
  }
  if (n.contains('side crunch')) {
    return {
      'desc': 'Yan karin kaslarini izole ederek sıkistirma saglar.',
      'inst':
          'Yan yat, dirsegini kalcana dogru cekerek oblikleri sikistir. 3 set 15 tekrar/yan.',
    };
  }
  if (n.contains('heel touch')) {
    return {
      'desc':
          'Oblikleri ve karin yanlarini basit ama etkili bicimde calistirir.',
      'inst':
          'Sirt ustu yat, dizler bükulu. Govdeyi yana bukerek ellerinle topuklara uzan. 3 set 30 tekrar.',
    };
  }
  if (n.contains('fire hydrant')) {
    return {
      'desc':
          'Kalca yan kaslarini aktive eden ve mobiliteyi destekleyen harekettir.',
      'inst':
          'Emekleme pozisyonunda dizini yana 90 derece aciyla kaldir ve yavas indir. 3 set 15 tekrar/yan.',
    };
  }
  if (n.contains('side lying leg abduction')) {
    return {
      'desc':
          'Kalca stabilizasyonu ve yan kalca formu icin temel izolasyon hareketidir.',
      'inst':
          'Yan yat, ustteki bacagi duz yukari kaldir ve kontrollu indir. 3 set 15-20 tekrar/yan.',
    };
  }
  if (n.contains('clamshell')) {
    return {
      'desc':
          'Kalca dis rotasyon kuvveti ve glute med aktivasyonu icin etkilidir.',
      'inst':
          'Yan yat, dizler bükulu. Topuklar birlesikken ust dizi yukari ac. 3 set 15 tekrar/yan.',
    };
  }
  if (n.contains('lateral band walk')) {
    return {
      'desc': 'Kalca stabilitesi ve yan kalca kaslari icin dinamik yuruyustur.',
      'inst':
          'Dizlere band tak, hafif squat pozisyonunda yana dogru kisa adimlar at. 3 set 15 adim/taraf.',
    };
  }
  return {};
}

String defaultExerciseDescriptionForGroup(String group) {
  return switch (group) {
    'CHEST' => 'Göğüs kaslarını hedefleyen destek egzersizidir.',
    'BACK' => 'Sırt kaslarını güçlendirmeye yardımcı egzersizdir.',
    'LEGS' => 'Bacak kuvveti ve dayanıklılığı için etkili egzersizdir.',
    'SHOULDERS' => 'Omuz stabilitesi ve hacmi için tamamlayıcı egzersizdir.',
    'BICEPS' => 'Biseps kaslarını izole etmeye yönelik egzersizdir.',
    'TRICEPS' => 'Triceps gelişimi ve kol itiş gücü için uygundur.',
    'CORE' => 'Karın bölgesi kontrolunu artıran denge odaklı egzersizdir.',
    'GLUTES' => 'Kalça kaslarını aktive ederek güç üretimini artırır.',
    _ => 'Hedef kas grubuna yönelik yardımcı egzersizdir.',
  };
}

String defaultExerciseInstruction(String name) {
  return '$name hareketini kontrollü formda uygula. 3-4 set, 8-15 tekrar aralığında çalış.';
}

List<Exercise> fallbackExercisesForGroup(String group) {
  switch (group) {
    case 'CHEST':
      return [
        Exercise(
          id: 9001,
          muscleGroup: 'CHEST',
          name: 'Pec Fly',
          description: 'Gogus ic ve orta bolgesini izole calistirir.',
          instructions:
              'Makineye otur. Kollari omuz hizasinda one kapat. 3 set 12 tekrar.',
        ),
        Exercise(
          id: 9002,
          muscleGroup: 'CHEST',
          name: 'Bench Press',
          description: 'Gogus, on omuz ve triceps icin temel itis hareketi.',
          instructions:
              'Bari gogus hizasina indir, kontrollu sekilde it. 4 set 6-10 tekrar.',
        ),
        Exercise(
          id: 9003,
          muscleGroup: 'CHEST',
          name: 'Incline Dumbbell Press',
          description: 'Ust gogus gelisimi icin egimli pres hareketi.',
          instructions:
              '30-45 derece egimde dumbbell ile press yap. 3 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9004,
          muscleGroup: 'CHEST',
          name: 'Incline Bench Press',
          description: 'Ust gogus ve on omuz icin guclu bilesik hareket.',
          instructions:
              'Eğimli benchte bari kontrollu indirip it. 4 set 6-10 tekrar.',
        ),
        Exercise(
          id: 9005,
          muscleGroup: 'CHEST',
          name: 'Cable Crossover',
          description: 'Goguste sikisma hissini artiran izolasyon hareketi.',
          instructions:
              'Kablolari yarim daire cizerek onde birlestir. 3 set 12-15 tekrar.',
        ),
        Exercise(
          id: 9006,
          muscleGroup: 'CHEST',
          name: 'Push-Up',
          description:
              'Vucut agirligiyla gogus gelistirmek icin temel hareket.',
          instructions:
              'Govde duz, gogsu yere yaklastirip it. 3 set maksimum tekrar.',
        ),
        Exercise(
          id: 9007,
          muscleGroup: 'CHEST',
          name: 'Dips (Chest Lean)',
          description: 'Alt gogus odakli zorlayici itis hareketi.',
          instructions:
              'Govdeyi hafif one egip kontrollu in-cik yap. 3 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9008,
          muscleGroup: 'CHEST',
          name: 'Machine Chest Press',
          description: 'Sabit hat uzerinde guvenli gogus presi saglar.',
          instructions:
              'Tutacaklari gogus hizasinda it, kilitlemeden geri don. 3 set 10-12 tekrar.',
        ),
      ];
    case 'BACK':
      return [
        Exercise(
          id: 9011,
          muscleGroup: 'BACK',
          name: 'Lat Pulldown',
          description: 'Genis sirt kaslarini hedefler.',
          instructions:
              'Bari ust gogse dogru cek, kontrollu birak. 4 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9012,
          muscleGroup: 'BACK',
          name: 'Seated Cable Row',
          description: 'Orta sirt kalinligi ve postur icin etkilidir.',
          instructions:
              'Kurek kemiklerini sikistirarak tutusu govdeye cek. 3 set 10-12 tekrar.',
        ),
        Exercise(
          id: 9013,
          muscleGroup: 'BACK',
          name: 'Barbell Row',
          description: 'Sirt ve arka omuz icin guclu temel hareket.',
          instructions: 'Bel sabit, bari karna dogru cek. 4 set 6-10 tekrar.',
        ),
        Exercise(
          id: 9014,
          muscleGroup: 'BACK',
          name: 'Pull-Up',
          description:
              'Vucut agirligiyla sirt genisligi icin temel harekettir.',
          instructions:
              'Bari ceneyi gecene kadar cek, kontrollu in. 4 set 6-10 tekrar.',
        ),
        Exercise(
          id: 9015,
          muscleGroup: 'BACK',
          name: 'Chest Supported Row',
          description: 'Bel yukunu azaltarak sirt kalinligi gelistirir.',
          instructions:
              'Gogsu benchte sabitleyip dirsekleri geriye cek. 3 set 10-12 tekrar.',
        ),
        Exercise(
          id: 9016,
          muscleGroup: 'BACK',
          name: 'Single Arm Dumbbell Row',
          description: 'Taraflar arasi kuvvet dengesini iyilestirir.',
          instructions:
              'Tek diz benchte, dumbbelli kalcaya dogru cek. 3 set 10-12 tekrar.',
        ),
        Exercise(
          id: 9017,
          muscleGroup: 'BACK',
          name: 'Straight Arm Pulldown',
          description: 'Lat kaslarini izolasyonla hedefler.',
          instructions:
              'Kollar hafif kirik, bari kalcaya dogru cek. 3 set 12-15 tekrar.',
        ),
        Exercise(
          id: 9018,
          muscleGroup: 'BACK',
          name: 'T-Bar Row',
          description: 'Orta sirt ve trapez icin agir cekis alternatifidir.',
          instructions: 'Gogus acik, bari alt gogse cek. 4 set 8-10 tekrar.',
        ),
      ];
    case 'LEGS':
      return [
        Exercise(
          id: 9021,
          muscleGroup: 'LEGS',
          name: 'Squat',
          description: 'Bacak ve kalca icin temel kuvvet hareketi.',
          instructions:
              'Diz-ayak hizasini koru, kalcayi geriye alarak in. 4 set 6-10 tekrar.',
        ),
        Exercise(
          id: 9022,
          muscleGroup: 'LEGS',
          name: 'Leg Press',
          description: 'Quadriceps odakli kontrollu itis hareketi.',
          instructions:
              'Platformu tam kilitlemeden it, kontrollu indir. 3 set 10-15 tekrar.',
        ),
        Exercise(
          id: 9023,
          muscleGroup: 'LEGS',
          name: 'Romanian Deadlift',
          description: 'Arka bacak ve kalca kaslarini hedefler.',
          instructions:
              'Dizleri hafif kir, kalcayi geriye iterek bari indir. 3 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9024,
          muscleGroup: 'LEGS',
          name: 'Walking Lunge',
          description:
              'Bacak ve kalca icin denge odakli tek tarafli calismadir.',
          instructions:
              'Uzun adim al, arka diz yere yaklasinca yuksel. 3 set 12 adim/ayak.',
        ),
        Exercise(
          id: 9025,
          muscleGroup: 'LEGS',
          name: 'Leg Extension',
          description: 'Quadriceps izolasyonu icin makine hareketi.',
          instructions:
              'Dizleri tam kilitlemeden bacaklari uzat. 3 set 12-15 tekrar.',
        ),
        Exercise(
          id: 9026,
          muscleGroup: 'LEGS',
          name: 'Leg Curl',
          description: 'Arka bacak kaslarini izole calistirir.',
          instructions:
              'Topuklari kalcaya cek, yavasca geri birak. 3 set 10-15 tekrar.',
        ),
        Exercise(
          id: 9027,
          muscleGroup: 'LEGS',
          name: 'Bulgarian Split Squat',
          description: 'Tek bacak kuvvetini ve kalca stabilitesini artirir.',
          instructions:
              'Arka ayagi yukseltip tek bacak squat yap. 3 set 8-12 tekrar/ayak.',
        ),
        Exercise(
          id: 9028,
          muscleGroup: 'LEGS',
          name: 'Calf Raise',
          description: 'Baldir kaslari icin temel hareket.',
          instructions:
              'Topuklari yukari kaldir, ustte 1 sn bekle. 4 set 12-20 tekrar.',
        ),
      ];
    case 'SHOULDERS':
      return [
        Exercise(
          id: 9031,
          muscleGroup: 'SHOULDERS',
          name: 'Overhead Press',
          description: 'Omuz kuvveti icin temel press hareketi.',
          instructions:
              'Bari bas ustune it, kontrollu indir. 4 set 6-10 tekrar.',
        ),
        Exercise(
          id: 9032,
          muscleGroup: 'SHOULDERS',
          name: 'Lateral Raise',
          description: 'Yan omuz hacmini artirir.',
          instructions:
              'Dirsek hafif kirik, kollari omuz hizasina kaldir. 3 set 12-15 tekrar.',
        ),
        Exercise(
          id: 9033,
          muscleGroup: 'SHOULDERS',
          name: 'Face Pull',
          description: 'Arka omuz ve rotator cuff icin koruyucu harekettir.',
          instructions:
              'Halati yuze cek, kurek kemiklerini sik. 3 set 12-15 tekrar.',
        ),
        Exercise(
          id: 9034,
          muscleGroup: 'SHOULDERS',
          name: 'Arnold Press',
          description:
              'On ve yan omuzu birlikte hedefleyen press varyasyonudur.',
          instructions:
              'Avuc icleri sana bakarken basla, yukarida disa cevir. 3 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9035,
          muscleGroup: 'SHOULDERS',
          name: 'Rear Delt Fly',
          description: 'Arka omuz gelisimi ve postur icin etkilidir.',
          instructions:
              'Govdeden hafif egil, kollari yana ac. 3 set 12-15 tekrar.',
        ),
        Exercise(
          id: 9036,
          muscleGroup: 'SHOULDERS',
          name: 'Upright Row',
          description: 'Omuz ve trapez kaslarini birlikte calistirir.',
          instructions:
              'Bari govdeye yakin sekilde cene altina cek. 3 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9037,
          muscleGroup: 'SHOULDERS',
          name: 'Cable Lateral Raise',
          description: 'Yan omuz icin surekli gerilim saglar.',
          instructions:
              'Tek kol kabloyla yana acis yap. 3 set 12-15 tekrar/kol.',
        ),
        Exercise(
          id: 9038,
          muscleGroup: 'SHOULDERS',
          name: 'Dumbbell Front Raise',
          description: 'On omuz odakli izolasyon hareketi.',
          instructions:
              'Dumbbelllari omuz hizasina kadar kaldir. 3 set 10-12 tekrar.',
        ),
      ];
    case 'BICEPS':
      return [
        Exercise(
          id: 9041,
          muscleGroup: 'BICEPS',
          name: 'Barbell Curl',
          description: 'Biseps icin temel kivirma hareketi.',
          instructions:
              'Dirsekleri sabit tutarak bari yukari kivir. 3 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9042,
          muscleGroup: 'BICEPS',
          name: 'Hammer Curl',
          description: 'Brachialis ve on kolu da calistirir.',
          instructions: 'Notr tutusla dumbbell curl yap. 3 set 10-12 tekrar.',
        ),
        Exercise(
          id: 9043,
          muscleGroup: 'BICEPS',
          name: 'Preacher Curl',
          description: 'Biseps izolasyonunu artirir, hileyi azaltir.',
          instructions:
              'Kolunu preacher padde sabitle, kontrollu curl yap. 3 set 10-12 tekrar.',
        ),
        Exercise(
          id: 9044,
          muscleGroup: 'BICEPS',
          name: 'Incline Dumbbell Curl',
          description: 'Biseps uzun basini daha fazla gererek calistirir.',
          instructions:
              'Eğimli benchte dirsekleri sabit tutarak curl yap. 3 set 10-12 tekrar.',
        ),
        Exercise(
          id: 9045,
          muscleGroup: 'BICEPS',
          name: 'Cable Curl',
          description: 'Hareket boyunca sabit gerilim saglar.',
          instructions:
              'Dirsekleri govde yaninda sabit tut, kabloyu kivir. 3 set 12-15 tekrar.',
        ),
        Exercise(
          id: 9046,
          muscleGroup: 'BICEPS',
          name: 'Concentration Curl',
          description: 'Tek kol izolasyonla kasi net hissettirir.',
          instructions:
              'Dirsegi uyluga dayayip tek kol curl yap. 3 set 10-12 tekrar/kol.',
        ),
      ];
    case 'TRICEPS':
      return [
        Exercise(
          id: 9051,
          muscleGroup: 'TRICEPS',
          name: 'Triceps Pushdown',
          description: 'Triceps izolasyonu icin etkili kablo hareketi.',
          instructions:
              'Dirsekler sabit, kabloyu asagi it. 3 set 10-15 tekrar.',
        ),
        Exercise(
          id: 9052,
          muscleGroup: 'TRICEPS',
          name: 'Skull Crusher',
          description: 'Triceps uzun bas icin etkili serbest agirlik hareketi.',
          instructions:
              'EZ bari alna dogru indir, kontrollu it. 3 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9053,
          muscleGroup: 'TRICEPS',
          name: 'Overhead Cable Extension',
          description: 'Triceps uzun basi icin etkili harekettir.',
          instructions: 'Halati bas ustunden one uzat. 3 set 10-15 tekrar.',
        ),
        Exercise(
          id: 9054,
          muscleGroup: 'TRICEPS',
          name: 'Close Grip Bench Press',
          description: 'Triceps odakli agir bilesik itis hareketi.',
          instructions: 'Dar tutusla bari indirip it. 4 set 6-10 tekrar.',
        ),
        Exercise(
          id: 9055,
          muscleGroup: 'TRICEPS',
          name: 'Bench Dip',
          description: 'Vucut agirligi ile triceps gelisimine yardimci olur.',
          instructions:
              'Eller benchte, dirsekleri bukerek in-cik yap. 3 set 10-15 tekrar.',
        ),
        Exercise(
          id: 9056,
          muscleGroup: 'TRICEPS',
          name: 'Single Arm Dumbbell Extension',
          description: 'Tek kol triceps kontrolunu gelistirir.',
          instructions:
              'Dumbbelli bas ustunde tek kolla indirip kaldir. 3 set 10-12 tekrar/kol.',
        ),
      ];
    case 'CORE':
      return [
        Exercise(
          id: 9061,
          muscleGroup: 'CORE',
          name: 'Plank',
          description: 'Core stabilitesi ve dayanikliligi artirir.',
          instructions: 'Govde duz, karin sikı. 3 set 30-60 saniye bekle.',
        ),
        Exercise(
          id: 9062,
          muscleGroup: 'CORE',
          name: 'Leg Raise',
          description: 'Alt karin odakli hareket.',
          instructions:
              'Bacaklari kontrollu kaldirip indir. 3 set 10-15 tekrar.',
        ),
        Exercise(
          id: 9063,
          muscleGroup: 'CORE',
          name: 'Crunch',
          description: 'Ust karin odakli temel core hareketidir.',
          instructions:
              'Belini zorlamadan govdeyi hafifce yukari kaldir. 3 set 15-20 tekrar.',
        ),
        Exercise(
          id: 9064,
          muscleGroup: 'CORE',
          name: 'Russian Twist',
          description: 'Oblik kaslari ve rotasyonel core kontrolunu artirir.',
          instructions:
              'Ayaklar hafif havada, sag-sol donus yap. 3 set 20 tekrar.',
        ),
        Exercise(
          id: 9065,
          muscleGroup: 'CORE',
          name: 'Dead Bug',
          description: 'Core stabilitesini guvenli sekilde gelistirir.',
          instructions:
              'Karsi kol-bacak uzatirken beli yerde tut. 3 set 10-12 tekrar/yan.',
        ),
        Exercise(
          id: 9066,
          muscleGroup: 'CORE',
          name: 'Mountain Climber',
          description: 'Core ve kondisyonu ayni anda calistirir.',
          instructions:
              'Plank pozisyonunda dizleri sirayla gogse cek. 3 set 30-45 sn.',
        ),
        Exercise(
          id: 9067,
          muscleGroup: 'CORE',
          name: 'Cable Crunch',
          description: 'Agirlikla karin kaslarina direnc uygular.',
          instructions:
              'Kabloyu asagi crunch hareketiyle cek. 3 set 12-15 tekrar.',
        ),
      ];
    case 'GLUTES':
      return [
        Exercise(
          id: 9071,
          muscleGroup: 'GLUTES',
          name: 'Hip Thrust',
          description: 'Kalca kaslarini guclu sekilde aktive eder.',
          instructions:
              'Ustte kalcayi sik, kontrollu asagi in. 4 set 8-12 tekrar.',
        ),
        Exercise(
          id: 9072,
          muscleGroup: 'GLUTES',
          name: 'Glute Bridge',
          description: 'Kalca aktivasyonu icin baslangic seviyesi harekettir.',
          instructions:
              'Topuklardan iterek kalcayi yukari kaldir. 3 set 12-15 tekrar.',
        ),
        Exercise(
          id: 9073,
          muscleGroup: 'GLUTES',
          name: 'Cable Kickback',
          description: 'Kalca izolasyonu icin etkili kablo hareketidir.',
          instructions:
              'Ayak bilegine kablo tak, ayagi geriye it. 3 set 12-15 tekrar/ayak.',
        ),
        Exercise(
          id: 9074,
          muscleGroup: 'GLUTES',
          name: 'Sumo Squat',
          description: 'Ic bacak ve kalca aktivasyonunu artirir.',
          instructions:
              'Genis durusta squat yap, dizleri disa yonlendir. 3 set 10-12 tekrar.',
        ),
        Exercise(
          id: 9075,
          muscleGroup: 'GLUTES',
          name: 'Step-Up',
          description: 'Tek tarafli kuvvet ve kalca aktivasyonuna destek olur.',
          instructions:
              'Yukseltiye tek ayakla cik, kontrollu in. 3 set 10-12 tekrar/ayak.',
        ),
        Exercise(
          id: 9076,
          muscleGroup: 'GLUTES',
          name: 'Frog Pump',
          description:
              'Kalca ust sikismasini artiran kisa aralikli harekettir.',
          instructions:
              'Ayak tabanlarini birlestir, kalcayi hizli ve kontrollu kaldir. 3 set 20 tekrar.',
        ),
        Exercise(
          id: 9077,
          muscleGroup: 'GLUTES',
          name: 'Reverse Lunge',
          description: 'Kalca ve bacaklari dengeli calistirir.',
          instructions:
              'Geri adim alarak lunge yap, ondeki topuktan guc al. 3 set 10-12 tekrar/ayak.',
        ),
      ];
    default:
      return [];
  }
}
