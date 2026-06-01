import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/recovery_engine.dart';

class MuscleHeatmapWidget extends StatelessWidget {
  final Map<String, FatigueStatus> fatigueByGroup;

  const MuscleHeatmapWidget({
    Key? key,
    required this.fatigueByGroup,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                color: Colors.cyanAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '3D Kas Isı Haritası',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hangi bölgelerin dinlenmeye ihtiyacı var?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Arka plan neon efekti
                Container(
                  width: 150,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withValues(alpha: 0.1),
                        blurRadius: 60,
                        spreadRadius: 20,
                      )
                    ],
                  ),
                ),
                // Vücut Çizimi
                CustomPaint(
                  size: const Size(200, 250),
                  painter: _HeatmapPainter(fatigueByGroup),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(Colors.cyanAccent, 'Dinlenmiş'),
              const SizedBox(width: 16),
              _buildLegend(Colors.amber, 'Yorgun'),
              const SizedBox(width: 16),
              _buildLegend(Colors.redAccent, 'Tükenmiş'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
              )
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final Map<String, FatigueStatus> fatigueByGroup;

  _HeatmapPainter(this.fatigueByGroup);

  Color _getColorForGroup(String group) {
    final status = fatigueByGroup[group];
    if (status == null) return Colors.cyanAccent.withValues(alpha: 0.3); // Fresh
    
    switch (status.level) {
      case FatigueLevel.fresh:
        return Colors.cyanAccent;
      case FatigueLevel.recovering:
        return Colors.amber;
      case FatigueLevel.fatigued:
        return Colors.redAccent;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Yarı saydam arka plan silüeti (fütüristik body)
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Kafa
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy - 90), width: 40, height: 50),
      bgPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy - 90), width: 40, height: 50),
      borderPaint,
    );

    // Omuzlar (Shoulders)
    _drawGlowingMuscle(
      canvas, 
      Rect.fromCenter(center: Offset(center.dx - 45, center.dy - 40), width: 30, height: 25), 
      _getColorForGroup('SHOULDERS'),
    );
    _drawGlowingMuscle(
      canvas, 
      Rect.fromCenter(center: Offset(center.dx + 45, center.dy - 40), width: 30, height: 25), 
      _getColorForGroup('SHOULDERS'),
    );

    // Göğüs (Chest)
    _drawGlowingMuscle(
      canvas, 
      Rect.fromCenter(center: Offset(center.dx, center.dy - 35), width: 50, height: 40), 
      _getColorForGroup('CHEST'),
    );

    // Kollar (Arms)
    _drawGlowingMuscle(
      canvas, 
      Rect.fromCenter(center: Offset(center.dx - 55, center.dy), width: 20, height: 60), 
      _getColorForGroup('ARMS'),
    );
    _drawGlowingMuscle(
      canvas, 
      Rect.fromCenter(center: Offset(center.dx + 55, center.dy), width: 20, height: 60), 
      _getColorForGroup('ARMS'),
    );

    // Karın (Core)
    _drawGlowingMuscle(
      canvas, 
      Rect.fromCenter(center: Offset(center.dx, center.dy + 15), width: 40, height: 50), 
      _getColorForGroup('CORE'),
    );

    // Bacaklar (Legs)
    _drawGlowingMuscle(
      canvas, 
      Rect.fromCenter(center: Offset(center.dx - 20, center.dy + 75), width: 30, height: 70), 
      _getColorForGroup('LEGS'),
    );
    _drawGlowingMuscle(
      canvas, 
      Rect.fromCenter(center: Offset(center.dx + 20, center.dy + 75), width: 30, height: 70), 
      _getColorForGroup('LEGS'),
    );
  }

  void _drawGlowingMuscle(Canvas canvas, Rect rect, Color color) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    
    // Glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, glowPaint);

    // Fill
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [color.withValues(alpha: 0.8), color.withValues(alpha: 0.3)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return true; // Simple approach for now
  }
}
