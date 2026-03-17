import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/ai_service.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_type.dart';
import '../../../presentation/state/diet_provider.dart';
import '../../../services/premium_feature_gate.dart';
import '../../domain/models/scanned_nutrition_result.dart';

class LabelOcrScanPage extends StatefulWidget {
  final MealType initialMealType;

  const LabelOcrScanPage({super.key, required this.initialMealType});

  @override
  State<LabelOcrScanPage> createState() => _LabelOcrScanPageState();
}

class _LabelOcrScanPageState extends State<LabelOcrScanPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  ScannedNutritionResult? _result;
  bool _isProcessing = false;
  String? _errorMessage;

  // Editable controllers
  final _nameController = TextEditingController();
  final _kcalController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbController = TextEditingController();
  final _fatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final allowed = await PremiumFeatureGate.ensureAccess(
        context,
        featureName: 'Besin etiketi tara',
      );
      if (!allowed && mounted) {
        Navigator.of(context).pop();
      }
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _result = null;
        _errorMessage = null;
      });

      await _processImage();
    } catch (e) {
      setState(() => _errorMessage = 'Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final aiService = Provider.of<AIService>(context, listen: false);
      final result = await aiService.scanNutritionLabel(_imageFile!);

      if (mounted) {
        setState(() {
          _result = result;
          _isProcessing = false;
          _nameController.text = result.productName ?? '';
          _kcalController.text = result.kcal.toStringAsFixed(1);
          _proteinController.text = result.protein.toStringAsFixed(1);
          _carbController.text = result.carb.toStringAsFixed(1);
          _fatController.text = result.fat.toStringAsFixed(1);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceFirst('ApiException: ', '');
        });
      }
    }
  }

  Future<void> _saveAndReturn() async {
    final kcal = double.tryParse(_kcalController.text) ?? 0;
    final protein = double.tryParse(_proteinController.text) ?? 0;
    final carb = double.tryParse(_carbController.text) ?? 0;
    final fat = double.tryParse(_fatController.text) ?? 0;
    final name = _nameController.text.trim().isEmpty
        ? 'Taranan Ürün'
        : _nameController.text.trim();

    try {
      final food = FoodItem(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: 'Diğer',
        basis: const FoodBasis(amount: 100, unit: 'g'),
        nutrients: Nutrients(
          kcal: kcal,
          protein: protein,
          carb: carb,
          fat: fat,
        ),
        servings: _result?.servingSize != null
            ? [
                ServingUnit(
                  id: 's_label',
                  label:
                      '1 ${(_result?.servingUnit?.trim().isNotEmpty ?? false) ? _result!.servingUnit!.trim() : 'Porsiyon'}',
                  grams: _result!.servingSize!,
                  isDefault: true,
                ),
              ]
            : const [],
      );

      final provider = context.read<DietProvider>();
      await provider.addCustomFood(food);

      if (mounted) Navigator.pop(context, food);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kaydetme hatası: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isProcessing
                  ? _buildLoadingView()
                  : _result != null
                  ? _buildResultView()
                  : _buildPickerView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Etiket Tara',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (_result != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _result = null;
                  _imageFile = null;
                });
              },
              child: const Text(
                'Yeniden Tara',
                style: TextStyle(color: Color(0xFF6C63FF)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickerView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  size: 56,
                  color: Colors.white,
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 400.ms,
              ),
          const SizedBox(height: 24),
          const Text(
            'Besin Etiketi Tara',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ürünün besin etiketi fotoğrafını çekin veya galeriden seçin.\nAI değerleri otomatik okuyacak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          _buildActionButton(
            icon: Icons.camera_alt_rounded,
            label: 'Fotoğraf Çek',
            gradient: const [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
            onTap: () => _pickImage(ImageSource.camera),
          ),
          const SizedBox(height: 14),
          _buildActionButton(
            icon: Icons.photo_library_rounded,
            label: 'Galeriden Seç',
            gradient: const [Color(0xFF4ECDC4), Color(0xFF44CF6C)],
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_imageFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(_imageFile!, height: 200, fit: BoxFit.cover),
          ),
        const SizedBox(height: 32),
        SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(
                  const Color(0xFF6C63FF).withValues(alpha: 0.8),
                ),
              ),
            )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 1500.ms,
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.3),
            ),
        const SizedBox(height: 20),
        const Text(
          'AI etiket okuyor...',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Gemini Vision analiz ediyor',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final confidence = _result?.confidence ?? 0;
    final confidencePercent = (confidence * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Confidence badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: confidence > 0.7
                      ? Colors.greenAccent.withValues(alpha: 0.15)
                      : Colors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Güven: %$confidencePercent',
                  style: TextStyle(
                    color: confidence > 0.7
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (_result != null && !_result!.isEmpty)
                const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Product name
          _buildEditableField(
            'Ürün Adı',
            _nameController,
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 12),

          // Macros grid
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Besin Değerleri (100g)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildMacroField(
                        'Kalori',
                        _kcalController,
                        'kcal',
                        const Color(0xFFFF6B6B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMacroField(
                        'Protein',
                        _proteinController,
                        'g',
                        const Color(0xFF4ECDC4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMacroField(
                        'Karb',
                        _carbController,
                        'g',
                        const Color(0xFFFFD93D),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMacroField(
                        'Yağ',
                        _fatController,
                        'g',
                        const Color(0xFF6C63FF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          GestureDetector(
                onTap: _saveAndReturn,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Günlüğe Ekle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.1, end: 0, duration: 300.ms),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
  }) {
    return _buildGlassCard(
      child: TextField(
        controller: ctrl,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.white38, size: 20)
              : null,
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildMacroField(
    String label,
    TextEditingController ctrl,
    String unit,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
