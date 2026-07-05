part of 'ai_coach_screen.dart';

class _AnimatedMeshBackground extends StatefulWidget {
  const _AnimatedMeshBackground();

  @override
  State<_AnimatedMeshBackground> createState() =>
      _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<_AnimatedMeshBackground> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF050814), Color(0xFF09111E), Color(0xFF060A12)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _CoachBackdropPainter(),
            size: Size.infinite,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.12),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.18),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.024);

    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF73D4FF).withValues(alpha: 0.032),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    const spacing = 56.0;
    for (double x = -20; x < size.width + 20; x += spacing) {
      final path = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(x + 18, size.height * 0.35, x - 10, size.height);
      canvas.drawPath(path, linePaint);
    }

    final beamRect = Rect.fromCenter(
      center: Offset(size.width * 0.78, size.height * 0.22),
      width: size.width * 0.28,
      height: size.height * 0.6,
    );
    canvas.drawOval(beamRect, beamPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LimitSheetFeature extends StatelessWidget {
  const _LimitSheetFeature({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: color.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}
