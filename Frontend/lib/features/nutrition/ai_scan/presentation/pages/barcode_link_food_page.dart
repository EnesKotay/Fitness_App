import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../presentation/state/diet_provider.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_type.dart';
import '../../data/repositories/barcode_food_repository.dart';

class BarcodeLinkFoodPage extends StatefulWidget {
  final String barcode;
  final MealType mealType;

  const BarcodeLinkFoodPage({
    super.key,
    required this.barcode,
    required this.mealType,
  });

  @override
  State<BarcodeLinkFoodPage> createState() => _BarcodeLinkFoodPageState();
}

class _BarcodeLinkFoodPageState extends State<BarcodeLinkFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _kcalController = TextEditingController();
  final _proteinController = TextEditingController(text: '0');
  final _carbController = TextEditingController(text: '0');
  final _fatController = TextEditingController(text: '0');

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _kcalController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Ürün Tanımla')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Barkod: ${widget.barcode}\nBu barkod veritabanında bulunamadı. Lütfen tanımlayın.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ürün Adı',
                  border: OutlineInputBorder(),
                  hintText: 'Örn: Tam Buğday Ekmeği',
                ),
                validator: (v) => v?.isEmpty == true ? 'Gerekli' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kcalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'kcal / 100g',
                        border: OutlineInputBorder(),
                        suffixText: 'kcal',
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Gerekli' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Makrolar (100g için OPSİYONEL)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMacroField(
                      _proteinController,
                      'Protein',
                      'g',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroField(
                      _carbController,
                      'Karb',
                      'g',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroField(
                      _fatController,
                      'Yağ',
                      'g',
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isLoading ? null : _saveAndLink,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Kaydet ve Ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroField(
    TextEditingController ctrl,
    String label,
    String suffix,
    Color color,
  ) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: color.withValues(alpha: 0.5))),
      ),
    );
  }

  Future<void> _saveAndLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final kcal = double.parse(_kcalController.text.replaceAll(',', '.'));
      final p = double.tryParse(_proteinController.text.replaceAll(',', '.')) ?? 0;
      final c = double.tryParse(_carbController.text.replaceAll(',', '.')) ?? 0;
      final f = double.tryParse(_fatController.text.replaceAll(',', '.')) ?? 0;

      final newFood = FoodItem(
        id: const Uuid().v4(),
        name: name,
        category: 'Barkodlu',
        basis: const FoodBasis(amount: 100, unit: 'g'),
        nutrients: Nutrients(
          kcal: kcal,
          protein: p,
          carb: c,
          fat: f,
        ),
      );

      // 1. Save as custom food
      final provider = context.read<DietProvider>();
      await provider.addCustomFood(newFood);

      // 2. Link barcode
      final repo = BarcodeFoodRepository();
      await repo.saveMapping(widget.barcode, newFood.id);

      // 3. Return result
      if (mounted) {
        Navigator.pop(context, true); // Success signal
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
