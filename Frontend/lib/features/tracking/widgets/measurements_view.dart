import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/body_measurement.dart';
import '../providers/tracking_provider.dart';
import 'add_measurement_sheet.dart';

class MeasurementsView extends StatelessWidget {
  final Function(BodyMeasurement)? onEdit;
  const MeasurementsView({super.key, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Selector<TrackingProvider, List<BodyMeasurement>>(
      selector: (_, p) => p.bodyMeasurements,
      builder: (context, measurements, child) {
        if (measurements.isEmpty) return const SizedBox.shrink();

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: measurements.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final current = measurements[index];
            final previous = index + 1 < measurements.length
                ? measurements[index + 1]
                : null;
            return _MeasurementCard(
              measurement: current,
              previous: previous,
              index: index,
            );
          },
        );
      },
    );
  }
}

// ── Single Measurement Card ──────────────────────────────────────────────────

class _MeasurementCard extends StatefulWidget {
  final BodyMeasurement measurement;
  final BodyMeasurement? previous;
  final int index;

  const _MeasurementCard({
    required this.measurement,
    required this.previous,
    required this.index,
  });

  @override
  State<_MeasurementCard> createState() => _MeasurementCardState();
}

class _MeasurementCardState extends State<_MeasurementCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.index * 80),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _CardContent(
          measurement: widget.measurement,
          previous: widget.previous,
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final BodyMeasurement measurement;
  final BodyMeasurement? previous;

  const _CardContent({required this.measurement, required this.previous});

  static const _metrics = [
    _MetricDef(
      'chest',
      'Göğüs',
      Icons.accessibility_new_rounded,
      Color(0xFF64D2FF),
    ),
    _MetricDef('waist', 'Bel', Icons.straighten_rounded, Color(0xFFFF6B6B)),
    _MetricDef(
      'hips',
      'Kalça',
      Icons.self_improvement_rounded,
      Color(0xFFFF9F43),
    ),
    _MetricDef(
      'leftArm',
      'Sol Kol',
      Icons.fitness_center_rounded,
      Color(0xFF48BB78),
    ),
    _MetricDef(
      'rightArm',
      'Sağ Kol',
      Icons.fitness_center_rounded,
      Color(0xFF48BB78),
    ),
    _MetricDef(
      'leftLeg',
      'Sol Bacak',
      Icons.directions_walk_rounded,
      Color(0xFFA78BFA),
    ),
    _MetricDef(
      'rightLeg',
      'Sağ Bacak',
      Icons.directions_walk_rounded,
      Color(0xFFA78BFA),
    ),
  ];

  double? _val(String key) {
    switch (key) {
      case 'chest':
        return measurement.chest;
      case 'waist':
        return measurement.waist;
      case 'hips':
        return measurement.hips;
      case 'leftArm':
        return measurement.leftArm;
      case 'rightArm':
        return measurement.rightArm;
      case 'leftLeg':
        return measurement.leftLeg;
      case 'rightLeg':
        return measurement.rightLeg;
      default:
        return null;
    }
  }

  double? _prevVal(String key) {
    if (previous == null) return null;
    switch (key) {
      case 'chest':
        return previous!.chest;
      case 'waist':
        return previous!.waist;
      case 'hips':
        return previous!.hips;
      case 'leftArm':
        return previous!.leftArm;
      case 'rightArm':
        return previous!.rightArm;
      case 'leftLeg':
        return previous!.leftLeg;
      case 'rightLeg':
        return previous!.rightLeg;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMMM yyyy', 'tr_TR').format(measurement.date);
    final activeMetrics = _metrics.where((m) => _val(m.key) != null).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${activeMetrics.length} ölçüm kaydedildi',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionButton(
                  icon: Icons.edit_rounded,
                  color: AppColors.primary.withValues(alpha: 0.6),
                  onTap: () => _editMeasurement(context, measurement),
                ),
                _ActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.white38,
                  onTap: () => _confirmDelete(context, measurement),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Divider ─────────────────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white.withValues(alpha: 0.06),
          ),

          const SizedBox(height: 14),

          // ── Metrics grid ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeMetrics.map((def) {
                final val = _val(def.key)!;
                final prev = _prevVal(def.key);
                return _MetricTile(def: def, value: val, previous: prev);
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  void _editMeasurement(BuildContext context, BodyMeasurement m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMeasurementSheet(existingMeasurement: m),
    );
  }

  void _confirmDelete(BuildContext context, BodyMeasurement m) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ölçümü Sil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Bu tarihteki ölçümleri silmek istediğine emin misin?',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final provider = context.read<TrackingProvider>();
              Navigator.pop(ctx);
              provider.deleteBodyMeasurement(m.userId, m.id);
            },
            child: const Text(
              'Sil',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Metric Tile ──────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final _MetricDef def;
  final double value;
  final double? previous;

  const _MetricTile({
    required this.def,
    required this.value,
    required this.previous,
  });

  @override
  Widget build(BuildContext context) {
    final diff = previous != null ? value - previous! : null;
    final diffStr = diff != null
        ? '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}'
        : null;
    final diffColor = diff == null
        ? Colors.transparent
        : (diff < 0 ? const Color(0xFF48BB78) : const Color(0xFFFF6B6B));

    return Container(
      width: (MediaQuery.of(context).size.width - 72) / 3,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: def.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: def.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(def.icon, size: 11, color: def.color.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  def.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${value.toStringAsFixed(1)} cm',
            style: TextStyle(
              color: def.color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (diffStr != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  diff! < 0
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 9,
                  color: diffColor,
                ),
                const SizedBox(width: 2),
                Text(
                  '$diffStr cm',
                  style: TextStyle(
                    color: diffColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }
}

// ── MetricDef ─────────────────────────────────────────────────────────────────

class _MetricDef {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _MetricDef(this.key, this.label, this.icon, this.color);
}
