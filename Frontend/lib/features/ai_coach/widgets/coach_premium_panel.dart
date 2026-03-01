import 'package:flutter/material.dart';

class CoachPremiumPanel extends StatelessWidget {
  const CoachPremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.baseColor = const Color(0xFF121A2E),
    this.edgeColor = const Color(0xFF34466D),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color baseColor;
  final Color edgeColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.96),
            const Color(0xFF0F1528).withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(color: edgeColor.withValues(alpha: 0.62)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF090D18).withValues(alpha: 0.75),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFEFB956).withValues(alpha: 0.08),
            blurRadius: 26,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            right: 18,
            top: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFFEAC37A).withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
