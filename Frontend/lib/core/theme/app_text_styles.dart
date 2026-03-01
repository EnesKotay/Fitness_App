import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get _manrope => GoogleFonts.manrope(color: AppColors.textPrimary);

  // Title: 28–32, hero / page title
  static TextStyle get titleLarge => _manrope.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      );
  static TextStyle get titleMedium => _manrope.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      );

  // Section: 16–18, card titles / section headers
  static TextStyle get sectionTitle => _manrope.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
  static TextStyle get sectionSubtitle => _manrope.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  // Body: 13–14
  static TextStyle get bodyLarge => _manrope.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      );
  static TextStyle get bodyMedium => _manrope.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );
  static TextStyle get bodySmall => _manrope.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.35,
      );

  // Labels
  static TextStyle get labelLarge => _manrope.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
  static TextStyle get labelMedium => _manrope.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  // Numbers (tabular figures)
  static TextStyle get numberLarge => _manrope.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimary,
      );
  static TextStyle get numberMedium => _manrope.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimary,
      );
  static TextStyle get numberSmall => _manrope.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimary,
      );

  // Legacy aliases for existing code
  static TextStyle get headlineLarge => titleMedium;
  static TextStyle get headlineMedium => sectionTitle;
  static TextStyle get headlineSmall => sectionSubtitle;
  static TextStyle get numberBig => numberLarge;
}
