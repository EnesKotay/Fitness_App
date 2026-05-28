import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/nutrition_preferences.dart';
import '../state/diet_provider.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/services/local_notification_service.dart';

const _kCyan = Color(0xFF00D9F5);
const _kGreen = Color(0xFF00F5A0);
const _kPurple = Color(0xFF9B8CFF);
const _kSurface = Color(0xFF10131A);
const _kBg = Color(0xFF07080D);

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    this.initial,
    this.navigateToHomeOnSave = true,
  });

  final UserProfile? initial;
  final bool navigateToHomeOnSave;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  static const int _totalSteps = 7;
  static const int _lastStep = _totalSteps - 1;

  final _pageController = PageController();
  final _nameFormKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isTransitioning = false;
  bool _saving = false;

  String _name = '';
  int _age = 25;
  double _weight = 70.0;
  double _targetWeight = 70.0;
  double _height = 175.0;
  Gender _gender = Gender.male;
  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  Goal _goal = Goal.cut;
  NutritionPreferences _nutritionPreferences = const NutritionPreferences();
  String _workoutLocation = 'home';
  String _equipmentType = 'bodyweight';

  static const _locationAllowed = {'home', 'gym'};
  static const _equipmentAllowed = {'bodyweight', 'dumbbells', 'full_gym'};

  @override
  void initState() {
    super.initState();

    if (widget.navigateToHomeOnSave) {
      final existingProfile = context.read<DietProvider>().profile;
      final onboardingDone = StorageHelper.getOnboardingDone();
      if (existingProfile != null || onboardingDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false);
          }
        });
        return;
      }
    }

    final p = widget.initial;
    if (p != null) {
      _name = p.name;
      _age = p.age;
      _weight = p.weight;
      _height = p.height;
      _gender = p.gender;
      _activityLevel = p.activityLevel;
      _goal = p.goal;
      _targetWeight = p.targetWeight ?? p.weight;
    } else {
      final user = context.read<AuthProvider>().user;
      if (user != null) _name = user.name;
    }

    _nutritionPreferences = NutritionPreferences.fromJson(
      StorageHelper.getNutritionPreferences(),
    );
    final loc = StorageHelper.getWorkoutLocation();
    _workoutLocation = _locationAllowed.contains(loc) ? loc : 'home';
    final eq = StorageHelper.getEquipmentType();
    _equipmentType = _equipmentAllowed.contains(eq) ? eq : 'bodyweight';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_saving || _isTransitioning) return;
    if (_currentStep == 0 && !_validateNameStep()) return;
    FocusScope.of(context).unfocus();

    if (_currentStep < _lastStep) {
      final next = _currentStep + 1;
      setState(() => _isTransitioning = true);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      if (!mounted) return;
      setState(() {
        _currentStep = next;
        _isTransitioning = false;
      });
    } else {
      await _saveAndFinish();
    }
  }

  Future<void> _previousStep() async {
    if (_saving || _isTransitioning || _currentStep <= 0) return;
    final prev = _currentStep - 1;
    setState(() => _isTransitioning = true);
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    setState(() {
      _currentStep = prev;
      _isTransitioning = false;
    });
  }

  Future<void> _goToStep(int step) async {
    final target = step.clamp(0, _lastStep);
    if (_currentStep == target) return;
    setState(() => _isTransitioning = true);
    await _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    setState(() {
      _currentStep = target;
      _isTransitioning = false;
    });
  }

  bool _validateNameStep() {
    final ok =
        _nameFormKey.currentState?.validate() ?? _name.trim().length >= 2;
    if (ok && _name != _name.trim()) setState(() => _name = _name.trim());
    return ok;
  }

  Future<void> _saveAndFinish() async {
    if (_saving) return;
    final trimmed = _name.trim();
    if (trimmed.length < 2) {
      await _goToStep(0);
      if (!mounted) return;
      _nameFormKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devam etmek için profil adını tamamla.')),
      );
      return;
    }

    setState(() => _saving = true);

    final profile = UserProfile(
      name: trimmed,
      age: _age,
      weight: _weight,
      height: _height,
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
      targetWeight: _targetWeight,
    );

    final ctx = context;
    final dietProvider = ctx.read<DietProvider>();

    try {
      await dietProvider.saveUserProfile(profile);
      if (!identical(dietProvider.profile, profile)) {
        throw Exception(dietProvider.error ?? 'Profil kaydedilemedi');
      }
      await dietProvider.saveNutritionPreferences(_nutritionPreferences);
      await StorageHelper.saveWorkoutLocation(_workoutLocation);
      await StorageHelper.saveEquipmentType(_equipmentType);

      if (!ctx.mounted) return;
      // İlk kurulumda profil sadece localde kalırsa uygulama silinip yeniden
      // kurulduğunda hesap profilini geri getiremeyiz. Bu yüzden tamamlandı
      // saymadan önce backend senkronunun başarılı olmasını bekliyoruz.
      await ctx.read<AuthProvider>().updateProfileFromDiet(profile);

      await StorageHelper.savePendingInitialProfileSetup(false);

      if (widget.navigateToHomeOnSave) {
        await StorageHelper.saveOnboardingDone(true);
        await StorageHelper.savePendingOnboardingSummary(true);
        await StorageHelper.savePendingAppTour(true);
        try {
          await LocalNotificationService.instance.requestPermission();
        } catch (e) {
          debugPrint('Bildirim izni hatası: $e');
        }
      }

      if (ctx.mounted) {
        if (widget.navigateToHomeOnSave) {
          Navigator.of(ctx).pushNamedAndRemoveUntil('/home', (r) => false);
        } else {
          Navigator.of(ctx).pop(true);
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _SetupBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildProgressHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildNameStep(),
                      _buildBiometricsStep(),
                      _buildGenderStep(),
                      _buildActivityStep(),
                      _buildGoalStep(),
                      _buildWorkoutStep(),
                      _buildEquipmentStep(),
                    ],
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    const stepNames = [
      'Profil',
      'Ölçüler',
      'Cinsiyet',
      'Aktivite',
      'Hedef',
      'Ortam',
      'Ekipman',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Adım ${_currentStep + 1} / $_totalSteps',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  stepNames[_currentStep],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: _currentStep / _totalSteps,
                  end: (_currentStep + 1) / _totalSteps,
                ),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Steps ──────────────────────────────────────────────────────────────────

  Widget _buildNameStep() {
    return _StepShell(
      key: const ValueKey('name'),
      icon: Icons.waving_hand_rounded,
      accent: _kCyan,
      title: 'Seni\ntanıyalım',
      subtitle:
          'Planini kişiselleştirmek için önce nasıl hitap edeceğimizi belirleyelim.',
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Form(
          key: _nameFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profil adı',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Adın',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _kCyan, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                  counterStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                maxLength: 50,
                onChanged: (v) => setState(() => _name = v),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'İsim gerekli';
                  if (val.trim().length < 2) return 'En az 2 karakter olmalı';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricsStep() {
    final appPrefs = context.watch<AppPreferences>();
    final imperial = appPrefs.usesImperial;
    return _StepShell(
      key: const ValueKey('biometrics'),
      icon: Icons.monitor_weight_outlined,
      accent: _kGreen,
      title: 'Vücut\nÖlçülerin',
      subtitle: 'Doğru kalori ve hedef önerileri için temel ölçüleri ayarla.',
      child: Column(
        children: [
          _NumberTile(
            label: 'Yaş',
            unit: 'yaş',
            value: _age.toDouble(),
            min: 10,
            max: 100,
            allowManualEntry: true,
            onChanged: (v) => setState(() => _age = v.toInt()),
          ),
          const SizedBox(height: 14),
          _NumberTile(
            label: imperial ? 'Height' : 'Boy',
            unit: AppUnits.heightUnitFor(appPrefs),
            value: _height,
            min: imperial ? 39 : 100,
            max: imperial ? 98 : 250,
            allowManualEntry: true,
            valueToDisplay: (v) => AppUnits.cmToDisplay(v, appPrefs),
            displayToValue: (v) => AppUnits.cmFromDisplay(v, appPrefs),
            onChanged: (v) => setState(() => _height = v),
          ),
          const SizedBox(height: 14),
          _NumberTile(
            label: imperial ? 'Weight' : 'Kilo',
            unit: AppUnits.weightUnitFor(appPrefs),
            value: _weight,
            min: imperial ? 66 : 30,
            max: imperial ? 440 : 200,
            step: imperial ? 0.5 : 0.1,
            allowManualEntry: true,
            valueToDisplay: (v) => AppUnits.kgToDisplay(v, appPrefs),
            displayToValue: (v) => AppUnits.kgFromDisplay(v, appPrefs),
            onChanged: (v) => setState(() => _weight = v),
          ),
          const SizedBox(height: 14),
          _NumberTile(
            label: imperial ? 'Goal Weight' : 'Hedef Kilo',
            unit: AppUnits.weightUnitFor(appPrefs),
            value: _targetWeight,
            min: imperial ? 66 : 30,
            max: imperial ? 440 : 200,
            step: imperial ? 0.5 : 0.1,
            allowManualEntry: true,
            valueToDisplay: (v) => AppUnits.kgToDisplay(v, appPrefs),
            displayToValue: (v) => AppUnits.kgFromDisplay(v, appPrefs),
            onChanged: (v) => setState(() => _targetWeight = v),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    return _StepShell(
      key: const ValueKey('gender'),
      icon: Icons.diversity_3_rounded,
      accent: _kPurple,
      title: 'Cinsiyetin',
      subtitle: 'Metabolizma hızı hesaplaması için gerekli.',
      child: Row(
        children: [
          Expanded(
            child: _BigChoiceCard(
              selected: _gender == Gender.male,
              emoji: '♂',
              label: 'Erkek',
              description: 'Kas kütlesi ve enerji hesabı buna göre uyarlanır.',
              accent: const Color(0xFF5DA9FF),
              onTap: () => setState(() => _gender = Gender.male),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _BigChoiceCard(
              selected: _gender == Gender.female,
              emoji: '♀',
              label: 'Kadın',
              description: 'Hedef kalori ve analizler buna göre hesaplanır.',
              accent: const Color(0xFFFF7EB6),
              onTap: () => setState(() => _gender = Gender.female),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStep() {
    return _StepShell(
      key: const ValueKey('activity'),
      icon: Icons.local_fire_department_outlined,
      accent: _kCyan,
      title: 'Aktivite\nSeviyen',
      subtitle: 'Günlük hayatın ne kadar hareketli?',
      child: Column(
        children: ActivityLevel.values.map((level) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceTile(
              selected: _activityLevel == level,
              icon: _activityIcon(level),
              label: _activityLabel(level),
              description: _activityHint(level),
              accent: _kGreen,
              onTap: () => setState(() => _activityLevel = level),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGoalStep() {
    return _StepShell(
      key: const ValueKey('goal'),
      icon: Icons.flag_rounded,
      accent: _kCyan,
      title: 'Hedefin\nNe?',
      subtitle: 'Sana en uygun planı oluşturalım.',
      child: Column(
        children: [
          ...Goal.values.map((goal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChoiceTile(
                selected: _goal == goal,
                icon: _goalIcon(goal),
                label: _goalLabel(goal),
                description: _goalHint(goal),
                accent: _kCyan,
                onTap: () => setState(() => _goal = goal),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildNutritionPrefs(),
        ],
      ),
    );
  }

  Widget _buildNutritionPrefs() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Beslenme Tercihlerin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Önerilerde görmek istemediğin filtreleri seç.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _prefChip(
                'Vejetaryen',
                _nutritionPreferences.vegetarian,
                () => setState(() {
                  final next = !_nutritionPreferences.vegetarian;
                  _nutritionPreferences = _nutritionPreferences.copyWith(
                    vegetarian: next,
                    vegan: next ? false : _nutritionPreferences.vegan,
                  );
                }),
              ),
              _prefChip(
                'Vegan',
                _nutritionPreferences.vegan,
                () => setState(() {
                  final next = !_nutritionPreferences.vegan;
                  _nutritionPreferences = _nutritionPreferences.copyWith(
                    vegan: next,
                    vegetarian: next ? true : _nutritionPreferences.vegetarian,
                  );
                }),
              ),
              _prefChip(
                'Laktozsuz',
                _nutritionPreferences.lactoseFree,
                () => setState(() {
                  _nutritionPreferences = _nutritionPreferences.copyWith(
                    lactoseFree: !_nutritionPreferences.lactoseFree,
                  );
                }),
              ),
              _prefChip(
                'Glutensiz',
                _nutritionPreferences.glutenFree,
                () => setState(() {
                  _nutritionPreferences = _nutritionPreferences.copyWith(
                    glutenFree: !_nutritionPreferences.glutenFree,
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prefChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? _kCyan.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _kCyan.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: selected ? _kCyan : Colors.white54,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutStep() {
    const accent = Color(0xFF7C83F7);
    final options = [
      (
        value: 'home',
        emoji: '🏠',
        label: 'Evde',
        hint: 'Minimal veya ekipmansız antrenman',
      ),
      (
        value: 'gym',
        emoji: '🏋️',
        label: 'Spor Salonunda',
        hint: 'Tüm gym ekipmanlarına erişim',
      ),
    ];
    return _StepShell(
      key: const ValueKey('workout'),
      icon: Icons.location_on_rounded,
      accent: accent,
      title: 'Nerede\nSpor Yapıyorsun?',
      subtitle: 'Antrenman önerileri ve planların sana uygun hazırlanacak.',
      child: Column(
        children: options.map((opt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChoiceTile(
              selected: _workoutLocation == opt.value,
              emojiIcon: opt.emoji,
              label: opt.label,
              description: opt.hint,
              accent: accent,
              onTap: () => setState(() => _workoutLocation = opt.value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEquipmentStep() {
    const accent = Color(0xFFFF8A65);
    final options = [
      (
        value: 'bodyweight',
        emoji: '🤸',
        label: 'Sadece Vücut Ağırlığı',
        hint: 'Ekipman gerektirmez, her yerde yapılır',
      ),
      (
        value: 'dumbbells',
        emoji: '🏋️',
        label: 'Dambıl / Kettlebell',
        hint: 'Hafif ekipmanla daha çeşitli hareketler',
      ),
      (
        value: 'full_gym',
        emoji: '💪',
        label: 'Tam Spor Salonu',
        hint: 'Barbell, makina ve tüm ekipmanlara erişim',
      ),
    ];
    return _StepShell(
      key: const ValueKey('equipment'),
      icon: Icons.fitness_center_rounded,
      accent: accent,
      title: 'Hangi\nEkipmanın Var?',
      subtitle: 'Antrenman programın mevcut ekipmanına göre oluşturulacak.',
      child: Column(
        children: options.map((opt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChoiceTile(
              selected: _equipmentType == opt.value,
              emojiIcon: opt.emoji,
              label: opt.label,
              description: opt.hint,
              accent: accent,
              onTap: () => setState(() => _equipmentType = opt.value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (_currentStep > 0)
            _BackBtn(
              onTap: (_saving || _isTransitioning)
                  ? null
                  : () => unawaited(_previousStep()),
            )
          else
            const SizedBox(width: 52),
          const Spacer(),
          _NextBtn(
            isLast: _currentStep == _lastStep,
            loading: _saving,
            disabled: _isTransitioning,
            onTap: () => unawaited(_nextStep()),
          ),
        ],
      ),
    );
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  IconData _activityIcon(ActivityLevel l) => switch (l) {
    ActivityLevel.sedentary => Icons.weekend,
    ActivityLevel.lightlyActive => Icons.directions_walk,
    ActivityLevel.moderatelyActive => Icons.fitness_center,
    ActivityLevel.veryActive => Icons.directions_run,
    ActivityLevel.extraActive => Icons.sports_gymnastics,
  };

  String _activityLabel(ActivityLevel l) => switch (l) {
    ActivityLevel.sedentary => 'Hareketsiz',
    ActivityLevel.lightlyActive => 'Az Hareketli',
    ActivityLevel.moderatelyActive => 'Orta Hareketli',
    ActivityLevel.veryActive => 'Çok Hareketli',
    ActivityLevel.extraActive => 'Ekstra Hareketli',
  };

  String _activityHint(ActivityLevel l) => switch (l) {
    ActivityLevel.sedentary => 'Çoğunlukla oturarak geçen günler.',
    ActivityLevel.lightlyActive =>
      'Hafif tempo, kısa yürüyüşler (haftada 1-3 spor).',
    ActivityLevel.moderatelyActive =>
      'Düzenli egzersiz ve aktif günlük rutin (haftada 3-5).',
    ActivityLevel.veryActive =>
      'Yoğun antrenman veya sürekli hareketli yaşam (6-7 gün).',
    ActivityLevel.extraActive =>
      'Ağır fiziksel tempo + yüksek enerji ihtiyacı.',
  };

  IconData _goalIcon(Goal g) => switch (g) {
    Goal.cut => Icons.trending_down_rounded,
    Goal.maintain => Icons.balance_rounded,
    Goal.bulk => Icons.trending_up_rounded,
    Goal.strength => Icons.fitness_center_rounded,
  };

  String _goalLabel(Goal g) => switch (g) {
    Goal.cut => 'Kilo Ver (Definasyon)',
    Goal.maintain => 'Kilomu Koru',
    Goal.bulk => 'Kilo Al (Hacim)',
    Goal.strength => 'Güç Artışı (Kuvvet)',
  };

  String _goalHint(Goal g) => switch (g) {
    Goal.cut => 'Yağ oranını düşürmeye odaklanan plan.',
    Goal.maintain => 'Mevcut formunu dengeli şekilde koru.',
    Goal.bulk => 'Kas kütlesi ve toplam ağırlığı artır.',
    Goal.strength => 'Kuvvet performansını önceliklendiren yaklaşım.',
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// Yardımcı widget'lar
// ══════════════════════════════════════════════════════════════════════════════

class _StepShell extends StatefulWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepShell({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  State<_StepShell> createState() => _StepShellState();
}

class _StepShellState extends State<_StepShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 480),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            widget.accent.withValues(alpha: 0.22),
                            widget.accent.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(widget.icon, color: widget.accent, size: 28),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.06,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    widget.child,
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NumberTile extends StatefulWidget {
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final double step;
  final bool allowManualEntry;
  final double Function(double value)? valueToDisplay;
  final double Function(double displayValue)? displayToValue;
  final ValueChanged<double> onChanged;

  const _NumberTile({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    this.allowManualEntry = false,
    this.valueToDisplay,
    this.displayToValue,
    required this.onChanged,
  });

  @override
  State<_NumberTile> createState() => _NumberTileState();
}

class _NumberTileState extends State<_NumberTile> {
  bool _editing = false;
  late final TextEditingController _editCtrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) _commit();
  }

  double _snap(double raw) {
    final stepped =
        ((raw - widget.min) / widget.step).round() * widget.step + widget.min;
    return stepped.clamp(widget.min, widget.max);
  }

  double _displayValue() =>
      widget.valueToDisplay?.call(widget.value) ?? widget.value;

  double _storedValue(double displayValue) =>
      widget.displayToValue?.call(displayValue) ?? displayValue;

  // Caller must pass an already-snapped value — never calls _snap internally
  // to avoid floating-point drift from double-snapping.
  String _fmt(double snapped) => widget.step >= 1
      ? snapped.round().toString()
      : snapped.toStringAsFixed(1);

  void _startEdit() {
    final current = _snap(_displayValue());
    final text = _fmt(current);
    _editCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _commit() {
    if (!_editing) return;
    final raw = _editCtrl.text.replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (mounted) setState(() => _editing = false);
    if (parsed == null) return;
    final clamped = parsed.clamp(widget.min, widget.max).toDouble();
    if (mounted && clamped != parsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.label}: ${_fmt(widget.min)}–${_fmt(widget.max)} ${widget.unit} arasında olmalı.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    widget.onChanged(_storedValue(_snap(clamped)));
  }

  // Slider sürüklenince açık inline field'ı kapat — iki input çakışmasın.
  void _onSliderChanged(double v) {
    if (_editing) {
      _focusNode.unfocus();
      if (mounted) setState(() => _editing = false);
    }
    widget.onChanged(_storedValue(_snap(v)));
  }

  @override
  Widget build(BuildContext context) {
    final snapped = _snap(_displayValue());
    final divisions = ((widget.max - widget.min) / widget.step).round();
    final displayText = '${_fmt(snapped)} ${widget.unit}';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.allowManualEntry
                          ? 'Kaydır veya değere dokun.'
                          : 'Aralığı kaydırarak belirle.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_editing && widget.allowManualEntry)
                _InlineField(
                  controller: _editCtrl,
                  focusNode: _focusNode,
                  unit: widget.unit,
                  onDone: _commit,
                )
              else
                GestureDetector(
                  onTap: widget.allowManualEntry ? _startEdit : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          _kGreen.withValues(alpha: 0.18),
                          _kCyan.withValues(alpha: 0.12),
                        ],
                      ),
                      border: Border.all(
                        color: _kGreen.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayText,
                          style: const TextStyle(
                            color: _kGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (widget.allowManualEntry) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.edit_rounded,
                            color: _kGreen.withValues(alpha: 0.55),
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip('Min ${_fmt(widget.min)} ${widget.unit}'),
              const SizedBox(width: 6),
              _chip('Max ${_fmt(widget.max)} ${widget.unit}'),
              if (widget.step < 1) ...[
                const SizedBox(width: 6),
                _chip('±${_fmt(widget.step)} ${widget.unit}'),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: const SliderThemeData(
              activeTrackColor: _kGreen,
              inactiveTrackColor: Color(0x14FFFFFF),
              trackHeight: 6,
              thumbColor: _kGreen,
              overlayColor: Color(0x2300F5A0),
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 13),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 22),
              valueIndicatorColor: _kGreen,
              valueIndicatorTextStyle: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Slider(
              value: snapped,
              min: widget.min,
              max: widget.max,
              divisions: divisions > 0 ? divisions : null,
              label: displayText,
              onChanged: _onSliderChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String unit;
  final VoidCallback onDone;

  const _InlineField({
    required this.controller,
    required this.focusNode,
    required this.unit,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCyan.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(
                  color: _kGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => onDone(),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçim satırı (aktivite / hedef / konum / ekipman)
class _ChoiceTile extends StatelessWidget {
  final bool selected;
  final IconData? icon;
  final String? emojiIcon;
  final String label;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.selected,
    this.icon,
    this.emojiIcon,
    required this.label,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? null : _kSurface,
          gradient: selected
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.18),
                    accent.withValues(alpha: 0.06),
                  ],
                )
              : null,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.06),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: selected ? 0.08 : 0.04),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: emojiIcon != null
                  ? Text(emojiIcon!, style: const TextStyle(fontSize: 22))
                  : Icon(
                      icon,
                      color: selected ? accent : Colors.grey,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[300],
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.check_circle_rounded, color: accent, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Büyük seçim kartı (cinsiyet adımı)
class _BigChoiceCard extends StatelessWidget {
  final bool selected;
  final String emoji;
  final String label;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  const _BigChoiceCard({
    required this.selected,
    required this.emoji,
    required this.label,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 180,
        decoration: BoxDecoration(
          color: selected ? null : _kSurface,
          gradient: selected
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.06),
            width: selected ? 1.8 : 1.2,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[300],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _BackBtn({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap != null ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _NextBtn extends StatelessWidget {
  final bool isLast;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  const _NextBtn({
    required this.isLast,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = loading || disabled;
    return GestureDetector(
      onTap: inactive ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: inactive
                ? [
                    _kGreen.withValues(alpha: 0.4),
                    _kCyan.withValues(alpha: 0.4),
                  ]
                : [_kGreen, _kCyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: inactive
              ? null
              : [
                  BoxShadow(
                    color: _kGreen.withValues(alpha: 0.28),
                    blurRadius: 20,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: loading
              ? [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                ]
              : [
                  Text(
                    isLast ? 'Tamamla' : 'Devam',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                ],
        ),
      ),
    );
  }
}

class _SetupBackground extends StatelessWidget {
  const _SetupBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF081018), _kBg, Color(0xFF0A0F12)],
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -80,
          child: _Glow(size: 280, color: _kCyan.withValues(alpha: 0.12)),
        ),
        Positioned(
          top: 200,
          left: -90,
          child: _Glow(size: 240, color: _kGreen.withValues(alpha: 0.10)),
        ),
        Positioned(
          bottom: -80,
          right: -50,
          child: _Glow(
            size: 220,
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}
