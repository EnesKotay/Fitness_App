import 'package:flutter/material.dart';
import '../../../../core/widgets/app_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/water_reminder_service.dart';

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
  bool _reminderEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadReminderState();
  }

  Future<void> _loadReminderState() async {
    final enabled = await WaterReminderService.instance.isEnabled();
    if (mounted) setState(() => _reminderEnabled = enabled);
  }

  Future<void> _toggleReminder() async {
    final newState = !_reminderEnabled;
    await WaterReminderService.instance.setEnabled(newState);
    if (mounted) {
      setState(() => _reminderEnabled = newState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState
                ? 'Su hatırlatıcı açıldı 💧'
                : 'Su hatırlatıcı kapatıldı',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: newState ? Colors.blueAccent : Colors.grey[700],
        ),
      );
    }
  }

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Su Takibi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Hatırlatıcı toggle
                  GestureDetector(
                    onTap: _toggleReminder,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _reminderEnabled
                            ? Colors.blueAccent.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _reminderEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_outlined,
                        size: 18,
                        color: _reminderEnabled
                            ? Colors.blueAccent
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: widget.onGoalTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.currentGlasses} / ${widget.goalGlasses} Bardak',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.onGoalTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: Colors.blueAccent.withValues(alpha: 0.8),
                      ),
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
              separatorBuilder: (_, index) => const SizedBox(width: 8),
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
                      color: isFilled
                          ? Colors.blueAccent
                          : Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color:
                                    Colors.blueAccent.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      Icons.water_drop,
                      color: isFilled
                          ? Colors.white
                          : Colors.blueAccent.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ),
                ).animate(target: isFilled ? 1 : 0).scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}
