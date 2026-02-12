import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Scaffold arkası: hafif soğuk ton (üstte çok az mavi/mor) top->bottom gradient.
/// Opsiyonel [imagePath] verilirse arka plan görseli gösterilir, üzerine overlay gradient uygulanır.
/// [lightOverlay] true ise açık arka planlar için daha hafif overlay (görsel daha görünür).
class AppGradientBackground extends StatelessWidget {
  final Widget child;
  /// Opsiyonel: Arka plan görseli yolu (örn: 'assets/images/home_bg.jpg')
  final String? imagePath;
  /// Açık temalı arka plan için hafif overlay (takip sayfası vb.)
  final bool lightOverlay;

  const AppGradientBackground({
    super.key,
    required this.child,
    this.imagePath,
    this.lightOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> overlayColors;
    if (imagePath == null) {
      overlayColors = const [
        Color(0xFF0E1014),
        Color(0xFF0A0B0E),
        AppColors.background,
      ];
    } else if (lightOverlay) {
      overlayColors = [
        Colors.black.withValues(alpha: 0.2),
        Colors.black.withValues(alpha: 0.35),
        Colors.black.withValues(alpha: 0.55),
      ];
    } else {
      overlayColors = [
        Colors.black.withValues(alpha: 0.5),
        Colors.black.withValues(alpha: 0.65),
        Colors.black.withValues(alpha: 0.85),
      ];
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: imagePath != null
            ? DecorationImage(
                image: AssetImage(imagePath!),
                fit: BoxFit.cover,
              )
            : null,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: overlayColors,
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: child,
    );
  }
}
