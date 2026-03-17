import 'package:flutter/material.dart';
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
        if (measurements.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Henüz vücut ölçüsü eklenmemiş.\nEklemek için + butonunu kullanın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: measurements.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final m = measurements[index];
            return _buildMeasurementCard(context, m);
          },
        );
      },
    );
  }

  Widget _buildMeasurementCard(BuildContext context, BodyMeasurement m) {
    final dateStr = DateFormat('d MMM yyyy', 'tr_TR').format(m.date);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.edit_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 18),
                onPressed: () => _editMeasurement(context, m),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 20),
                onPressed: () => _confirmDelete(context, m),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (m.chest != null) _buildStat('Göğüs', m.chest!),
              if (m.waist != null) _buildStat('Bel', m.waist!),
              if (m.hips != null) _buildStat('Kalça', m.hips!),
              if (m.leftArm != null) _buildStat('Sol Kol', m.leftArm!),
              if (m.rightArm != null) _buildStat('Sağ Kol', m.rightArm!),
              if (m.leftLeg != null) _buildStat('Sol Bacak', m.leftLeg!),
              if (m.rightLeg != null) _buildStat('Sağ Bacak', m.rightLeg!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, double val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${val.toStringAsFixed(1)} cm',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Ölçümü sil?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu tarihteki ölçümleri silmek istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TrackingProvider>().deleteBodyMeasurement(m.userId, m.id);
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
