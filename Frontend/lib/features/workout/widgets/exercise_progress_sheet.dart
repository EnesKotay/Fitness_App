import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/workout.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/workout_provider.dart';

Future<void> showExerciseProgress(BuildContext context, String exerciseName) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ExerciseProgressSheet(exerciseName: exerciseName),
  );
}

class ExerciseProgressSheet extends StatefulWidget {
  final String exerciseName;
  const ExerciseProgressSheet({super.key, required this.exerciseName});

  @override
  State<ExerciseProgressSheet> createState() => _ExerciseProgressSheetState();
}

class _ExerciseProgressSheetState extends State<ExerciseProgressSheet> {
  static const _bg = Color(0xFF0D1520);
  static const _accent = Color(0xFFCC7A4A);
  static const _card = Color(0xFF121E2E);

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = context.read<AuthProvider?>()?.user?.id;
    if (uid == null) return;
    setState(() => _loading = true);
    await context.read<WorkoutProvider>().loadExerciseHistory(uid, widget.exerciseName);
    if (mounted) setState(() => _loading = false);
  }

  List<Workout> _sortedHistory(WorkoutProvider prov) {
    final history = prov.exerciseHistory
        .where((w) => w.name.toLowerCase() == widget.exerciseName.toLowerCase() && (w.weight ?? 0) > 0)
        .toList()
      ..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));
    return history;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, prov, _) {
        final history = _sortedHistory(prov);
        final pr = history.isNotEmpty
            ? history.map((w) => w.weight ?? 0.0).reduce((a, b) => a > b ? a : b)
            : 0.0;
        final first = history.isNotEmpty ? history.first.weight ?? 0.0 : 0.0;
        final last = history.isNotEmpty ? history.last.weight ?? 0.0 : 0.0;
        final gain = last - first;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.trending_up_rounded, color: _accent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.exerciseName,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${history.length} seans kaydı',
                              style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
                      : history.isEmpty
                          ? _buildEmpty()
                          : ListView(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                              children: [
                                // Stats row
                                _buildStatsRow(pr, gain, history.length),
                                const SizedBox(height: 20),
                                // Chart
                                _buildChart(history),
                                const SizedBox(height: 20),
                                // Recent history
                                _buildHistoryList(history),
                              ],
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart_rounded, color: Colors.white12, size: 56),
          const SizedBox(height: 14),
          Text(
            'Henüz ağırlık kaydı yok',
            style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Antrenman eklerken ağırlık girdikçe\nburada ilerleme grafiği görünür.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(double pr, double gain, int count) {
    return Row(
      children: [
        _StatCard(
          label: 'Kişisel Rekor',
          value: '${pr.toStringAsFixed(1)} kg',
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFEBC374),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Toplam Gelişim',
          value: gain >= 0 ? '+${gain.toStringAsFixed(1)} kg' : '${gain.toStringAsFixed(1)} kg',
          icon: gain >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: gain >= 0 ? const Color(0xFF34D399) : const Color(0xFFFF6B6B),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Toplam Seans',
          value: '$count',
          icon: Icons.repeat_rounded,
          color: const Color(0xFF73D4FF),
        ),
      ],
    );
  }

  Widget _buildChart(List<Workout> history) {
    // Use last 20 sessions for readability
    final data = history.length > 20 ? history.sublist(history.length - 20) : history;
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weight ?? 0))
        .toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPad = ((maxY - minY) * 0.2).clamp(5.0, 20.0);

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (data.length / 4).ceilToDouble().clamp(1, 5),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final d = data[idx].workoutDate;
                  return Text(
                    '${d.day}/${d.month}',
                    style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 9),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minY: (minY - yPad).clamp(0, double.infinity),
          maxY: maxY + yPad,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _accent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 3.5,
                  color: _accent,
                  strokeColor: Colors.black,
                  strokeWidth: 1.5,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    _accent.withValues(alpha: 0.18),
                    _accent.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<Workout> history) {
    final recent = history.reversed.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Seanslar',
          style: GoogleFonts.dmSans(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        ...recent.map((w) {
          final isRecord = w.weight != null &&
              (w.weight! >= history.map((h) => h.weight ?? 0).reduce((a, b) => a > b ? a : b));
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRecord ? _accent.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                if (isRecord)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.emoji_events_rounded, color: Color(0xFFEBC374), size: 14),
                  ),
                Expanded(
                  child: Text(
                    _formatDate(w.workoutDate),
                    style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12.5),
                  ),
                ),
                if (w.sets != null && w.reps != null)
                  Text(
                    '${w.sets}×${w.reps}',
                    style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12),
                  ),
                const SizedBox(width: 12),
                Text(
                  '${(w.weight ?? 0).toStringAsFixed(1)} kg',
                  style: GoogleFonts.dmSans(
                    color: isRecord ? const Color(0xFFEBC374) : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
