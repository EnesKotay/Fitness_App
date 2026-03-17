import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../nutrition/domain/entities/user_profile.dart';
import '../models/ai_coach_models.dart';

class GoalSelector extends StatelessWidget {
  const GoalSelector({super.key, required this.goal, required this.onChanged});

  final Goal goal;
  final ValueChanged<Goal> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hedefin',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Koçun üreteceği öneri tonu bu hedefe göre şekillenir.',
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: Goal.values
                .map(
                  (item) => _GoalCard(
                    goal: item,
                    selected: item == goal,
                    onTap: () => onChanged(item),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Text(
              goal.subtitle,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final Goal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(goal);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _icon(goal),
                size: 18,
                color: selected ? accent : Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              goal.label,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _icon(Goal goal) {
  switch (goal) {
    case Goal.bulk:
      return Icons.fitness_center_rounded;
    case Goal.cut:
      return Icons.local_fire_department_rounded;
    case Goal.strength:
      return Icons.bolt_rounded;
    case Goal.maintain:
      return Icons.balance_rounded;
  }
}

Color _accent(Goal goal) {
  switch (goal) {
    case Goal.bulk:
      return const Color(0xFFF0B54C);
    case Goal.cut:
      return const Color(0xFF53D3B4);
    case Goal.strength:
      return const Color(0xFF73A7FF);
    case Goal.maintain:
      return const Color(0xFFB388FF);
  }
}
