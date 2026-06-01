import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/weekly_digest_service.dart';

/// Geçen haftanın performans raporunu gösteren widget.
/// AI tarafından üretilen kişiselleştirilmiş haftalık özet.
class WeeklyDigestCard extends StatelessWidget {
  const WeeklyDigestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: WeeklyDigestService().getDigest(),
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

        final digest = snapshot.data!;
        final weekLabel = digest['weekLabel'] ?? '';
        final aiSummary = digest['aiSummary'] ?? '';
        final data = digest['data'] as Map<String, dynamic>?;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF73D4FF).withOpacity(0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF73D4FF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Haftalık Rapor',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            weekLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Stats
              if (data != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.fitness_center,
                          label: 'Antrenman',
                          value: '${data['totalWorkouts'] ?? 0}',
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.monitor_weight_outlined,
                          label: 'Kilo Değişimi',
                          value: '${(data['weightChange'] ?? 0) >= 0 ? "+" : ""}${(data['weightChange'] ?? 0).toStringAsFixed(1)} kg',
                          color: (data['weightChange'] ?? 0) < 0
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF6B6B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.restaurant,
                          label: 'Ort. Kalori',
                          value: '${data['avgDailyCalories'] ?? 0}',
                          color: const Color(0xFF73D4FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // AI Summary
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFFEBC374),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Analizi',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEBC374),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1018),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MarkdownBody(
                        data: aiSummary,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
                          ),
                          strong: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF73D4FF),
                          ),
                          listBullet: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFEBC374),
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
      },
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1018),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
