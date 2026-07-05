import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/food_entry.dart';

class VisualMealCard extends StatelessWidget {
  final MealType mealType;
  final List<FoodEntry> entries;
  final VoidCallback onAdd;
  final Function(String) onDelete;
  final Function(FoodEntry)? onEdit;

  const VisualMealCard({
    super.key,
    required this.mealType,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
    this.onEdit,
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

  String get _emptyStateMessage {
    switch (mealType) {
      case MealType.breakfast: return 'Güne enerjik başla, kahvaltını ekle!';
      case MealType.lunch: return 'Öğle yemeği zamanı, tabağını doldur!';
      case MealType.dinner: return 'Günü güzel kapat, akşam yemeğini gir!';
      case MealType.snack: return 'Küçük bir mola, atıştırmalığını ekle!';
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, size: 28, color: _color.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _emptyStateMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Builder(
        builder: (context) => Dismissible(
          key: Key(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.red.shade600.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.backgroundCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade300, size: 24),
                    const SizedBox(width: 10),
                    const Text('Silmek istediğine emin misin?'),
                  ],
                ),
                content: Text(
                  '${entry.foodName} kaydı silinecek.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('İptal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Sil'),
                  ),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (_) => onDelete(entry.id),
          child: InkWell(
            onLongPress: () => _showQuickActionsSheet(context, entry),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
              // Renkli nokta
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),

              // Yemek adı & gram
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.foodName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.grams.round()}g  •  ${entry.calculatedKcal.round()} kcal',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Düzenle butonu
              if (onEdit != null)
                _actionButton(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF5B9BFF),
                  tooltip: 'Düzenle',
                  onTap: () => onEdit!(entry),
                ),

              const SizedBox(width: 4),

              // Sil butonu
              _actionButton(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFFF6B6B),
                tooltip: 'Sil',
                onTap: () => onDelete(entry.id),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickActionsSheet(BuildContext context, FoodEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.foodName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.grams.round()}g  •  ${entry.calculatedKcal.round()} kcal',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (onEdit != null)
              _quickActionTile(
                icon: Icons.edit_rounded,
                label: 'Düzenle',
                color: Colors.blue.shade300,
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit!(entry);
                },
              ),
            _quickActionTile(
              icon: Icons.delete_rounded,
              label: 'Sil',
              color: Colors.red.shade300,
              onTap: () {
                Navigator.pop(ctx);
                onDelete(entry.id);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
          ),
        ),
      ),
    );
  }
}
