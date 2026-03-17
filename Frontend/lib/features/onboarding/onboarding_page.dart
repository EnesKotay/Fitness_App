import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/storage_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pro_badge.dart';
import '../auth/providers/auth_provider.dart';

/// İlk kullanım rehberi — 4 slide halinde uygulamayı tanıtır.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final _slides = const [
    _SlideData(
      icon: Icons.restaurant_menu_rounded,
      iconColor: Color(0xFF4CD1A3),
      title: 'Beslenme Takibi',
      subtitle:
          'Yemek ara, barkod okut veya kendi besinini ekle. Günlük kalori ve makroları hızlıca takip et.',
      highlights: ['Yemek arama', 'Barkod tarama', 'Hızlı porsiyon ekleme'],
      note: 'Temel takip araçları ücretsiz.',
    ),
    _SlideData(
      icon: Icons.smart_toy_rounded,
      iconColor: Color(0xFF5B9BFF),
      title: 'AI ile Daha Akıllı',
      subtitle:
          'AI koç ile günlük yönlendirme al. Ücretsiz kullanıcılar sınırlı deneyebilir, premium ile tüm AI araçları açılır.',
      highlights: ['AI koç', 'Beslenme asistanı', 'Akıllı öneriler'],
      note: 'AI koçta günlük ücretsiz deneme hakkın var.',
    ),
    _SlideData(
      icon: Icons.camera_alt_rounded,
      iconColor: Color(0xFFFFB74D),
      title: 'Kamera ve Premium Araçlar',
      subtitle:
          'Besin etiketi tara, yemek fotoğrafı analizi yap, beslenme trendlerini incele ve akıllı tarifler oluştur.',
      highlights: ['Etiket tarama', 'Yemek fotoğrafı', 'Trendler ve tarifler'],
      note: 'Bu gelişmiş araçlar premium ile açılır.',
      showProBadge: true,
    ),
    _SlideData(
      icon: Icons.rocket_launch_rounded,
      iconColor: Color(0xFFB388FF),
      title: 'Hazırsın!',
      subtitle:
          'Profilini ayarla, hedefini seç ve uygulamayı kendi ritmine göre kişiselleştir. Sonrasında ana ekrana geçeceğiz.',
      highlights: ['Hedef belirleme', 'Kişisel plan', 'Hemen başla'],
      note: 'Kurulum 1 dakikadan kısa sürer.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    await StorageHelper.saveOnboardingDone(true);
    if (!mounted) return;
    final isLoggedIn = context.read<AuthProvider>().isAuthenticated;
    Navigator.of(context).pushReplacementNamed(
      isLoggedIn ? '/home' : '/profile-setup',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Arka plan gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  AppColors.background.withValues(alpha: 0.95),
                  const Color(0xFF0A1628),
                ],
              ),
            ),
          ),

          // Sayfalar
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return _buildSlide(slide);
            },
          ),

          // Alt kısım: noktalar + butonlar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.only(
                    left: 32,
                    right: 32,
                    top: 24,
                    bottom: MediaQuery.of(context).padding.bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sayfa noktaları
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? _slides[_currentPage].iconColor
                                  : Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Butonlar
                      Row(
                        children: [
                          // Atla
                          if (!isLast)
                            TextButton(
                              onPressed: _completeOnboarding,
                              child: Text(
                                'Atla',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 60),

                          const Spacer(),

                          // İleri / Başla
                          GestureDetector(
                            onTap: () {
                              if (isLast) {
                                _completeOnboarding();
                              } else {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: EdgeInsets.symmetric(
                                horizontal: isLast ? 32 : 24,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _slides[_currentPage].iconColor,
                                    _slides[_currentPage].iconColor.withValues(
                                      alpha: 0.7,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _slides[_currentPage].iconColor
                                        .withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isLast ? 'Başla' : 'İleri',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isLast
                                        ? Icons.arrow_forward_rounded
                                        : Icons.chevron_right_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // İkon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: slide.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: slide.iconColor.withValues(alpha: 0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.iconColor.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(slide.icon, size: 52, color: slide.iconColor),
          ),
          const SizedBox(height: 48),

          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  slide.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (slide.showProBadge) ...[
                const SizedBox(width: 10),
                const ProBadge(compact: true),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Alt başlık
          Text(
            slide.subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: slide.highlights
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: slide.iconColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  slide.showProBadge
                      ? Icons.workspace_premium_rounded
                      : Icons.check_circle_rounded,
                  size: 18,
                  color: slide.iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    slide.note,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<String> highlights;
  final String note;
  final bool showProBadge;

  const _SlideData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.highlights,
    required this.note,
    this.showProBadge = false,
  });
}
