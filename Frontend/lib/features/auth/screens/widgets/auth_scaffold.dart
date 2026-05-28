import 'dart:math' as math;
import 'dart:ui';
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

  late final AnimationController _starsCtrl;

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
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
          ),
        );
    _pulse = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _starsCtrl = AnimationController(
      duration: const Duration(milliseconds: 4500),
      vsync: this,
    )..repeat(reverse: true);

    _logoAnims = Listenable.merge([_pulseCtrl, _ringCtrl]);
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _starsCtrl.dispose();
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
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Katman 1: siyah zemin ─────────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.3),
                radius: 1.8,
                colors: [
                  Color(0xFF101010),
                  Color(0xFF050505),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),

          // ── Katman 2: çok hafif sıcak alt parıltı ─────────────
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Positioned(
              bottom: -size.height * 0.30,
              left: 0,
              right: 0,
              child: Container(
                height: size.height * 0.75,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _kAccent.withValues(alpha: 0.09 * _pulse.value),
                      _kAccentLight.withValues(alpha: 0.035 * _pulse.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Katman 2b: sağ orta sıcak ışık (sabit) ────────────
          Positioned(
            right: -size.width * 0.25,
            top: size.height * 0.35,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kAccent.withValues(alpha: 0.035),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Katman 3: üst sağ sıcak ışık ──────────────────────
          Positioned(
            top: -size.height * 0.10,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kAccentLight.withValues(alpha: 0.10),
                    _kAccent.withValues(alpha: 0.035),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Katman 3b: üst sol koyu gölge ─────────────────────
          Positioned(
            top: -60,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.025),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Katman 3c: orta yumuşak gölge bandı ───────────────
          Positioned(
            top: size.height * 0.28,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.018),
                    _kAccent.withValues(alpha: 0.018),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Katman 4: arka plan dokusu (çok hafif) ────────────
          Opacity(
            opacity: 0.012,
            child: Image.asset(
              'assets/images/tracking_bg_light.png',
              fit: BoxFit.cover,
            ),
          ),

          // ── Katman 5: animasyonlu yıldız alanı ────────────────
          AnimatedBuilder(
            animation: _starsCtrl,
            builder: (_, _) => CustomPaint(
              size: Size.infinite,
              painter: _StarFieldPainter(progress: _starsCtrl.value),
            ),
          ),

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
                                      angle: _ringCtrl.value * 2 * math.pi,
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
                                shaderCallback: (b) => const LinearGradient(
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

                        // ── Form kartı ───────────────────────
                        FadeTransition(
                          opacity: _formFade,
                          child: SlideTransition(
                            position: _formSlide,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    20,
                                    18,
                                    20,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    color: const Color(
                                      0xFF0E0F13,
                                    ).withValues(alpha: 0.96),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.42,
                                        ),
                                        blurRadius: 34,
                                        spreadRadius: -14,
                                        offset: const Offset(0, 18),
                                      ),
                                      BoxShadow(
                                        color: _kAccent.withValues(alpha: 0.06),
                                        blurRadius: 26,
                                        spreadRadius: -20,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 10,
                                        right: 10,
                                        top: 0,
                                        child: Container(
                                          height: 1,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                _kAccentLight.withValues(
                                                  alpha: 0.26,
                                                ),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      widget.formContent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
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

class _StarData {
  final double x, y, r, phase;
  const _StarData(this.x, this.y, this.r, this.phase);
}

/// Twinkling yıldız alanı
class _StarFieldPainter extends CustomPainter {
  final double progress;

  static final List<_StarData> _stars = _build();

  static List<_StarData> _build() {
    final rng = math.Random(9999);
    return List.generate(
      90,
      (_) => _StarData(
        rng.nextDouble(),
        rng.nextDouble(),
        0.4 + rng.nextDouble() * 1.1,
        rng.nextDouble(),
      ),
    );
  }

  _StarFieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in _stars) {
      final alpha = 0.08 + 0.22 * math.sin((progress + s.phase) * math.pi);
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        paint,
      );
    }
  }

  // Sadece progress 0.5° faz kadar değişince yeniden çiz (~45fps eşdeğeri).
  @override
  bool shouldRepaint(_StarFieldPainter old) =>
      (old.progress - progress).abs() > 0.005;
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
