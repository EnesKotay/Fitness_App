import 'package:flutter/material.dart';
import '../../../core/models/exercise.dart';
import '../providers/workout_provider.dart';

class ExerciseSelectionList extends StatelessWidget {
  final List<Exercise> exercises;
  final String? selectedExerciseName;
  final ValueChanged<String?> onExerciseSelected;
  final WorkoutProvider workoutProv;
  final Color accentColor;
  final String? Function(WorkoutProvider, String)? latestWorkoutSummaryCallback;

  const ExerciseSelectionList({
    super.key,
    required this.exercises,
    required this.selectedExerciseName,
    required this.onExerciseSelected,
    required this.workoutProv,
    required this.accentColor,
    this.latestWorkoutSummaryCallback,
  });

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF0E1318);
    const cardBorder = Color(0xFF1C2530);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: exercises.map((ex) {
        final selected = selectedExerciseName == ex.name;
        final recentWeights = workoutProv.maxWeightsFor(ex.name, limit: 4);
        final summary = latestWorkoutSummaryCallback != null 
            ? latestWorkoutSummaryCallback!(workoutProv, ex.name) 
            : null;

        return GestureDetector(
          onTap: () {
            final newSelected = selected ? null : ex.name;
            onExerciseSelected(newSelected);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? accentColor.withAlpha((0.12 * 255).toInt()) : cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accentColor.withAlpha((0.5 * 255).toInt()) : cardBorder,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: accentColor.withAlpha((0.12 * 255).toInt()), blurRadius: 8)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? accentColor.withAlpha((0.2 * 255).toInt())
                            : Colors.white.withAlpha((0.04 * 255).toInt()),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        selected ? Icons.check_rounded : Icons.fitness_center_rounded,
                        color: selected ? accentColor : Colors.white24,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ex.name,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white60,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (recentWeights.isNotEmpty)
                      Text(
                        '${recentWeights.last.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          color: accentColor.withAlpha((0.7 * 255).toInt()),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (summary != null) ...[
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Text(
                      'Son seans: $summary',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.42 * 255).toInt()),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
                if (recentWeights.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 44),
                      ...recentWeights.asMap().entries.map((e) {
                        final isLast = e.key == recentWeights.length - 1;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLast
                                    ? accentColor.withAlpha((0.18 * 255).toInt())
                                    : Colors.white.withAlpha((0.04 * 255).toInt()),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isLast ? accentColor.withAlpha((0.4 * 255).toInt()) : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                '${e.value.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  color: isLast ? accentColor : Colors.white30,
                                  fontSize: 10,
                                  fontWeight: isLast ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (!isLast)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Colors.white.withAlpha((0.06 * 255).toInt())),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
