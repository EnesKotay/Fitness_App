
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_entry.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/usecases/calorie_calculator.dart';
import '../../domain/usecases/food_calculator.dart';
import '../../domain/usecases/diary_service.dart';
import '../../data/repositories/local_diary_repository.dart';
import '../state/diet_provider.dart';
import '../../../workout/providers/workout_provider.dart';
import '../../../../core/models/workout_models.dart';
import '../../../auth/providers/auth_provider.dart';

/// Sadece debug modda (kReleaseMode == false) kullanılan test sayfası.
/// Örnek profiller, hesaplanan değerler, otomatik doğrulamalar (PASS/FAIL) ve hızlı aksiyonlar.
class TestModePage extends StatefulWidget {
  const TestModePage({super.key});

  @override
  State<TestModePage> createState() => _TestModePageState();
}

class _TestResult {
  final String name;
  final bool passed;
  final String detail;

  _TestResult(this.name, this.passed, this.detail);
}

class _TestModePageState extends State<TestModePage> {
  final LocalDiaryRepository _repo = LocalDiaryRepository();
  late final DiaryService _diaryService;
  final _uuid = const Uuid();

  UserProfile? _selectedProfile;
  double? _bmr;
  double? _tdee;
  double? _target;
  List<_TestResult> _results = [];
  bool _testsRunning = false;

  static final List<({String label, UserProfile profile})> _exampleProfiles = [
    (label: 'Erkek 30, 80kg, 175cm, Orta, Koru', profile: UserProfile(
      name: 'Test 1', age: 30, weight: 80, height: 175, gender: Gender.male,
      activityLevel: ActivityLevel.moderatelyActive, goal: Goal.maintainWeight,
    )),
    (label: 'Erkek 30, 80kg, 175cm, Orta, Kilo ver', profile: UserProfile(
      name: 'Test 2', age: 30, weight: 80, height: 175, gender: Gender.male,
      activityLevel: ActivityLevel.moderatelyActive, goal: Goal.loseWeight,
    )),
    (label: 'Erkek 30, 80kg, 175cm, Orta, Kilo al', profile: UserProfile(
      name: 'Test 3', age: 30, weight: 80, height: 175, gender: Gender.male,
      activityLevel: ActivityLevel.moderatelyActive, goal: Goal.gainWeight,
    )),
    (label: 'Kadın 25, 60kg, 165cm', profile: UserProfile(
      name: 'Test 4', age: 25, weight: 60, height: 165, gender: Gender.female,
      activityLevel: ActivityLevel.sedentary, goal: Goal.loseWeight,
    )),
  ];

  @override
  void initState() {
    super.initState();
    _diaryService = DiaryService(_repo);
    _selectedProfile = _exampleProfiles.first.profile;
    _recalcValues();
  }

  void _recalcValues() {
    if (_selectedProfile == null) return;
    setState(() {
      _bmr = CalorieCalculator.calculateBmr(_selectedProfile!);
      _tdee = CalorieCalculator.calculateTdee(_selectedProfile!);
      _target = CalorieCalculator.calculateDailyTarget(_selectedProfile!);
    });
  }

  Future<void> _runTests() async {
    setState(() => _testsRunning = true);
    final results = <_TestResult>[];

    // A) Profil persistence
    try {
      final testProfile = UserProfile(
        name: 'test-persist-${_uuid.v4()}',
        age: 35,
        weight: 75,
        height: 170,
        gender: Gender.male,
        activityLevel: ActivityLevel.lightlyActive,
        goal: Goal.maintainWeight,
      );
      await _repo.saveProfile(testProfile);
      final read = await _repo.getProfile();
      final same = read != null &&
          read.name == testProfile.name &&
          read.gender == testProfile.gender &&
          read.age == testProfile.age &&
          read.weight == testProfile.weight &&
          read.height == testProfile.height &&
          read.activityLevel == testProfile.activityLevel &&
          read.goal == testProfile.goal;
      results.add(_TestResult(
        'A) Profil persistence (Hive\'a yazılıp okunuyor mu?)',
        same,
        same ? 'Profil kaydedildi ve aynı okundu.' : 'Okunan profil farklı: name=${read?.name}, weight=${read?.weight}, height=${read?.height}',
      ));
    } catch (e) {
      results.add(_TestResult('A) Profil persistence', false, 'Hata: $e'));
    }

    // B) Hedef kalori doğrulama
    final maleMaintain = _exampleProfiles[0].profile;
    final bmrM = CalorieCalculator.calculateBmr(maleMaintain);
    final tdeeM = CalorieCalculator.calculateTdee(maleMaintain);
    final targetM = CalorieCalculator.calculateDailyTarget(maleMaintain);
    final bmrOk = (bmrM.round() == 1749);
    final tdeeOk = (tdeeM.round() == 2711);
    final targetMaintainOk = (targetM.round() == 2711);
    results.add(_TestResult(
      'B1) BMR/TDEE/Target Koru (Erkek 30,80,175, Orta)',
      bmrOk && tdeeOk && targetMaintainOk,
      'Beklenen: BMR≈1749, TDEE≈2711, Target≈2711. Gerçek: BMR=${bmrM.round()}, TDEE=${tdeeM.round()}, Target=${targetM.round()}',
    ));
    final maleLose = _exampleProfiles[1].profile;
    final targetLose = CalorieCalculator.calculateDailyTarget(maleLose);
    results.add(_TestResult(
      'B2) Target Kilo ver (%15 açık)',
      targetLose.round() == 2304,
      'Beklenen: ≈2304. Gerçek: ${targetLose.round()}',
    ));
    final maleGain = _exampleProfiles[2].profile;
    final targetGain = CalorieCalculator.calculateDailyTarget(maleGain);
    results.add(_TestResult(
      'B3) Target Kilo al (%10 fazla)',
      targetGain.round() == 2982,
      'Beklenen: ≈2982. Gerçek: ${targetGain.round()}',
    ));
    final female = _exampleProfiles[3].profile;
    final bmrF = CalorieCalculator.calculateBmr(female);
    results.add(_TestResult(
      'B4) BMR Kadın (25, 60, 165)',
      bmrF.round() == 1345,
      'Beklenen: ≈1345. Gerçek: ${bmrF.round()}',
    ));

    // C) Porsiyon hesabı
    const testFood = FoodItem(
      id: 't1', 
      name: 'Test 250kcal', 
      category: 'Test',
      basis: FoodBasis(amount: 100, unit: 'g'),
      nutrients: Nutrients(kcal: 250, protein: 0, carb: 0, fat: 0),
    );
    final kcal180 = FoodCalculator.calculateCalories(testFood, 180);
    final kcal0 = FoodCalculator.calculateCalories(testFood, 0);
    final kcalNeg = FoodCalculator.calculateCalories(testFood, -50);
    results.add(_TestResult(
      'C) Porsiyon 180g → 450 kcal; 0/neg → 0',
      kcal180 == 450 && kcal0 == 0 && kcalNeg == 0,
      '180g: $kcal180 (beklenen 450). 0g: $kcal0. -50g: $kcalNeg.',
    ));

    // D) Tarih normalize
    final now = DateTime.now();
    final todayStr = DiaryService.normalizeDate(now);
    final todayEvening = DateTime(now.year, now.month, now.day, 23, 59);
    final todayStr2 = DiaryService.normalizeDate(todayEvening);
    final sameDay = todayStr == todayStr2;
    results.add(_TestResult(
      'D) normalizeDate aynı gün farklı saat → aynı key',
      sameDay,
      'Sabah: $todayStr, Akşam: $todayStr2. Aynı: $sameDay',
    ));

    // E) Öğün toplamları: 3 entry ekle (100, 200, 150), toplam 450 ve öğün bazı doğru mu?
    final today = DateTime(now.year, now.month, now.day);
    final dateTodayStr = DiaryService.normalizeDate(today);
    final totalBefore = await _diaryService.getTotalsByDate(today);
    final e1 = FoodEntry(id: _uuid.v4(), date: dateTodayStr, mealType: MealType.breakfast, foodId: 'e1', foodName: 'E1', grams: 100, calculatedKcal: 100, createdAt: DateTime.now());
    final e2 = FoodEntry(id: _uuid.v4(), date: dateTodayStr, mealType: MealType.lunch, foodId: 'e2', foodName: 'E2', grams: 100, calculatedKcal: 200, createdAt: DateTime.now());
    final e3 = FoodEntry(id: _uuid.v4(), date: dateTodayStr, mealType: MealType.dinner, foodId: 'e3', foodName: 'E3', grams: 100, calculatedKcal: 150, createdAt: DateTime.now());
    await _diaryService.addEntry(e1);
    await _diaryService.addEntry(e2);
    await _diaryService.addEntry(e3);
    final totals = await _diaryService.getTotalsByDate(today);
    final byMeal = await _diaryService.getTotalsByMeal(today);
    final delta = totals.totalKcal - totalBefore.totalKcal;
    final totalOk = delta.round() == 450;
    final mealOk = (byMeal[MealType.breakfast] ?? 0) >= 100 &&
        (byMeal[MealType.lunch] ?? 0) >= 200 &&
        (byMeal[MealType.dinner] ?? 0) >= 150;
    results.add(_TestResult(
      'E) Öğün toplamları (Kahvaltı 100 + Öğle 200 + Akşam 150 = 450)',
      totalOk && mealOk,
      'Eklenen toplam: ${delta.round()} (beklenen 450). Öğünler: K=${byMeal[MealType.breakfast]?.round()}, Ö=${byMeal[MealType.lunch]?.round()}, A=${byMeal[MealType.dinner]?.round()}.',
    ));
    await _repo.deleteEntry(e1.id);
    await _repo.deleteEntry(e2.id);
    await _repo.deleteEntry(e3.id);

    // F) Makrodan kalori (kcalPer100g null)
    const macroFood = FoodItem(
      id: 'm1', 
      name: 'Macro', 
      category: 'Test',
      basis: FoodBasis(amount: 100, unit: 'g'),
      nutrients: Nutrients(kcal: 0, protein: 10, carb: 20, fat: 5), // 0 kcal -> fallback to macros
    );
    final kcal100 = FoodCalculator.calculateCalories(macroFood, 100);
    final expectedMacro = 4 * 10 + 4 * 20 + 9 * 5; // 40+80+45 = 165
    results.add(_TestResult(
      'F) Makrodan kcal (4*P+4*C+9*F, 100g)',
      kcal100 == expectedMacro,
      'Beklenen: $expectedMacro. Gerçek: $kcal100',
    ));

    // G) Yuvarlama (UI ve servis aynı round kullanıyor mu - hedef/toplam gösteriminde)
    final targetRounded = _target != null ? _target!.round() : 0;
    final totalRounded = totals.totalKcal.round();
    results.add(_TestResult(
      'G) Yuvarlama (round tutarlı)',
      true,
      'Target round: $targetRounded, Totals round: $totalRounded (aynı mantık kullanılıyor).',
    ));

    setState(() {
      _results = results;
      _testsRunning = false;
    });
  }

  Future<void> _addTestDataToday() async {
    final now = DateTime.now();
    final dateStr = DiaryService.normalizeDate(now);
    final e1 = FoodEntry(id: _uuid.v4(), date: dateStr, mealType: MealType.breakfast, foodId: 'test', foodName: 'Test Kahvaltı', grams: 100, calculatedKcal: 100, createdAt: DateTime.now());
    final e2 = FoodEntry(id: _uuid.v4(), date: dateStr, mealType: MealType.lunch, foodId: 'test', foodName: 'Test Öğle', grams: 100, calculatedKcal: 200, createdAt: DateTime.now());
    final e3 = FoodEntry(id: _uuid.v4(), date: dateStr, mealType: MealType.dinner, foodId: 'test', foodName: 'Test Akşam', grams: 100, calculatedKcal: 150, createdAt: DateTime.now());
    await _diaryService.addEntry(e1);
    await _diaryService.addEntry(e2);
    await _diaryService.addEntry(e3);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bugün için test verisi eklendi (100+200+150 kcal).')));
      Provider.of<DietProvider>(context, listen: false).loadDay(now);
    }
  }

  Future<void> _addTestDataYesterday() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = DiaryService.normalizeDate(yesterday);
    final e1 = FoodEntry(id: _uuid.v4(), date: dateStr, mealType: MealType.breakfast, foodId: 'test', foodName: 'Test Dün', grams: 100, calculatedKcal: 80, createdAt: DateTime.now());
    await _diaryService.addEntry(e1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dün için test verisi eklendi.')));
    }
  }

  Future<void> _clearData() async {
    await _diaryService.clearAllEntries();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tüm günlük kayıtlar silindi.')));
      Provider.of<DietProvider>(context, listen: false).loadDay(DateTime.now());
    }
  }

  Future<void> _addTestWorkout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = int.tryParse(auth.user?.id.toString() ?? '1') ?? 1;
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    
    final req = WorkoutRequest(
      name: 'Test Koşu (300 kcal)',
      workoutType: 'Running',
      durationMinutes: 30,
      caloriesBurned: 300,
      workoutDate: DateTime.now(),
      notes: 'Test modundan eklendi',
    );

    final ok = await workoutProvider.createWorkout(userId, req);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('300 kcal yakılan antrenman eklendi! Bonus hedefe yansıyacak.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Test Mode', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Örnek Profil Seç', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<UserProfile>(
            value: _selectedProfile,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white24)),
            ),
            items: _exampleProfiles.map((e) => DropdownMenuItem(value: e.profile, child: Text(e.label, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (p) {
              setState(() {
                _selectedProfile = p;
                _recalcValues();
              });
            },
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hesaplanan Değerler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _row('BMR', _bmr?.round().toString() ?? '—'),
                  _row('TDEE', _tdee?.round().toString() ?? '—'),
                  _row('Target', _target?.round().toString() ?? '—'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Test Sonuçları', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          if (_testsRunning)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))))
          else if (_results.isEmpty)
            OutlinedButton.icon(
              onPressed: _runTests,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Testleri Çalıştır'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2E7D32), side: const BorderSide(color: Color(0xFF2E7D32))),
            )
          else
            Column(
              children: [
                ..._results.map((r) => Card(
                  color: const Color(0xFF141414),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text(r.detail, style: TextStyle(color: Colors.white70, fontSize: 11)),
                    trailing: Chip(
                      label: Text(r.passed ? 'PASS' : 'FAIL', style: TextStyle(color: r.passed ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      backgroundColor: (r.passed ? Colors.green : Colors.red).withValues(alpha: 0.2),
                    ),
                  ),
                )),
                TextButton.icon(onPressed: _runTests, icon: const Icon(Icons.refresh, color: Color(0xFF2E7D32)), label: const Text('Yeniden çalıştır', style: TextStyle(color: Color(0xFF2E7D32)))),
              ],
            ),
          const SizedBox(height: 24),
          const Text('Hızlı Aksiyonlar', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: _addTestDataToday, icon: const Icon(Icons.add), label: const Text('Test verisi ekle (bugün)'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70)),
              OutlinedButton.icon(onPressed: _addTestDataYesterday, icon: const Icon(Icons.add), label: const Text('Test verisi ekle (dün)'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70)),
              OutlinedButton.icon(onPressed: _addTestWorkout, icon: const Icon(Icons.bolt), label: const Text('Antrenman Ekle (300 kcal)'), style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent)),
              OutlinedButton.icon(onPressed: _clearData, icon: const Icon(Icons.delete_outline), label: const Text('Verileri temizle'), style: OutlinedButton.styleFrom(foregroundColor: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
          Text(value, style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
