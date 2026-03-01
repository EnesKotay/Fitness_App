import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HistoryList extends StatelessWidget {
  final WeightProvider provider;
  final Function(WeightEntry) onDelete;

  const HistoryList({
    super.key,
    required this.provider,
    required this.onDelete,
  });

  /// Kilo gösterimi için güvenli format (taşma ve float gürültüsü önlenir).
  static String formatWeight(double kg) {
    if (kg.isNaN || kg.isInfinite) return '--';
    return kg.clamp(0, 999).toStringAsFixed(1);
  }

  /// Tarih: "15 Şubat 2025"
  static String formatDate(DateTime date) {
    try {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    } catch (_) {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  /// Gün adı: "Pazartesi"
  static String formatWeekday(DateTime date) {
    try {
      return DateFormat('EEEE', 'tr_TR').format(date);
    } catch (_) {
      return '';
    }
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Tüm kayıtları döndürür (en yeni en üstte).
  static List<WeightEntry> entriesWithWeightChange(List<WeightEntry> entries) {
    return entries; // Artık filtreleme yapmıyoruz, her gelişim değerli.
  }

  @override
  Widget build(BuildContext context) {
    final entries = entriesWithWeightChange(provider.entries);
    if (entries.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final entry = entries[index];
          final isLast = index == entries.length - 1;
          final isFirst = index == 0;
          // Bir sonraki (daha eski) kayda göre fark: pozitif = kilo almış, negatif = vermiş
          double? diff;
          if (index < entries.length - 1) {
            final olderEntry = entries[index + 1];
            diff = entry.weightKg - olderEntry.weightKg;
            if (diff.abs() < 0.05) diff = null;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HistoryListItem(
              entry: entry,
              diff: diff,
              isLast: isLast,
              isFirst: isFirst,
              onDelete: () => onDelete(entry),
              index: index,
            ),
          );
        }, childCount: entries.length),
      ),
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  final WeightEntry entry;
  final double? diff;
  final bool isLast;
  final bool isFirst;
  final VoidCallback onDelete;
  final int index;

  const _HistoryListItem({
    required this.entry,
    required this.diff,
    required this.isLast,
    required this.isFirst,
    required this.onDelete,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final weightStr = HistoryList.formatWeight(entry.weightKg);
    final dateStr = HistoryList.formatDate(entry.date);
    final weekdayStr = HistoryList.formatWeekday(entry.date);
    final diffValue = diff;
    final showToday = HistoryList.isToday(entry.date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.35),
                    border: Border.all(
                      color: isFirst
                          ? AppColors.primaryLight.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.15),
                      width: isFirst ? 2 : 1,
                    ),
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: showToday
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
                    color: showToday
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.04),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showToday)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Bugün',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryLight,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              weekdayStr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (diffValue != null && diffValue.abs() >= 0.05) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    diffValue < 0
                                        ? Icons.trending_down_rounded
                                        : Icons.trending_up_rounded,
                                    size: 14,
                                    color: diffValue < 0
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    diffValue < 0
                                        ? '${diffValue.toStringAsFixed(1)} kg'
                                        : '+${diffValue.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: diffValue < 0
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    diffValue < 0 ? 'verdi' : 'aldı',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$weightStr',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'kg',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Kaydı sil',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(
                duration: 350.ms,
                delay: (30 * index).clamp(0, 300).ms,
              ).slideX(begin: 0.02, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}
