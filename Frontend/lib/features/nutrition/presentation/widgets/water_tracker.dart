import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WaterTracker extends StatefulWidget {
  final int currentGlasses;
  final int goalGlasses;
  final Function(int) onChanged;
  final VoidCallback? onGoalTap;

  const WaterTracker({
    super.key,
    required this.currentGlasses,
    required this.onChanged,
    this.goalGlasses = 10,
    this.onGoalTap,
  });

  @override
  State<WaterTracker> createState() => _WaterTrackerState();
}

class _WaterTrackerState extends State<WaterTracker> {
  // Animasyon için local state kullanabiliriz ama basit tutalım
  @override
  Widget build(BuildContext context) {
    return AppCard(
      animateOnAppear: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Su Takibi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              GestureDetector(
                onTap: widget.onGoalTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.currentGlasses} / ${widget.goalGlasses} Bardak',
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                    if (widget.onGoalTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.tune_rounded, size: 16, color: Colors.blueAccent.withValues(alpha: 0.8)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.goalGlasses,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isFilled = index < widget.currentGlasses;
                return GestureDetector(
                  onTap: () {
                    int newValue = (index + 1).clamp(0, widget.goalGlasses);
                    if (widget.currentGlasses == newValue) newValue = index;
                    widget.onChanged(newValue);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    width: 32,
                    decoration: BoxDecoration(
                      color: isFilled ? Colors.blueAccent : Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isFilled ? [
                        BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))
                      ] : [],
                    ),
                    child: Icon(
                      Icons.water_drop,
                      color: isFilled ? Colors.white : Colors.blueAccent.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ),
                ).animate(target: isFilled ? 1 : 0).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
              },
            ),
          ),
        ],
      ),
    );
  }
}
