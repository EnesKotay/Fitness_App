import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonStyle { primary, secondary, outline, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonStyle style;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.width,
  });

  const AppButton.primary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  }) : style = AppButtonStyle.primary;

  const AppButton.secondary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  }) : style = AppButtonStyle.secondary;

  const AppButton.outline({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  }) : style = AppButtonStyle.outline;

  const AppButton.text({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  }) : style = AppButtonStyle.text;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle();
    final child = _buildChild();

    Widget button = switch (style) {
      AppButtonStyle.primary || AppButtonStyle.secondary => ElevatedButton(
          onPressed: isLoading ? null : () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          },
          style: buttonStyle,
          child: child,
        ),
      AppButtonStyle.outline => OutlinedButton(
          onPressed: isLoading ? null : () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          },
          style: buttonStyle,
          child: child,
        ),
      AppButtonStyle.text => TextButton(
          onPressed: isLoading ? null : () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          },
          style: buttonStyle,
          child: child,
        ),
    };

    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    return button;
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: AppSpacing.s),
          Text(text),
        ],
      );
    }
    return Text(text);
  }

  ButtonStyle _getButtonStyle() {
    return switch (style) {
      AppButtonStyle.primary => ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.m,
            horizontal: AppSpacing.l,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      AppButtonStyle.secondary => ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppColors.secondary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.m,
            horizontal: AppSpacing.l,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      AppButtonStyle.outline => OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.m,
            horizontal: AppSpacing.l,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      AppButtonStyle.text => TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s,
            horizontal: AppSpacing.m,
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
    };
  }
}
