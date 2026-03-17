import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/ai_service.dart';
import '../../ai_coach/models/ai_coach_models.dart';

class AiCoachInsightSheet extends StatefulWidget {
  final String question;
  final String goal;

  const AiCoachInsightSheet({
    super.key,
    required this.question,
    required this.goal,
  });

  @override
  State<AiCoachInsightSheet> createState() => _AiCoachInsightSheetState();
}

class _AiCoachInsightSheetState extends State<AiCoachInsightSheet>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  CoachAdviceView? _advice;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardFades = [];
  final List<Animation<Offset>> _cardSlides = [];

  int _tipIndex = 0;
  Timer? _tipTimer;

  static const _tips = [
    'Ölçüm verilerin analiz ediliyor...',
    'Hedeflerin değerlendiriliyor...',
    'Kişisel tavsiyeler hazırlanıyor...',
    'Beslenme önerileri oluşturuluyor...',
    'Son rötuşlar yapılıyor...',
  ];

  @override
  void initState() {
    super.initState();
    _startTipRotation();
    _fetchAdvice();
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _isLoading) {
        setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
      }
    });
  }

  void _initCardAnimations(int count) {
    for (final c in _cardControllers) {
      c.dispose();
    }
    _cardControllers.clear();
    _cardFades.clear();
    _cardSlides.clear();
    for (int i = 0; i < count; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 450));
      _cardControllers.add(ctrl);
      _cardFades
          .add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
              begin: const Offset(0, 0.1), end: Offset.zero)
          .animate(
              CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
    }
  }

  void _playStaggered() async {
    for (int i = 0; i < _cardControllers.length; i++) {
      await Future.delayed(Duration(milliseconds: 120 * i));
      if (mounted) _cardControllers[i].forward();
    }
  }

  Future<void> _fetchAdvice() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _advice = null;
    });
    try {
      final aiService = context.read<AIService>();
      final result = await aiService.getTrackingAdvice(
        goal: widget.goal,
        question: widget.question,
      );
      if (!mounted) return;
      final count = (result.focus.isNotEmpty ? 1 : 0) +
          (result.actions.isNotEmpty ? 1 : 0) +
          (result.nutritionNote.isNotEmpty ? 1 : 0);
      _initCardAnimations(count);
      setState(() {
        _advice = result;
        _isLoading = false;
      });
      _tipTimer?.cancel();
      _playStaggered();
    } catch (e) {
      if (mounted) {
        _tipTimer?.cancel();
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_advice == null) return;
    final buf = StringBuffer();
    if (_advice!.focus.isNotEmpty) buf.writeln('ODAK\n${_advice!.focus}\n');
    if (_advice!.actions.isNotEmpty) {
      buf.writeln('YAPILACAKLAR');
      for (int i = 0; i < _advice!.actions.length; i++) {
        buf.writeln('${i + 1}. ${_advice!.actions[i]}');
      }
      buf.writeln();
    }
    if (_advice!.nutritionNote.isNotEmpty) {
      buf.writeln('BESLENME\n${_advice!.nutritionNote}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Analiz panoya kopyalandı'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F14),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildHeader(),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.auto_awesome,
                color: AppColors.primaryLight, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI İlerleme Analizi',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Ölçümlerine göre kişisel analiz',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (_advice != null)
            _iconBtn(Icons.copy_rounded, _copyToClipboard),
          const SizedBox(width: 6),
          _iconBtn(Icons.close_rounded, () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: Colors.white38, size: 17),
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.07),
                  ),
                ),
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                  ),
                ),
                const Icon(Icons.auto_awesome,
                    color: AppColors.primaryLight, size: 20),
              ],
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                _tips[_tipIndex],
                key: ValueKey(_tipIndex),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu işlem ~10 saniye sürebilir',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final active = i == _tipIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 18),
            const Text('Analiz alınamadı',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fetchAdvice,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_advice == null) return const SizedBox.shrink();
    int idx = 0;
    final widgets = <Widget>[];

    if (_advice!.focus.isNotEmpty) {
      widgets.add(_animated(idx++, _FocusCard(text: _advice!.focus)));
    }
    if (_advice!.actions.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(_animated(idx++, _ActionsCard(items: _advice!.actions)));
    }
    if (_advice!.nutritionNote.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(
          _animated(idx++, _NutritionCard(text: _advice!.nutritionNote)));
    }

    widgets.add(const SizedBox(height: 20));
    widgets.add(_buildRefreshFooter());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _animated(int i, Widget child) {
    if (i >= _cardFades.length) return child;
    return FadeTransition(
      opacity: _cardFades[i],
      child: SlideTransition(position: _cardSlides[i], child: child),
    );
  }

  Widget _buildRefreshFooter() {
    return Center(
      child: TextButton.icon(
        onPressed: _fetchAdvice,
        icon: const Icon(Icons.refresh_rounded, size: 15),
        label: const Text('Yeni Analiz Al'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white24,
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ── Focus Card ────────────────────────────────────────────────────────────────

class _FocusCard extends StatefulWidget {
  final String text;
  const _FocusCard({required this.text});
  @override
  State<_FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<_FocusCard> {
  bool _expanded = false;
  static const _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lightbulb_rounded,
                      color: AppColors.primaryLight, size: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Odak Noktası',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              widget.text,
              maxLines: _expanded ? null : _maxLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFDDDDDD),
                fontSize: 14,
                height: 1.65,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          // Expand button — only if text would overflow
          LayoutBuilder(builder: (ctx, constraints) {
            final tp = TextPainter(
              text: TextSpan(
                  text: widget.text,
                  style: const TextStyle(fontSize: 14, height: 1.65)),
              maxLines: _maxLines,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth - 32);
            final overflows = tp.didExceedMaxLines;
            if (!overflows && !_expanded) return const SizedBox(height: 14);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Daha az göster' : 'Devamını gör',
                  style: TextStyle(
                    color: AppColors.primaryLight.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Actions Card ──────────────────────────────────────────────────────────────

class _ActionsCard extends StatelessWidget {
  final List<String> items;
  const _ActionsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131820),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.checklist_rounded,
                      color: Color(0xFF30D158), size: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Yapılacaklar',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${items.length} adım',
                    style: const TextStyle(
                        color: Color(0xFF30D158),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Items
          ...items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(
              children: [
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.white.withValues(alpha: 0.05)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: 12, top: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            color: Color(0xFFB0B8C8),
                            fontSize: 13.5,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLast) const SizedBox(height: 2),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Nutrition Card ────────────────────────────────────────────────────────────

class _NutritionCard extends StatefulWidget {
  final String text;
  const _NutritionCard({required this.text});
  @override
  State<_NutritionCard> createState() => _NutritionCardState();
}

class _NutritionCardState extends State<_NutritionCard> {
  bool _expanded = false;
  static const _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1408),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFF9F0A).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant_rounded,
                      color: Color(0xFFFF9F0A), size: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Beslenme Notu',
                  style: TextStyle(
                      color: Color(0xFFFF9F0A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              widget.text,
              maxLines: _expanded ? null : _maxLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB0A898),
                fontSize: 13.5,
                height: 1.65,
              ),
            ),
          ),
          LayoutBuilder(builder: (ctx, constraints) {
            final tp = TextPainter(
              text: TextSpan(
                  text: widget.text,
                  style: const TextStyle(fontSize: 13.5, height: 1.65)),
              maxLines: _maxLines,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth - 32);
            final overflows = tp.didExceedMaxLines;
            if (!overflows && !_expanded) return const SizedBox(height: 14);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Daha az göster' : 'Devamını gör',
                  style: const TextStyle(
                    color: Color(0xFFFF9F0A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
