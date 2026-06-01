import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class MacroProgressCard extends StatelessWidget {
  final int remKcal;
  final int remP;
  final int remC;
  final int remF;
  final double pKcal;
  final double pProt;
  final double pCarb;
  final double pFat;
  final int consumedKcal;
  final int targetKcal;
  final bool expanded;
  final VoidCallback onToggle;

  const MacroProgressCard({
    super.key,
    required this.remKcal,
    required this.remP,
    required this.remC,
    required this.remF,
    required this.pKcal,
    required this.pProt,
    required this.pCarb,
    required this.pFat,
    required this.consumedKcal,
    required this.targetKcal,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final kcalText = remKcal >= 0
        ? '$remKcal kcal alan var'
        : '${remKcal.abs()} kcal aşıldı';
    final focusText = remP >= 20
        ? 'Protein açığın ${remP}g'
        : remC >= 35
            ? 'Karb alanın ${remC}g'
            : remF >= 12
                ? 'Yağ alanın ${remF}g'
                : 'Makrolar dengede';

    final statusColor = remKcal >= 0 ? AppColors.secondary : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF121722), Color(0xFF0C1015)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        remKcal >= 0
                            ? Icons.local_fire_department_rounded
                            : Icons.warning_amber_rounded,
                        color: statusColor,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$kcalText · $focusText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$consumedKcal / $targetKcal kcal tüketildi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 23,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pKcal,
                    minHeight: 5,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 13),
                          child: Row(
                            children: [
                              _macroProgressTile(
                                label: 'Kalori',
                                value: '$remKcal',
                                unit: 'kcal',
                                progress: pKcal,
                                color: AppColors.secondary,
                                icon: Icons.local_fire_department_rounded,
                              ),
                              _macroProgressTile(
                                label: 'Protein',
                                value: '$remP',
                                unit: 'g',
                                progress: pProt,
                                color: AppColors.chartBlue,
                                icon: Icons.fitness_center_rounded,
                              ),
                              _macroProgressTile(
                                label: 'Karb',
                                value: '$remC',
                                unit: 'g',
                                progress: pCarb,
                                color: AppColors.chartGreen,
                                icon: Icons.grain_rounded,
                              ),
                              _macroProgressTile(
                                label: 'Yağ',
                                value: '$remF',
                                unit: 'g',
                                progress: pFat,
                                color: const Color(0xFFFFB74D),
                                icon: Icons.water_drop_rounded,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _macroProgressTile({
    required String label,
    required String value,
    required String unit,
    required double progress,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 7),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.65),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

