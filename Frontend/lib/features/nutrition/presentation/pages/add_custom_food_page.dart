import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui'; // For blur
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart'; // Import for dummy usage in preview if needed
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../../../core/utils/app_snack.dart';
import '../widgets/visual_meal_card.dart'; // Reuse for consistent look style if possible, or custom preview card

/// Özel yemek ekle: Premium tasarım, Canlı Önizleme.
class AddCustomFoodPage extends StatefulWidget {
  const AddCustomFoodPage({super.key});

  @override
  State<AddCustomFoodPage> createState() => _AddCustomFoodPageState();
}

class _AddCustomFoodPageState extends State<AddCustomFoodPage> {
  final _nameController = TextEditingController();
  final _kcalController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbController = TextEditingController();
  final _fatController = TextEditingController();
  bool _saving = false;

  // Preview state
  String _name = '';
  double _kcal = 0;
  double _p = 0;
  double _c = 0;
  double _f = 0;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() => _name = _nameController.text));
    _kcalController.addListener(_updateValues);
    _proteinController.addListener(_updateValues);
    _carbController.addListener(_updateValues);
    _fatController.addListener(_updateValues);
  }

  void _updateValues() {
    setState(() {
      _kcal = double.tryParse(_kcalController.text.replaceAll(',', '.')) ?? 0;
      _p = double.tryParse(_proteinController.text.replaceAll(',', '.')) ?? 0;
      _c = double.tryParse(_carbController.text.replaceAll(',', '.')) ?? 0;
      _f = double.tryParse(_fatController.text.replaceAll(',', '.')) ?? 0;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _kcalController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameVal = _nameController.text.trim();
    if (nameVal.isEmpty) {
      AppSnack.showError(context, 'Lütfen yemek adı girin.');
      return;
    }

    setState(() => _saving = true);
    
    // Auto calculate calories if not provided
    double? finalKcal = _kcal > 0 ? _kcal : (4 * _p + 4 * _c + 9 * _f);
    if (finalKcal == 0 && _kcalController.text.isEmpty) finalKcal = null;

    final food = FoodItem(
      id: 'custom_${const Uuid().v4()}',
      name: nameVal,
      category: 'Özel',
      basis: const FoodBasis(amount: 100, unit: 'g'),
      nutrients: Nutrients(
        kcal: finalKcal ?? 0,
        protein: _p,
        carb: _c,
        fat: _f,
      ),
    );

    try {
      await Provider.of<DietProvider>(context, listen: false).addCustomFood(food);
      if (!mounted) return;
      setState(() => _saving = false);
      try {
        Navigator.of(context, rootNavigator: false).pop(true);
      } catch (e) {
        Navigator.of(context).pop(true);
      }
      if (mounted) {
        AppSnack.showSuccess(context, 'Yemek başarıyla eklendi!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.showError(context, 'Kaydedilirken hata oluştu: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate display kcal for preview
    final displayKcal = _kcal > 0 ? _kcal : (4 * _p + 4 * _c + 9 * _f);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () {
                        try {
                          Navigator.of(context, rootNavigator: false).pop();
                        } catch (e) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const Text('Özel Yemek Ekle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Live Preview Card
                      Center(
                        child: Text('CANLI ÖNİZLEME', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.surfaceLight, AppColors.surface.withValues(alpha: 0.5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.restaurant, color: AppColors.primary, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _name.isEmpty ? 'Yemek Adı' : _name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _name.isEmpty ? Colors.white.withValues(alpha: 0.3) : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _previewBadge('Kcal', '${displayKcal.round()}', AppColors.textPrimary),
                                      const SizedBox(width: 8),
                                      _previewBadge('P', '${_p.round()}', const Color(0xFF4CAF50)),
                                      const SizedBox(width: 4),
                                      _previewBadge('C', '${_c.round()}', const Color(0xFF2196F3)),
                                      const SizedBox(width: 4),
                                      _previewBadge('Y', '${_f.round()}', const Color(0xFFE91E63)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: 0.1, end: 0, duration: 400.ms),

                      const SizedBox(height: 32),

                      // 2. Inputs
                      _buildInputGroup('Temel Bilgiler', [
                        _GlassInput(
                          controller: _nameController,
                          label: 'Yemek İsmi',
                          icon: Icons.edit,
                          hint: 'Örn. Mercimek Çorbası',
                        ),
                        const SizedBox(height: 16),
                        _GlassInput(
                          controller: _kcalController,
                          label: 'Kalori (100g için)',
                          icon: Icons.local_fire_department,
                          hint: 'Otomatik hesaplanır',
                          isNumber: true,
                        ),
                      ]),

                      const SizedBox(height: 24),

                      _buildInputGroup('Besin Değerleri (100g için)', [
                        Row(
                          children: [
                            Expanded(
                              child: _GlassInput(
                                controller: _proteinController,
                                label: 'Protein (g)',
                                icon: Icons.fitness_center,
                                color: const Color(0xFF4CAF50),
                                isNumber: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GlassInput(
                                controller: _carbController,
                                label: 'Karb (g)',
                                icon: Icons.grain,
                                color: const Color(0xFF2196F3),
                                isNumber: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _GlassInput(
                                controller: _fatController,
                                label: 'Yağ (g)',
                                icon: Icons.opacity,
                                color: const Color(0xFFE91E63),
                                isNumber: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Spacer for layout balance
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ]),

                      const SizedBox(height: 40),

                      AppButton.primary(
                        onPressed: _save,
                        text: 'Kaydet ve Ekle',
                        icon: Icons.check_circle,
                        isLoading: _saving,
                      ).animate().scale(delay: 200.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        ...children,
      ],
    );
  }

  Widget _previewBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool isNumber;
  final Color color;

  const _GlassInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.isNumber = false,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              icon: Icon(icon, color: color.withValues(alpha: 0.7), size: 20),
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
        ),
      ),
    );
  }
}
