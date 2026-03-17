import 'package:flutter/material.dart';

class PremiumStateBadge extends StatelessWidget {
  const PremiumStateBadge({
    super.key,
    required this.active,
    this.compact = false,
    this.padding,
  });

  final bool active;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final verticalPadding = compact ? 2.0 : 6.0;
    final horizontalPadding = compact ? 7.0 : 12.0;
    final iconSize = compact ? 12.0 : 16.0;
    final fontSize = compact ? 10.0 : 12.0;
    final gradient = active
        ? const [Color(0xFF8CF0C2), Color(0xFF3FBF91)]
        : const [Color(0xFFFFD37A), Color(0xFFCD8F35)];
    final textColor = active
        ? const Color(0xFF072114)
        : const Color(0xFF241607);
    final icon = active
        ? Icons.verified_rounded
        : Icons.workspace_premium_rounded;
    final label = active ? 'AKTIF' : 'PRO';

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.22),
              blurRadius: compact ? 10 : 16,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: iconSize),
            SizedBox(width: compact ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                letterSpacing: compact ? 0.3 : 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
