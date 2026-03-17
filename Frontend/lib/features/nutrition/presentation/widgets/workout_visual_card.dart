import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/workout.dart';

class WorkoutVisualCard extends StatelessWidget {
  final List<Workout> workouts;
  final VoidCallback onAdd;
  final Function(int) onDelete;

  const WorkoutVisualCard({
    super.key,
    required this.workouts,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final totalBurned = workouts.fold<double>(0, (sum, w) => sum + (w.caloriesBurned?.toDouble() ?? 0.0));
    const accentColor = Colors.orangeAccent;

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
                colors: [accentColor.withValues(alpha: 0.8), accentColor.withValues(alpha: 0.4)],
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
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Antrenmanlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (totalBurned > 0)
                      Text('${totalBurned.round()} kcal yakıldı', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle, color: Colors.white70, size: 28),
                  tooltip: 'Antrenman Ekle',
                ),
              ],
            ),
          ),
          
          // İçerik Listesi
          if (workouts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: workouts.map((workout) => _buildWorkoutItem(workout)).toList(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              child: Column(
                children: [
                  Text(
                    'Bugün henüz antrenman kaydı yok',
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
                          border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                          color: accentColor.withValues(alpha: 0.12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 18, color: accentColor),
                            const SizedBox(width: 8),
                            const Text(
                              'Antrenmanlara git',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
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

  Widget _buildWorkoutItem(Workout workout) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orangeAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name ?? 'Antrenman',
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
                    '${workout.sets ?? 0} set x ${workout.reps ?? 0}${workout.weight != null ? ' x ${workout.weight}kg' : ''}  •  ${workout.caloriesBurned?.round() ?? 0} kcal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF6B6B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => onDelete(workout.id),
            ),
          ],
        ),
      ),
    );
  }
}
