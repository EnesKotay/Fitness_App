import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuideStep {
  final String emoji;
  final String title;
  final String description;
  /// Opsiyonel ipucu satırı — açıklamanın altında küçük renk kutusu olarak gösterilir
  final String? tip;

  const GuideStep({
    required this.emoji,
    required this.title,
    required this.description,
    this.tip,
  });
}

/// Sayfa rehberini modal olarak gösterir.
/// [pageKey] ile SharedPreferences'tan ilk ziyaret kontrolü yapılır.
/// Otomatik kullanım için [showPageGuideIfNeeded], manuel için [showPageGuide].
class PageGuideOverlay extends StatefulWidget {
  final List<GuideStep> steps;

  const PageGuideOverlay({super.key, required this.steps});

  @override
  State<PageGuideOverlay> createState() => _PageGuideOverlayState();
}

class _PageGuideOverlayState extends State<PageGuideOverlay>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  // Her adım için farklı accent renk
  static const List<Color> _stepColors = [
    Color(0xFF4CAF50),
    Color(0xFF5B9BFF),
    Color(0xFFFFB74D),
    Color(0xFFB388FF),
    Color(0xFF4CD1A3),
    Color(0xFFFF8A65),
    Color(0xFFE57373),
    Color(0xFF81D4FA),
  ];

  Color get _accent =>
      _stepColors[_current % _stepColors.length];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_current < widget.steps.length - 1) {
      _animController.reverse().then((_) {
        if (mounted) {
          setState(() => _current++);
          _animController.forward();
        }
      });
    } else {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    HapticFeedback.selectionClick();
    if (_current > 0) {
      _animController.reverse().then((_) {
        if (mounted) {
          setState(() => _current--);
          _animController.forward();
        }
      });
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_current];
    final isLast = _current == widget.steps.length - 1;

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
          color: Colors.white,
        ),
        child: GestureDetector(
          onTap: _next,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Blur arka plan
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(color: Colors.black.withValues(alpha: 0.74)),
                ),

                // Atla butonu
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 16),
                      child: GestureDetector(
                        onTap: _skip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Atla',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Ana kart
                Center(
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.25),
                              width: 1,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1A2030).withValues(alpha: 0.97),
                                const Color(0xFF0D1018).withValues(alpha: 0.99),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.18),
                                blurRadius: 40,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row: emoji + step badge
                                    Row(
                                      children: [
                                        // Emoji container
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: _accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(
                                              color: _accent.withValues(alpha: 0.28),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _accent.withValues(alpha: 0.2),
                                                blurRadius: 14,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              step.emoji,
                                              style: const TextStyle(
                                                fontSize: 28,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Step counter badge
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 9,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _accent.withValues(
                                                    alpha: 0.15,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  '${_current + 1} / ${widget.steps.length}',
                                                  style: TextStyle(
                                                    color: _accent,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    decoration:
                                                        TextDecoration.none,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              // Başlık
                                              Text(
                                                step.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 18),

                                    // Divider
                                    Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _accent.withValues(alpha: 0.3),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Açıklama
                                    Text(
                                      step.description,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.78),
                                        fontSize: 14.5,
                                        height: 1.6,
                                        fontWeight: FontWeight.w400,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),

                                    // Opsiyonel ipucu
                                    if (step.tip != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                _accent.withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.tips_and_updates_rounded,
                                              color: _accent,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                step.tip!,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.82),
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.4,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 24),

                                    // Alt: Önceki + dot indikatörler + İleri butonu
                                    Row(
                                      children: [
                                        // Önceki butonu
                                        if (_current > 0) ...[
                                          GestureDetector(
                                            onTap: _prev,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.arrow_back_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        // Dot indikatörler
                                        if (widget.steps.length > 1)
                                          Expanded(
                                            child: Row(
                                              children: List.generate(
                                                widget.steps.length,
                                                (i) => AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 250,
                                                  ),
                                                  margin: const EdgeInsets
                                                      .only(right: 5),
                                                  width: i == _current ? 18 : 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(3),
                                                    color: i == _current
                                                        ? _accent
                                                        : Colors.white
                                                            .withValues(
                                                              alpha: 0.22,
                                                            ),
                                                    boxShadow: i == _current
                                                        ? [
                                                            BoxShadow(
                                                              color: _accent
                                                                  .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                              blurRadius: 6,
                                                            ),
                                                          ]
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                        // İleri / Harika! butonu
                                        GestureDetector(
                                          onTap: _next,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 22,
                                              vertical: 11,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  _accent,
                                                  _accent.withValues(alpha: 0.72),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _accent
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 14,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isLast ? 'Anladım!' : 'Sonraki',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    decoration:
                                                        TextDecoration.none,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  isLast
                                                      ? Icons.check_rounded
                                                      : Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 16,
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
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rehberi modal olarak gösterir.
Future<void> showPageGuide(
  BuildContext context, {
  required List<GuideStep> steps,
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, a1, a2) => PageGuideOverlay(steps: steps),
  );
}
