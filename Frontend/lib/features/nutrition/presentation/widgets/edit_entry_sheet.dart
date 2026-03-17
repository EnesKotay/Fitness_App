import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/food_entry.dart';
import '../../domain/entities/meal_type.dart';

/// Yemek kaydını düzenleme bottom sheet'i.
/// Gramaj ve öğün tipi değiştirilebilir; makrolar otomatik yeniden hesaplanır.
class EditEntrySheet extends StatefulWidget {
  final FoodEntry entry;
  final Future<void> Function({
    required String entryId,
    required double newGrams,
    required MealType newMealType,
  }) onSave;

  const EditEntrySheet({
    super.key,
    required this.entry,
    required this.onSave,
  });

  /// Bottom sheet'i gösterir, düzenleme tamamlanırsa true döner.
  static Future<bool?> show(
    BuildContext context, {
    required FoodEntry entry,
    required Future<void> Function({
      required String entryId,
      required double newGrams,
      required MealType newMealType,
    }) onSave,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditEntrySheet(entry: entry, onSave: onSave),
    );
  }

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  late final TextEditingController _gramsController;
  late MealType _selectedMealType;
  bool _saving = false;

  // Per-100g values (recalculated from current entry)
  late final double _per100Kcal;
  late final double _per100Protein;
  late final double _per100Carb;
  late final double _per100Fat;

  @override
  void initState() {
    super.initState();
    _gramsController = TextEditingController(
      text: widget.entry.grams.round().toString(),
    );
    _selectedMealType = widget.entry.mealType;

    final ratio = widget.entry.grams > 0 ? widget.entry.grams / 100 : 1;
    _per100Kcal = ratio > 0 ? widget.entry.calculatedKcal / ratio : 0;
    _per100Protein = ratio > 0 ? widget.entry.protein / ratio : 0;
    _per100Carb = ratio > 0 ? widget.entry.carb / ratio : 0;
    _per100Fat = ratio > 0 ? widget.entry.fat / ratio : 0;
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  double get _currentGrams => double.tryParse(_gramsController.text) ?? 0;
  double get _previewKcal => _per100Kcal * _currentGrams / 100;
  double get _previewProtein => _per100Protein * _currentGrams / 100;
  double get _previewCarb => _per100Carb * _currentGrams / 100;
  double get _previewFat => _per100Fat * _currentGrams / 100;

  Future<void> _save() async {
    final grams = _currentGrams;
    if (grams <= 0) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(
        entryId: widget.entry.id,
        newGrams: grams,
        newMealType: _selectedMealType,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme hatası: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  widget.entry.foodName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),

                // Grams input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _gramsController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Gramaj',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                          suffixText: 'g',
                          suffixStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.secondary, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Quick gram buttons
                    ...([50, 100, 150, 200]).map((g) {
                      final isSelected = _currentGrams.round() == g;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: GestureDetector(
                          onTap: () {
                            _gramsController.text = g.toString();
                            setState(() {});
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.secondary.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.secondary
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$g',
                              style: TextStyle(
                                color: isSelected ? AppColors.secondary : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Meal type selector
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: MealType.values.map((type) {
                      final isSelected = type == _selectedMealType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMealType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.secondary.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.secondary
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              type.label,
                              style: TextStyle(
                                color: isSelected ? AppColors.secondary : Colors.white60,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Preview macros
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macroChip('Kalori', '${_previewKcal.round()}', 'kcal', const Color(0xFFFF6B6B)),
                      _macroChip('Protein', _previewProtein.toStringAsFixed(1), 'g', const Color(0xFF4ECDC4)),
                      _macroChip('Karb', _previewCarb.toStringAsFixed(1), 'g', const Color(0xFFFFD93D)),
                      _macroChip('Yağ', _previewFat.toStringAsFixed(1), 'g', const Color(0xFF6C63FF)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving || _currentGrams <= 0 ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Güncelle',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _macroChip(String label, String value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(unit, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
      ],
    );
  }
}
