import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../workout/providers/workout_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum HeatmapFilter { weight, workout }

class ConsistencyHeatmap extends StatefulWidget {
  final WeightProvider provider;

  const ConsistencyHeatmap({super.key, required this.provider});

  @override
  State<ConsistencyHeatmap> createState() => _ConsistencyHeatmapState();
}

class _ConsistencyHeatmapState extends State<ConsistencyHeatmap> {
  HeatmapFilter _filter = HeatmapFilter.weight;
  int _monthOffset = 0; // 0 = bu ay, -1 = geçen ay, vb.

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Offset ayı hesapla
    final displayDate = DateTime(now.year, now.month + _monthOffset, 1);
    final displayYear = displayDate.year;
    final displayMonth = displayDate.month;
    final isCurrentMonth = _monthOffset == 0;

    final firstDayOfMonth = DateTime(displayYear, displayMonth, 1);
    final daysInMonth = DateUtils.getDaysInMonth(displayYear, displayMonth);

    final firstWeekday = firstDayOfMonth.weekday;
    final leadingEmptyDays = firstWeekday - 1;

    final weightEntries = widget.provider.entries;
    final workoutProvider = context.watch<WorkoutProvider>();

    bool hasEntryOn(int day) {
      final dateToCheck = DateTime(displayYear, displayMonth, day);
      if (_filter == HeatmapFilter.weight) {
        return weightEntries.any((e) => DateUtils.isSameDay(e.date, dateToCheck));
      } else if (_filter == HeatmapFilter.workout) {
        return workoutProvider.workouts.any((w) => DateUtils.isSameDay(w.workoutDate, dateToCheck));
      }
      return false;
    }

    bool isToday(int day) {
      if (!isCurrentMonth) return false;
      return day == now.day;
    }

    final monthLabel = DateFormat('MMMM yyyy', 'tr_TR').format(displayDate);

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
              // ── Başlık Satırı ──
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
                        'İstikrar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  // Tab / Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _filter = HeatmapFilter.weight),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _filter == HeatmapFilter.weight ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Kilo', style: TextStyle(color: _filter == HeatmapFilter.weight ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _filter = HeatmapFilter.workout),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _filter == HeatmapFilter.workout ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Antrenman', style: TextStyle(color: _filter == HeatmapFilter.workout ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── Ay Navigasyonu ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _monthOffset--),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: const Icon(Icons.chevron_left_rounded, color: Colors.white54, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    monthLabel,
                    style: TextStyle(
                      color: isCurrentMonth ? Colors.white : Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: isCurrentMonth ? null : () => setState(() => _monthOffset++),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isCurrentMonth
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrentMonth
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: isCurrentMonth ? Colors.white12 : Colors.white54,
                        size: 20,
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
                  final isTodayCell = isToday(day);
                  final hasEntry = hasEntryOn(day);
                  
                  Widget cellContent = Container(
                    decoration: BoxDecoration(
                      color: hasEntry 
                          ? AppColors.primary 
                          : (isTodayCell ? AppColors.primary.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(12),
                      gradient: hasEntry
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF69F0AE),
                                AppColors.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: isTodayCell && !hasEntry 
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
                          : (isTodayCell ? [
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
                              ? const Color(0xFF003300)
                              : (isTodayCell ? AppColors.primary : Colors.white30),
                          fontWeight: hasEntry || isTodayCell ? FontWeight.w900 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );

                  // Animate today cell if empty
                  if (isTodayCell && !hasEntry) {
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
              
              Builder(
                builder: (context) {
                  // Bu ay içindeki gün sayısını say
                  int countForMonth() {
                    int count = 0;
                    for (int d = 1; d <= daysInMonth; d++) {
                      if (hasEntryOn(d)) count++;
                    }
                    return count;
                  }
                  final entryCount = countForMonth();
                  
                  if (entryCount == 0) return const SizedBox.shrink();

                  return Column(
                    children: [
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
                                'Harika gidiyorsun! Son 30 günde $entryCount gün ${_filter == HeatmapFilter.weight ? "kayıt girdin" : "antrenman yaptın"}.',
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
                    ],
                  );
                }
              ),
              
              Builder(
                builder: (context) {
                  final isWeight = _filter == HeatmapFilter.weight;
                  final entriesLength = isWeight ? widget.provider.entries.length : workoutProvider.workouts.length;
                  final currentStreak = isWeight ? widget.provider.currentStreak : 0; // workout doesn't have currentStreak directly, simplified here
                  
                  if (entriesLength == 0) return const SizedBox.shrink();
                  
                  return Column(
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryLight, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Kazanılan Rozetler',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildBadgeItem(
                            title: 'İlk Adım',
                            icon: Icons.star_rounded,
                            color: const Color(0xFFCD7F32), // Bronze
                            isUnlocked: entriesLength > 0,
                          ),
                          _buildBadgeItem(
                            title: '7 Gün',
                            icon: Icons.local_fire_department_rounded,
                            color: const Color(0xFFC0C0C0), // Silver
                            isUnlocked: isWeight ? currentStreak >= 7 : entriesLength >= 7,
                          ),
                          _buildBadgeItem(
                            title: '30 Gün',
                            icon: Icons.emoji_events_rounded,
                            color: const Color(0xFFFFD700), // Gold
                            isUnlocked: isWeight ? currentStreak >= 30 : entriesLength >= 30,
                          ),
                          _buildBadgeItem(
                            title: 'Sadık',
                            icon: Icons.diamond_rounded,
                            color: const Color(0xFF00E5FF), // Diamond
                            isUnlocked: entriesLength >= 100,
                          ),
                        ],
                      ),
                    ],
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeItem({
    required String title,
    required IconData icon,
    required Color color,
    required bool isUnlocked,
  }) {
    final badgeColor = isUnlocked ? color : Colors.white.withValues(alpha: 0.1);
    
    Widget badge = Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUnlocked ? badgeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: isUnlocked ? badgeColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
              width: 2,
            ),
            boxShadow: isUnlocked ? [
              BoxShadow(
                color: badgeColor.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ] : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 28,
              color: isUnlocked ? badgeColor : Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: isUnlocked ? Colors.white : Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );

    if (isUnlocked) {
      badge = badge.animate().scale(
        duration: 600.ms, 
        curve: Curves.elasticOut,
        delay: 300.ms,
      ).shimmer(
        duration: 2.seconds,
        color: Colors.white.withValues(alpha: 0.4),
        delay: 800.ms,
      );
    }

    return badge;
  }
}
