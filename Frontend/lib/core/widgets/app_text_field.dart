import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? errorText;
  final bool readOnly;
  final VoidCallback? onTap;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
    this.focusNode,
    this.errorText,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon:
                prefixIcon != null ? Icon(prefixIcon, size: AppSpacing.iconM) : null,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.m,
            ),
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          inputFormatters: inputFormatters,
          autofocus: autofocus,
          focusNode: focusNode,
          readOnly: readOnly,
          onTap: onTap,
          style: AppTextStyles.bodyLarge,
          cursorColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}
