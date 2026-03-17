import '../../../core/models/exercise.dart';

class ExerciseGuideData {
  final List<ExerciseGuideFrame> frames;
  final String setup;
  final List<String> executionSteps;
  final String breathing;
  final String tempo;
  final List<String> targetMuscles;
  final List<ExerciseGuideIssue> commonMistakes;
  final List<String> normalFeel;
  final List<String> stopSignals;
  final ExerciseGuideVariant regression;
  final ExerciseGuideVariant progression;
  final List<ExerciseGuideChecklistItem> checklist;
  final List<String> coachPrompts;
  final Map<String, ExerciseGuideGoalPlan> goalPlans;

  const ExerciseGuideData({
    required this.frames,
    required this.setup,
    required this.executionSteps,
    required this.breathing,
    required this.tempo,
    required this.targetMuscles,
    required this.commonMistakes,
    required this.normalFeel,
    required this.stopSignals,
    required this.regression,
    required this.progression,
    required this.checklist,
    required this.coachPrompts,
    required this.goalPlans,
  });
}

class ExerciseGuideFrame {
  final String label;
  final String cue;
  final String detail;

  const ExerciseGuideFrame({
    required this.label,
    required this.cue,
    required this.detail,
  });
}

class ExerciseGuideIssue {
  final String issue;
  final String fix;

  const ExerciseGuideIssue({required this.issue, required this.fix});
}

class ExerciseGuideVariant {
  final String title;
  final String description;

  const ExerciseGuideVariant({required this.title, required this.description});
}

class ExerciseGuideChecklistItem {
  final String title;
  final String detail;

  const ExerciseGuideChecklistItem({required this.title, required this.detail});
}

class ExerciseGuideGoalPlan {
  final String title;
  final String prescription;
  final String focus;

  const ExerciseGuideGoalPlan({
    required this.title,
    required this.prescription,
    required this.focus,
  });
}

class ExerciseGuideOverride {
  final String? setup;
  final List<String>? executionSteps;
  final String? breathing;
  final String? tempo;
  final List<String>? targetMuscles;
  final List<ExerciseGuideIssue>? commonMistakes;
  final List<String>? normalFeel;
  final List<String>? stopSignals;
  final ExerciseGuideVariant? regression;
  final ExerciseGuideVariant? progression;
  final List<ExerciseGuideChecklistItem>? checklist;
  final List<String>? coachPrompts;
  final Map<String, ExerciseGuideGoalPlan>? goalPlans;
  final List<ExerciseGuideFrame>? frames;

  const ExerciseGuideOverride({
    this.setup,
    this.executionSteps,
    this.breathing,
    this.tempo,
    this.targetMuscles,
    this.commonMistakes,
    this.normalFeel,
    this.stopSignals,
    this.regression,
    this.progression,
    this.checklist,
    this.coachPrompts,
    this.goalPlans,
    this.frames,
  });
}

ExerciseGuideData buildExerciseGuideData(Exercise exercise) {
  final group = exercise.muscleGroup.trim().toUpperCase();
  final name = exercise.name.trim().isEmpty
      ? 'Bu hareket'
      : exercise.name.trim();
  final override = _exerciseGuideOverrides[_normalizeExerciseName(name)];
  final rawInstructions = _instructionLines(exercise.instructions);
  final baseDescription = exercise.description?.trim();
  final targetMuscles =
      override?.targetMuscles ?? _targetMusclesForGroup(group);
  final setup = rawInstructions.isNotEmpty
      ? rawInstructions.first
      : override?.setup ?? _defaultSetupForGroup(group);
  final execution = rawInstructions.length > 1
      ? rawInstructions
      : override?.executionSteps ?? _defaultExecutionFor(name, group);
  final frames = override?.frames ?? _framesFor(name, group, override);

  return ExerciseGuideData(
    frames: frames,
    setup: setup,
    executionSteps: execution,
    breathing: override?.breathing ?? _breathingForGroup(group),
    tempo: override?.tempo ?? _tempoForGroup(group),
    targetMuscles: targetMuscles,
    commonMistakes: override?.commonMistakes ?? _mistakesFor(name, group),
    normalFeel: override?.normalFeel ?? _normalFeelFor(group, baseDescription),
    stopSignals: override?.stopSignals ?? _stopSignalsFor(group),
    regression: override?.regression ?? _regressionFor(name, group),
    progression: override?.progression ?? _progressionFor(name, group),
    checklist: override?.checklist ?? _checklistFor(group),
    coachPrompts: override?.coachPrompts ?? _coachPromptsFor(name, group),
    goalPlans: override?.goalPlans ?? _goalPlansFor(name, group),
  );
}

String _normalizeExerciseName(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

List<ExerciseGuideFrame> _framesFor(
  String name,
  String group, [
  ExerciseGuideOverride? override,
]) {
  if (override?.frames != null) {
    return override!.frames!;
  }
  final setup = override?.setup ?? _defaultSetupForGroup(group);
  final execution =
      override?.executionSteps ?? _defaultExecutionFor(name, group);
  final mid = execution.length > 1 ? execution[1] : execution.first;
  final finish = execution.length > 2
      ? execution.last
      : switch (group) {
          'CORE' => 'Bel pozisyonunu kaybetmeden baslangica don.',
          'BACK' => 'Negatif fazi yavaslat, agirligi birakma.',
          _ => 'Zirvede 1 saniye kontrol sagla ve baslangica don.',
        };

  return [
    ExerciseGuideFrame(label: 'Baslangic', cue: 'Pozisyon al', detail: setup),
    ExerciseGuideFrame(label: 'Uygulama', cue: name, detail: mid),
    ExerciseGuideFrame(label: 'Bitis', cue: 'Kontrollu donus', detail: finish),
  ];
}

List<String> _instructionLines(String? text) {
  if (text == null || text.trim().isEmpty) return const [];
  final normalized = text
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\n')
      .replaceAll('\r\n', '\n');

  return normalized
      .split(RegExp(r'[\n]+'))
      .map((e) => e.trim())
      .map((e) => e.replaceFirst(RegExp(r'^\d+[\).\-\s]*'), '').trim())
      .where((e) => e.isNotEmpty)
      .where((e) => !RegExp(r'^\d+$').hasMatch(e))
      .toList();
}

List<String> _targetMusclesForGroup(String group) {
  return switch (group) {
    'CHEST' => const ['Gogus', 'On omuz', 'Triceps'],
    'BACK' => const ['Lat', 'Orta sirt', 'Arka omuz'],
    'LEGS' => const ['Quadriceps', 'Hamstring', 'Glute'],
    'SHOULDERS' => const ['On omuz', 'Yan omuz', 'Arka omuz'],
    'BICEPS' => const ['Biceps', 'Brachialis', 'On kol'],
    'TRICEPS' => const ['Triceps uzun bas', 'Lateral bas', 'Medial bas'],
    'CORE' => const ['Ust karin', 'Alt karin', 'Core stabilite'],
    'GLUTES' => const ['Glute max', 'Glute med', 'Hamstring'],
    _ => const ['Hedef kas grubu'],
  };
}

String _defaultSetupForGroup(String group) {
  return switch (group) {
    'CHEST' =>
      'Ayaklarini yere sabitle, gogus acik ve kurek kemikleri geride olsun.',
    'BACK' =>
      'Gobdeyi sabitle, gogsu ac ve cekise baslamadan once omuzlari ayarla.',
    'LEGS' => 'Ayak tabanini zemine kokle, karin sıkı ve bel notr olsun.',
    'SHOULDERS' =>
      'Kaburgalari asagi indir, boynu uzat ve omuzlari merkezde tut.',
    'BICEPS' => 'Dirsekleri govdeye yakin sabitle, avuclari tam kavra.',
    'TRICEPS' =>
      'Dirsekleri bir eksende sabitle ve govdeyi hile icin kullanma.',
    'CORE' => 'Kaburgalari kapat, bel boslugunu kontrol et ve nefesi merkezle.',
    'GLUTES' =>
      'Kalca hattini duz tut, topuklardan yere bas ve core’u aktif tut.',
    _ =>
      'Baslangic pozisyonunda eklemlerini hizala ve hareket acikligini kontrol et.',
  };
}

List<String> _defaultExecutionFor(String name, String group) {
  final groupStep = switch (group) {
    'CHEST' =>
      'Agirligi indirirken gogus acikligini koru, iterken dirsekleri kontrollu ac.',
    'BACK' =>
      'Cekisi dirseklerle baslat, son noktada kurek kemiklerini hafifce yaklastir.',
    'LEGS' => 'Asagi inerken dengeyi kaybetme, kalkista topuktan guc al.',
    'SHOULDERS' =>
      'Omuz hizasini bozmadan hareket acikliginin tepesine kadar cik.',
    'BICEPS' =>
      'Dirsek sabitken agirligi yukari kivir, inerken negatif fazi yavaslat.',
    'TRICEPS' =>
      'Itisi tamamlarken dirsek acisini sabit tut, geri donuste omuzlari oynatma.',
    'CORE' => 'Her tekrarda karin duvarini aktif tut ve boynu gevsek birak.',
    'GLUTES' => 'Kalcadan guc uret, ust noktada 1 saniye siki kal.',
    _ => 'Kontrollu yuklen, kontrollu don.',
  };

  return [
    '$name icin once kurulumunu tamamla.',
    groupStep,
    'Son tekrarlarda formun bozuluyorsa seti bitir ve hareket kalitesini koru.',
  ];
}

String _breathingForGroup(String group) {
  return switch (group) {
    'CORE' =>
      'Hazirlikta burundan nefes al, zor kisimda nefesi ver ve karin duvarini kapali tut.',
    'LEGS' =>
      'Asagi inerken nefes al, kalkarken disari ver ve karin basincini koru.',
    _ => 'Eksen pozisyonunda nefes al, efor fazinda nefesi kontrollu ver.',
  };
}

String _tempoForGroup(String group) {
  return switch (group) {
    'CHEST' => '3-1-1: 3 sn inis, altta 1 sn kontrol, 1 sn itis.',
    'BACK' => '2-1-2: 2 sn cekis, 1 sn sikisma, 2 sn donus.',
    'LEGS' => '3-1-1: 3 sn inis, dipte 1 sn durus, 1 sn kalkis.',
    'SHOULDERS' => '2-1-2: 2 sn yukaris, 1 sn zirve, 2 sn inis.',
    'BICEPS' => '2-1-3: 2 sn yukaris, 1 sn zirve, 3 sn negatif.',
    'TRICEPS' => '2-1-2: 2 sn itis, 1 sn kilitlenmeden kontrol, 2 sn donus.',
    'CORE' => 'Yavas ve kontrollu: her tekrar boyunca gerginligi koru.',
    'GLUTES' => '2-2-2: 2 sn cikis, ustte 2 sn sıkma, 2 sn donus.',
    _ => 'Kontrollu tempo kullan: hiz yerine formu koru.',
  };
}

List<ExerciseGuideIssue> _mistakesFor(String name, String group) {
  final lower = name.toLowerCase();
  if (lower.contains('squat')) {
    return const [
      ExerciseGuideIssue(
        issue: 'Dizlerin ice kacmasi',
        fix:
            'Ayak tabanini yere yay ve dizleri ayak parmaklari yonune takip ettir.',
      ),
      ExerciseGuideIssue(
        issue: 'Belin yuvarlanmasi',
        fix:
            'Kaburgalari kapat, karin basinicini koru ve hareket derinligini azalt.',
      ),
      ExerciseGuideIssue(
        issue: 'Topuklarin kalkmasi',
        fix: 'Agirlik merkezini orta ayaga al, gerekirse stance acini ayarla.',
      ),
    ];
  }
  if (lower.contains('row') || group == 'BACK') {
    return const [
      ExerciseGuideIssue(
        issue: 'Omuzla cekmek',
        fix: 'Cekisi dirseklerden baslat ve boynu gevsek tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Govdeyi savurmak',
        fix: 'Agirligi azalt ve negatif fazi 2-3 saniye kontrol et.',
      ),
      ExerciseGuideIssue(
        issue: 'Bel notrunu kaybetmek',
        fix: 'Core’u aktif tut ve hareket acikligini biraz kisalt.',
      ),
    ];
  }
  if (group == 'CHEST') {
    return const [
      ExerciseGuideIssue(
        issue: 'Omuzlarin one dusmesi',
        fix: 'Kurek kemiklerini hafif geriye al ve gogsu acik tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Dirsekleri fazla acmak',
        fix: 'Dirsek acisini yaklaşık 45-70 derece bandinda tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Agirligi ziplatmak',
        fix: 'Alt noktada 1 saniye kontrol kur, momentumla itme.',
      ),
    ];
  }
  if (group == 'SHOULDERS') {
    return const [
      ExerciseGuideIssue(
        issue: 'Omuzlari kulaga cekmek',
        fix: 'Boynu uzat ve trapezi degil deltoidi hedefle.',
      ),
      ExerciseGuideIssue(
        issue: 'Govdeyle sallamak',
        fix: 'Agirligi azalt, tekrar kalitesini koru.',
      ),
      ExerciseGuideIssue(
        issue: 'Yarim tekrar yapmak',
        fix: 'Agri yoksa kontrollu tam hareket acikligi kullan.',
      ),
    ];
  }
  if (group == 'CORE') {
    return const [
      ExerciseGuideIssue(
        issue: 'Belin bosalmasi',
        fix: 'Kaburgalari asagi indir, hareket acikligini gerekirse azalt.',
      ),
      ExerciseGuideIssue(
        issue: 'Boyunla yuklenmek',
        fix: 'Bakisi sabitle ve cene-gogus mesafesini koru.',
      ),
      ExerciseGuideIssue(
        issue: 'Nefesi tutmak',
        fix: 'Her tekrar boyunca kontrollu nefes veris ekle.',
      ),
    ];
  }

  return const [
    ExerciseGuideIssue(
      issue: 'Hizi formin onune koymak',
      fix: 'Temponu yavaslat ve tekrar kalitesini oncele.',
    ),
    ExerciseGuideIssue(
      issue: 'Eksen bozulmasi',
      fix: 'Ayak, kalca ve omuz hizzasini her tekrar kontrol et.',
    ),
    ExerciseGuideIssue(
      issue: 'Agrisina ragmen devam etmek',
      fix: 'Batıcı agrida dur, varyasyona gec veya hareketi kes.',
    ),
  ];
}

List<String> _normalFeelFor(String group, String? description) {
  final intro = description != null && description.isNotEmpty
      ? 'Hareketin dogruysa ${description.toLowerCase()}.'
      : null;
  final base = switch (group) {
    'CHEST' => const [
      'Goguste sıkisma',
      'On omuz ve triceps destegi',
      'Negatif fazda kontrollu gerilim',
    ],
    'BACK' => const [
      'Lat ve orta sirtta cekis hissi',
      'Kurek kemiklerinde kontrollu kapanis',
      'On kolda hafif destek',
    ],
    'LEGS' => const [
      'Uyluk ve kalcada yuklenme',
      'Topukta denge',
      'Core’da stabilite',
    ],
    'SHOULDERS' => const [
      'Omuz baslarinda yanma',
      'Core’da denge',
      'Boyunda gereksiz gerilim olmamasi',
    ],
    'BICEPS' => const [
      'Pazuda doluluk',
      'Negatif fazda kuvvetli gerilim',
      'On kolda hafif destek',
    ],
    'TRICEPS' => const [
      'Arka kolda doluluk',
      'Itis sonunda kontrollu kasilma',
      'Omuzda degil triceps’te yuk',
    ],
    'CORE' => const [
      'Karin duvarinda surekli gerginlik',
      'Belde degil merkez bolgede calisma',
      'Nefesle birlikte stabilite',
    ],
    'GLUTES' => const [
      'Kalcada sıkisma',
      'Topuklardan guc aktarimi',
      'Hamstringde ikincil destek',
    ],
    _ => const ['Hedef kastta net gerilim', 'Eklemde degil kasta yük hissi'],
  };
  return [if (intro != null) intro, ...base];
}

List<String> _stopSignalsFor(String group) {
  return switch (group) {
    'SHOULDERS' => const [
      'Omuz onunde batıcı agrı',
      'Klik ile birlikte guc kaybi',
      'Kola vuran uyusma veya yanma',
    ],
    'LEGS' => const [
      'Dizde keskin agrı',
      'Belde anlik batma',
      'Ayaga vuran sinirsel agrı',
    ],
    _ => const [
      'Eklemde batıcı agrı',
      'Ani guc kaybi veya dengesizlik',
      'Uyusma, karincalanma veya yayilan agrı',
    ],
  };
}

ExerciseGuideVariant _regressionFor(String name, String group) {
  return switch (group) {
    'CHEST' => const ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          'Makine veya incline versiyona gec. Sabit yol seni forma odaklar.',
    ),
    'BACK' => const ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          'Chest-supported veya kablo varyasyonu kullan. Bel yukunu azalt.',
    ),
    'LEGS' => const ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          'Goblet veya box varyasyonuna gec. Derinligi kontrol ederek ilerle.',
    ),
    'CORE' => const ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          'Dizler bükülü veya kisa aralikli versiyonla basla, bel kontrolunu koru.',
    ),
    _ => ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          '$name hareketini daha hafif agirlikla veya makine destekli uygula.',
    ),
  };
}

ExerciseGuideVariant _progressionFor(String name, String group) {
  return switch (group) {
    'CHEST' => const ExerciseGuideVariant(
      title: 'Zor versiyon',
      description:
          'Duraklamali tekrar, tek tarafli varyasyon veya daha uzun negatif faz ekle.',
    ),
    'BACK' => const ExerciseGuideVariant(
      title: 'Zor versiyon',
      description: 'Zirvede 2 saniye sıkisma veya tek kol varyasyonu kullan.',
    ),
    'LEGS' => const ExerciseGuideVariant(
      title: 'Zor versiyon',
      description:
          'Tempo squat, split squat veya pause tekrar ile yuklenmeyi artir.',
    ),
    'CORE' => const ExerciseGuideVariant(
      title: 'Zor versiyon',
      description:
          'Kollari daha uzun tut, lever’i buyut veya ekstra duraklama ekle.',
    ),
    _ => ExerciseGuideVariant(
      title: 'Zor versiyon',
      description:
          '$name icin tempo, tek tarafli kontrol veya ekstra duraklama ekle.',
    ),
  };
}

List<ExerciseGuideChecklistItem> _checklistFor(String group) {
  final common = const [
    ExerciseGuideChecklistItem(
      title: 'Core aktif',
      detail: 'Kaburgalar kapali, merkez bolge gergin.',
    ),
    ExerciseGuideChecklistItem(
      title: 'Kontrollu tempo',
      detail: 'Momentum yerine kas kontrolu kullaniyorum.',
    ),
  ];

  final specific = switch (group) {
    'CHEST' => const [
      ExerciseGuideChecklistItem(
        title: 'Gogus acik',
        detail: 'Kurek kemikleri hafif geride.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Dirsek hatti temiz',
        detail: 'Dirsekler ne fazla acik ne fazla kapali.',
      ),
    ],
    'BACK' => const [
      ExerciseGuideChecklistItem(
        title: 'Cekis dirsekten basliyor',
        detail: 'Omuzu degil sirti kullaniyorum.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Boyun serbest',
        detail: 'Trap kasar gibi yuklenmiyorum.',
      ),
    ],
    'LEGS' => const [
      ExerciseGuideChecklistItem(
        title: 'Ayak tabani tam yerde',
        detail: 'Topuk temasi kaybolmuyor.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Diz-ayak hatti korunuyor',
        detail: 'Dizler ice kacmiyor.',
      ),
    ],
    'CORE' => const [
      ExerciseGuideChecklistItem(
        title: 'Bel kontrol altinda',
        detail: 'Hareket boyunca notr pozisyona yakınım.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Nefes akiyor',
        detail: 'Her tekrar nefesle senkron ilerliyor.',
      ),
    ],
    _ => const [
      ExerciseGuideChecklistItem(
        title: 'Eksen sabit',
        detail: 'Ana eklem hattim bozulmuyor.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Hedef kası hissediyorum',
        detail: 'Yuk ekleme degil kasta.',
      ),
    ],
  };

  return [...specific, ...common];
}

List<String> _coachPromptsFor(String name, String group) {
  return [
    'Hazir ol. Pozisyonunu kur.',
    _defaultSetupForGroup(group),
    'Nefes al. Merkez bolgeyi sabitle.',
    _defaultExecutionFor(name, group).first,
    _defaultExecutionFor(name, group)[1],
    'Zirvede kontrol sagla.',
    'Nefes ver ve kontrollu don.',
    'Form bozuluyorsa seti burada bitir.',
  ];
}

Map<String, ExerciseGuideGoalPlan> _goalPlansFor(String name, String group) {
  return {
    'beginner': ExerciseGuideGoalPlan(
      title: 'Yeni baslayan',
      prescription: '2-3 set x 8-12 tekrar, RPE 6-7',
      focus: 'Formu oturt, tam hareket acikligini acele etmeden ogren.',
    ),
    'muscle': ExerciseGuideGoalPlan(
      title: 'Kas kazanimi',
      prescription: _groupPrescription(group, muscle: true),
      focus: 'Kontrollu negatif, zirvede kısa sıkisma ve sete yakin bitis.',
    ),
    'fat_loss': ExerciseGuideGoalPlan(
      title: 'Yag yakimi',
      prescription: '3-4 set x 12-20 tekrar, dinlenme 30-60 sn',
      focus: 'Formu koruyarak yogunlugu ritim ve toplam hacimle artir.',
    ),
    'home': ExerciseGuideGoalPlan(
      title: 'Evde ekipmansiz',
      prescription: '3 set x 10-20 tekrar veya 30-45 sn',
      focus: '$name hareketinin vucut agirligi veya bantli versiyonunu kullan.',
    ),
    'sensitive': ExerciseGuideGoalPlan(
      title: 'Hassasiyet odakli',
      prescription: '2-3 set x 8-10 kaliteli tekrar',
      focus:
          'Agri araligi disina cikma, makine/bant destekli varyasyon tercih et.',
    ),
  };
}

const Map<String, ExerciseGuideOverride> _exerciseGuideOverrides = {
  'bench press': ExerciseGuideOverride(
    setup:
        'Ayaklarini yere kilitle, kurek kemiklerini geriye al ve barı goz hizasinda konumlandir.',
    executionSteps: [
      'Bari bilek-dirsek hattini koruyarak alt gogse kontrollu indir.',
      'Alt noktada omuzlarini one dusurmeden 1 saniye kontrol kur.',
      'Ayak itisini kullanip bari hafif yay cizerek yukari gonder.',
    ],
    tempo: '3-1-1: 3 sn inis, altta 1 sn durus, 1 sn guclu itis.',
    targetMuscles: ['Gogus', 'On omuz', 'Triceps'],
    commonMistakes: [
      ExerciseGuideIssue(
        issue: 'Dirsekleri fazla acmak',
        fix:
            'Dirsekleri omuz hattindan hafif asagida, 45-70 derece bandinda tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Kalca ve sirt set-upini kaybetmek',
        fix: 'Set boyunca ayak basincini koru ve kurek kemiklerini bankta tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Bari goguste sektirmek',
        fix: 'Alt noktada kisa kontrol kur, momentumla degil kasla it.',
      ),
    ],
  ),
  'barbell row': ExerciseGuideOverride(
    setup:
        'Ayaklarini kalca genisliginde ac, kalcadan mentese yap ve govdeyi yere yakin sabitle.',
    executionSteps: [
      'Bari karin altina dogru cekmeye dirseklerden basla.',
      'Zirvede kurek kemiklerini kisa bir an yaklastir, boynu gevsek tut.',
      'Agirligi bel pozisyonunu bozmadan kontrollu sekilde asagi birak.',
    ],
    tempo: '2-1-2: 2 sn cekis, 1 sn sıkisma, 2 sn kontrollu donus.',
    commonMistakes: [
      ExerciseGuideIssue(
        issue: 'Govdeyi savurmak',
        fix: 'Agirligi azalt ve torso acini set boyunca sabit tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Bari gogse cekmek',
        fix: 'Dirsekleri kalcaya sur, cekisi karin altina hedefle.',
      ),
      ExerciseGuideIssue(
        issue: 'Bel notrunu kaybetmek',
        fix:
            'Karni kilitle ve hareket acikligini belin izin verdigi aralikta tut.',
      ),
    ],
  ),
  'lat pulldown': ExerciseGuideOverride(
    setup:
        'Dizlerini ped altina sabitle, gogsu ac ve bara omuz genisliginden biraz genis tutun.',
    executionSteps: [
      'Cekise omuzlari asagi indirerek basla, sonra dirsekleri yanlara ve asagi sur.',
      'Bari ust gogse getirirken belden geriye yasma miktarini kucuk tut.',
      'Kollar tam uzarken omuzlari kulaga cekmeden kontrollu yukari don.',
    ],
    targetMuscles: ['Lat', 'Teres major', 'Biceps'],
  ),
  'squat': ExerciseGuideOverride(
    setup:
        'Ayaklarini omuz genisliginde ac, karin basinicini kur ve bari orta ayak uzerinde dengele.',
    executionSteps: [
      'Kalca ve dizleri birlikte kirarak kontrollu sekilde asagi in.',
      'Dizleri ayak parmaklari yonunde takip ettir ve gogus kafesini acik tut.',
      'Dipten orta ayaga basip kalca ile omuzlari birlikte yukari cikar.',
    ],
    targetMuscles: ['Quadriceps', 'Glute', 'Adduktor'],
    commonMistakes: [
      ExerciseGuideIssue(
        issue: 'Dizlerin ice kacmasi',
        fix: 'Ayak tabanini yay ve dizleri ayak parmaklari yonune it.',
      ),
      ExerciseGuideIssue(
        issue: 'Dipte belin kapanmasi',
        fix:
            'Derinligi mobilitenin izin verdigi yerde kes ve core basincini koru.',
      ),
      ExerciseGuideIssue(
        issue: 'Topuklarin kalkmasi',
        fix:
            'Agirlik merkezini orta ayakta tut, gerekiyorsa stance acini ayarla.',
      ),
    ],
  ),
  'overhead press': ExerciseGuideOverride(
    setup:
        'Kalcalari sIk, kaburgalari kapat ve bari koprucuk kemiği hizasinda baslat.',
    executionSteps: [
      'Bari cene hattindan gecirirken basi hafif geri cek.',
      'Bar bas ustune geldiginde basi tekrar alta al ve bicepsi kulaga yaklastir.',
      'Donuste kaburgalari acmadan bari ayni hatta kontrollu indir.',
    ],
    stopSignals: [
      'Omuz onunde keskin batma',
      'Belde asiri yaylanma',
      'Kola vuran uyusma veya yanma',
    ],
  ),
  'hip thrust': ExerciseGuideOverride(
    setup:
        'Sirtinin alt kismi bench kenarina dayanirken ayaklarini dizler 90 dereceye yakin olacak sekilde yerlestir.',
    executionSteps: [
      'Topuklardan basip kalcayi yukari sur.',
      'Ust noktada kaburgalari acmadan kalcayi 1-2 saniye sık.',
      'Belden degil kalcadan kontrolle asagi in ve gerginligi kaybetme.',
    ],
    targetMuscles: ['Glute max', 'Hamstring', 'Core stabilite'],
  ),
  'barbell curl': ExerciseGuideOverride(
    setup:
        'Dirseklerini govde yaninda sabitle, bilekleri kirma ve omuzlari geride tut.',
    executionSteps: [
      'Bari omuzu devreye sokmadan pazuya cek.',
      'Zirvede kisa bir an kasilmayi hisset.',
      'Negatif fazi 2-3 saniyede indirerek gerilimi koru.',
    ],
  ),
  'triceps pushdown': ExerciseGuideOverride(
    setup:
        'Dirseklerini yanlara acmadan govde yaninda sabitle ve omuzlarini asagi indir.',
    executionSteps: [
      'Bari ya da halati dirsek acisini sabit tutarak asagi it.',
      'Alt noktada dirsegi kilitlemeden tricepsi 1 saniye sık.',
      'Donuste omuzlari oynatmadan kontrollu yukari cik.',
    ],
    targetMuscles: ['Triceps uzun bas', 'Lateral bas', 'Medial bas'],
  ),
};

String _groupPrescription(String group, {required bool muscle}) {
  if (!muscle) return '3 set x 10 tekrar';
  return switch (group) {
    'LEGS' => '3-5 set x 6-10 tekrar, dinlenme 90-150 sn',
    'BACK' => '3-4 set x 8-12 tekrar, dinlenme 75-120 sn',
    'CHEST' => '3-4 set x 6-12 tekrar, dinlenme 75-120 sn',
    'CORE' => '3-4 set x 10-15 tekrar veya 30-45 sn',
    _ => '3-4 set x 8-15 tekrar, dinlenme 60-90 sn',
  };
}
