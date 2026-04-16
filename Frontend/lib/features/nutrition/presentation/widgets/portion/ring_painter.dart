import 'dart:math' as math;
import 'package:flutter/material.dart';

class RingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double glowOpacity;

  const RingPainter({
    required this.color,
    this.strokeWidth = 3,
    this.glowOpacity = 0.12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Glow
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: glowOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Arc (270°)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.glowOpacity != glowOpacity || old.color != color;
}
