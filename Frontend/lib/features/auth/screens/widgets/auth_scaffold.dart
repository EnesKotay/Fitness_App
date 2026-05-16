import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

const _kAccent = Color(0xFFCC7A4A);
const _kAccentLight = Color(0xFFE8955A);

class AuthScaffold extends StatefulWidget {
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
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _ringCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _pulse;

  // Merged listenable — build içinde değil initState'te oluşturulur
  late final Listenable _logoAnims;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _ringCtrl = AnimationController(
      duration: const Duration(seconds: 14),
      vsync: this,
    )..repeat();

    _logoFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );
    _formFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _logoAnims = Listenable.merge([_pulseCtrl, _ringCtrl]);
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final compact = size.height < 760;
    final logoSize = compact ? 100.0 : 120.0;

    return Scaffold(
      backgroundColor: const Color(0xFF04080F),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Katman 1: temel gradient ──────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, 0.6),
                radius: 1.4,
                colors: [
                  Color(0xFF12100E),
                  Color(0xFF08080D),
                  Color(0xFF04080F),
                ],
              ),
            ),
          ),

          // ── Katman 2: amber zemin parıltısı (animasyonlu) ─────
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Positioned(
              bottom: -size.height * 0.25,
              left: 0,
              right: 0,
              child: Container(
                height: size.height * 0.7,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _kAccent.withValues(alpha: 0.18 * _pulse.value),
                      _kAccentLight.withValues(alpha: 0.06 * _pulse.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Katman 3: üst mavi soğuk ışık ─────────────────────
          Positioned(
            top: -size.height * 0.12,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E3A5F).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Katman 4: arka plan dokusu (çok hafif) ────────────
          Opacity(
            opacity: 0.03,
            child: Image.asset(
              'assets/images/tracking_bg_light.png',
              fit: BoxFit.cover,
            ),
          ),

          // ── Katman 5: nokta grid (alt yarı) ───────────────────
          CustomPaint(painter: _DotGridPainter()),

          // ── Katman 6: içerik ─────────────────────────────────
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 28,
                  right: 28,
                  top: compact ? 24 : 36,
                  bottom: bottomPad + 24 + keyboardH,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Logo ──────────────────────────────
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: AnimatedBuilder(
                              animation: _logoAnims,
                              builder: (_, child) => SizedBox(
                                width: logoSize + 52,
                                height: logoSize + 52,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Dış dönen yay
                                    Transform.rotate(
                                      angle:
                                          _ringCtrl.value * 2 * math.pi,
                                      child: CustomPaint(
                                        size: Size(
                                          logoSize + 48,
                                          logoSize + 48,
                                        ),
                                        painter: _ArcRingPainter(
                                          color: _kAccent,
                                          glowOpacity: _pulse.value,
                                        ),
                                      ),
                                    ),
                                    // Glow hale
                                    Container(
                                      width: logoSize + 32 * _pulse.value,
                                      height: logoSize + 32 * _pulse.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            _kAccent.withValues(
                                              alpha: 0.28 * _pulse.value,
                                            ),
                                            _kAccentLight.withValues(
                                              alpha: 0.1 * _pulse.value,
                                            ),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Logo kendi
                                    child!,
                                  ],
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  logoSize * 0.24,
                                ),
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  width: logoSize,
                                  height: logoSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 28),

                        // ── Başlık ──────────────────────────
                        FadeTransition(
                          opacity: _logoFade,
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (b) =>
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFEDD9C8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(b),
                                child: Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: compact ? 34 : 38,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                widget.subtitle,
                                style: TextStyle(
                                  fontSize: compact ? 13 : 14.5,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  letterSpacing: 0.4,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 32 : 44),

                        // ── Form (kart yok) ─────────────────
                        FadeTransition(
                          opacity: _formFade,
                          child: SlideTransition(
                            position: _formSlide,
                            child: widget.formContent,
                          ),
                        ),

                        if (widget.bottomContent != null) ...[
                          const SizedBox(height: 24),
                          FadeTransition(
                            opacity: _formFade,
                            child: widget.bottomContent!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nokta grid (sadece alt yarıda)
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    const spacing = 30.0;
    final startY = size.height * 0.52;
    for (double y = startY; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Dönen ark halka
class _ArcRingPainter extends CustomPainter {
  final Color color;
  final double glowOpacity;

  const _ArcRingPainter({required this.color, required this.glowOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Kesik çizgili dış halka
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const segments = 20;
    const total = math.pi * 2;
    const dash = total / segments * 0.55;
    const gap = total / segments * 0.45;
    double angle = 0;
    while (angle < total) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        dash,
        false,
        dashPaint,
      );
      angle += dash + gap;
    }

    // Parlak kısa ark (gradient efekti — tek renk yarı-opak)
    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.7 * glowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 0.55,
      false,
      arcPaint,
    );

    // 4 köşe noktası (pusula)
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2 - math.pi / 2;
      final dx = center.dx + radius * math.cos(a);
      final dy = center.dy + radius * math.sin(a);
      canvas.drawCircle(
        Offset(dx, dy),
        2.8,
        Paint()
          ..color = color.withValues(alpha: 0.65 * glowOpacity)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) =>
      old.glowOpacity != glowOpacity || old.color != color;
}
