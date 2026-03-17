import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Scaffold arkası: hafif soğuk ton (üstte çok az mavi/mor) top->bottom gradient.
/// Opsiyonel [imagePath] verilirse arka plan görseli gösterilir, üzerine overlay gradient uygulanır.
/// [lightOverlay] true ise açık arka planlar için daha hafif overlay (görsel daha görünür).
class AppGradientBackground extends StatelessWidget {
  final Widget child;

  /// Opsiyonel: Arka plan görseli yolu (örn: 'assets/images/home_bg.jpg')
  final String? imagePath;

  /// Görsel sığdırma modu (varsayılan: cover).
  final BoxFit imageFit;

  /// Görsel hizalama (varsayılan: center).
  final Alignment imageAlignment;

  /// Açık temalı arka plan için hafif overlay (takip sayfası vb.)
  final bool lightOverlay;

  const AppGradientBackground({
    super.key,
    required this.child,
    this.imagePath,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.center,
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
        Colors.black.withValues(alpha: 0.70), // Even darker
        Colors.black.withValues(alpha: 0.82),
        Colors.black.withValues(alpha: 0.94),
      ];
    } else {
      overlayColors = [
        Colors.black.withValues(alpha: 0.6),
        Colors.black.withValues(alpha: 0.75),
        Colors.black.withValues(alpha: 0.9),
      ];
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: imagePath != null
            ? DecorationImage(
                image: AssetImage(imagePath!),
                fit: imageFit,
                alignment: imageAlignment,
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
