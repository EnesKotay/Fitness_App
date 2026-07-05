import 'package:flutter/material.dart';
import '../models/workout_program.dart';

/// Hazır program tanımı — UI'da gösterilecek meta veri + gerçek program objesi.
class PresetProgramMeta {
  final String id;
  final String name;
  final String description;
  final String goal;
  final String level;
  final Color levelColor;
  final Color accentColor;
  final IconData icon;
  final int daysPerWeek;
  final int durationWeeks;
  final List<String> tags;
  final WorkoutProgram program;

  /// Ortalama seans süresi (dakika)
  final int avgSessionMinutes;

  /// "Önerilen", "Popüler", "Yeni" gibi rozet
  final String? badge;

  /// Kısa tek satır açıklama (kart altı)
  final String shortDesc;

  const PresetProgramMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.goal,
    required this.level,
    required this.levelColor,
    required this.accentColor,
    required this.icon,
    required this.daysPerWeek,
    required this.durationWeeks,
    required this.tags,
    required this.program,
    this.avgSessionMinutes = 50,
    this.badge,
    this.shortDesc = '',
  });

  int get totalExercises =>
      program.days.fold(0, (sum, d) => sum + d.exercises.length);
}

// ── Helpers ──────────────────────────────────────────────────────────────────

ProgramExercise _ex(
  String name,
  String muscleGroup, {
  int sets = 3,
  int reps = 10,
  int rest = 90,
  String note = '',
}) => ProgramExercise(
  name: name,
  muscleGroup: muscleGroup,
  sets: sets,
  reps: reps,
  restSeconds: rest,
  note: note,
);

ProgramDay _day(String name, List<ProgramExercise> exercises) =>
    ProgramDay(name: name, exercises: exercises);

// ── PROGRAM 0A: Sıfırdan Başla (2 gün) ───────────────────────────────────────

final _zeroToWorkout = PresetProgramMeta(
  id: 'preset_zero_to_workout',
  badge: 'İlk Program',
  shortDesc: 'Hiç spor yapmamış kişiler için',
  avgSessionMinutes: 25,
  name: 'Sıfırdan Başla',
  description:
      'İlk 4 hafta için çok düşük bariyerli başlangıç planı. Amaç hareketleri öğrenmek, eklemleri hazırlamak ve düzen kurmak. Zorlanırsan tekrarları azalt, ağrı hissedersen hareketi bırak.',
  goal: 'Alışkanlık & Temel Hareket',
  level: 'Başlangıç',
  levelColor: const Color(0xFF30D158),
  accentColor: const Color(0xFF30D158),
  icon: Icons.accessibility_new_rounded,
  daysPerWeek: 2,
  durationWeeks: 4,
  tags: ['Başlangıç', '2 Gün', 'Ev', 'Ekipsiz', 'Mobilite'],
  program: WorkoutProgram(
    id: 'preset_zero_to_workout',
    name: 'Sıfırdan Başla',
    description: 'Haftada 2 gün, evde ve ekipsiz temel hareket öğrenme',
    days: [
      _day('1. Gün — Temel Kontrol', [
        _ex(
          'Marching in Place',
          'FULL BODY',
          sets: 1,
          reps: 60,
          rest: 30,
          note: 'Isınma: 60 saniye rahat tempo',
        ),
        _ex(
          'Chair Squat',
          'LEGS',
          sets: 2,
          reps: 8,
          rest: 90,
          note: 'Sandalyeye kontrollü otur-kalk',
        ),
        _ex(
          'Wall Push-Up',
          'CHEST',
          sets: 2,
          reps: 8,
          rest: 90,
          note: 'Duvara şınav, belini sabit tut',
        ),
        _ex(
          'Glute Bridge',
          'GLUTES',
          sets: 2,
          reps: 10,
          rest: 75,
          note: 'Kalçayı sık, belden itme',
        ),
        _ex(
          'Bird Dog',
          'CORE',
          sets: 2,
          reps: 8,
          rest: 60,
          note: 'Her taraf için 8 tekrar',
        ),
        _ex(
          'Plank',
          'CORE',
          sets: 2,
          reps: 20,
          rest: 60,
          note: '20 saniye; form bozulursa bırak',
        ),
      ]),
      _day('2. Gün — Denge & Dayanıklılık', [
        _ex(
          'Step-Up',
          'LEGS',
          sets: 2,
          reps: 8,
          rest: 75,
          note: 'Her bacak; alçak basamak kullan',
        ),
        _ex(
          'Incline Push-Up',
          'CHEST',
          sets: 2,
          reps: 8,
          rest: 90,
          note: 'Masa/tezgah kenarında daha kolay şınav',
        ),
        _ex(
          'Bodyweight Squat',
          'LEGS',
          sets: 2,
          reps: 10,
          rest: 75,
          note: 'Dizler ayak yönünde ilerlesin',
        ),
        _ex(
          'Superman',
          'BACK',
          sets: 2,
          reps: 10,
          rest: 60,
          note: 'Belini sıkıştırmadan kontrollü kaldır',
        ),
        _ex(
          'Dead Bug',
          'CORE',
          sets: 2,
          reps: 8,
          rest: 60,
          note: 'Her taraf için 8 tekrar',
        ),
        _ex(
          'Standing Calf Raise',
          'LEGS',
          sets: 2,
          reps: 12,
          rest: 45,
          note: 'Yavaş in, tepede 1 saniye bekle',
        ),
      ]),
    ],
  ),
);

// ── PROGRAM 0B: Salon İlk Ay (3 gün) ─────────────────────────────────────────

final _gymFirstMonth = PresetProgramMeta(
  id: 'preset_gym_first_month',
  badge: 'Yeni',
  shortDesc: 'Salon makineleriyle güvenli başlangıç',
  avgSessionMinutes: 40,
  name: 'Salon İlk Ay',
  description:
      'Spor salonuna yeni başlayanlar için makineler ve basit dumbbell hareketleriyle hazırlanmış 4 haftalık program. Önce tekniği öğren, son 2 tekrarda zorlanacağın ama formunun bozulmadığı ağırlığı seç.',
  goal: 'Salon Adaptasyonu',
  level: 'Başlangıç',
  levelColor: const Color(0xFF30D158),
  accentColor: const Color(0xFF64D2FF),
  icon: Icons.domain_rounded,
  daysPerWeek: 3,
  durationWeeks: 4,
  tags: ['Başlangıç', '3 Gün', 'Salon', 'Makine', 'Full Body'],
  program: WorkoutProgram(
    id: 'preset_gym_first_month',
    name: 'Salon İlk Ay',
    description: 'Pzt-Çar-Cum, makineli full body başlangıç',
    days: [
      _day('Pazartesi — Full Body A', [
        _ex(
          'Leg Press',
          'LEGS',
          sets: 2,
          reps: 12,
          rest: 90,
          note: 'Hafif başla, dizleri kilitleme',
        ),
        _ex('Machine Chest Press', 'CHEST', sets: 2, reps: 12, rest: 90),
        _ex(
          'Lat Pulldown',
          'BACK',
          sets: 2,
          reps: 12,
          rest: 90,
          note: 'Barı göğse doğru çek',
        ),
        _ex(
          'Seated Cable Row',
          'BACK',
          sets: 2,
          reps: 12,
          rest: 90,
          note: 'Göğüs açık, omuzlar aşağı',
        ),
        _ex(
          'Dumbbell Lateral Raise',
          'SHOULDERS',
          sets: 2,
          reps: 12,
          rest: 60,
          note: 'Çok hafif dumbbell seç',
        ),
        _ex('Plank', 'CORE', sets: 2, reps: 25, rest: 60, note: 'Saniye'),
      ]),
      _day('Çarşamba — Full Body B', [
        _ex(
          'Goblet Squat',
          'LEGS',
          sets: 2,
          reps: 10,
          rest: 90,
          note: 'Dumbbell göğüs hizasında',
        ),
        _ex('Dumbbell Bench Press', 'CHEST', sets: 2, reps: 10, rest: 90),
        _ex(
          'Single Arm Dumbbell Row',
          'BACK',
          sets: 2,
          reps: 10,
          rest: 75,
          note: 'Her kol',
        ),
        _ex(
          'Romanian Deadlift',
          'LEGS',
          sets: 2,
          reps: 10,
          rest: 90,
          note: 'Kalçayı geriye gönder, sırt düz',
        ),
        _ex('Tricep Pushdown', 'TRICEPS', sets: 2, reps: 12, rest: 60),
        _ex('Dead Bug', 'CORE', sets: 2, reps: 10, rest: 60, note: 'Her taraf'),
      ]),
      _day('Cuma — Full Body C', [
        _ex('Leg Extension', 'LEGS', sets: 2, reps: 12, rest: 75),
        _ex('Seated Leg Curl', 'LEGS', sets: 2, reps: 12, rest: 75),
        _ex('Incline Dumbbell Press', 'CHEST', sets: 2, reps: 10, rest: 90),
        _ex('Wide Grip Lat Pulldown', 'BACK', sets: 2, reps: 12, rest: 90),
        _ex('Dumbbell Curl', 'BICEPS', sets: 2, reps: 12, rest: 60),
        _ex('Bicycle Crunch', 'CORE', sets: 2, reps: 16, rest: 45),
      ]),
    ],
  ),
);

// ── PROGRAM 0C: 3 Gün Klasik Split ───────────────────────────────────────────

final _classicThreeDaySplit = PresetProgramMeta(
  id: 'preset_classic_three_day_split',
  badge: 'Klasik Split',
  shortDesc: 'Bacak+Omuz, Göğüs+Triceps, Sırt+Biceps',
  avgSessionMinutes: 50,
  name: '3 Gün Klasik Split',
  description:
      'Haftada 3 gün uygulanan anlaşılır salon split’i. 1. gün bacak ve omuz, 2. gün göğüs ve triceps, 3. gün sırt ve biceps çalışılır. Yeni başlayanlar ağırlığı hafif seçip hareket formunu oturtmalı.',
  goal: 'Kas Gelişimi & Düzen',
  level: 'Başlangıç-Orta',
  levelColor: const Color(0xFF5B9BFF),
  accentColor: const Color(0xFFBF5AF2),
  icon: Icons.view_week_rounded,
  daysPerWeek: 3,
  durationWeeks: 8,
  tags: ['Split', '3 Gün', 'Başlangıç', 'Salon', 'Hacim'],
  program: WorkoutProgram(
    id: 'preset_classic_three_day_split',
    name: '3 Gün Klasik Split',
    description: 'Bacak+Omuz / Göğüs+Triceps / Sırt+Biceps',
    days: [
      _day('1. Gün — Bacak + Omuz', [
        _ex(
          'Leg Press',
          'LEGS',
          sets: 3,
          reps: 12,
          rest: 90,
          note: 'Kontrollü in, dizleri kilitleme',
        ),
        _ex('Goblet Squat', 'LEGS', sets: 3, reps: 10, rest: 90),
        _ex('Romanian Deadlift', 'LEGS', sets: 3, reps: 10, rest: 120),
        _ex('Leg Extension', 'LEGS', sets: 2, reps: 15, rest: 60),
        _ex(
          'Overhead Press (Dumbbell)',
          'SHOULDERS',
          sets: 3,
          reps: 10,
          rest: 90,
        ),
        _ex('Dumbbell Lateral Raise', 'SHOULDERS', sets: 3, reps: 12, rest: 60),
        _ex('Face Pull', 'SHOULDERS', sets: 2, reps: 15, rest: 60),
      ]),
      _day('2. Gün — Göğüs + Triceps', [
        _ex('Machine Chest Press', 'CHEST', sets: 3, reps: 10, rest: 90),
        _ex('Incline Dumbbell Press', 'CHEST', sets: 3, reps: 10, rest: 90),
        _ex('Cable Flye', 'CHEST', sets: 2, reps: 12, rest: 75),
        _ex(
          'Push-Up',
          'CHEST',
          sets: 2,
          reps: 12,
          rest: 60,
          note: 'Gerekirse diz üstü yap',
        ),
        _ex('Tricep Pushdown', 'TRICEPS', sets: 3, reps: 12, rest: 60),
        _ex(
          'Overhead Tricep Extension',
          'TRICEPS',
          sets: 2,
          reps: 12,
          rest: 60,
        ),
      ]),
      _day('3. Gün — Sırt + Biceps', [
        _ex(
          'Lat Pulldown',
          'BACK',
          sets: 3,
          reps: 10,
          rest: 90,
          note: 'Omuzları aşağıda tut',
        ),
        _ex('Seated Cable Row', 'BACK', sets: 3, reps: 10, rest: 90),
        _ex('Single Arm Dumbbell Row', 'BACK', sets: 3, reps: 10, rest: 75),
        _ex('Face Pull', 'SHOULDERS', sets: 2, reps: 15, rest: 60),
        _ex('Dumbbell Curl', 'BICEPS', sets: 3, reps: 12, rest: 60),
        _ex('Hammer Curl', 'BICEPS', sets: 2, reps: 12, rest: 60),
      ]),
    ],
  ),
);

// ── PROGRAM 0D: Yoğunlar İçin 2 Gün Full Body ────────────────────────────────

final _busyTwoDayFullBody = PresetProgramMeta(
  id: 'preset_busy_two_day_full_body',
  badge: 'Pratik',
  shortDesc: 'Az zamanla tüm vücudu çalıştır',
  avgSessionMinutes: 42,
  name: '2 Gün Full Body',
  description:
      'Haftada sadece 2 gün ayırabilenler için tüm büyük kas gruplarını kapsayan pratik program. İki gün arasında en az 1 gün dinlenme bırak. Her hafta 1-2 tekrar veya küçük ağırlık artışı hedefle.',
  goal: 'Genel Güç & Kas',
  level: 'Başlangıç-Orta',
  levelColor: const Color(0xFF5B9BFF),
  accentColor: const Color(0xFFFFB74D),
  icon: Icons.schedule_rounded,
  daysPerWeek: 2,
  durationWeeks: 8,
  tags: ['Full Body', '2 Gün', 'Başlangıç', 'Yoğun Program'],
  program: WorkoutProgram(
    id: 'preset_busy_two_day_full_body',
    name: '2 Gün Full Body',
    description: 'Pzt-Per veya Sal-Cum, tüm vücut pratik plan',
    days: [
      _day('1. Gün — Squat & Press', [
        _ex('Goblet Squat', 'LEGS', sets: 3, reps: 10, rest: 90),
        _ex('Dumbbell Bench Press', 'CHEST', sets: 3, reps: 10, rest: 90),
        _ex('Lat Pulldown', 'BACK', sets: 3, reps: 10, rest: 90),
        _ex('Romanian Deadlift', 'LEGS', sets: 3, reps: 10, rest: 120),
        _ex('Dumbbell Lateral Raise', 'SHOULDERS', sets: 2, reps: 12, rest: 60),
        _ex('Plank', 'CORE', sets: 3, reps: 35, rest: 60, note: 'Saniye'),
      ]),
      _day('2. Gün — Hinge & Row', [
        _ex('Leg Press', 'LEGS', sets: 3, reps: 12, rest: 90),
        _ex('Machine Chest Press', 'CHEST', sets: 3, reps: 10, rest: 90),
        _ex('Seated Cable Row', 'BACK', sets: 3, reps: 10, rest: 90),
        _ex('Hip Thrust', 'GLUTES', sets: 3, reps: 12, rest: 90),
        _ex(
          'Overhead Press (Dumbbell)',
          'SHOULDERS',
          sets: 2,
          reps: 10,
          rest: 75,
        ),
        _ex('Dead Bug', 'CORE', sets: 3, reps: 10, rest: 45, note: 'Her taraf'),
      ]),
    ],
  ),
);

// ── PROGRAM 0E: Kilo Verme Başlangıç Devresi (3 gün) ─────────────────────────

final _fatLossStarterCircuit = PresetProgramMeta(
  id: 'preset_fat_loss_starter_circuit',
  badge: 'Kolay Takip',
  shortDesc: 'Güç + kondisyon, kısa devreler',
  avgSessionMinutes: 32,
  name: 'Kilo Verme Başlangıç',
  description:
      'Yeni başlayanlar için düşük karmaşıklıkta güç ve kondisyon devresi. Hareketleri hızlı değil temiz yap; nefesin çok açılırsa dinlenmeyi 30-60 saniye uzat.',
  goal: 'Yağ Yakımı & Kondisyon',
  level: 'Başlangıç',
  levelColor: const Color(0xFF30D158),
  accentColor: const Color(0xFFFF9F0A),
  icon: Icons.local_fire_department_rounded,
  daysPerWeek: 3,
  durationWeeks: 6,
  tags: ['Başlangıç', '3 Gün', 'Kondisyon', 'Yağ Yakımı', 'Ekipsiz'],
  program: WorkoutProgram(
    id: 'preset_fat_loss_starter_circuit',
    name: 'Kilo Verme Başlangıç',
    description: 'Pzt-Çar-Cum, kısa devre mantığıyla güç ve kondisyon',
    days: [
      _day('Pazartesi — Devre A', [
        _ex(
          'Jumping Jack',
          'FULL BODY',
          sets: 3,
          reps: 30,
          rest: 45,
          note: 'Saniye, rahat tempo',
        ),
        _ex('Bodyweight Squat', 'LEGS', sets: 3, reps: 12, rest: 45),
        _ex('Incline Push-Up', 'CHEST', sets: 3, reps: 8, rest: 60),
        _ex('Glute Bridge', 'GLUTES', sets: 3, reps: 12, rest: 45),
        _ex(
          'Mountain Climber',
          'CORE',
          sets: 3,
          reps: 20,
          rest: 60,
          note: 'Her bacak',
        ),
      ]),
      _day('Çarşamba — Devre B', [
        _ex('Step-Up', 'LEGS', sets: 3, reps: 10, rest: 60, note: 'Her bacak'),
        _ex('Superman', 'BACK', sets: 3, reps: 12, rest: 45),
        _ex(
          'Reverse Lunge',
          'LEGS',
          sets: 3,
          reps: 10,
          rest: 60,
          note: 'Her bacak',
        ),
        _ex('Plank', 'CORE', sets: 3, reps: 30, rest: 60, note: 'Saniye'),
        _ex('Standing Calf Raise', 'LEGS', sets: 3, reps: 15, rest: 45),
      ]),
      _day('Cuma — Devre C', [
        _ex(
          'Marching in Place',
          'FULL BODY',
          sets: 2,
          reps: 60,
          rest: 30,
          note: 'Saniye',
        ),
        _ex(
          'Goblet Squat',
          'LEGS',
          sets: 3,
          reps: 10,
          rest: 60,
          note: 'Dumbbell yoksa vücut ağırlığı',
        ),
        _ex(
          'Push-Up',
          'CHEST',
          sets: 3,
          reps: 8,
          rest: 60,
          note: 'Gerekirse diz üstü',
        ),
        _ex('Bird Dog', 'CORE', sets: 3, reps: 10, rest: 45, note: 'Her taraf'),
        _ex('Bicycle Crunch', 'CORE', sets: 3, reps: 16, rest: 45),
      ]),
    ],
  ),
);

// ── PROGRAM 1: Yeni Başlayan Full Body (3 gün) ───────────────────────────────

final _beginnerFullBody = PresetProgramMeta(
  id: 'preset_beginner_full_body',
  badge: 'Önerilen',
  shortDesc: 'Güne sıfırdan başlamak için ideal',
  avgSessionMinutes: 45,
  name: 'Yeni Başlayan Full Body',
  description:
      'Haftada 3 gün, tüm vücudu çalıştıran başlangıç programı. A ve B günleri dönüşümlü uygulanır. Her seanstan sonra yeterli dinlenme sağlanır.',
  goal: 'Temel Güç',
  level: 'Başlangıç',
  levelColor: const Color(0xFF30D158),
  accentColor: const Color(0xFF30D158),
  icon: Icons.emoji_nature_rounded,
  daysPerWeek: 3,
  durationWeeks: 8,
  tags: ['Full Body', 'Başlangıç', '3 Gün', 'Güç'],
  program: WorkoutProgram(
    id: 'preset_beginner_full_body',
    name: 'Yeni Başlayan Full Body',
    description: 'Pzt-Çar-Cum, A ve B gün dönüşümlü',
    days: [
      _day('Pazartesi — A Günü', [
        _ex(
          'Back Squat',
          'LEGS',
          sets: 3,
          reps: 5,
          rest: 180,
          note: 'Ağırlığı her seansta 2.5 kg artır',
        ),
        _ex('Bench Press', 'CHEST', sets: 3, reps: 5, rest: 180),
        _ex('Barbell Row', 'BACK', sets: 3, reps: 5, rest: 180),
        _ex('Dumbbell Curl', 'BICEPS', sets: 2, reps: 10, rest: 60),
        _ex('Plank', 'CORE', sets: 3, reps: 30, rest: 60, note: 'Saniye'),
      ]),
      _day('Çarşamba — B Günü', [
        _ex(
          'Back Squat',
          'LEGS',
          sets: 3,
          reps: 5,
          rest: 180,
          note: 'A gününden hafif',
        ),
        _ex(
          'Overhead Press (Barbell)',
          'SHOULDERS',
          sets: 3,
          reps: 5,
          rest: 180,
        ),
        _ex(
          'Deadlift',
          'BACK',
          sets: 1,
          reps: 5,
          rest: 240,
          note: 'Tek ağır set',
        ),
        _ex(
          'Pull-Up',
          'BACK',
          sets: 3,
          reps: 5,
          rest: 120,
          note: 'Yapamıyorsan yardımlı kullan',
        ),
        _ex('Ab Wheel Rollout', 'CORE', sets: 3, reps: 8, rest: 60),
      ]),
      _day('Cuma — A Günü (Tekrar)', [
        _ex(
          'Back Squat',
          'LEGS',
          sets: 3,
          reps: 5,
          rest: 180,
          note: 'Çarşambadan 2.5 kg fazla',
        ),
        _ex('Bench Press', 'CHEST', sets: 3, reps: 5, rest: 180),
        _ex('Barbell Row', 'BACK', sets: 3, reps: 5, rest: 180),
        _ex('Dumbbell Curl', 'BICEPS', sets: 2, reps: 10, rest: 60),
        _ex('Plank', 'CORE', sets: 3, reps: 30, rest: 60),
      ]),
    ],
  ),
);

// ── PROGRAM 2: PPL Hipertrofi (6 gün) ────────────────────────────────────────

final _pplHypertrophy = PresetProgramMeta(
  id: 'preset_ppl_hypertrophy',
  badge: 'Popüler',
  shortDesc: 'Kasları haftada 2 kez çalıştır',
  avgSessionMinutes: 70,
  name: 'PPL Hipertrofi',
  description:
      'Push-Pull-Legs formatında haftada 6 gün antrenman. Her kas grubu haftada 2 kez çalışır — kas büyümesi için bilimsel olarak optimal hacim.',
  goal: 'Kas Büyümesi',
  level: 'Orta',
  levelColor: const Color(0xFF5B9BFF),
  accentColor: const Color(0xFF5B9BFF),
  icon: Icons.fitness_center_rounded,
  daysPerWeek: 6,
  durationWeeks: 12,
  tags: ['PPL', 'Hipertrofi', '6 Gün', 'Hacim'],
  program: WorkoutProgram(
    id: 'preset_ppl_hypertrophy',
    name: 'PPL Hipertrofi',
    description: 'Push-Pull-Legs, haftada 2 tur',
    days: [
      _day('Pazartesi — Push A (İtiş)', [
        _ex('Bench Press', 'CHEST', sets: 4, reps: 8, rest: 150),
        _ex('Incline Dumbbell Press', 'CHEST', sets: 3, reps: 10, rest: 120),
        _ex(
          'Overhead Press (Barbell)',
          'SHOULDERS',
          sets: 3,
          reps: 10,
          rest: 120,
        ),
        _ex('Dumbbell Lateral Raise', 'SHOULDERS', sets: 4, reps: 15, rest: 60),
        _ex('Tricep Pushdown', 'TRICEPS', sets: 3, reps: 12, rest: 60),
        _ex('Skull Crusher', 'TRICEPS', sets: 3, reps: 10, rest: 75),
      ]),
      _day('Salı — Pull A (Çekiş)', [
        _ex(
          'Deadlift',
          'BACK',
          sets: 3,
          reps: 5,
          rest: 210,
          note: 'Ağır, iyi form',
        ),
        _ex('Pull-Up', 'BACK', sets: 4, reps: 8, rest: 120),
        _ex('Seated Cable Row', 'BACK', sets: 3, reps: 10, rest: 90),
        _ex('Face Pull', 'SHOULDERS', sets: 3, reps: 15, rest: 60),
        _ex('Barbell Curl', 'BICEPS', sets: 3, reps: 10, rest: 75),
        _ex('Hammer Curl', 'BICEPS', sets: 3, reps: 12, rest: 60),
      ]),
      _day('Çarşamba — Legs A (Bacak)', [
        _ex('Back Squat', 'LEGS', sets: 4, reps: 6, rest: 180),
        _ex('Romanian Deadlift', 'LEGS', sets: 3, reps: 10, rest: 120),
        _ex('Leg Press', 'LEGS', sets: 3, reps: 12, rest: 90),
        _ex('Seated Leg Curl', 'LEGS', sets: 3, reps: 12, rest: 75),
        _ex('Leg Extension', 'LEGS', sets: 3, reps: 15, rest: 60),
        _ex('Standing Calf Raise', 'LEGS', sets: 4, reps: 20, rest: 60),
      ]),
      _day('Perşembe — Push B (İtiş)', [
        _ex('Incline Barbell Press', 'CHEST', sets: 4, reps: 8, rest: 150),
        _ex('Cable Flye', 'CHEST', sets: 3, reps: 12, rest: 90),
        _ex('Arnold Press', 'SHOULDERS', sets: 3, reps: 10, rest: 120),
        _ex('Dumbbell Lateral Raise', 'SHOULDERS', sets: 4, reps: 15, rest: 60),
        _ex(
          'Overhead Tricep Extension',
          'TRICEPS',
          sets: 3,
          reps: 12,
          rest: 75,
        ),
        _ex('Tricep Dip', 'TRICEPS', sets: 3, reps: 10, rest: 90),
      ]),
      _day('Cuma — Pull B (Çekiş)', [
        _ex('Barbell Row', 'BACK', sets: 4, reps: 8, rest: 150),
        _ex('Wide Grip Lat Pulldown', 'BACK', sets: 4, reps: 10, rest: 90),
        _ex('Face Pull', 'SHOULDERS', sets: 3, reps: 15, rest: 60),
        _ex('Rear Delt Fly', 'SHOULDERS', sets: 3, reps: 15, rest: 60),
        _ex('Preacher Curl', 'BICEPS', sets: 3, reps: 12, rest: 75),
        _ex('Cable Curl', 'BICEPS', sets: 3, reps: 15, rest: 60),
      ]),
      _day('Cumartesi — Legs B (Bacak)', [
        _ex('Front Squat', 'LEGS', sets: 4, reps: 8, rest: 180),
        _ex('Hip Thrust', 'GLUTES', sets: 4, reps: 10, rest: 120),
        _ex('Bulgarian Split Squat', 'LEGS', sets: 3, reps: 10, rest: 90),
        _ex('Leg Extension', 'LEGS', sets: 3, reps: 15, rest: 60),
        _ex('Seated Calf Raise', 'LEGS', sets: 4, reps: 20, rest: 60),
      ]),
    ],
  ),
);

// ── PROGRAM 3: Upper/Lower Split (4 gün) ─────────────────────────────────────

final _upperLower = PresetProgramMeta(
  id: 'preset_upper_lower',
  shortDesc: 'Güç ve hacim bir arada',
  avgSessionMinutes: 55,
  name: 'Upper / Lower Split',
  description:
      'Haftada 4 gün, üst-alt vücut ayrımıyla hem güç hem hacim. Kas grupları haftada 2 kez çalışır. Pzt-Sal-Per-Cum formatı önerilir.',
  goal: 'Güç & Hacim',
  level: 'Orta',
  levelColor: const Color(0xFF5B9BFF),
  accentColor: const Color(0xFFFFB74D),
  icon: Icons.swap_vert_rounded,
  daysPerWeek: 4,
  durationWeeks: 10,
  tags: ['Upper/Lower', 'Güç', 'Hacim', '4 Gün'],
  program: WorkoutProgram(
    id: 'preset_upper_lower',
    name: 'Upper / Lower Split',
    description: 'Pzt=Üst A, Sal=Alt A, Per=Üst B, Cum=Alt B',
    days: [
      _day('Pazartesi — Üst Vücut A (Güç)', [
        _ex('Bench Press', 'CHEST', sets: 4, reps: 6, rest: 180),
        _ex('Barbell Row', 'BACK', sets: 4, reps: 6, rest: 180),
        _ex(
          'Overhead Press (Barbell)',
          'SHOULDERS',
          sets: 3,
          reps: 8,
          rest: 120,
        ),
        _ex('Pull-Up', 'BACK', sets: 3, reps: 8, rest: 120),
        _ex('Skull Crusher', 'TRICEPS', sets: 3, reps: 10, rest: 75),
        _ex('Barbell Curl', 'BICEPS', sets: 3, reps: 10, rest: 75),
      ]),
      _day('Salı — Alt Vücut A (Güç)', [
        _ex('Back Squat', 'LEGS', sets: 4, reps: 6, rest: 210),
        _ex('Romanian Deadlift', 'LEGS', sets: 3, reps: 8, rest: 150),
        _ex('Leg Press', 'LEGS', sets: 3, reps: 10, rest: 90),
        _ex('Seated Leg Curl', 'LEGS', sets: 3, reps: 12, rest: 75),
        _ex('Standing Calf Raise', 'LEGS', sets: 4, reps: 15, rest: 60),
      ]),
      _day('Perşembe — Üst Vücut B (Hacim)', [
        _ex('Incline Dumbbell Press', 'CHEST', sets: 4, reps: 10, rest: 120),
        _ex('Wide Grip Lat Pulldown', 'BACK', sets: 4, reps: 10, rest: 90),
        _ex('Arnold Press', 'SHOULDERS', sets: 3, reps: 12, rest: 90),
        _ex('Seated Cable Row', 'BACK', sets: 3, reps: 12, rest: 75),
        _ex('Tricep Pushdown', 'TRICEPS', sets: 3, reps: 12, rest: 60),
        _ex('Hammer Curl', 'BICEPS', sets: 3, reps: 12, rest: 60),
      ]),
      _day('Cuma — Alt Vücut B (Hacim)', [
        _ex('Front Squat', 'LEGS', sets: 4, reps: 8, rest: 180),
        _ex('Hip Thrust', 'GLUTES', sets: 4, reps: 10, rest: 120),
        _ex('Bulgarian Split Squat', 'LEGS', sets: 3, reps: 10, rest: 90),
        _ex('Leg Extension', 'LEGS', sets: 3, reps: 15, rest: 60),
        _ex('Seated Calf Raise', 'LEGS', sets: 4, reps: 15, rest: 60),
      ]),
    ],
  ),
);

// ── PROGRAM 4: Güç Bloğu / Powerlifting (3 gün) ──────────────────────────────

final _strengthBlock = PresetProgramMeta(
  id: 'preset_strength_block',
  shortDesc: 'Squat, bench, deadlift odaklı',
  avgSessionMinutes: 60,
  name: 'Güç Bloğu',
  description:
      'Squat, Bench Press ve Deadlift üçgenine odaklanan güç programı. Texas Method prensibini temel alır: Hacim Günü → Toparlanma → PR Günü.',
  goal: 'Maksimal Güç',
  level: 'İleri',
  levelColor: const Color(0xFFFF6B6B),
  accentColor: const Color(0xFFFF6B6B),
  icon: Icons.sports_martial_arts_rounded,
  daysPerWeek: 3,
  durationWeeks: 8,
  tags: ['Powerlifting', 'Güç', '3 Gün', 'İleri'],
  program: WorkoutProgram(
    id: 'preset_strength_block',
    name: 'Güç Bloğu (Texas Method)',
    description: 'Pzt=Hacim, Çar=Toparlanma, Cum=PR',
    days: [
      _day('Pazartesi — Hacim Günü', [
        _ex(
          'Back Squat',
          'LEGS',
          sets: 5,
          reps: 5,
          rest: 210,
          note: '%90 1RM ağırlık',
        ),
        _ex('Bench Press', 'CHEST', sets: 5, reps: 5, rest: 210),
        _ex('Barbell Row', 'BACK', sets: 5, reps: 5, rest: 180),
        _ex('Ab Wheel Rollout', 'CORE', sets: 3, reps: 10, rest: 60),
      ]),
      _day('Çarşamba — Toparlanma Günü', [
        _ex(
          'Back Squat',
          'LEGS',
          sets: 2,
          reps: 5,
          rest: 120,
          note: 'Pazartesinin %80\'i',
        ),
        _ex(
          'Overhead Press (Barbell)',
          'SHOULDERS',
          sets: 3,
          reps: 5,
          rest: 180,
        ),
        _ex(
          'Deadlift',
          'BACK',
          sets: 1,
          reps: 5,
          rest: 240,
          note: 'Tek ağır set',
        ),
        _ex('Face Pull', 'SHOULDERS', sets: 3, reps: 15, rest: 60),
        _ex('Plank', 'CORE', sets: 3, reps: 60, rest: 60),
      ]),
      _day('Cuma — PR (Kişisel Rekor) Günü', [
        _ex(
          'Back Squat',
          'LEGS',
          sets: 1,
          reps: 5,
          rest: 300,
          note: 'Yeni rekor hedefle',
        ),
        _ex(
          'Bench Press',
          'CHEST',
          sets: 1,
          reps: 5,
          rest: 300,
          note: 'Yeni rekor hedefle',
        ),
        _ex(
          'Deadlift',
          'BACK',
          sets: 5,
          reps: 3,
          rest: 210,
          note: 'Hacim turu',
        ),
        _ex('Pull-Up', 'BACK', sets: 3, reps: 8, rest: 90),
        _ex('Dip', 'TRICEPS', sets: 3, reps: 8, rest: 75),
      ]),
    ],
  ),
);

// ── PROGRAM 5: Bro Split / Estetik (5 gün) ───────────────────────────────────

final _broSplit = PresetProgramMeta(
  id: 'preset_bro_split',
  shortDesc: 'Klasik 5 günlük bölme antrenmanı',
  avgSessionMinutes: 65,
  name: 'Bro Split — Estetik',
  description:
      'Klasik 5 günlük bölme antrenmanı. Her gün tek kas grubu maksimum hacimle çalışır. Görsel olarak gelişmiş bir vücut için tasarlanmıştır.',
  goal: 'Estetik & Hacim',
  level: 'Orta',
  levelColor: const Color(0xFF5B9BFF),
  accentColor: const Color(0xFFBF5AF2),
  icon: Icons.star_rounded,
  daysPerWeek: 5,
  durationWeeks: 12,
  tags: ['Bro Split', 'Estetik', '5 Gün', 'Klasik'],
  program: WorkoutProgram(
    id: 'preset_bro_split',
    name: 'Bro Split — Estetik',
    description: 'Pzt=Göğüs, Sal=Sırt, Çar=Omuz, Per=Bacak, Cum=Kol',
    days: [
      _day('Pazartesi — Göğüs', [
        _ex('Bench Press', 'CHEST', sets: 4, reps: 8, rest: 150),
        _ex('Incline Barbell Press', 'CHEST', sets: 4, reps: 8, rest: 120),
        _ex('Incline Dumbbell Press', 'CHEST', sets: 3, reps: 10, rest: 90),
        _ex('Cable Flye', 'CHEST', sets: 3, reps: 12, rest: 75),
        _ex(
          'Dip',
          'CHEST',
          sets: 3,
          reps: 10,
          rest: 75,
          note: 'Öne eğilerek göğüs odaklı',
        ),
        _ex('Push-Up', 'CHEST', sets: 2, reps: 20, rest: 60, note: 'Finişer'),
      ]),
      _day('Salı — Sırt', [
        _ex(
          'Deadlift',
          'BACK',
          sets: 3,
          reps: 5,
          rest: 210,
          note: 'Güçlü başlangıç',
        ),
        _ex('Pull-Up', 'BACK', sets: 4, reps: 8, rest: 120),
        _ex('Wide Grip Lat Pulldown', 'BACK', sets: 4, reps: 10, rest: 90),
        _ex('Seated Cable Row', 'BACK', sets: 4, reps: 10, rest: 90),
        _ex('Face Pull', 'SHOULDERS', sets: 3, reps: 15, rest: 60),
        _ex('Shrug', 'BACK', sets: 3, reps: 15, rest: 60),
      ]),
      _day('Çarşamba — Omuz', [
        _ex(
          'Overhead Press (Barbell)',
          'SHOULDERS',
          sets: 4,
          reps: 8,
          rest: 150,
        ),
        _ex('Dumbbell Lateral Raise', 'SHOULDERS', sets: 4, reps: 15, rest: 60),
        _ex('Arnold Press', 'SHOULDERS', sets: 3, reps: 10, rest: 90),
        _ex('Rear Delt Fly', 'SHOULDERS', sets: 3, reps: 15, rest: 60),
        _ex('Upright Row', 'SHOULDERS', sets: 3, reps: 12, rest: 75),
        _ex('Front Raise', 'SHOULDERS', sets: 3, reps: 12, rest: 60),
      ]),
      _day('Perşembe — Bacak', [
        _ex('Back Squat', 'LEGS', sets: 4, reps: 8, rest: 180),
        _ex('Romanian Deadlift', 'LEGS', sets: 3, reps: 10, rest: 120),
        _ex('Leg Press', 'LEGS', sets: 4, reps: 12, rest: 90),
        _ex('Leg Extension', 'LEGS', sets: 3, reps: 15, rest: 60),
        _ex('Seated Leg Curl', 'LEGS', sets: 3, reps: 15, rest: 60),
        _ex('Standing Calf Raise', 'LEGS', sets: 5, reps: 20, rest: 60),
      ]),
      _day('Cuma — Kol', [
        _ex('Barbell Curl', 'BICEPS', sets: 4, reps: 10, rest: 75),
        _ex('Skull Crusher', 'TRICEPS', sets: 4, reps: 10, rest: 75),
        _ex('Hammer Curl', 'BICEPS', sets: 3, reps: 12, rest: 60),
        _ex('Tricep Pushdown', 'TRICEPS', sets: 3, reps: 12, rest: 60),
        _ex('Preacher Curl', 'BICEPS', sets: 3, reps: 12, rest: 60),
        _ex(
          'Overhead Tricep Extension',
          'TRICEPS',
          sets: 3,
          reps: 12,
          rest: 60,
        ),
        _ex(
          'Cable Curl',
          'BICEPS',
          sets: 2,
          reps: 15,
          rest: 45,
          note: 'Finişer',
        ),
      ]),
    ],
  ),
);

// ── PROGRAM 6: Ev Antrenmanı — Ekipsiz (3 gün) ───────────────────────────────

final _homeWorkout = PresetProgramMeta(
  id: 'preset_home_workout',
  badge: 'Ekipsiz',
  shortDesc: 'Hiç ekipman gerektirmez',
  avgSessionMinutes: 35,
  name: 'Ev Antrenmanı',
  description:
      'Hiç ekipman gerektirmeyen, evde yapılabilen program. Vücut ağırlığı hareketleriyle hem güç hem kondisyon gelişimi sağlar.',
  goal: 'Kondisyon & Güç',
  level: 'Başlangıç',
  levelColor: const Color(0xFF30D158),
  accentColor: const Color(0xFF30D158),
  icon: Icons.home_rounded,
  daysPerWeek: 3,
  durationWeeks: 6,
  tags: ['Ev', 'Ekipsiz', '3 Gün', 'Başlangıç'],
  program: WorkoutProgram(
    id: 'preset_home_workout',
    name: 'Ev Antrenmanı — Ekipsiz',
    description: 'Pzt=Üst, Çar=Alt, Cum=Full Body',
    days: [
      _day('Pazartesi — Üst Vücut', [
        _ex(
          'Push-Up',
          'CHEST',
          sets: 4,
          reps: 15,
          rest: 75,
          note: 'Dar veya geniş tutuş değiştirebilirsin',
        ),
        _ex('Pike Push-Up', 'SHOULDERS', sets: 3, reps: 10, rest: 75),
        _ex('Diamond Push-Up', 'TRICEPS', sets: 3, reps: 10, rest: 60),
        _ex(
          'Dip',
          'TRICEPS',
          sets: 3,
          reps: 12,
          rest: 75,
          note: 'Sandalye veya sehpa',
        ),
        _ex('Superman', 'BACK', sets: 3, reps: 15, rest: 60),
        _ex('Plank', 'CORE', sets: 3, reps: 45, rest: 60, note: 'Saniye'),
      ]),
      _day('Çarşamba — Alt Vücut', [
        _ex('Bodyweight Squat', 'LEGS', sets: 4, reps: 20, rest: 60),
        _ex(
          'Reverse Lunge',
          'LEGS',
          sets: 3,
          reps: 12,
          rest: 60,
          note: 'Her bacak',
        ),
        _ex('Glute Bridge', 'GLUTES', sets: 4, reps: 20, rest: 60),
        _ex(
          'Hip Thrust',
          'GLUTES',
          sets: 3,
          reps: 15,
          rest: 75,
          note: 'Sırtın sehpada',
        ),
        _ex('Standing Calf Raise', 'LEGS', sets: 3, reps: 25, rest: 45),
        _ex('Wall Sit', 'LEGS', sets: 3, reps: 45, rest: 60, note: 'Saniye'),
      ]),
      _day('Cuma — Full Body & Core', [
        _ex('Burpee', 'FULL BODY', sets: 3, reps: 10, rest: 90),
        _ex('Push-Up', 'CHEST', sets: 3, reps: 12, rest: 60),
        _ex('Bodyweight Squat', 'LEGS', sets: 3, reps: 15, rest: 60),
        _ex(
          'Mountain Climber',
          'CORE',
          sets: 3,
          reps: 30,
          rest: 60,
          note: 'Her bacak',
        ),
        _ex('Bicycle Crunch', 'CORE', sets: 3, reps: 20, rest: 45),
        _ex('Plank', 'CORE', sets: 3, reps: 60, rest: 60),
      ]),
    ],
  ),
);

// ── PROGRAM 7: Kadın — Glute & Toning (4 gün) ────────────────────────────────

final _womenGluteToning = PresetProgramMeta(
  id: 'preset_women_glute_toning',
  badge: 'Popüler',
  shortDesc: 'Kalça ve üst vücut dengeli gelişimi',
  avgSessionMinutes: 50,
  name: 'Kadın — Glute & Toning',
  description:
      'Kalça ve bacak gelişimine odaklanan, üst vücut tonlamayı da kapsayan 4 günlük program. Her antrenman 45-55 dakika sürer.',
  goal: 'Kalça & Toning',
  level: 'Başlangıç-Orta',
  levelColor: const Color(0xFFBF5AF2),
  accentColor: const Color(0xFFBF5AF2),
  icon: Icons.favorite_rounded,
  daysPerWeek: 4,
  durationWeeks: 10,
  tags: ['Glute', 'Toning', '4 Gün', 'Kadın'],
  program: WorkoutProgram(
    id: 'preset_women_glute_toning',
    name: 'Kadın — Glute & Toning',
    description: 'Pzt=Alt Ön, Sal=Üst, Per=Alt Arka, Cum=Üst+Core',
    days: [
      _day('Pazartesi — Alt Ön (Quad & Glute)', [
        _ex(
          'Hip Thrust',
          'GLUTES',
          sets: 4,
          reps: 12,
          rest: 90,
          note: 'En önemli hareket',
        ),
        _ex('Back Squat', 'LEGS', sets: 4, reps: 10, rest: 120),
        _ex(
          'Walking Lunge',
          'LEGS',
          sets: 3,
          reps: 12,
          rest: 75,
          note: 'Her bacak',
        ),
        _ex('Leg Extension', 'LEGS', sets: 3, reps: 15, rest: 60),
        _ex('Standing Calf Raise', 'LEGS', sets: 3, reps: 20, rest: 45),
      ]),
      _day('Salı — Üst Vücut', [
        _ex('Dumbbell Bench Press', 'CHEST', sets: 3, reps: 12, rest: 90),
        _ex('Wide Grip Lat Pulldown', 'BACK', sets: 3, reps: 12, rest: 90),
        _ex('Dumbbell Lateral Raise', 'SHOULDERS', sets: 3, reps: 15, rest: 60),
        _ex('Seated Cable Row', 'BACK', sets: 3, reps: 12, rest: 75),
        _ex('Dumbbell Curl', 'BICEPS', sets: 3, reps: 12, rest: 60),
        _ex('Tricep Pushdown', 'TRICEPS', sets: 3, reps: 12, rest: 60),
      ]),
      _day('Perşembe — Alt Arka (Hamstring & Glute)', [
        _ex('Romanian Deadlift', 'LEGS', sets: 4, reps: 10, rest: 120),
        _ex(
          'Bulgarian Split Squat',
          'LEGS',
          sets: 3,
          reps: 10,
          rest: 90,
          note: 'Her bacak',
        ),
        _ex(
          'Glute Kickback (Cable)',
          'GLUTES',
          sets: 3,
          reps: 15,
          rest: 60,
          note: 'Her bacak',
        ),
        _ex('Hip Abduction (Machine)', 'GLUTES', sets: 3, reps: 20, rest: 60),
        _ex('Seated Leg Curl', 'LEGS', sets: 3, reps: 15, rest: 60),
      ]),
      _day('Cuma — Üst Vücut + Core', [
        _ex(
          'Overhead Press (Dumbbell)',
          'SHOULDERS',
          sets: 3,
          reps: 12,
          rest: 90,
        ),
        _ex(
          'Pull-Up',
          'BACK',
          sets: 3,
          reps: 8,
          rest: 90,
          note: 'Yardımlı bantla olabilir',
        ),
        _ex('Incline Dumbbell Press', 'CHEST', sets: 3, reps: 12, rest: 75),
        _ex('Face Pull', 'SHOULDERS', sets: 3, reps: 15, rest: 60),
        _ex('Plank', 'CORE', sets: 3, reps: 60, rest: 60),
        _ex('Russian Twist', 'CORE', sets: 3, reps: 20, rest: 45),
      ]),
    ],
  ),
);

// ── PROGRAM 8: Atletik Performans (4 gün) ────────────────────────────────────

final _athletic = PresetProgramMeta(
  id: 'preset_athletic_performance',
  shortDesc: 'Güç, patlayıcılık ve çeviklik',
  avgSessionMinutes: 60,
  name: 'Atletik Performans',
  description:
      'Güç, patlayıcılık ve çevikliği bir arada geliştiren 4 günlük program. Sporcular ve aktif bireyler için; sadece estetik değil performans odaklı.',
  goal: 'Güç & Performans',
  level: 'Orta-İleri',
  levelColor: const Color(0xFFFF9F0A),
  accentColor: const Color(0xFFFF9F0A),
  icon: Icons.sports_rounded,
  daysPerWeek: 4,
  durationWeeks: 8,
  tags: ['Atletik', 'Performans', '4 Gün', 'Patlayıcı'],
  program: WorkoutProgram(
    id: 'preset_athletic_performance',
    name: 'Atletik Performans',
    description: 'Pzt=Güç Alt, Sal=Güç Üst, Per=Patlayıcı, Cum=Dayanıklılık',
    days: [
      _day('Pazartesi — Güç (Alt Vücut)', [
        _ex(
          'Back Squat',
          'LEGS',
          sets: 5,
          reps: 3,
          rest: 240,
          note: 'Maksimal yük, %90 1RM',
        ),
        _ex('Deadlift', 'BACK', sets: 3, reps: 3, rest: 240),
        _ex(
          'Box Jump',
          'LEGS',
          sets: 4,
          reps: 5,
          rest: 120,
          note: 'Yumuşak iniş',
        ),
        _ex('Bulgarian Split Squat', 'LEGS', sets: 3, reps: 8, rest: 90),
        _ex('Plank', 'CORE', sets: 3, reps: 60, rest: 60),
      ]),
      _day('Salı — Güç (Üst Vücut)', [
        _ex(
          'Bench Press',
          'CHEST',
          sets: 5,
          reps: 3,
          rest: 210,
          note: 'Maksimal yük',
        ),
        _ex('Barbell Row', 'BACK', sets: 4, reps: 5, rest: 180),
        _ex('Pull-Up', 'BACK', sets: 4, reps: 8, rest: 120),
        _ex(
          'Overhead Press (Barbell)',
          'SHOULDERS',
          sets: 3,
          reps: 6,
          rest: 150,
        ),
        _ex('Medicine Ball Slam', 'CORE', sets: 3, reps: 10, rest: 90),
      ]),
      _day('Perşembe — Patlayıcı & Güç Dayanıklılığı', [
        _ex('Front Squat', 'LEGS', sets: 4, reps: 5, rest: 180),
        _ex('Romanian Deadlift', 'LEGS', sets: 3, reps: 6, rest: 150),
        _ex('Dip', 'TRICEPS', sets: 4, reps: 10, rest: 90),
        _ex(
          'Single Leg Romanian Deadlift',
          'LEGS',
          sets: 3,
          reps: 8,
          rest: 90,
          note: 'Her bacak, denge odaklı',
        ),
        _ex(
          'Farmer\'s Walk',
          'FULL BODY',
          sets: 3,
          reps: 30,
          rest: 120,
          note: 'Metre',
        ),
      ]),
      _day('Cuma — Dayanıklılık & Tamamlama', [
        _ex('Barbell Row', 'BACK', sets: 3, reps: 8, rest: 90),
        _ex('Push-Up', 'CHEST', sets: 3, reps: 20, rest: 60),
        _ex(
          'Walking Lunge',
          'LEGS',
          sets: 3,
          reps: 12,
          rest: 75,
          note: 'Her bacak',
        ),
        _ex('Mountain Climber', 'CORE', sets: 3, reps: 30, rest: 60),
        _ex('Plank', 'CORE', sets: 3, reps: 60, rest: 60),
        _ex('Ab Wheel Rollout', 'CORE', sets: 3, reps: 10, rest: 60),
      ]),
    ],
  ),
);

// ── Tüm Hazır Programlar ─────────────────────────────────────────────────────

final List<PresetProgramMeta> kPresetPrograms = [
  _zeroToWorkout,
  _gymFirstMonth,
  _classicThreeDaySplit,
  _fatLossStarterCircuit,
  _busyTwoDayFullBody,
  _beginnerFullBody,
  _homeWorkout,
  _upperLower,
  _pplHypertrophy,
  _womenGluteToning,
  _broSplit,
  _athletic,
  _strengthBlock,
];
