import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  /// Üst kenarda ince aksan çizgisi (primary / secondary).
  final Color? accentColor;
  
  /// Eğer true ise, kart ekrana ilk geldiğinde fade+slide animasyonu çalışır.
  /// Varsayılan false (performans için).
  final bool animateOnAppear;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.accentColor,
    this.animateOnAppear = false,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const radius = 22.0;
    final bg = widget.backgroundColor ?? AppColors.surfaceElevated;
    final hasAccent = widget.accentColor != null;

    final content = Container(
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: _isPressed ? bg.withValues(alpha: 0.98) : bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: _isPressed ? 8 : 14,
            offset: Offset(0, _isPressed ? 2 : 5),
          ),
          if (widget.accentColor != null)
            BoxShadow(
              color: widget.accentColor!.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: hasAccent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 3,
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                widget.child,
              ],
            )
          : widget.child,
    );

    Widget wrapped = widget.onTap != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              borderRadius: BorderRadius.circular(radius),
              splashColor: AppColors.primary.withValues(alpha: 0.08),
              highlightColor: AppColors.primary.withValues(alpha: 0.04),
              child: content,
            ),
          )
        : content;

    // Apply wrapper margin if exists
    if (widget.margin != null) {
      wrapped = Padding(padding: widget.margin!, child: wrapped);
    }

    // Apply animation if requested
    if (widget.animateOnAppear) {
      return wrapped.animate().fadeIn(duration: 220.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
    }

    return wrapped;
  }
}
