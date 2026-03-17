import 'package:flutter/material.dart';

class ProBadge extends StatelessWidget {
  const ProBadge({
    super.key,
    this.label = 'PRO',
    this.compact = false,
    this.padding,
  });

  final String label;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final verticalPadding = compact ? 2.0 : 6.0;
    final horizontalPadding = compact ? 6.0 : 12.0;
    final iconSize = compact ? 12.0 : 16.0;
    final fontSize = compact ? 10.0 : 12.0;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD37A), Color(0xFFCD8F35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFFFE1A6).withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE9B858).withValues(alpha: 0.24),
              blurRadius: compact ? 10 : 16,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: const Color(0xFF241607),
              size: iconSize,
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF241607),
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
