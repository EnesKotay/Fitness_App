import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../domain/entities/food_item.dart';
import '../../state/diet_provider.dart';
import '../../../../../../core/theme/app_colors.dart';

class PortionUtils {
  static String formatGrams(double grams) {
    final rounded = grams.roundToDouble();
    if ((grams - rounded).abs() < 0.05) {
      return '${rounded.toInt()} g';
    }
    return '${grams.toStringAsFixed(1).replaceAll('.', ',')} g';
  }

  static String cleanServingLabel(String raw) {
    var label = raw.trim();
    label = label.replaceAll(RegExp(r'\s+'), ' ');
    label = label.replaceAllMapped(
      RegExp(r'(\d+)\.(\d+)'),
      (match) => '${match.group(1)},${match.group(2)}',
    );
    label = label.replaceAll(
      RegExp(r'\s*\((?:yaklaşık|yaklasik)?\s*\d+(?:[.,]\d+)?\s*g\)\s*', caseSensitive: false),
      '',
    );
    label = label.replaceAll(
      RegExp(r'\s*\((?:yaklaşık|yaklasik)?\s*\d+(?:[.,]\d+)?\s*gram\)\s*', caseSensitive: false),
      '',
    );
    return label.trim();
  }

  static String capitalizeServing(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String displayServingLabel(String raw) {
    final cleaned = cleanServingLabel(raw);
    final lower = cleaned.toLowerCase();
    if (lower == '1 porsiyon' || lower == 'porsiyon') return 'Standart porsiyon';
    return capitalizeServing(cleaned);
  }

  static String unit(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('çay bardağı')) return 'Çay Bardağı';
    if (lower.contains('su bardağı')) return 'Su Bardağı';
    if (lower.contains('çorba kaşığı')) return 'Çorba K.';
    if (lower.contains('tatlı kaşığı')) return 'Tatlı K.';
    if (lower.contains('çay kaşığı')) return 'Çay K.';
    if (lower.contains('tabak')) return 'Tabak';
    if (lower.contains('kase')) return 'Kase';
    if (lower.contains('adet')) return 'Adet';
    if (lower.contains('dilim')) return 'Dilim';
    if (lower.contains('bardak')) return 'Bardak';
    if (lower.contains('avuç')) return 'Avuç';
    if (lower.contains('demet')) return 'Demet';
    return 'Porsiyon';
  }

  static IconData servingIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('çay bardağı')) return Icons.local_cafe_rounded;
    if (lower.contains('su bardağı')) return Icons.local_drink_rounded;
    if (lower.contains('çorba kaşığı')) return Icons.soup_kitchen_rounded;
    if (lower.contains('tatlı kaşığı') || lower.contains('çay kaşığı')) return Icons.restaurant_rounded;
    if (lower.contains('adet')) return Icons.egg_alt_rounded;
    if (lower.contains('tabak') || lower.contains('dinner')) return Icons.dinner_dining_rounded;
    if (lower.contains('kase')) return Icons.ramen_dining_rounded;
    if (lower.contains('dilim')) return Icons.cake_rounded;
    if (lower.contains('bardak')) return Icons.local_drink_rounded;
    if (lower.contains('avuç')) return Icons.back_hand_rounded;
    if (lower.contains('porsiyon')) return Icons.restaurant_rounded;
    return Icons.restaurant_menu_rounded;
  }

  static String displayPresetTitle(String raw, FoodItem food) {
    var cleaned = cleanServingLabel(raw);
    final smartUnit = DietProvider.getSmartUnit(food.name, food.category);
    
    // Porsiyon kelimesini her zaman akıllı birimle (Tabak/Kase/Adet) değiştir
    cleaned = cleaned.replaceAll(RegExp('porsiyon', caseSensitive: false), capitalizeServing(smartUnit));

    final lower = cleaned.toLowerCase();
    if (lower == '1 ${smartUnit.toLowerCase()}' || lower == smartUnit.toLowerCase()) {
      return '1 ${capitalizeServing(smartUnit)}';
    }
    return capitalizeServing(cleaned);
  }

  static String humanPresetSubtitle(String label, double grams, FoodItem food) {
    final cleanLabel = label.toLowerCase();
    if (cleanLabel.startsWith('yarım ')) {
      return '${formatGrams(grams)} • daha hafif seçenek';
    }
    if (cleanLabel.startsWith('1,5 ')) {
      return '${formatGrams(grams)} • biraz daha doyurucu';
    }
    if (cleanLabel.startsWith('2 ')) {
      return '${formatGrams(grams)} • büyük porsiyon';
    }
    return '${formatGrams(grams)} • ${((food.kcalPer100g * grams) / 100).round()} kcal';
  }

  static List<(String, IconData, double)> buildUserFriendlyPresets(FoodItem food, double defaultPortionGrams) {
    final smartUnit = DietProvider.getSmartUnit(food.name, food.category);
    final Map<int, (String, IconData, double)> presetsByGram = {};

    void addPreset(String label, IconData icon, double grams) {
      if (grams <= 0) return;
      
      // Check for duplicate grams (within 3g margin)
      bool exists = false;
      for (final key in presetsByGram.keys) {
        if ((key - grams).abs() <= 3) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        presetsByGram[grams.round()] = (label, icon, grams);
      }
    }

    String replacePorsiyon(String original) {
      return original.replaceAll(RegExp('porsiyon', caseSensitive: false), capitalizeServing(smartUnit));
    }

    // 1st Pass: Add original servings from the DB (translated to smart unit)
    for (final s in food.servings) {
      if (s.label.toLowerCase().contains('100 g') || s.label.toLowerCase().contains('100g')) continue;
      String label = displayServingLabel(s.label);
      label = replacePorsiyon(label);
      addPreset(label, servingIcon(label), s.grams);
    }

    // 2nd Pass: Add fractions of those servings
    for (final s in food.servings) {
      if (s.label.toLowerCase().contains('100 g') || s.label.toLowerCase().contains('100g')) continue;
      
      String label = replacePorsiyon(s.label);
      final u = unit(label);
      final icon = servingIcon(label);
      final grams = s.grams;

      addPreset('Yarım $u', icon, grams * 0.5);
      addPreset('1.5 $u', icon, grams * 1.5);
      addPreset('2 $u', icon, grams * 2);
    }

    var presets = presetsByGram.values.toList();
    
    // Sort by grams ascending
    presets.sort((a, b) => a.$3.compareTo(b.$3));

    // Limit to 6 presets, keeping the ones closest to the default portion
    if (presets.length > 6) {
      presets.sort((a, b) => (a.$3 - defaultPortionGrams).abs().compareTo((b.$3 - defaultPortionGrams).abs()));
      presets = presets.take(6).toList();
      presets.sort((a, b) => a.$3.compareTo(b.$3));
    }

    final fallbackU = DietProvider.getSmartUnit(food.name, food.category);
    final fallbackIcon = servingIcon(fallbackU);

    return [
      ('Yarım $fallbackU', Icons.pie_chart_outline_rounded, defaultPortionGrams * 0.5),
      ('1 $fallbackU', fallbackIcon, defaultPortionGrams),
      ('1.5 $fallbackU', Icons.restaurant_menu_rounded, defaultPortionGrams * 1.5),
      ('2 $fallbackU', Icons.lunch_dining_rounded, defaultPortionGrams * 2),
    ];
  }

  // ─── Shared UI Helpers ────────────────────────────────────────────
  static Widget buildGlassCard({
    required Widget child,
    double radius = 20,
    bool accentBorder = false,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: accentBorder
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.09),
          ),
          boxShadow: [
            BoxShadow(
              color: accentBorder
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              spreadRadius: -14,
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

  static Widget buildHeader(IconData icon, String title) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.28),
              AppColors.primary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 15),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    ],
  );

  static Widget buildBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
