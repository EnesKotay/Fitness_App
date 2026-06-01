import 'package:flutter/material.dart';

/// Plato tespiti kartı - egzersiz bazında
class WorkoutPlateauCard extends StatelessWidget {
  final String exerciseName;
  final bool plateaued;
  final String reason;
  final String? suggestion;
  final double progressPercent;

  const WorkoutPlateauCard({
    super.key,
    required this.exerciseName,
    required this.plateaued,
    required this.reason,
    this.suggestion,
    required this.progressPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: plateaued
                ? [Colors.orange.shade700.withValues(alpha: 0.1), Colors.red.shade700.withValues(alpha: 0.1)]
                : [Colors.green.shade700.withValues(alpha: 0.1), Colors.teal.shade700.withValues(alpha: 0.1)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  plateaued ? Icons.warning_amber_rounded : Icons.trending_up_rounded,
                  color: plateaued ? Colors.orange.shade700 : Colors.green.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plateaued ? '⚠️ Plato Tespit Edildi' : '✅ İyi İlerleme',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: plateaued ? Colors.orange.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getProgressColor(progressPercent).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${progressPercent >= 0 ? '+' : ''}${progressPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getProgressColor(progressPercent),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.grey.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Suggestions (if plateaued)
            if (plateaued && suggestion != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Öneriler',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      suggestion!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double percent) {
    if (percent < 0) return Colors.red.shade700;
    if (percent < 2.5) return Colors.orange.shade700;
    if (percent < 5) return Colors.yellow.shade800;
    if (percent < 10) return Colors.lightGreen.shade700;
    return Colors.green.shade700;
  }
}
