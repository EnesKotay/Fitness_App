import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../workout/providers/workout_provider.dart';
import '../../../core/models/workout.dart';

class PerformanceTrendCard extends StatelessWidget {
  final WorkoutProvider workoutProvider;

  const PerformanceTrendCard({super.key, required this.workoutProvider});

  // Haftalık hacim: toplam set × rep × kg (son 8 hafta)
  List<_WeekVolume> _weeklyVolumes() {
    final now = DateTime.now();
    final weeks = <_WeekVolume>[];
    for (int i = 7; i >= 0; i--) {
      final start = now.subtract(Duration(days: (i + 1) * 7));
      final end = now.subtract(Duration(days: i * 7));
      final vol = workoutProvider.workouts
          .where((w) =>
              w.workoutDate.isAfter(start) && w.workoutDate.isBefore(end))
          .fold<double>(0, (sum, w) {
        final sets = w.sets ?? 1;
        final reps = w.reps ?? 1;
        final kg = w.weight ?? 0;
        return sum + (sets * reps * kg);
      });
      weeks.add(_WeekVolume(weekIndex: 8 - i, volume: vol));
    }
    return weeks;
  }

  // En son 5 antrenman için PR trendleri
  List<_ExercisePR> _topPRs() {
    final prs = workoutProvider.personalRecords;
    if (prs.isEmpty) return [];

    final entries = prs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(5).map((e) {
      final weights = workoutProvider.maxWeightsFor(e.key, limit: 4);
      double? prev;
      if (weights.length >= 2) {
        prev = weights[weights.length - 2];
      }
      final trend = prev == null
          ? _Trend.neutral
          : e.value > prev
          ? _Trend.up
          : e.value < prev
          ? _Trend.down
          : _Trend.neutral;
      return _ExercisePR(
        name: e.key,
        maxKg: e.value,
        trend: trend,
        history: weights,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prs = _topPRs();
    final volumes = _weeklyVolumes();
    final maxVol = volumes.map((v) => v.volume).fold<double>(1, (a, b) => a > b ? a : b);

    return Column(
      children: [
        // ── Kişisel Rekorlar ──
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFD60A).withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD60A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFD60A),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kişisel Rekorlar',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Her egzersizdeki maks. ağırlık',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (prs.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Text(
                    'Antrenman ekledikçe rekorların burada görünür.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                )
              else
                ...prs.map(
                  (pr) => _PRRow(pr: pr),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Haftalık Hacim ──
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF5E5CE6).withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E5CE6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stacked_bar_chart_rounded,
                        color: Color(0xFF5E5CE6),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haftalık Hacim Trendi',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Set × Tekrar × Kg (son 8 hafta)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _VolumeChart(volumes: volumes, maxVol: maxVol),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PRRow extends StatelessWidget {
  final _ExercisePR pr;
  const _PRRow({required this.pr});

  @override
  Widget build(BuildContext context) {
    final trendColor = pr.trend == _Trend.up
        ? const Color(0xFF30D158)
        : pr.trend == _Trend.down
        ? const Color(0xFFFF453A)
        : Colors.white38;
    final trendIcon = pr.trend == _Trend.up
        ? Icons.trending_up_rounded
        : pr.trend == _Trend.down
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                pr.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Mini sparkline
            if (pr.history.length >= 2)
              _Sparkline(data: pr.history, color: trendColor),
            const SizedBox(width: 10),
            Text(
              '${pr.maxKg.toStringAsFixed(pr.maxKg == pr.maxKg.roundToDouble() ? 0 : 1)} kg',
              style: const TextStyle(
                color: Color(0xFFFFD60A),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Icon(trendIcon, color: trendColor, size: 16),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  const _Sparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 20,
      child: CustomPaint(painter: _SparklinePainter(data: data, color: color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs();

    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = range == 0
          ? size.height / 2
          : size.height - ((data[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VolumeChart extends StatelessWidget {
  final List<_WeekVolume> volumes;
  final double maxVol;
  const _VolumeChart({required this.volumes, required this.maxVol});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: volumes.asMap().entries.map((entry) {
          final i = entry.key;
          final v = entry.value;
          final isLast = i == volumes.length - 1;
          final fraction = maxVol > 0 ? (v.volume / maxVol) : 0.0;
          final barColor = isLast
              ? const Color(0xFF5E5CE6)
              : const Color(0xFF5E5CE6).withValues(alpha: 0.40);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isLast && v.volume > 0)
                    Text(
                      _fmt(v.volume),
                      style: const TextStyle(
                        color: Color(0xFF5E5CE6),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 2),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction.toDouble()),
                    duration: Duration(milliseconds: 400 + i * 60),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, __) => Container(
                      height: (val * 60).clamp(3, 60),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLast ? 'Bu\nhafta' : 'H${i + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isLast
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.25),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _WeekVolume {
  final int weekIndex;
  final double volume;
  _WeekVolume({required this.weekIndex, required this.volume});
}

class _ExercisePR {
  final String name;
  final double maxKg;
  final _Trend trend;
  final List<double> history;
  _ExercisePR({
    required this.name,
    required this.maxKg,
    required this.trend,
    required this.history,
  });
}

enum _Trend { up, down, neutral }
