import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/user_profile.dart';
import '../state/diet_provider.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, this.initial});

  final UserProfile? initial;

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
  double _height = 175.0;
  Gender _gender = Gender.male;
  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  Goal _goal = Goal.loseWeight;

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
    );

    try {
      // DietProvider üzerinden kaydet - await ile bekle
      await context.read<DietProvider>().saveUserProfile(profile);

      if (mounted) {
        // Ana sayfaya git ve önceki sayfaları sil
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Profil kaydedilirken hata oluştu: $e')),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
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
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 6,
            width: MediaQuery.of(context).size.width * ((_currentStep + 1) / 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00F5A0), Color(0xFF00D9F5)],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameStep() {
    return _StepContainer(
      title: 'Seni tanıyalım',
      subtitle: 'Hedeflerine ulaşman için sana nasıl hitap edelim?',
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 24),
        decoration: InputDecoration(
          hintText: 'Adın',
          hintStyle: TextStyle(color: Colors.grey[600]),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00F5A0)),
          ),
        ),
        onChanged: (value) => setState(() => _name = value),
      ),
    );
  }

  Widget _buildBiometricsStep() {
    return _StepContainer(
      title: 'Vücut Ölçülerin',
      subtitle: 'Kalori ihtiyacını hesaplamak için buna ihtiyacımız var.',
      child: Column(
        children: [
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
            onChanged: (val) => setState(() => _weight = val),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    return _StepContainer(
      title: 'Cinsiyetin',
      subtitle: 'Metabolizma hızı hesaplaması için gerekli.',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SelectableCard(
            selected: _gender == Gender.male,
            icon: Icons.male,
            label: 'Erkek',
            onTap: () => setState(() => _gender = Gender.male),
          ),
          _SelectableCard(
            selected: _gender == Gender.female,
            icon: Icons.female,
            label: 'Kadın',
            onTap: () => setState(() => _gender = Gender.female),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStep() {
    return _StepContainer(
      title: 'Aktivite Seviyen',
      subtitle: 'Günlük hayatın ne kadar hareketli?',
      child: Column(
        children: ActivityLevel.values.map((level) {
          final isSelected = _activityLevel == level;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _activityLevel = level),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00F5A0).withValues(alpha: 0.2) : Colors.grey[900],
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00F5A0) : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getActivityIcon(level),
                      color: isSelected ? const Color(0xFF00F5A0) : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _getActivityLabel(level),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
      title: 'Hedefin Ne?',
      subtitle: 'Senin için en uygun planı oluşturalım.',
      child: Column(
        children: Goal.values.map((goal) {
          final isSelected = _goal == goal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _goal = goal),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00D9F5).withValues(alpha: 0.2) : Colors.grey[900],
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00D9F5) : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getGoalIcon(goal),
                      color: isSelected ? const Color(0xFF00D9F5) : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _getGoalLabel(goal),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentStep--);
              },
              child: const Text('Geri', style: TextStyle(color: Colors.grey)),
            )
          else
            const SizedBox.shrink(),
            
          FloatingActionButton(
             onPressed: _nextStep,
             backgroundColor: const Color(0xFF00F5A0),
             child: Icon(
               _currentStep == 4 ? Icons.check : Icons.arrow_forward,
               color: Colors.black,
             ),
          ),
        ],
      ),
    );
  }

  // Helpers
  IconData _getActivityIcon(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary: return Icons.weekend;
      case ActivityLevel.lightlyActive: return Icons.directions_walk;
      case ActivityLevel.moderatelyActive: return Icons.fitness_center;
      case ActivityLevel.veryActive: return Icons.directions_run;
      case ActivityLevel.extraActive: return Icons.sports_gymnastics;
    }
  }

  String _getActivityLabel(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary: return 'Hareketsiz (Masa başı iş)';
      case ActivityLevel.lightlyActive: return 'Az Hareketli (Haftada 1-3 spor)';
      case ActivityLevel.moderatelyActive: return 'Orta Hareketli (Haftada 3-5 spor)';
      case ActivityLevel.veryActive: return 'Çok Hareketli (Haftada 6-7 spor)';
      case ActivityLevel.extraActive: return 'Ekstra Hareketli (Fiziksel iş + spor)';
    }
  }
  
  IconData _getGoalIcon(Goal goal) {
     switch (goal) {
       case Goal.loseWeight: return Icons.arrow_downward;
       case Goal.maintainWeight: return Icons.balance;
       case Goal.gainWeight: return Icons.arrow_upward;
     }
  }

  String _getGoalLabel(Goal goal) {
     switch (goal) {
       case Goal.loseWeight: return 'Kilo Vermek';
       case Goal.maintainWeight: return 'Kilomu Korumak';
       case Goal.gainWeight: return 'Kilo Almak (Kas Yapmak)';
     }
  }
}

class _StepContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepContainer({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const SizedBox(height: 20), // Top spacing
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                      .animate().fadeIn().slideX(),
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 16))
                      .animate().fadeIn(delay: 200.ms).slideX(),
                  const SizedBox(height: 40),
                  child.animate().fadeIn(delay: 400.ms).moveY(begin: 20),
                  const SizedBox(height: 20), // Bottom spacing
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
  final ValueChanged<double> onChanged;

  const _NumberSelector({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
            Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF00F5A0), fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF00F5A0),
          inactiveColor: Colors.grey[800],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SelectableCard({required this.selected, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00F5A0).withValues(alpha: 0.1) : Colors.grey[900],
          border: Border.all(color: selected ? const Color(0xFF00F5A0) : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: selected ? const Color(0xFF00F5A0) : Colors.grey),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
