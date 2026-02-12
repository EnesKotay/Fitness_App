import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// İkon + değer + label (Adım, Kalori, Su vb.)
class StatChip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String value;
  final String label;

  const StatChip({
    super.key,
    required this.icon,
    this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTextStyles.numberSmall.copyWith(fontSize: 14),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.labelMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
