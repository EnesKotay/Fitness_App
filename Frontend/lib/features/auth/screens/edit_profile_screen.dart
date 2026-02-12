import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../nutrition/domain/entities/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  
  Gender _gender = Gender.male;
  ActivityLevel _activityLevel = ActivityLevel.sedentary;
  Goal _goal = Goal.maintainWeight;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<DietProvider>().profile;
    
    _nameController = TextEditingController(text: profile?.name ?? '');
    _ageController = TextEditingController(text: profile?.age.toString() ?? '');
    _heightController = TextEditingController(text: profile?.height.toString() ?? '');
    _weightController = TextEditingController(text: profile?.weight.toString() ?? '');
    
    if (profile != null) {
      _gender = profile.gender;
      _activityLevel = profile.activityLevel;
      _goal = profile.goal;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text.trim());
      final height = double.parse(_heightController.text.trim());
      final weight = double.parse(_weightController.text.trim());

      final newProfile = UserProfile(
        name: name,
        age: age,
        height: height,
        weight: weight,
        gender: _gender,
        activityLevel: _activityLevel,
        goal: _goal,
      );

      await context.read<DietProvider>().saveUserProfile(newProfile);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil başarıyla güncellendi!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profili Düzenle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kaydet', style: TextStyle(color: Color(0xFFCC7A4A), fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('KİŞİSEL BİLGİLER'),
              _buildTextField(label: 'Ad Soyad', controller: _nameController),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(label: 'Yaş', controller: _ageController, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGenderSelector()),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildSectionTitle('VÜCUT ÖLÇÜLERİ'),
              Row(
                children: [
                  Expanded(child: _buildTextField(label: 'Boy (cm)', controller: _heightController, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(label: 'Kilo (kg)', controller: _weightController, isNumber: true)),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('AKTİVİTE & HEDEF'),
              _buildDropdown<ActivityLevel>(
                value: _activityLevel,
                items: ActivityLevel.values,
                label: (val) {
                  switch (val) {
                    case ActivityLevel.sedentary: return 'Hareketsiz (Masa başı)';
                    case ActivityLevel.lightlyActive: return 'Az Hareketli (Haftada 1-3 spor)';
                    case ActivityLevel.moderatelyActive: return 'Orta Hareketli (Haftada 3-5 spor)';
                    case ActivityLevel.veryActive: return 'Çok Hareketli (Haftada 6-7 spor)';
                    case ActivityLevel.extraActive: return 'Ekstra Hareketli (Fiziksel iş/spor)';
                  }
                },
                onChanged: (val) => setState(() => _activityLevel = val!),
              ),
              const SizedBox(height: 16),
              _buildDropdown<Goal>(
                value: _goal,
                items: Goal.values,
                label: (val) {
                  switch (val) {
                    case Goal.loseWeight: return 'Kilo Ver';
                    case Goal.maintainWeight: return 'Kilomu Koru';
                    case Goal.gainWeight: return 'Kilo Al';
                  }
                },
                onChanged: (val) => setState(() => _goal = val!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label, 
    required TextEditingController controller,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Gerekli';
        if (isNumber && double.tryParse(value) == null) return 'Geçersiz sayı';
        return null;
      },
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      height: 50, // Match text field height roughly
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildGenderOption(Gender.male, Icons.male),
          Container(width: 1, color: Colors.white.withValues(alpha: 0.1), margin: const EdgeInsets.symmetric(vertical: 8)),
          _buildGenderOption(Gender.female, Icons.female),
        ],
      ),
    );
  }

  Widget _buildGenderOption(Gender gender, IconData icon) {
    final isSelected = _gender == gender;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _gender = gender),
        borderRadius: BorderRadius.circular(12),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFFCC7A4A) : Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(label(item)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
