import 'dart:math' as math;
import 'package:flutter/material.dart';

class RestTimerPanel extends StatelessWidget {
  final int restSeconds;
  final int restRemaining;
  final VoidCallback onStopTimer;
  final ValueChanged<int> onRestSecondsSelected;

  const RestTimerPanel({
    super.key,
    required this.restSeconds,
    required this.restRemaining,
    required this.onStopTimer,
    required this.onRestSecondsSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pct = restSeconds > 0 ? restRemaining / restSeconds : 0.0;
    final mins = restRemaining ~/ 60;
    final secs = restRemaining % 60;
    final timeStr = mins > 0
        ? '$mins:${secs.toString().padLeft(2, '0')}'
        : '$secs sn';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha((0.4 * 255).toInt())),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Dinlenme Süresi',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).toInt()),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onStopTimer,
                child: const Icon(Icons.close, color: Colors.white38, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(96, 96),
                    painter: _RestTimerPainter(
                      progress: pct,
                      color: restRemaining < 10 ? Colors.redAccent : Colors.orange,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: restRemaining < 10 ? Colors.redAccent : Colors.orange,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'dinlenme',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.35 * 255).toInt()),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Süre seçenekleri
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [60, 90, 120, 180].map((sec) {
              final sel = restSeconds == sec;
              return GestureDetector(
                onTap: () => onRestSecondsSelected(sec),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.orange.withAlpha((0.2 * 255).toInt())
                        : Colors.white.withAlpha((0.05 * 255).toInt()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? Colors.orange
                          : Colors.white.withAlpha((0.1 * 255).toInt()),
                    ),
                  ),
                  child: Text(
                    sec < 60 ? '${sec}s' : '${sec ~/ 60}dk',
                    style: TextStyle(
                      color: sel ? Colors.orange : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RestTimerPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RestTimerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 6.0;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withAlpha((0.08 * 255).toInt()),
    );

    // Progress arc (sweeps clockwise from top)
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RestTimerPainter old) =>
      old.progress != progress || old.color != color;
}
