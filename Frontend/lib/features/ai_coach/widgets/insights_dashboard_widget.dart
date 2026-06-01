import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'workout_plateau_card.dart';
import 'deload_recommendation_card.dart';
import 'learning_stats_card.dart';
import 'weekly_digest_card.dart';

/// Analizler ve İçgörüler Dashboard'u
class InsightsDashboardWidget extends StatelessWidget {
  const InsightsDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider?>()?.user?.id;

    if (userId == null) {
      return const Center(
        child: Text(
          'Giriş yapmanız gerekiyor',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 Analizler ve İçgörüler',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI koçun senin için hazırladı',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section: Öğrenme İstatistikleri
        _buildSectionHeader('🎓 Öğrenme Seviyesi'),
        const LearningStatsCard(),
        const SizedBox(height: 16),

        // Section: Haftalık Rapor
        _buildSectionHeader('📅 Haftalık Performans'),
        const WeeklyDigestCard(),
        const SizedBox(height: 16),

        // Section: Antrenman Analizi
        _buildSectionHeader('💪 Antrenman Durumu'),
        const DeloadRecommendationCard(
          needsDeload: false,
          reason: 'Volume ve RPE dengeli görünüyor',
        ),
        const SizedBox(height: 16),

        // Placeholder: Daha fazla kart eklenebilir
        _buildSectionHeader('🎯 Plato Analizi'),
        const WorkoutPlateauCard(
          exerciseName: 'Bench Press',
          plateaued: false,
          reason: 'Son 4 haftada %8 ilerleme',
          progressPercent: 8.0,
        ),
        const SizedBox(height: 16),

        // Info card
        _buildInfoCard(context),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00D9FF),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF00D9FF),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Analizler günde 1 kez güncellenir. Daha fazla veri girdikçe daha doğru sonuçlar alırsın.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
