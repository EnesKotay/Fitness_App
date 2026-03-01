import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_coach_models.dart';
import 'coach_premium_panel.dart';

class GoalSelector extends StatelessWidget {
  const GoalSelector({super.key, required this.goal, required this.onChanged});

  final CoachGoal goal;
  final ValueChanged<CoachGoal> onChanged;

  @override
  Widget build(BuildContext context) {
    return CoachPremiumPanel(
      baseColor: const Color(0xFF15203A),
      edgeColor: const Color(0xFF3A4D77),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFEFB756).withValues(alpha: 0.45),
                        const Color(0xFFEFB756).withValues(alpha: 0.07),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFEAC37A).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Icon(
                    Icons.track_changes_rounded,
                    color: Color(0xFFEFD08F),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Hedefin',
                  style: GoogleFonts.cormorantGaramond(
                    color: const Color(0xFFF6EFD8),
                    fontWeight: FontWeight.w700,
                    fontSize: 27,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Modunu sec, koc o tonda plan olustursun.',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFC9D4EE),
                fontWeight: FontWeight.w500,
                fontSize: 12.6,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: CoachGoal.values.map((item) {
                return _GoalChip(
                  item: item,
                  selected: item == goal,
                  onTap: () => onChanged(item),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF0C1426),
                border: Border.all(color: const Color(0xFF304366)),
              ),
              child: Text(
                goal.subtitle,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFDCE5FA),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CoachGoal item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(item);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? LinearGradient(
                    colors: [accent.withValues(alpha: 0.96), _deepen(accent)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF131D33), Color(0xFF0E172C)],
                  ),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.85)
                  : const Color(0xFF34496D),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 14,
                      spreadRadius: -4,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon(item),
                size: 16,
                color: selected
                    ? const Color(0xFF130B00)
                    : const Color(0xFFADC1E8),
              ),
              const SizedBox(width: 7),
              Text(
                item.label,
                style: GoogleFonts.dmSans(
                  color: selected
                      ? const Color(0xFF1C1307)
                      : const Color(0xFFD6E2FA),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _icon(CoachGoal goal) {
  switch (goal) {
    case CoachGoal.bulk:
      return Icons.fitness_center_rounded;
    case CoachGoal.cut:
      return Icons.local_fire_department_rounded;
    case CoachGoal.strength:
      return Icons.bolt_rounded;
  }
}

Color _accent(CoachGoal goal) {
  switch (goal) {
    case CoachGoal.bulk:
      return const Color(0xFFF0B54C);
    case CoachGoal.cut:
      return const Color(0xFF5ED9C1);
    case CoachGoal.strength:
      return const Color(0xFF79ABFF);
  }
}

Color _deepen(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor();
}
