import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/storage_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pro_badge.dart';
import '../auth/providers/auth_provider.dart';

// Sağa kaydır ipucu animasyonu — yalnızca ilk slaytta gösterilir
class _SwipeHint extends StatefulWidget {
  const _SwipeHint({required this.accentColor});
  final Color accentColor;

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: false);

    _slide = Tween<double>(
      begin: 0,
      end: 18,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Opacity(
        opacity: _fade.value * 0.65,
        child: Transform.translate(
          offset: Offset(_slide.value, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swipe_right_alt_rounded,
                size: 18,
                color: widget.accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Kaydırarak ilerle',
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yeni kayıt olan kullanıcılara 1 kere gösterilen premium uygulama tur rehberi.
class OnboardingPage extends StatefulWidget {
  /// [isNewUserTour] = true → kayıt sonrası gösterilir, tamamlanınca [onDone] çağrılır.
  /// [isNewUserTour] = false → uygulama kurulumunda gösterilir (eski akış).
  final bool isNewUserTour;
  final VoidCallback? onDone;

  const OnboardingPage({super.key, this.isNewUserTour = false, this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _isAnimating = false;

  late final AnimationController _bgAnimController;
  late final AnimationController _particleController;
  late final Animation<double> _bgAnim;

  List<_SlideData> get _slides => [
    const _SlideData(
      gradientColors: [Color(0xFF0D3B2E), Color(0xFF0A1628)],
      accentColor: Color(0xFF4CD1A3),
      icon: Icons.restaurant_menu_rounded,
      emoji: '🥗',
      title: 'Beslenme Takibi',
      subtitle:
          'Yüzlerce Türk ve dünya yemeği arasından ara, barkod okut veya kendi besinini ekle. Kalori ve makroları saniyeler içinde takip et.',
      features: [
        _FeatureItem(icon: Icons.search_rounded, label: 'Akıllı yemek arama'),
        _FeatureItem(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Barkod tarayıcı',
        ),
        _FeatureItem(icon: Icons.bolt_rounded, label: 'Hızlı porsiyon ekleme'),
        _FeatureItem(icon: Icons.water_drop_rounded, label: 'Su takibi'),
      ],
      note: '✅  Tüm temel takip araçları ücretsiz.',
      nextStepLabel: 'İlk iş: günlük öğünlerini veya su tüketimini kaydet.',
    ),
    const _SlideData(
      gradientColors: [Color(0xFF0D1F3B), Color(0xFF0A1628)],
      accentColor: Color(0xFF5B9BFF),
      icon: Icons.smart_toy_rounded,
      emoji: '🤖',
      title: 'AI Koç ile Daha Akıllı',
      subtitle:
          'Adaptif öğrenme sistemi, haftalık performans raporları, akıllı hedef tahminleri ve motivasyon analizi ile tamamen kişiselleşmiş rehberlik.',
      features: [
        _FeatureItem(icon: Icons.school_rounded, label: 'Adaptif öğrenme sistemi'),
        _FeatureItem(
          icon: Icons.calendar_view_week_rounded,
          label: 'Haftalık performans raporu',
        ),
        _FeatureItem(
          icon: Icons.timeline_rounded,
          label: 'Akıllı hedef tahminleri',
        ),
        _FeatureItem(icon: Icons.psychology_alt_rounded, label: 'Motivasyon analizi'),
      ],
      note: '🎁  Günlük ücretsiz deneme hakkın var.',
      nextStepLabel: 'AI koça girip günlük öneri iste, adaptif öğrenme seni tanısın.',
    ),
    const _SlideData(
      gradientColors: [Color(0xFF2B1F0D), Color(0xFF0A1628)],
      accentColor: Color(0xFFFFB74D),
      icon: Icons.camera_alt_rounded,
      emoji: '📸',
      title: 'Kamera & Tarif Araçları',
      subtitle:
          'Yemeğini fotoğrafla, besin etiketini tara. Gelişmiş AI görsel analizi ile Türk mutfağı dahil tüm yemekleri saniyeler içinde tanı.',
      features: [
        _FeatureItem(
          icon: Icons.document_scanner_rounded,
          label: 'Etiket OCR tarama',
        ),
        _FeatureItem(
          icon: Icons.image_search_rounded,
          label: 'Gelişmiş görsel analiz',
        ),
        _FeatureItem(icon: Icons.bar_chart_rounded, label: 'Haftalık trendler'),
        _FeatureItem(
          icon: Icons.menu_book_rounded,
          label: 'AI tarif önerileri',
        ),
      ],
      note: '⭐  Premium ile tüm kamera araçları ve gelişmiş AI analizi açılır.',
      showProBadge: true,
      nextStepLabel: 'Araçlar sekmesinde barkod ve görsel taramayı dene.',
    ),
    const _SlideData(
      gradientColors: [Color(0xFF1A0D2B), Color(0xFF0A1628)],
      accentColor: Color(0xFFB388FF),
      icon: Icons.fitness_center_rounded,
      emoji: '💪',
      title: 'Antrenman Takibi',
      subtitle:
          'Egzersizlerini kaydet, ilerlemeni takip et ve günlük görevlerinle motivasyonunu yüksek tut.',
      features: [
        _FeatureItem(
          icon: Icons.sports_gymnastics_rounded,
          label: '500+ egzersiz rehberi',
        ),
        _FeatureItem(
          icon: Icons.calendar_today_rounded,
          label: 'Antrenman planı',
        ),
        _FeatureItem(
          icon: Icons.emoji_events_rounded,
          label: 'Başarı rozetleri',
        ),
        _FeatureItem(icon: Icons.checklist_rounded, label: 'Günlük görevler'),
      ],
      note: '🏆  Antrenman takibi tamamen ücretsiz.',
      nextStepLabel: 'Bir antrenman ekleyip günlük görevlerle serini başlat.',
    ),
    _SlideData(
      gradientColors: const [Color(0xFF0D2014), Color(0xFF0A1628)],
      accentColor: const Color(0xFF4CAF50),
      icon: Icons.rocket_launch_rounded,
      emoji: '🚀',
      title: 'Her Şey Hazır!',
      subtitle: widget.isNewUserTour
          ? 'Şimdi birkaç küçük adımda profilini tamamlayıp PusulaFit\'i sana göre kişiselleştireceğiz.'
          : 'Profilini oluştur, hedefini seç ve PusulaFit\'i kendi ritmine göre kişiselleştir. Sağlıklı yaşam yolculuğun başlıyor!',
      features: const [
        _FeatureItem(icon: Icons.person_rounded, label: 'Kişisel profil kur'),
        _FeatureItem(icon: Icons.flag_rounded, label: 'Hedef belirle'),
        _FeatureItem(icon: Icons.tune_rounded, label: 'Planını özelleştir'),
        _FeatureItem(icon: Icons.star_rounded, label: 'Hemen başla'),
      ],
      note: widget.isNewUserTour
          ? '⚡  Bu tur yalnızca yeni hesabın için 1 kez gösterilir.'
          : '⚡  Kurulum sadece 1 dakika sürer.',
      nextStepLabel: widget.isNewUserTour
          ? 'Sonraki adımda profilini tamamlayıp ana ekrana geçeceksin.'
          : 'Sonraki adımda giriş yapıp uygulamayı keşfetmeye başlayacaksın.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _bgAnim = CurvedAnimation(
      parent: _bgAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _bgAnimController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    if (widget.isNewUserTour) {
      await StorageHelper.saveAppTourSeen(true);
      await StorageHelper.savePendingAppTour(false);
      if (!mounted) return;
      widget.onDone?.call();
    } else {
      await StorageHelper.saveOnboardingDone(true);
      if (!mounted) return;
      final isLoggedIn = context.read<AuthProvider>().isAuthenticated;
      Navigator.of(
        context,
      ).pushReplacementNamed(isLoggedIn ? '/home' : '/login');
    }
  }

  void _nextPage() {
    if (_isAnimating) return;
    HapticFeedback.selectionClick();
    if (_currentPage < _slides.length - 1) {
      _isAnimating = true;
      _controller
          .nextPage(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
          )
          .then((_) => _isAnimating = false);
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (context2, child2) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      slide.gradientColors[0],
                      slide.gradientColors[1],
                      _bgAnim.value,
                    )!,
                    AppColors.background,
                    const Color(0xFF050810),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Floating particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context3, child3) => CustomPaint(
              size: Size.infinite,
              painter: _ParticlePainter(
                progress: _particleController.value,
                color: slide.accentColor,
              ),
            ),
          ),

          // Page content
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _currentPage = i);
            },
            itemBuilder: (context, index) => _buildSlide(_slides[index]),
          ),

          // Bottom bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(slide, isLast),
          ),

          // Skip button (top right)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 16),
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: TextButton(
                    onPressed: isLast ? null : _complete,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Atla',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
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

  Widget _buildSlide(_SlideData slide) {
    final isNewUserTour = widget.isNewUserTour;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 1),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: slide.accentColor.withValues(alpha: 0.26),
                  ),
                ),
                child: Text(
                  isNewUserTour ? 'Yeni Kullanıcı Turu' : 'Hızlı Başlangıç',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Emoji + Icon container
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow ring
                  AnimatedBuilder(
                    animation: _bgAnim,
                    builder: (ctx, ch) => Container(
                      width: 140 + 20 * _bgAnim.value,
                      height: 140 + 20 * _bgAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            slide.accentColor.withValues(alpha: 0.18),
                            slide.accentColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Icon circle
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: slide.accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: slide.accentColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: slide.accentColor.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        slide.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Title
            Row(
              children: [
                Flexible(
                  child: Text(
                    slide.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: slide.accentColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                if (slide.showProBadge) ...[
                  const SizedBox(width: 10),
                  const ProBadge(compact: true),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // Subtitle
            Text(
              slide.subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.55,
              ),
            ),

            const SizedBox(height: 28),

            // Feature chips grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: slide.features
                  .map(
                    (f) =>
                        _FeatureChip(item: f, accentColor: slide.accentColor),
                  )
                  .toList(),
            ),

            const SizedBox(height: 20),

            // Note card
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: slide.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: slide.accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    slide.note,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.flag_circle_rounded,
                    color: slide.accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      slide.nextStepLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Swipe hint — yalnızca ilk slayta gösterilir
            if (_currentPage == 0) ...[
              const SizedBox(height: 14),
              Center(child: _SwipeHint(accentColor: slide.accentColor)),
            ],

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(_SlideData slide, bool isLast) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            left: 28,
            right: 28,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Adım ${_currentPage + 1}/${_slides.length}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.isNewUserTour
                        ? 'Bu tur yalnızca 1 kez gösterilir'
                        : 'İstediğin zaman geçebilirsin',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.46),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Step indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final isActive = i == _currentPage;
                  return GestureDetector(
                    onTap: () {
                      if (!_isAnimating) {
                        _isAnimating = true;
                        _controller
                            .animateToPage(
                              i,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                            )
                            .then((_) => _isAnimating = false);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isActive
                            ? slide.accentColor
                            : Colors.white.withValues(alpha: 0.18),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: slide.accentColor.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  // Back / skip area
                  if (_currentPage > 0)
                    GestureDetector(
                      onTap: () {
                        if (!_isAnimating) {
                          _isAnimating = true;
                          HapticFeedback.selectionClick();
                          _controller
                              .previousPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubic,
                              )
                              .then((_) => _isAnimating = false);
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 18,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),

                  const SizedBox(width: 12),

                  // Main CTA button
                  Expanded(
                    child: GestureDetector(
                      onTap: _nextPage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              slide.accentColor,
                              slide.accentColor.withValues(alpha: 0.75),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: slide.accentColor.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Haydi Başlayalım!' : 'Devam Et',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature chip ─────────────────────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final _FeatureItem item;
  final Color accentColor;

  const _FeatureChip({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: accentColor, size: 14),
          const SizedBox(width: 7),
          Text(
            item.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Particle painter ──────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  static const int _count = 18;

  const _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(42);

    for (int i = 0; i < _count; i++) {
      final seed = i / _count;
      final speed = 0.3 + rng.nextDouble() * 0.5;
      final offset = (progress * speed + seed) % 1.0;

      final x = (rng.nextDouble() * size.width);
      final startY = size.height * 1.1;
      final endY = -size.height * 0.1;
      final y = startY + (endY - startY) * offset;

      final radius = 1.5 + rng.nextDouble() * 2.5;
      final alpha = (1.0 - (offset - 0.5).abs() * 2).clamp(0.0, 1.0);

      paint.color = color.withValues(alpha: alpha * 0.18);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress || old.color != color;
}

// ── Data classes ──────────────────────────────────────────────────────────────
class _SlideData {
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final List<_FeatureItem> features;
  final String note;
  final String nextStepLabel;
  final bool showProBadge;

  const _SlideData({
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.note,
    required this.nextStepLabel,
    this.showProBadge = false,
  });
}

class _FeatureItem {
  final IconData icon;
  final String label;

  const _FeatureItem({required this.icon, required this.label});
}
