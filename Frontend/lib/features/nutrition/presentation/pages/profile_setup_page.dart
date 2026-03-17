import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../weight/domain/entities/weight_entry.dart';
import '../../../weight/presentation/providers/weight_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../state/diet_provider.dart';
import '../../../../core/utils/validators.dart';

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
  final _pageController = PageController();
  int _currentStep = 0;

  // Form Data
  String _name = '';
  int _age = 25;
  double _weight = 70.0;
  double _targetWeight = 70.0;
  double _height = 175.0;
  Gender _gender = Gender.male;
  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  Goal _goal = Goal.cut;

  @override
  void initState() {
    super.initState();
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
      // Yeni profil oluşturuluyorsa, kayıt ekranındaki ismi AuthProvider'dan al:
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        _name = user.name;
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      FocusScope.of(context).unfocus(); // Klavyeyi kapat
      setState(() => _currentStep++);
    } else {
      _saveAndFinish();
    }
  }

  Future<void> _saveAndFinish() async {
    final profile = UserProfile(
      name: _name.isEmpty ? 'Kullanıcı' : _name,
      age: _age,
      weight: _weight,
      height: _height,
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
      targetWeight: _targetWeight,
    );

    final currentContext = context;

    try {
      // DietProvider üzerinden kaydet - await ile bekle
      await currentContext.read<DietProvider>().saveUserProfile(profile);

      if (currentContext.mounted) {
        // Eğer bu yeni bir profilse (ilk kurulum) veya hiç kayıt yoksa, başlangıç kilosunu takip sayfasına da ekle
        final wp = currentContext.read<WeightProvider>();
        if (wp.entries.isEmpty) {
          final firstEntry = WeightEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            weightKg: profile.weight,
            date: DateTime.now(),
            note: 'Başlangıç Kilosu',
          );
          final added = await wp.addEntry(firstEntry);
          if (!added) {
            debugPrint('İlk kilo eklenirken hata: ${wp.error}');
          }
        }
      }

      // Backend profile senkronizasyonu (cross-device tutarlilik)
      try {
        if (!currentContext.mounted) return;
        await currentContext.read<AuthProvider>().updateProfileFromDiet(
          profile,
        );
      } catch (e) {
        debugPrint('ProfileSetup backend sync hatasi: $e');
      }

      if (currentContext.mounted) {
        if (widget.navigateToHomeOnSave) {
          // Onboarding akışı: ana sayfaya git ve önceki sayfaları sil.
          Navigator.of(
            currentContext,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        } else {
          // Sekme içi düzenleme/ilk kurulum: mevcut akışa geri dön.
          Navigator.of(currentContext).pop(true);
        }
      }
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Profil kaydedilirken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06070A),
      body: Stack(
        children: [
          const Positioned.fill(child: _SetupBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildProgressBar(),
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

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: -12,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Adım ${_currentStep + 1}/5',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _stepTitle(_currentStep),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 8,
                  width:
                      (MediaQuery.of(context).size.width - 68) *
                      ((_currentStep + 1) / 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00F5A0), Color(0xFF00D9F5)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F5A0).withValues(alpha: 0.32),
                        blurRadius: 16,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return 'Profil';
      case 1:
        return 'Olculer';
      case 2:
        return 'Cinsiyet';
      case 3:
        return 'Aktivite';
      case 4:
        return 'Hedef';
      default:
        return '';
    }
  }

  Widget _buildNameStep() {
    return _StepContainer(
      icon: Icons.waving_hand_rounded,
      accent: const Color(0xFF00D9F5),
      title: 'Seni tanıyalım',
      subtitle: 'Planini kisilestirmek icin once sana nasil hitap edecegimizi belirleyelim.',
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF10141D),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              spreadRadius: -10,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profil adi',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu isim ozet ekranlarinda ve koç onerilerinde gorunecek.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                initialValue: _name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Adin',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFF00D9F5)),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                ),
                onChanged: (value) => setState(() => _name = value),
                validator: (val) =>
                    AppValidators.required(val, message: 'Isim gerekli'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricsStep() {
    return _StepContainer(
      icon: Icons.monitor_weight_outlined,
      accent: const Color(0xFF00F5A0),
      title: 'Vücut Ölçülerin',
      subtitle:
          'Sana daha isabetli kalori ve hedef önerileri verebilmemiz için temel ölçülerini ayarlayalım.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00F5A0).withValues(alpha: 0.14),
                  const Color(0xFF00D9F5).withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF00F5A0).withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F5A0).withValues(alpha: 0.08),
                  blurRadius: 28,
                  spreadRadius: -10,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.monitor_weight_outlined,
                    color: Color(0xFF00F5A0),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Temel profil ayarları',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bu değerler günlük hedeflerini ve ilerleme analizini daha akıllı hale getirir.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _NumberSelector(
            label: 'Yaş',
            value: _age.toDouble(),
            min: 10,
            max: 100,
            onChanged: (val) => setState(() => _age = val.toInt()),
          ),
          const SizedBox(height: 20),
          _NumberSelector(
            label: 'Boy (cm)',
            value: _height,
            min: 100,
            max: 250,
            onChanged: (val) => setState(() => _height = val),
          ),
          const SizedBox(height: 20),
          _NumberSelector(
            label: 'Kilo (kg)',
            value: _weight,
            min: 30,
            max: 200,
            step: 0.1,
            allowManualEntry: true,
            onChanged: (val) => setState(() => _weight = val),
          ),
          const SizedBox(height: 20),
          _NumberSelector(
            label: 'Hedef Kilo (kg)',
            value: _targetWeight,
            min: 30,
            max: 200,
            step: 0.1,
            allowManualEntry: true,
            onChanged: (val) => setState(() => _targetWeight = val),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    return _StepContainer(
      icon: Icons.diversity_3_rounded,
      accent: const Color(0xFF9B8CFF),
      title: 'Cinsiyetin',
      subtitle: 'Metabolizma hızı hesaplaması için gerekli.',
      child: Row(
        children: [
          Expanded(
            child: _SelectableCard(
              selected: _gender == Gender.male,
              icon: Icons.male,
              label: 'Erkek',
              description: 'Kas kutlesi ve enerji hesabı buna gore uyarlanir.',
              accent: const Color(0xFF5DA9FF),
              onTap: () => setState(() => _gender = Gender.male),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _SelectableCard(
              selected: _gender == Gender.female,
              icon: Icons.female,
              label: 'Kadın',
              description: 'Hedef kalori ve analizler buna gore hesaplanir.',
              accent: const Color(0xFFFF7EB6),
              onTap: () => setState(() => _gender = Gender.female),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStep() {
    return _StepContainer(
      icon: Icons.local_fire_department_outlined,
      accent: const Color(0xFF00D9F5),
      title: 'Aktivite Seviyen',
      subtitle: 'Günlük hayatın ne kadar hareketli?',
      child: Column(
        children: ActivityLevel.values.map((level) {
          final isSelected = _activityLevel == level;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _activityLevel = level),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            const Color(0xFF00F5A0).withValues(alpha: 0.18),
                            const Color(0xFF00D9F5).withValues(alpha: 0.10),
                          ],
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFF111318),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00F5A0).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: isSelected ? 0.08 : 0.04),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getActivityIcon(level),
                        color: isSelected ? const Color(0xFF00F5A0) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getActivityLabel(level),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[300],
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getActivityHint(level),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.52),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF00F5A0),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGoalStep() {
    return _StepContainer(
      icon: Icons.flag_rounded,
      accent: const Color(0xFF00D9F5),
      title: 'Hedefin Ne?',
      subtitle: 'Senin için en uygun planı oluşturalım.',
      child: Column(
        children: Goal.values.map((goal) {
          final isSelected = _goal == goal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _goal = goal),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            const Color(0xFF00D9F5).withValues(alpha: 0.18),
                            const Color(0xFF00F5A0).withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFF111318),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00D9F5).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: isSelected ? 0.08 : 0.04),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getGoalIcon(goal),
                        color: isSelected ? const Color(0xFF00D9F5) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGoalLabel(goal),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[300],
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getGoalHint(goal),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.52),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF00D9F5),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentStep--);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                backgroundColor: Colors.white.withValues(alpha: 0.03),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                'Geri',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            const SizedBox(width: 88),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF00F5A0), Color(0xFF00D9F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F5A0).withValues(alpha: 0.28),
                  blurRadius: 26,
                  spreadRadius: -8,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _nextStep,
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Icon(
                _currentStep == 4
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers
  IconData _getActivityIcon(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return Icons.weekend;
      case ActivityLevel.lightlyActive:
        return Icons.directions_walk;
      case ActivityLevel.moderatelyActive:
        return Icons.fitness_center;
      case ActivityLevel.veryActive:
        return Icons.directions_run;
      case ActivityLevel.extraActive:
        return Icons.sports_gymnastics;
    }
  }

  String _getActivityLabel(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Hareketsiz (Masa başı iş)';
      case ActivityLevel.lightlyActive:
        return 'Az Hareketli (Haftada 1-3 spor)';
      case ActivityLevel.moderatelyActive:
        return 'Orta Hareketli (Haftada 3-5 spor)';
      case ActivityLevel.veryActive:
        return 'Çok Hareketli (Haftada 6-7 spor)';
      case ActivityLevel.extraActive:
        return 'Ekstra Hareketli (Fiziksel iş + spor)';
    }
  }

  String _getActivityHint(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Cogunlukla oturarak gecen gunler.';
      case ActivityLevel.lightlyActive:
        return 'Hafif tempo, kisa yuruyusler ve ara sira spor.';
      case ActivityLevel.moderatelyActive:
        return 'Duzenli egzersiz ve aktif gunluk rutin.';
      case ActivityLevel.veryActive:
        return 'Yogun antrenman veya surekli hareketli yasam.';
      case ActivityLevel.extraActive:
        return 'Agir fiziksel tempo ve yuksek enerji ihtiyaci.';
    }
  }

  IconData _getGoalIcon(Goal goal) {
    switch (goal) {
      case Goal.cut:
        return Icons.arrow_downward;
      case Goal.maintain:
        return Icons.balance;
      case Goal.bulk:
        return Icons.arrow_upward;
      case Goal.strength:
        return Icons.fitness_center;
    }
  }

  String _getGoalLabel(Goal goal) {
    switch (goal) {
      case Goal.cut:
        return 'Kilo Ver (Definasyon)';
      case Goal.maintain:
        return 'Kilomu Koru';
      case Goal.bulk:
        return 'Kilo Al (Hacim)';
      case Goal.strength:
        return 'Güç Artışı (Kuvvet)';
    }
  }

  String _getGoalHint(Goal goal) {
    switch (goal) {
      case Goal.cut:
        return 'Yag oranini dusurmeye odaklanan plan.';
      case Goal.maintain:
        return 'Mevcut formunu dengeli sekilde koru.';
      case Goal.bulk:
        return 'Kas kutlesi ve toplam agirligi artir.';
      case Goal.strength:
        return 'Kuvvet performansini onceliklendiren yaklasim.';
    }
  }
}

class _StepContainer extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepContainer({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.18),
                          accent.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: accent,
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                  const SizedBox(height: 26),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.04,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                    ),
                  ).animate().fadeIn().slideX(),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontSize: 17,
                      height: 1.45,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(),
                  const SizedBox(height: 32),
                  child.animate().fadeIn(delay: 400.ms).moveY(begin: 20),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NumberSelector extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final bool allowManualEntry;
  final ValueChanged<double> onChanged;

  const _NumberSelector({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    this.allowManualEntry = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final snappedValue = _snap(value);
    final divisions = ((max - min) / step).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF12161F),
            Color(0xFF0E1117),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Araligi kaydirarak belirle.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00F5A0).withValues(alpha: 0.16),
                      const Color(0xFF00D9F5).withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF00F5A0).withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  _formatValue(snappedValue),
                  style: const TextStyle(
                    color: Color(0xFF00F5A0),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                _rangeChip('Min', _formatValue(min)),
                const SizedBox(width: 8),
                _rangeChip('Max', _formatValue(max)),
                const Spacer(),
                if (step < 1) _rangeChip('Adim', step.toStringAsFixed(1)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00F5A0),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              trackHeight: 7,
              thumbColor: const Color(0xFF00F5A0),
              overlayColor: const Color(0xFF00F5A0).withValues(alpha: 0.14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: snappedValue,
              min: min,
              max: max,
              divisions: divisions > 0 ? divisions : null,
              label: _formatValue(snappedValue),
              onChanged: (nextValue) => onChanged(_snap(nextValue)),
            ),
          ),
        ],
      ),
    );
  }

  double _snap(double raw) {
    final snapped = ((raw - min) / step).round() * step + min;
    return snapped.clamp(min, max);
  }

  String _formatValue(double raw) {
    final snapped = _snap(raw);
    if (step >= 1) {
      return snapped.round().toString();
    }
    return snapped.toStringAsFixed(1);
  }

  Widget _rangeChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
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
          color: selected ? null : const Color(0xFF111318),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.06),
            width: selected ? 1.8 : 1.2,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 28,
                    spreadRadius: -12,
                    offset: const Offset(0, 16),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: selected ? 0.1 : 0.04),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 34,
                color: selected ? accent : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[300],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 12,
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
              colors: [
                Color(0xFF081018),
                Color(0xFF06070A),
                Color(0xFF0A0F12),
              ],
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -90,
          child: _BackgroundGlow(
            size: 300,
            color: const Color(0xFF00D9F5).withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          top: 180,
          left: -100,
          child: _BackgroundGlow(
            size: 260,
            color: const Color(0xFF00F5A0).withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -60,
          child: _BackgroundGlow(
            size: 240,
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _BackgroundGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
