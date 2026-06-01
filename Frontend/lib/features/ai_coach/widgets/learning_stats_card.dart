import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/learning_service.dart';

/// Kullanıcının AI Coach ile öğrenme ilerlemesini gösteren widget.
/// Bilgi seviyesi, soru sayısı ve memnuniyet oranını görselleştirir.
class LearningStatsCard extends StatelessWidget {
  const LearningStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: LearningService().getStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final level = stats['knowledgeLevel'] ?? 'INTERMEDIATE';
        final levelLabel = stats['levelLabel'] ?? 'Orta Seviye';
        final levelEmoji = stats['levelEmoji'] ?? '💪';
        final questionsAsked = stats['questionsAsked30d'] ?? 0;
        final satisfactionRate = stats['satisfactionRate'] ?? '0%';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getGradientColors(level),
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
                  Text(
                    levelEmoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Öğrenme Seviyesi',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          levelLabel,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // İstatistikler
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.question_answer_outlined,
                      label: 'Son 30 Gün',
                      value: '$questionsAsked soru',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.thumb_up_outlined,
                      label: 'Memnuniyet',
                      value: satisfactionRate,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bilgi notu
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFFEBC374),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getLevelDescription(level),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
              Icon(icon, color: const Color(0xFF73D4FF), size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors(String level) {
    switch (level.toUpperCase()) {
      case 'BEGINNER':
        return [const Color(0xFF2E7D32), const Color(0xFF1B5E20)];
      case 'ADVANCED':
        return [const Color(0xFFD84315), const Color(0xFFBF360C)];
      default:
        return [const Color(0xFF1976D2), const Color(0xFF0D47A1)];
    }
  }

  String _getLevelDescription(String level) {
    switch (level.toUpperCase()) {
      case 'BEGINNER':
        return 'AI Coach temel kavramları detaylı açıklıyor ve sana özel öğrenme yolu oluşturuyor.';
      case 'ADVANCED':
        return 'AI Coach bilimsel detaylara giriyor ve ileri seviye taktikler veriyor.';
      default:
        return 'AI Coach dengeli bir dil kullanıyor ve temel bilgilerle ileri taktikleri birleştiriyor.';
    }
  }
}
