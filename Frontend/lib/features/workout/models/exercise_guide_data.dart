import '../../../core/models/exercise.dart';
import 'exercise_media_catalog.dart';

class ExerciseGuideData {
  final List<ExerciseGuideFrame> frames;
  final String? mediaAttribution;
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
    this.mediaAttribution,
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
  final ExerciseGuideVisualStage stage;
  final String? imageAsset;

  const ExerciseGuideFrame({
    required this.label,
    required this.cue,
    required this.detail,
    required this.stage,
    this.imageAsset,
  });
}

enum ExerciseGuideVisualStage { setup, brace, drive, peak, returnControl }

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
  final media = getExerciseGuideMedia(_normalizeExerciseName(name));
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
  final frames = override?.frames ?? _framesFor(name, group, override, media);

  return ExerciseGuideData(
    frames: frames,
    mediaAttribution: media?.attribution,
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
  ExerciseGuideMedia? media,
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
          'CORE' => 'Bel pozisyonunu kaybetmeden başlangıca dön.',
          'BACK' => 'Negatif fazı yavaşlat, ağırlığı bırakma.',
          _ => 'Zirvede 1 saniye kontrol sağla ve başlangıca dön.',
        };
  final firstMove = execution.isNotEmpty ? execution.first : setup;
  final lateMove = execution.length > 1
      ? execution[execution.length - 1]
      : finish;

  return [
    ExerciseGuideFrame(
      label: 'Kurulum',
      cue: 'Pozisyon al',
      detail: setup,
      stage: ExerciseGuideVisualStage.setup,
      imageAsset: media?.stageAssets[0],
    ),
    ExerciseGuideFrame(
      label: 'Hazırlık',
      cue: 'Core sıkı',
      detail: firstMove,
      stage: ExerciseGuideVisualStage.brace,
      imageAsset: media?.stageAssets[1],
    ),
    ExerciseGuideFrame(
      label: 'İtiş / Çekiş',
      cue: name,
      detail: mid,
      stage: ExerciseGuideVisualStage.drive,
      imageAsset: media?.stageAssets[2],
    ),
    ExerciseGuideFrame(
      label: 'Zirve',
      cue: 'Sık ve bekle',
      detail: lateMove,
      stage: ExerciseGuideVisualStage.peak,
      imageAsset: media?.stageAssets[3],
    ),
    ExerciseGuideFrame(
      label: 'Dönüş',
      cue: 'Kontrollü bırak',
      detail: finish,
      stage: ExerciseGuideVisualStage.returnControl,
      imageAsset: media?.stageAssets[4],
    ),
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
    'CHEST' => const ['Göğüs', 'Ön omuz', 'Triceps'],
    'BACK' => const ['Lat', 'Orta sırt', 'Arka omuz'],
    'LEGS' => const ['Quadriceps', 'Hamstring', 'Glute'],
    'SHOULDERS' => const ['Ön omuz', 'Yan omuz', 'Arka omuz'],
    'BICEPS' => const ['Biceps', 'Brachialis', 'Ön kol'],
    'TRICEPS' => const ['Triceps uzun baş', 'Lateral baş', 'Medial baş'],
    'CORE' => const ['Üst karın', 'Alt karın', 'Core stabilite'],
    'GLUTES' => const ['Glute max', 'Glute med', 'Hamstring'],
    _ => const ['Hedef kas grubu'],
  };
}

String _defaultSetupForGroup(String group) {
  return switch (group) {
    'CHEST' =>
      'Ayaklarını yere sabitle, göğüs açık ve kürek kemikleri geride olsun.',
    'BACK' =>
      'Gövdeyi sabitle, göğsü aç ve çekişe başlamadan önce omuzları ayarla.',
    'LEGS' => 'Ayak tabanını zemine kökle, karın sıkı ve bel nötr olsun.',
    'SHOULDERS' =>
      'Kaburgaları aşağı indir, boynu uzat ve omuzları merkezde tut.',
    'BICEPS' => 'Dirsekleri gövdeye yakın sabitle, avuçları tam kavra.',
    'TRICEPS' =>
      'Dirsekleri bir eksende sabitle ve gövdeyi hile için kullanma.',
    'CORE' => 'Kaburgaları kapat, bel boşluğunu kontrol et ve nefesi merkezle.',
    'GLUTES' =>
      'Kalça hattını düz tut, topuklardan yere bas ve core’u aktif tut.',
    _ =>
      'Başlangıç pozisyonunda eklemlerini hizala ve hareket açıklığını kontrol et.',
  };
}

List<String> _defaultExecutionFor(String name, String group) {
  final groupStep = switch (group) {
    'CHEST' =>
      'Ağırlığı indirirken göğüs açıklığını koru, iterken dirsekleri kontrollü aç.',
    'BACK' =>
      'Çekişi dirseklerle başlat, son noktada kürek kemiklerini hafifçe yaklaştır.',
    'LEGS' => 'Aşağı inerken dengeyi kaybetme, kalkışta topuktan güç al.',
    'SHOULDERS' =>
      'Omuz hizasını bozmadan hareket açıklığının tepesine kadar çık.',
    'BICEPS' =>
      'Dirsek sabitken ağırlığı yukarı kıvır, inerken negatif fazı yavaşlat.',
    'TRICEPS' =>
      'İtişi tamamlarken dirsek açısını sabit tut, geri dönüşte omuzları oynatma.',
    'CORE' => 'Her tekrarda karın duvarını aktif tut ve boynu gevşek bırak.',
    'GLUTES' => 'Kalçadan güç üret, üst noktada 1 saniye sıkı kal.',
    _ => 'Kontrollü yüklen, kontrollü dön.',
  };

  return [
    '$name için önce kurulumunu tamamla.',
    groupStep,
    'Son tekrarlarda formun bozuluyorsa seti bitir ve hareket kalitesini koru.',
  ];
}

String _breathingForGroup(String group) {
  return switch (group) {
    'CORE' =>
      'Hazırlıkta burundan nefes al, zor kısmında nefesi ver ve karın duvarını kapalı tut.',
    'LEGS' =>
      'Aşağı inerken nefes al, kalkarken dışarı ver ve karın basıncını koru.',
    _ => 'Eksen pozisyonunda nefes al, efor fazında nefesi kontrollü ver.',
  };
}

String _tempoForGroup(String group) {
  return switch (group) {
    'CHEST' => '3-1-1: 3 sn iniş, altta 1 sn kontrol, 1 sn itiş.',
    'BACK' => '2-1-2: 2 sn çekiş, 1 sn sıkışma, 2 sn dönüş.',
    'LEGS' => '3-1-1: 3 sn iniş, dipte 1 sn duruş, 1 sn kalkış.',
    'SHOULDERS' => '2-1-2: 2 sn yukarı, 1 sn zirve, 2 sn iniş.',
    'BICEPS' => '2-1-3: 2 sn yukarı, 1 sn zirve, 3 sn negatif.',
    'TRICEPS' => '2-1-2: 2 sn itiş, 1 sn kilitlenmeden kontrol, 2 sn dönüş.',
    'CORE' => 'Yavaş ve kontrollü: her tekrar boyunca gerginliği koru.',
    'GLUTES' => '2-2-2: 2 sn çıkış, üstte 2 sn sıkma, 2 sn dönüş.',
    _ => 'Kontrollü tempo kullan: hız yerine formu koru.',
  };
}

List<ExerciseGuideIssue> _mistakesFor(String name, String group) {
  final lower = name.toLowerCase();
  if (lower.contains('squat')) {
    return const [
      ExerciseGuideIssue(
        issue: 'Dizlerin içe kaçması',
        fix:
            'Ayak tabanını yere yay ve dizleri ayak parmakları yönüne takip ettir.',
      ),
      ExerciseGuideIssue(
        issue: 'Belin yuvarlanması',
        fix:
            'Kaburgaları kapat, karın basıncını koru ve hareket derinliğini azalt.',
      ),
      ExerciseGuideIssue(
        issue: 'Topukların kalkması',
        fix: 'Ağırlık merkezini orta ayağa al, gerekirse stance açını ayarla.',
      ),
    ];
  }
  if (lower.contains('row') || group == 'BACK') {
    return const [
      ExerciseGuideIssue(
        issue: 'Omuzla çekmek',
        fix: 'Çekişi dirseklerden başlat ve boynu gevşek tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Gövdeyi savurmak',
        fix: 'Ağırlığı azalt ve negatif fazı 2-3 saniye kontrol et.',
      ),
      ExerciseGuideIssue(
        issue: 'Bel nötrünü kaybetmek',
        fix: 'Core’u aktif tut ve hareket açıklığını biraz kısalt.',
      ),
    ];
  }
  if (group == 'CHEST') {
    return const [
      ExerciseGuideIssue(
        issue: 'Omuzların öne düşmesi',
        fix: 'Kürek kemiklerini hafif geriye al ve göğsü açık tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Dirsekleri fazla açmak',
        fix: 'Dirsek açısını yaklaşık 45-70 derece bandında tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Ağırlığı zıplatmak',
        fix: 'Alt noktada 1 saniye kontrol kur, momentumla itme.',
      ),
    ];
  }
  if (group == 'SHOULDERS') {
    return const [
      ExerciseGuideIssue(
        issue: 'Omuzları kulağa çekmek',
        fix: 'Boynu uzat ve trapezi değil deltoidi hedefle.',
      ),
      ExerciseGuideIssue(
        issue: 'Gövdeyle sallamak',
        fix: 'Ağırlığı azalt, tekrar kalitesini koru.',
      ),
      ExerciseGuideIssue(
        issue: 'Yarım tekrar yapmak',
        fix: 'Ağrı yoksa kontrollü tam hareket açıklığı kullan.',
      ),
    ];
  }
  if (group == 'CORE') {
    return const [
      ExerciseGuideIssue(
        issue: 'Belin boşalması',
        fix: 'Kaburgaları aşağı indir, hareket açıklığını gerekirse azalt.',
      ),
      ExerciseGuideIssue(
        issue: 'Boyunla yüklenmek',
        fix: 'Bakışı sabitle ve çene-göğüs mesafesini koru.',
      ),
      ExerciseGuideIssue(
        issue: 'Nefesi tutmak',
        fix: 'Her tekrar boyunca kontrollü nefes veriş ekle.',
      ),
    ];
  }

  return const [
    ExerciseGuideIssue(
      issue: 'Hızı formun önüne koymak',
      fix: 'Temponu yavaşlat ve tekrar kalitesini öncele.',
    ),
    ExerciseGuideIssue(
      issue: 'Eksen bozulması',
      fix: 'Ayak, kalça ve omuz hizasını her tekrar kontrol et.',
    ),
    ExerciseGuideIssue(
      issue: 'Ağrısına rağmen devam etmek',
      fix: 'Batıcı ağrıda dur, varyasyona geç veya hareketi kes.',
    ),
  ];
}

List<String> _normalFeelFor(String group, String? description) {
  final intro = description != null && description.isNotEmpty
      ? 'Hareketin doğruysa ${description.toLowerCase()}.'
      : null;
  final base = switch (group) {
    'CHEST' => const [
      'Göğüste sıkışma',
      'Ön omuz ve triceps desteği',
      'Negatif fazda kontrollü gerilim',
    ],
    'BACK' => const [
      'Lat ve orta sırtta çekiş hissi',
      'Kürek kemiklerinde kontrollü kapanış',
      'Ön kolda hafif destek',
    ],
    'LEGS' => const [
      'Uyluk ve kalçada yüklenme',
      'Topukta denge',
      'Core’da stabilite',
    ],
    'SHOULDERS' => const [
      'Omuz baslarinda yanma',
      'Core’da denge',
      'Boyunda gereksiz gerilim olmaması',
    ],
    'BICEPS' => const [
      'Pazuda doluluk',
      'Negatif fazda kuvvetli gerilim',
      'Ön kolda hafif destek',
    ],
    'TRICEPS' => const [
      'Arka kolda doluluk',
      'İtiş sonunda kontrollü kasılma',
      'Omuzda değil triceps’te yük',
    ],
    'CORE' => const [
      'Karın duvarında sürekli gerginlik',
      'Belde değil merkez bölgede çalışma',
      'Nefesle birlikte stabilite',
    ],
    'GLUTES' => const [
      'Kalçada sıkışma',
      'Topuklardan güç aktarımı',
      'Hamstringde ikincil destek',
    ],
    _ => const ['Hedef kastta net gerilim', 'Eklemde değil kasta yük hissi'],
  };
  return [
    ...?intro == null ? null : [intro],
    ...base,
  ];
}

List<String> _stopSignalsFor(String group) {
  return switch (group) {
    'SHOULDERS' => const [
      'Omuz önünde batıcı ağrı',
      'Klik ile birlikte güç kaybı',
      'Kola vuran uyuşma veya yanma',
    ],
    'LEGS' => const [
      'Dizde keskin ağrı',
      'Belde anlık batma',
      'Ayağa vuran sinirsel ağrı',
    ],
    _ => const [
      'Eklemde batıcı ağrı',
      'Ani güç kaybı veya dengesizlik',
      'Uyuşma, karıncalanma veya yayılan ağrı',
    ],
  };
}

ExerciseGuideVariant _regressionFor(String name, String group) {
  return switch (group) {
    'CHEST' => const ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          'Makine veya incline versiyona geç. Sabit yol seni forma odaklar.',
    ),
    'BACK' => const ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          'Chest-supported veya kablo varyasyonu kullan. Bel yükünü azalt.',
    ),
    'LEGS' => const ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          'Goblet veya box varyasyonuna geç. Derinliği kontrol ederek ilerle.',
    ),
    'CORE' => const ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          'Dizler bükülü veya kısa aralıklı versiyonla başla, bel kontrolünü koru.',
    ),
    _ => ExerciseGuideVariant(
      title: 'Kolay versiyon',
      description:
          '$name hareketini daha hafif ağırlıkla veya makine destekli uygula.',
    ),
  };
}

ExerciseGuideVariant _progressionFor(String name, String group) {
  return switch (group) {
    'CHEST' => const ExerciseGuideVariant(
      title: 'Zor versiyon',
      description:
          'Duraklmalı tekrar, tek taraflı varyasyon veya daha uzun negatif faz ekle.',
    ),
    'BACK' => const ExerciseGuideVariant(
      title: 'Zor versiyon',
      description: 'Zirvede 2 saniye sıkışma veya tek kol varyasyonu kullan.',
    ),
    'LEGS' => const ExerciseGuideVariant(
      title: 'Zor versiyon',
      description:
          'Tempo squat, split squat veya pause tekrar ile yüklenmeyi artır.',
    ),
    'CORE' => const ExerciseGuideVariant(
      title: 'Zor versiyon',
      description:
          'Kolları daha uzun tut, lever’i büyüt veya ekstra duraklama ekle.',
    ),
    _ => ExerciseGuideVariant(
      title: 'Zor versiyon',
      description:
          '$name için tempo, tek taraflı kontrol veya ekstra duraklama ekle.',
    ),
  };
}

List<ExerciseGuideChecklistItem> _checklistFor(String group) {
  final common = const [
    ExerciseGuideChecklistItem(
      title: 'Core aktif',
      detail: 'Kaburgalar kapalı, merkez bölge gergin.',
    ),
    ExerciseGuideChecklistItem(
      title: 'Kontrollu tempo',
      detail: 'Momentum yerine kas kontrolü kullanıyorum.',
    ),
  ];

  final specific = switch (group) {
    'CHEST' => const [
      ExerciseGuideChecklistItem(
        title: 'Göğüs açık',
        detail: 'Kürek kemikleri hafif geride.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Dirsek hatti temiz',
        detail: 'Dirsekler ne fazla açık ne fazla kapalı.',
      ),
    ],
    'BACK' => const [
      ExerciseGuideChecklistItem(
        title: 'Çekiş dirsekten başlıyor',
        detail: 'Omuzu değil sırtı kullanıyorum.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Boyun serbest',
        detail: 'Trap kasar gibi yüklenmiyorum.',
      ),
    ],
    'LEGS' => const [
      ExerciseGuideChecklistItem(
        title: 'Ayak tabani tam yerde',
        detail: 'Topuk temasi kaybolmuyor.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Diz-ayak hatti korunuyor',
        detail: 'Dizler içe kaçmıyor.',
      ),
    ],
    'CORE' => const [
      ExerciseGuideChecklistItem(
        title: 'Bel kontrol altinda',
        detail: 'Hareket boyunca nötr pozisyona yakınım.',
      ),
      ExerciseGuideChecklistItem(
        title: 'Nefes akıyor',
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
        detail: 'Yük ekleme değil kasta.',
      ),
    ],
  };

  return [...specific, ...common];
}

List<String> _coachPromptsFor(String name, String group) {
  return [
    'Hazır ol. Pozisyonunu kur.',
    _defaultSetupForGroup(group),
    'Nefes al. Merkez bölgeyi sabitle.',
    _defaultExecutionFor(name, group).first,
    _defaultExecutionFor(name, group)[1],
    'Zirvede kontrol sağla.',
    'Nefes ver ve kontrollü dön.',
    'Form bozuluyorsa seti burada bitir.',
  ];
}

Map<String, ExerciseGuideGoalPlan> _goalPlansFor(String name, String group) {
  return {
    'beginner': ExerciseGuideGoalPlan(
      title: 'Yeni başlayan',
      prescription: '2-3 set x 8-12 tekrar, RPE 6-7',
      focus: 'Formu oturt, tam hareket açıklığını acele etmeden öğren.',
    ),
    'muscle': ExerciseGuideGoalPlan(
      title: 'Kas kazanimi',
      prescription: _groupPrescription(group, muscle: true),
      focus: 'Kontrollü negatif, zirvede kısa sıkışma ve sete yakın bitiş.',
    ),
    'fat_loss': ExerciseGuideGoalPlan(
      title: 'Yağ yakımı',
      prescription: '3-4 set x 12-20 tekrar, dinlenme 30-60 sn',
      focus: 'Formu koruyarak yoğunluğu ritim ve toplam hacimle artır.',
    ),
    'home': ExerciseGuideGoalPlan(
      title: 'Evde ekipmansız',
      prescription: '3 set x 10-20 tekrar veya 30-45 sn',
      focus: '$name hareketinin vücut ağırlığı veya bantlı versiyonunu kullan.',
    ),
    'sensitive': ExerciseGuideGoalPlan(
      title: 'Hassasiyet odaklı',
      prescription: '2-3 set x 8-10 kaliteli tekrar',
      focus:
          'Ağrı aralığı dışına çıkma, makine/bant destekli varyasyon tercih et.',
    ),
  };
}

const Map<String, ExerciseGuideOverride> _exerciseGuideOverrides = {
  'bench press': ExerciseGuideOverride(
    setup:
        'Ayaklarını yere kilitle, kürek kemiklerini geriye al ve barı göz hizasında konumlandır.',
    executionSteps: [
      'Barı bilek-dirsek hattını koruyarak alt göğse kontrollü indir.',
      'Alt noktada omuzlarını öne düşürmeden 1 saniye kontrol kur.',
      'Ayak itişini kullanıp barı hafif yay çizerek yukarı gönder.',
    ],
    tempo: '3-1-1: 3 sn iniş, altta 1 sn duruş, 1 sn güçlü itiş.',
    targetMuscles: ['Göğüs', 'Ön omuz', 'Triceps'],
    commonMistakes: [
      ExerciseGuideIssue(
        issue: 'Dirsekleri fazla açmak',
        fix:
            'Dirsekleri omuz hattından hafif aşağıda, 45-70 derece bandında tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Kalça ve sırt set-up’ını kaybetmek',
        fix: 'Set boyunca ayak basıncını koru ve kürek kemiklerini bankta tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Barı göğüste sektirmek',
        fix: 'Alt noktada kısa kontrol kur, momentumla değil kasla it.',
      ),
    ],
  ),
  'barbell row': ExerciseGuideOverride(
    setup:
        'Ayaklarını kalça genişliğinde aç, kalçadan menteşe yap ve gövdeyi yere yakın sabitle.',
    executionSteps: [
      'Barı karın altına doğru çekmeye dirseklerden başla.',
      'Zirvede kürek kemiklerini kısa bir an yaklaştır, boynu gevşek tut.',
      'Ağırlığı bel pozisyonunu bozmadan kontrollü şekilde aşağı bırak.',
    ],
    tempo: '2-1-2: 2 sn çekiş, 1 sn sıkışma, 2 sn kontrollü dönüş.',
    commonMistakes: [
      ExerciseGuideIssue(
        issue: 'Gövdeyi savurmak',
        fix: 'Ağırlığı azalt ve torso açını set boyunca sabit tut.',
      ),
      ExerciseGuideIssue(
        issue: 'Barı göğse çekmek',
        fix: 'Dirsekleri kalçaya sür, çekişi karın altına hedefle.',
      ),
      ExerciseGuideIssue(
        issue: 'Bel nötrünü kaybetmek',
        fix:
            'Karnı kilitle ve hareket açıklığını belin izin verdiği aralıkta tut.',
      ),
    ],
  ),
  'lat pulldown': ExerciseGuideOverride(
    setup:
        'Dizlerini ped altına sabitle, göğsü aç ve bara omuz genişliğinden biraz geniş tutun.',
    executionSteps: [
      'Çekişe omuzları aşağı indirerek başla, sonra dirsekleri yanlara ve aşağı sür.',
      'Barı üst göğse getirirken belden geriye yaslanma miktarını küçük tut.',
      'Kollar tam uzarken omuzları kulağa çekmeden kontrollü yukarı dön.',
    ],
    targetMuscles: ['Lat', 'Teres major', 'Biceps'],
  ),
  'squat': ExerciseGuideOverride(
    setup:
        'Ayaklarını omuz genişliğinde aç, karın basıncını kur ve barı orta ayak üzerinde dengele.',
    executionSteps: [
      'Kalça ve dizleri birlikte kırarak kontrollü şekilde aşağı in.',
      'Dizleri ayak parmakları yönünde takip ettir ve göğüs kafesini açık tut.',
      'Dipten orta ayağa basıp kalça ile omuzları birlikte yukarı çıkar.',
    ],
    targetMuscles: ['Quadriceps', 'Glute', 'Adduktor'],
    commonMistakes: [
      ExerciseGuideIssue(
        issue: 'Dizlerin içe kaçması',
        fix: 'Ayak tabanını yay ve dizleri ayak parmakları yönüne it.',
      ),
      ExerciseGuideIssue(
        issue: 'Dipte belin kapanması',
        fix:
            'Derinliği mobilitenin izin verdiği yerde kes ve core basıncını koru.',
      ),
      ExerciseGuideIssue(
        issue: 'Topukların kalkması',
        fix:
            'Ağırlık merkezini orta ayakta tut, gerekiyorsa stance açını ayarla.',
      ),
    ],
  ),
  'overhead press': ExerciseGuideOverride(
    setup:
        'Kalçaları sık, kaburgaları kapat ve barı köprücük kemiği hizasında başlat.',
    executionSteps: [
      'Barı çene hattından geçirirken başı hafif geri çek.',
      'Bar baş üstüne geldiğinde başı tekrar alta al ve bicepsi kulağa yaklaştır.',
      'Dönüşte kaburgaları açmadan barı aynı hatta kontrollü indir.',
    ],
    stopSignals: [
      'Omuz önünde keskin batma',
      'Belde aşırı yaylanma',
      'Kola vuran uyuşma veya yanma',
    ],
  ),
  'hip thrust': ExerciseGuideOverride(
    setup:
        'Sırtının alt kısmı bench kenarına dayanırken ayaklarını dizler 90 dereceye yakın olacak şekilde yerleştir.',
    executionSteps: [
      'Topuklardan basıp kalçayı yukarı sür.',
      'Üst noktada kaburgaları açmadan kalçayı 1-2 saniye sık.',
      'Belden değil kalçadan kontrolle aşağı in ve gerginliği kaybetme.',
    ],
    targetMuscles: ['Glute max', 'Hamstring', 'Core stabilite'],
  ),
  'barbell curl': ExerciseGuideOverride(
    setup:
        'Dirseklerini gövde yanında sabitle, bilekleri kırma ve omuzları geride tut.',
    executionSteps: [
      'Barı omuzu devreye sokmadan pazuya çek.',
      'Zirvede kısa bir an kasılmayı hisset.',
      'Negatif fazı 2-3 saniyede indirerek gerilimi koru.',
    ],
  ),
  'triceps pushdown': ExerciseGuideOverride(
    setup:
        'Dirseklerini yanlara açmadan gövde yanında sabitle ve omuzlarını aşağı indir.',
    executionSteps: [
      'Barı ya da halatı dirsek açısını sabit tutarak aşağı it.',
      'Alt noktada dirseği kilitlemeden tricepsi 1 saniye sık.',
      'Dönüşte omuzları oynatmadan kontrollü yukarı çık.',
    ],
    targetMuscles: ['Triceps uzun baş', 'Lateral baş', 'Medial baş'],
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
