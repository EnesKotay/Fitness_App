import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const _kAccentColor = Color(0xFFCC7A4A);

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget formContent;
  final Widget? bottomContent;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formContent,
    this.bottomContent,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomLeft,
                  colors: const [
                    Color(0xFF0B1220),
                    Color(0xFF090E17),
                    Color(0xFF070A11),
                    Color(0xFF120B09),
                  ],
                ),
                image: DecorationImage(
                  image: const AssetImage('assets/images/tracking_bg_light.png'),
                  fit: BoxFit.cover,
                  opacity: 0.05,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.55),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _AuthBackgroundPainter()),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.22),
                    const Color(0xFF38BDF8).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      const Color(0xFF38BDF8).withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD97706).withValues(alpha: 0.2),
                    _kAccentColor.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: 40,
            right: 40,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  colors: [
                    _kAccentColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.16),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: bottomPadding + 24 + viewInsetsBottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      children: [
                        Image.asset(
                          'assets/images/app_icon.png',
                          width: 220,
                          height: 220,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 36,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: formContent,
                        ),
                      ),
                    ),
                    if (bottomContent != null) ...[
                      const SizedBox(height: 20),
                      bottomContent!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bluePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.48, size.height * 0.1),
        Offset(size.width * 0.9, size.height * 0.42),
        [
          const Color(0xFF38BDF8).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final orangePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.05, size.height * 0.72),
        Offset(size.width * 0.52, size.height),
        [
          _kAccentColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final bluePath = Path()
      ..moveTo(size.width * 0.58, 0)
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.2,
        size.width * 0.7,
        size.height * 0.43,
      )
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.55,
        size.width * 0.74,
        size.height * 0.72,
      );
    canvas.drawPath(bluePath, bluePaint);

    final orangePath = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.78,
        size.width * 0.26,
        size.height * 0.92,
      )
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height,
        size.width * 0.56,
        size.height * 0.96,
      );
    canvas.drawPath(orangePath, orangePaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;

    const spacing = 32.0;
    for (double y = size.height * 0.58; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
