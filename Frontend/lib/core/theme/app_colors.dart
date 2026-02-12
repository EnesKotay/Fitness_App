import 'package:flutter/material.dart';

/// Uyumlu koyu tema paleti: yeşil (primary) + turuncu (secondary) aileleri, soğuk arka plan.
class AppColors {
  // Primary (yeşil) ailesi
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryMuted = Color(0xFF2E7D32); // kart vurgusu için

  // Secondary (turuncu/amber) ailesi
  static const Color secondary = Color(0xFFCC7A4A);
  static const Color secondaryLight = Color(0xFFE0986A);
  static const Color secondaryDark = Color(0xFFB85C2E);
  static const Color secondaryMuted = Color(0xFFCC7A4A);

  // Hedef tamamlandı / başarı vurgusu
  static const Color accentSuccess = Color(0xFF4CAF50);

  // Arka plan (hafif soğuk ton: çok az mavi)
  static const Color background = Color(0xFF0A0B0E);
  static const Color surface = Color(0xFF13161A);
  static const Color surfaceElevated = Color(0xFF1A1E24);
  static const Color surfaceLight = Color(0xFF242830);

  // Premium Dark Theme Backgrounds
  static const Color backgroundDeep = Color(0xFF141619); // Deepest background
  static const Color backgroundCard = Color(0xFF1E1E1E); // Standard card background
  static const Color backgroundLighter = Color(0xFF1A1D21); // Lighter background variant

  // Metin
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x80FFFFFF);

  // Durum
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFED6C02);
  static const Color info = Color(0xFF0288D1);

  // Kenar / ayırıcı
  static const Color border = Color(0x18FFFFFF);
  static const Color divider = Color(0x18FFFFFF);

  // Overlay
  static final Color overlay = Colors.black.withValues(alpha: 0.5);

  // Glassmorphic surfaces (for premium UI)
  static final Color glass = Colors.white.withValues(alpha: 0.05);
  static final Color glassBorder = Colors.white.withValues(alpha: 0.1);
  static final Color glassElevated = Colors.white.withValues(alpha: 0.08);

  // Neon accents (for glow effects)
  static final Color neonGreen = primaryLight.withValues(alpha: 0.3);
  static final Color neonPurple = const Color(0xFF7C4DFF).withValues(alpha: 0.3);
  static final Color neonOrange = secondaryLight.withValues(alpha: 0.3);
  static final Color neonBlue = const Color(0xFF2196F3).withValues(alpha: 0.3);

  const AppColors._();
}
