import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bir tur adımını tanımlar.
class TourStep {
  /// Vurgulanacak widget'ın GlobalKey'i. null ise merkez kart modu.
  final GlobalKey? targetKey;

  /// Spotlight'ın şekli
  final TourSpotShape spotShape;

  /// Tooltip başlığı
  final String title;

  /// Tooltip açıklaması
  final String description;

  /// Emoji / ikon
  final String emoji;

  /// Tooltip'in hedefin hangi tarafında çıkacağı (null → otomatik)
  final TourTooltipSide? tooltipSide;

  /// Accent renk
  final Color accentColor;

  const TourStep({
    this.targetKey,
    this.spotShape = TourSpotShape.rect,
    required this.title,
    required this.description,
    required this.emoji,
    this.tooltipSide,
    this.accentColor = const Color(0xFF4CAF50),
  });
}

enum TourSpotShape { circle, rect }

enum TourTooltipSide { top, bottom, center }

/// Interaktif spotlight turu overlay widget'ı.
/// Kullanım: [AppTourOverlay.show(context, steps)] ile başlatılır.
class AppTourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback? onComplete;

  const AppTourOverlay({
    super.key,
    required this.steps,
    this.onComplete,
  });

  /// Turu göster. Navigator.of(context).overlay üzerine yüklenir.
  static OverlayEntry show(
    BuildContext context, {
    required List<TourStep> steps,
    VoidCallback? onComplete,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
            color: Colors.white,
            fontFamily: 'sans-serif',
          ),
          child: AppTourOverlay(
            steps: steps,
            onComplete: () {
              entry.remove();
              onComplete?.call();
            },
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  Rect? _spotRect;

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _entryAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureStep());
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _measureStep() {
    final step = widget.steps[_currentStep];
    if (step.targetKey != null) {
      final renderBox =
          step.targetKey!.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final pos = renderBox.localToGlobal(Offset.zero);
        setState(() {
          _spotRect = Rect.fromLTWH(
            pos.dx - 8,
            pos.dy - 6,
            renderBox.size.width + 16,
            renderBox.size.height + 12,
          );
        });
      } else {
        setState(() => _spotRect = null);
      }
    } else {
      setState(() => _spotRect = null);
    }
    _entryCtrl.forward(from: 0);
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_currentStep < widget.steps.length - 1) {
      _entryCtrl.reverse().then((_) {
        if (mounted) {
          setState(() => _currentStep++);
          _measureStep();
        }
      });
    } else {
      _entryCtrl.reverse().then((_) => widget.onComplete?.call());
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_currentStep > 0) {
      _entryCtrl.reverse().then((_) {
        if (mounted) {
          setState(() => _currentStep--);
          _measureStep();
        }
      });
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _entryAnim,
      child: Stack(
        children: [
          // Dimmed overlay with spotlight cutout
          if (_spotRect != null)
            CustomPaint(
              size: size,
              painter: _SpotlightPainter(
                spotRect: _spotRect!,
                shape: step.spotShape,
                pulse: _pulseAnim,
                accentColor: step.accentColor,
              ),
            )
          else
            // Full dim when no target
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(color: Colors.black.withValues(alpha: 0.75)),
            ),

          // Tap on dimmed area → next
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),

          // Tooltip card
          _buildTooltip(step, isLast, size),

          // Skip button
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
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      'Turu Atla',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Step counter (top left)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.steps.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 5),
                      width: i == _currentStep ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _currentStep
                            ? step.accentColor
                            : Colors.white.withValues(alpha: 0.25),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(TourStep step, bool isLast, Size screenSize) {
    // Tooltip pozisyonu: spotlight'ın altında mı, üstünde mi?
    TourTooltipSide side = step.tooltipSide ?? TourTooltipSide.center;
    if (step.tooltipSide == null && _spotRect != null) {
      final centerY = _spotRect!.center.dy;
      side = centerY > screenSize.height * 0.5
          ? TourTooltipSide.top
          : TourTooltipSide.bottom;
    }

    final card = GestureDetector(
      onTap: () {}, // kartın kendisine dokunmayı engelle
      child: ScaleTransition(
        scale: _entryAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A2030).withValues(alpha: 0.97),
                const Color(0xFF0D1018).withValues(alpha: 0.99),
              ],
            ),
            border: Border.all(
              color: step.accentColor.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: step.accentColor.withValues(alpha: 0.15),
                blurRadius: 32,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Emoji badge
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: step.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: step.accentColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              step.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step label
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: step.accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Adım ${_currentStep + 1}/${widget.steps.length}',
                                  style: TextStyle(
                                    color: step.accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                step.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Arrow indicator toward the target
                    if (_spotRect != null)
                      _ArrowHint(side: side, color: step.accentColor),
                    if (_spotRect != null) const SizedBox(height: 10),
                    Text(
                      step.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tap hint
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.32),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Ekrana dokun → devam et',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.32),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Back button
                        if (_currentStep > 0) ...[
                          GestureDetector(
                            onTap: _back,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        // Dot indicators
                        Expanded(
                          child: Row(
                            children: List.generate(widget.steps.length, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(right: 5),
                                width: i == _currentStep ? 16 : 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: i == _currentStep
                                      ? step.accentColor
                                      : Colors.white.withValues(alpha: 0.2),
                                ),
                              );
                            }),
                          ),
                        ),
                        GestureDetector(
                          onTap: _next,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  step.accentColor,
                                  step.accentColor.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: step.accentColor.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isLast ? 'Harika!' : 'Sonraki',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
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
    );

    if (side == TourTooltipSide.top && _spotRect != null) {
      // Kart spotlight'ın üstünde
      final topEdge = _spotRect!.top - 12;
      return Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.of(context).size.height - topEdge,
        child: card,
      );
    } else if (side == TourTooltipSide.bottom && _spotRect != null) {
      // Kart spotlight'ın altında
      final bottomEdge = _spotRect!.bottom + 12;
      return Positioned(
        left: 0,
        right: 0,
        top: bottomEdge,
        child: card,
      );
    } else {
      // Ortada
      return Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.of(context).size.height * 0.12,
        child: card,
      );
    }
  }
}

// ── Arrow hint ──────────────────────────────────────────────────────────────
class _ArrowHint extends StatelessWidget {
  final TourTooltipSide side;
  final Color color;

  const _ArrowHint({required this.side, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDown = side == TourTooltipSide.top; // kart üstte → ok aşağıya
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDown ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: color,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                isDown ? 'Aşağıdaki alana bak' : 'Yukarıdaki alana bak',
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Spotlight painter ────────────────────────────────────────────────────────
class _SpotlightPainter extends CustomPainter {
  final Rect spotRect;
  final TourSpotShape shape;
  final Animation<double> pulse;
  final Color accentColor;

  const _SpotlightPainter({
    required this.spotRect,
    required this.shape,
    required this.pulse,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // BlendMode.clear'ın sadece bu katmanı temizlemesi için saveLayer kullanılmalı.
    // Yoksa iOS Impeller renderer'da alttaki widget'ları da silip siyah yapar.
    canvas.saveLayer(Offset.zero & size, Paint());

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.68);

    // Full dim
    canvas.drawRect(Offset.zero & size, dimPaint);

    // Cut out spotlight
    final spotPath = Path();
    if (shape == TourSpotShape.circle) {
      spotPath.addOval(Rect.fromCircle(
        center: spotRect.center,
        radius: spotRect.longestSide / 2 + 6,
      ));
    } else {
      spotPath.addRRect(RRect.fromRectAndRadius(
        spotRect,
        const Radius.circular(16),
      ));
    }

    canvas.drawPath(
      spotPath,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();

    // Glow ring
    final pulseVal = pulse.value;
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35 - pulseVal * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + pulseVal * 2;

    if (shape == TourSpotShape.circle) {
      canvas.drawCircle(
        spotRect.center,
        spotRect.longestSide / 2 + 8 + pulseVal * 6,
        glowPaint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          spotRect.inflate(6 + pulseVal * 4),
          const Radius.circular(20),
        ),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotRect != spotRect ||
      old.pulse != pulse ||
      old.accentColor != accentColor;
}
