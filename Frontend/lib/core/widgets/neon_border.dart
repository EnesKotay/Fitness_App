import 'package:flutter/material.dart';

/// Animated neon border effect for premium UI elements
class NeonBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double width;
  final double glowIntensity;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  const NeonBorder({
    super.key,
    required this.child,
    required this.color,
    this.width = 1.5,
    this.glowIntensity = 0.3,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: width,
        ),
        boxShadow: [
          // Inner glow
          BoxShadow(
            color: color.withValues(alpha: glowIntensity),
            blurRadius: 12,
            spreadRadius: -2,
          ),
          // Outer glow
          BoxShadow(
            color: color.withValues(alpha: glowIntensity * 0.5),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
