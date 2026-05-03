import 'package:flutter/material.dart';

/// Tüm ekranlarda kullanılan rehber (?) butonu.
/// Soru işareti yerine altın sarısı bir ampul+sparkle ikonu.
class PageGuideButton extends StatelessWidget {
  final VoidCallback onTap;

  const PageGuideButton({super.key, required this.onTap});

  static const Color _amber = Color(0xFFEBC374);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sayfa Rehberi',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: _amber.withValues(alpha: 0.12),
          highlightColor: _amber.withValues(alpha: 0.06),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _amber.withValues(alpha: 0.18),
                  _amber.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: _amber.withValues(alpha: 0.30),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _amber.withValues(alpha: 0.16),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.tips_and_updates_rounded,
              color: _amber.withValues(alpha: 0.92),
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}
