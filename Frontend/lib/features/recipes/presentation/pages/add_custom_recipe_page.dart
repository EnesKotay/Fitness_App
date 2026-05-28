import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/recipe.dart';
import '../state/recipe_provider.dart';

class AddCustomRecipePage extends StatefulWidget {
  const AddCustomRecipePage({super.key});

  @override
  State<AddCustomRecipePage> createState() => _AddCustomRecipePageState();
}

class _AddCustomRecipePageState extends State<AddCustomRecipePage> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  
  String _category = 'ana_yemek';
  final List<RecipeIngredient> _ingredients = [];
  final List<String> _steps = [];

  void _addIngredient() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'g');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D25),
        title: const Text('Malzeme Ekle', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Malzeme (örn: Tavuk Göğsü)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Miktar',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Birim (g, ml, adet)',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                setState(() {
                  _ingredients.add(
                    RecipeIngredient(
                      name: nameCtrl.text.trim(),
                      amount: double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0,
                      unit: unitCtrl.text.trim().isEmpty ? 'g' : unitCtrl.text.trim(),
                    ),
                  );
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _addStep() {
    final stepCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D25),
        title: const Text('Adım Ekle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: stepCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ne yapılması gerekiyor?',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (stepCtrl.text.isNotEmpty) {
                setState(() {
                  _steps.add(stepCtrl.text.trim());
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir malzeme eklemelisin.')));
      return;
    }
    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir adım eklemelisin.')));
      return;
    }

    final kcal = double.tryParse(_kcalCtrl.text) ?? 0;
    final protein = double.tryParse(_proteinCtrl.text) ?? 0;
    final carb = double.tryParse(_carbCtrl.text) ?? 0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0;

    final recipe = Recipe(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      servings: 1,
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      ingredients: _ingredients,
      steps: _steps,
      imageEmoji: '👨‍🍳',
      kcalPerServing: kcal,
      proteinPerServing: protein,
      carbPerServing: carb,
      fatPerServing: fat,
      fiberPerServing: 0,
      sugarPerServing: 0,
      tags: ['kendi tarifim'],
      difficulty: 'orta',
    );

    context.read<RecipeProvider>().addCustomRecipe(recipe);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarifin kaydedildi!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Özel Tarif Ekle', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Kaydet', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Tarif Adı',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: const UnderlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Tarif adı gerekli' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: const UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _category,
              dropdownColor: const Color(0xFF1A1D25),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Kategori',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'kahvalti', child: Text('Kahvaltı')),
                DropdownMenuItem(value: 'ana_yemek', child: Text('Ana Yemek')),
                DropdownMenuItem(value: 'salata', child: Text('Salata')),
                DropdownMenuItem(value: 'bowl', child: Text('Bowl')),
                DropdownMenuItem(value: 'smoothie', child: Text('Smoothie')),
                DropdownMenuItem(value: 'atistirmalik', child: Text('Atıştırmalık')),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 24),
            Text('Besin Değerleri (1 porsiyon için)', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildNumberField(_kcalCtrl, 'Kalori (kcal)')),
                const SizedBox(width: 12),
                Expanded(child: _buildNumberField(_proteinCtrl, 'Protein (g)')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildNumberField(_carbCtrl, 'Karb (g)')),
                const SizedBox(width: 12),
                Expanded(child: _buildNumberField(_fatCtrl, 'Yağ (g)')),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Malzemeler', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryLight),
                ),
              ],
            ),
            if (_ingredients.isEmpty)
              Text('Henüz malzeme eklenmedi.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ..._ingredients.asMap().entries.map((e) {
              final i = e.key;
              final ing = e.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ing.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${ing.amount} ${ing.unit}', style: const TextStyle(color: Colors.white54)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() => _ingredients.removeAt(i)),
                ),
              );
            }),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hazırlanış Adımları', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryLight),
                ),
              ],
            ),
            if (_steps.isEmpty)
              Text('Henüz adım eklenmedi.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ..._steps.asMap().entries.map((e) {
              final i = e.key;
              final step = e.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text('${i+1}', style: const TextStyle(color: AppColors.primaryLight)),
                ),
                title: Text(step, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() => _steps.removeAt(i)),
                ),
              );
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (v) => v!.isEmpty ? 'Gerekli' : null,
    );
  }
}
