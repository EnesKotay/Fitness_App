import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/food_entry.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VisualMealCard extends StatelessWidget {
  final MealType mealType;
  final List<FoodEntry> entries;
  final VoidCallback onAdd;
  final Function(String) onDelete;

  const VisualMealCard({
    super.key,
    required this.mealType,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
  });

  IconData get _icon {
    switch (mealType) {
      case MealType.breakfast: return Icons.wb_sunny_outlined;
      case MealType.lunch: return Icons.wb_cloudy_outlined;
      case MealType.dinner: return Icons.nights_stay_outlined;
      case MealType.snack: return Icons.cookie_outlined;
    }
  }

  Color get _color {
    switch (mealType) {
      case MealType.breakfast: return Colors.orangeAccent;
      case MealType.lunch: return Colors.lightBlueAccent;
      case MealType.dinner: return Colors.purpleAccent;
      case MealType.snack: return Colors.pinkAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = entries.fold<double>(0, (sum, e) => sum + e.calculatedKcal);

    return AppCard(
      animateOnAppear: false,
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Başlık ve İkon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_color.withValues(alpha: 0.8), _color.withValues(alpha: 0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _color, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mealType.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (totalKcal > 0)
                      Text('${totalKcal.round()} kcal', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 32),
                  tooltip: 'Hızlı Ekle',
                ),
              ],
            ),
          ),
          
          // İçerik Listesi
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: entries.map((entry) => _buildEntryItem(entry)).toList(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Column(
                children: [
                  Text(
                    'Henüz eklenmedi',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: _color.withValues(alpha: 0.6), width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                          color: _color.withValues(alpha: 0.12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 18, color: _color),
                            const SizedBox(width: 8),
                            Text(
                              'Bu öğüne ekle',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntryItem(FoodEntry entry) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(entry.id),
      background: Container(
        color: Colors.red.withValues(alpha: 0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        visualDensity: VisualDensity.compact,
        leading: const Icon(Icons.circle, size: 8, color: AppColors.textTertiary),
        title: Text(entry.foodName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text('${entry.grams.round()}g', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Text('${entry.calculatedKcal.round()} kcal', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
      ),
    );
  }
}
