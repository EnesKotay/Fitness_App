import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Circular goal progress widget.
/// Shows current weight vs target weight as an animated arc.
class CircularGoalProgress extends StatefulWidget {
  final double current;
  final double target;
  final double? start;
  final double size;

  const CircularGoalProgress({
    super.key,
    required this.current,
    required this.target,
    this.start,
    this.size = 140,
  });

  @override
  State<CircularGoalProgress> createState() => _CircularGoalProgressState();
}

class _CircularGoalProgressState extends State<CircularGoalProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  double get _progress {
    final s = widget.start ?? widget.current;
    final total = (s - widget.target).abs();
    if (total < 0.01) return 1.0;
    // Yön kontrolü: hedefe yaklaşıyorsa say, uzaklaşıyorsa 0
    final double done;
    if (_goingDown) {
      // Kilo verme hedefi: s > target, current azalmalı
      done = (s - widget.current).clamp(0.0, total);
    } else {
      // Kilo alma hedefi: s < target, current artmalı
      done = (widget.current - s).clamp(0.0, total);
    }
    return done / total;
  }

  bool get _goalReached => (widget.current - widget.target).abs() < 0.1;
  bool get _goingDown => widget.target < (widget.start ?? widget.current);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _goalReached
        ? AppColors.success
        : _goingDown
            ? const Color(0xFF48BB78)
            : const Color(0xFF64D2FF);

    final diff = (widget.current - widget.target).abs();
    final diffStr = diff < 0.1
        ? '🎯 Hedefe ulaştın!'
        : '${diff.toStringAsFixed(1)} kg kaldı';

    final startVal = widget.start;
    final alreadyLost = startVal != null
        ? (startVal - widget.current).abs()
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => CustomPaint(
              painter: _ArcPainter(
                progress: _progress * _anim.value,
                color: color,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                strokeWidth: 10,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_goalReached)
                      const Icon(Icons.emoji_events_rounded,
                          color: AppColors.success, size: 28)
                    else ...[
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'tamamlandı',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          diffStr,
          style: TextStyle(
            color: _goalReached ? AppColors.success : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Hedef: ${widget.target.toStringAsFixed(1)} kg',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 12,
          ),
        ),
        if (startVal != null && !_goalReached && alreadyLost != null && alreadyLost > 0.05) ...[
          const SizedBox(height: 2),
          Text(
            'Başlangıç: ${startVal.toStringAsFixed(1)} kg · ${alreadyLost.toStringAsFixed(1)} kg gitti',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    const startAngle = -pi * 0.75;
    const sweepAngle = pi * 1.5;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle * progress,
        colors: [color.withValues(alpha: 0.6), color],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Glow paint
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    if (progress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        glowPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}
