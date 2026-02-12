import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// İkon + mesaj + belirgin CTA. İkon etrafında hafif gradient halka.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaText;
  final VoidCallback? onCtaPressed;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaText,
    this.onCtaPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: Icon(icon, size: 52, color: color.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            title,
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
            textAlign: TextAlign.center,
          ),
          if (ctaText != null && onCtaPressed != null) ...[
            const SizedBox(height: AppSpacing.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  onPressed: onCtaPressed,
                  text: ctaText!,
                  icon: Icons.add_rounded,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
