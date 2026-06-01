import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/progress_prediction_service.dart';

/// Kullanıcının ilerleme tahminlerini gösteren kart widget'ı.
/// Backend'den gelen kilo projeksiyonu ve kalori dengesini görselleştirir.
class ProgressPredictionCard extends StatelessWidget {
  const ProgressPredictionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProgressPrediction?>(
      future: ProgressPredictionService().fetchPrediction(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final prediction = snapshot.data;
        if (prediction == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E2A3A), Color(0xFF0F1621)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: Color(0xFF73D4FF), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'İlerleme Tahmini',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Kilo Projeksiyonu
              if (prediction.weightProjection != null) ...[
                _buildWeightProjection(prediction.weightProjection!),
                const SizedBox(height: 12),
              ],

              // Kalori Dengesi
              if (prediction.calorieBalance != null) ...[
                _buildCalorieBalance(prediction.calorieBalance!),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeightProjection(WeightProjection proj) {
    IconData icon;
    Color iconColor;
    switch (proj.status) {
      case 'ON_TRACK':
        icon = Icons.trending_up;
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'STAGNANT':
        icon = Icons.trending_flat;
        iconColor = const Color(0xFFFFA726);
        break;
      case 'WRONG_DIRECTION':
        icon = Icons.trending_down;
        iconColor = const Color(0xFFEF5350);
        break;
      default:
        icon = Icons.help_outline;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1018),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  proj.message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (proj.weeksToTarget != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: Color(0xFF73D4FF), size: 14),
                const SizedBox(width: 6),
                Text(
                  '${proj.weeksToTarget!.toStringAsFixed(1)} hafta',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF73D4FF),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.fitness_center, color: Color(0xFFEBC374), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Haftalık: ${proj.weeklyChangeKg.toStringAsFixed(2)} kg',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalorieBalance(CalorieBalance balance) {
    final isDeficit = balance.dailyBalance < 0;
    final isSurplus = balance.dailyBalance > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1018),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDeficit ? Icons.arrow_downward : (isSurplus ? Icons.arrow_upward : Icons.remove),
                color: isDeficit ? const Color(0xFF4CAF50) : (isSurplus ? const Color(0xFFFF6B6B) : Colors.grey),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  balance.insight,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildMetricChip('Ort. Kalori', '${balance.avgDailyCalories} kcal'),
              _buildMetricChip('TDEE', '${balance.tdee.toStringAsFixed(0)} kcal'),
              _buildMetricChip(
                'Denge',
                '${balance.dailyBalance >= 0 ? "+" : ""}${balance.dailyBalance.toStringAsFixed(0)} kcal',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF73D4FF),
            ),
          ),
        ],
      ),
    );
  }
}
