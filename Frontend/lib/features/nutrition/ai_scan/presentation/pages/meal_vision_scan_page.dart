import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/ai_service.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_type.dart';
import '../../../presentation/state/diet_provider.dart';
import '../../../services/premium_feature_gate.dart';
import '../../domain/models/scanned_meal_result.dart';

class MealVisionScanPage extends StatefulWidget {
  final MealType initialMealType;

  const MealVisionScanPage({super.key, required this.initialMealType});

  @override
  State<MealVisionScanPage> createState() => _MealVisionScanPageState();
}

class _MealVisionScanPageState extends State<MealVisionScanPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  ScannedMealResult? _result;
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
        featureName: 'Yemek fotoğrafı analizi',
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
      if (mounted) {
        setState(() => _errorMessage = 'Fotoğraf seçilemedi: $e');
      }
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
      final result = await aiService.analyzeFoodImage(_imageFile!);

      if (mounted) {
        setState(() {
          _result = result;
          _isProcessing = false;
          _nameController.text = result.mealName ?? 'Yemek';
          _kcalController.text = result.estimatedKcal.toStringAsFixed(1);
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
        ? 'AI Yemek'
        : _nameController.text.trim();

    try {
      final food = FoodItem(
        id: 'vision_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: 'Yemek',
        basis: const FoodBasis(amount: 1, unit: 'porsiyon'),
        nutrients: Nutrients(
          kcal: kcal,
          protein: protein,
          carb: carb,
          fat: fat,
        ),
        servings: const [
          ServingUnit(
            id: 's_portion',
            label: '1 Porsiyon',
            grams: 100,
            isDefault: true,
          ),
        ],
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
            'Yemek Fotoğrafı Tara',
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
                  Icons.restaurant_rounded,
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
            'Yemek Fotoğrafı Yükle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yemeğinin fotoğrafını çekin veya galeriden seçin.\nAI porsiyon ve kaloriyi tahmin edecek.',
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

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
                  strokeWidth: 3,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: 1500.ms,
                color: Colors.white.withValues(alpha: 0.2),
              ),
          const SizedBox(height: 24),
          const Text(
                'Yapay Zeka Analiz Ediyor...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fade(begin: 0.5, end: 1, duration: 1000.ms),
          const SizedBox(height: 8),
          Text(
            'Bu işlem birkaç saniye sürebilir\nlütfen bekleyin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          if (_imageFile != null)
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4ECDC4),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Güven: %${(_result!.confidence * 100).round()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),

          Text(
            'Analiz Sonuçları',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          _buildInputRow(
            'Yemek Adı',
            _nameController,
            icon: Icons.fastfood_rounded,
          ),
          _buildInputRow(
            'Kalori (kcal)',
            _kcalController,
            isNumber: true,
            icon: Icons.local_fire_department_rounded,
          ),

          Row(
            children: [
              Expanded(
                child: _buildInputRow(
                  'Protein (g)',
                  _proteinController,
                  isNumber: true,
                  isSmall: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputRow(
                  'Karb (g)',
                  _carbController,
                  isNumber: true,
                  isSmall: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputRow(
                  'Yağ (g)',
                  _fatController,
                  isNumber: true,
                  isSmall: true,
                ),
              ),
            ],
          ),

          if (_result?.detectedIngredients != null &&
              _result!.detectedIngredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Görünen Malzemeler',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _result!.detectedIngredients.map((ingredient) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ingredient,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 32),
          _buildActionButton(
            icon: Icons.check_rounded,
            label: 'Kaydet ve Günlüğe Ekle',
            gradient: const [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
            onTap: _saveAndReturn,
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isSmall = false,
    IconData? icon,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: controller,
              keyboardType: isNumber
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                isDense: true,
              ),
            ),
          ),
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
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
