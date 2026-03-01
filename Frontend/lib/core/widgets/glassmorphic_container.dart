import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Reusable glassmorphic container widget for modern, premium UI
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.padding,
    this.borderWidth = 1.0,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
            borderRadius: borderRadius ?? BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.1),
              width: borderWidth,
            ),
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
