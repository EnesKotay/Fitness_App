import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../../../core/theme/app_colors.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ConsistencyHeatmap extends StatelessWidget {
  final WeightProvider provider;

  const ConsistencyHeatmap({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    
    // Adjust logic to start week on Monday (default usually Sunday in DateUtils)
    // weekday 1 = Monday, 7 = Sunday
    final firstWeekday = firstDayOfMonth.weekday;
    final leadingEmptyDays = firstWeekday - 1; // if Mon(1), 0 empty. if Tue(2), 1 empty.
    
    // entries lookup
    final entries = provider.entries;
    bool hasEntryOn(int day) {
      final dateToCheck = DateTime(now.year, now.month, day);
      return entries.any((e) => DateUtils.isSameDay(e.date, dateToCheck));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Aylık İstikrar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      DateFormat('MMMM yyyy', 'tr_TR').format(now),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Days Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'].map((day) {
                  return SizedBox(
                    width: 32, // Fixed width for alignment
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Calendar Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leadingEmptyDays + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0, 
                ),
                itemBuilder: (context, index) {
                  if (index < leadingEmptyDays) {
                    return const SizedBox.shrink();
                  }
                  final day = index - leadingEmptyDays + 1;
                  final isToday = day == now.day;
                  final hasEntry = hasEntryOn(day);
                  
                  Widget cellContent = Container(
                    decoration: BoxDecoration(
                      color: hasEntry 
                          ? AppColors.primary 
                          : (isToday ? AppColors.primary.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(12),
                      gradient: hasEntry
                          ? LinearGradient(
                              colors: [
                                const Color(0xFF69F0AE), // Neon Green Light
                                AppColors.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: isToday && !hasEntry 
                          ? Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5) 
                          : Border.all(
                              color: hasEntry ? Colors.transparent : Colors.white.withValues(alpha: 0.05),
                              width: 1,
                            ),
                      boxShadow: hasEntry
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : (isToday ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                blurRadius: 8,
                                spreadRadius: -2,
                              )
                          ] : null),
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: hasEntry 
                              ? const Color(0xFF003300) // Deep green for contrast on neon
                              : (isToday ? AppColors.primary : Colors.white30),
                          fontWeight: hasEntry || isToday ? FontWeight.w900 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );

                  // Animate today cell if empty
                  if (isToday && !hasEntry) {
                    return cellContent.animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 2500.ms, color: AppColors.primary.withValues(alpha: 0.3));
                  }
                  
                  // Animate filled cells on load
                  if (hasEntry) {
                    return cellContent.animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack, delay: (index * 15).ms)
                      .fadeIn(duration: 400.ms);
                  }

                  return cellContent;
                },
              ),
              
              if (provider.last30DaysCount > 0) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF9800),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Harika gidiyorsun! Bu ay ${provider.last30DaysCount} gün kayıt girdin.',
                          style: const TextStyle(
                            color: Color(0xFFFFAB40), 
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
