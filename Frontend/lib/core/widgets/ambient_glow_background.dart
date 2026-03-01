import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';

class AmbientGlowBackground extends StatelessWidget {
  const AmbientGlowBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.3),
                AppColors.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ).animate(
          onPlay: (controller) => controller.repeat(reverse: true),
        ).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.2, 1.2),
          duration: 3000.ms,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
}
