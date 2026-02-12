import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Başlık + sağda aksiyon (Ekle, vb.)
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.sectionTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
