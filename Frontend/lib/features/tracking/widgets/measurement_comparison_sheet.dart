import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/tracking_provider.dart';
import '../../../core/models/body_measurement.dart';

/// ModalBottomSheet ile açılan iki ölçüm karşılaştırma ekranı.
/// Kullanım: `showMeasurementComparisonSheet(context)` ile çağırın.
void showMeasurementComparisonSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const MeasurementComparisonSheet(),
  );
}

class MeasurementComparisonSheet extends StatefulWidget {
  const MeasurementComparisonSheet({super.key});

  @override
  State<MeasurementComparisonSheet> createState() =>
      _MeasurementComparisonSheetState();
}

class _MeasurementComparisonSheetState
    extends State<MeasurementComparisonSheet> {
  int _indexA = 0; // newer
  int _indexB = 1; // older

  static final _dateFmt = DateFormat('d MMM yyyy', 'tr_TR');

  @override
  Widget build(BuildContext context) {
    final measurements =
        context.watch<TrackingProvider>().bodyMeasurements;

    if (measurements.length < 2) {
      return _buildSheet(
        context: context,
        child: _buildNotEnoughData(),
      );
    }

    // Güvenli indeks
    final safeA = _indexA.clamp(0, measurements.length - 1);
    final safeB = _indexB.clamp(0, measurements.length - 1);
    final mA = measurements[safeA];
    final mB = measurements[safeB];

    return _buildSheet(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildDropdowns(measurements, safeA, safeB),
          const SizedBox(height: 24),
          if (safeA != safeB) _buildComparisonTable(mA, mB),
          if (safeA == safeB) _buildSameSelectionWarning(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSheet({
    required BuildContext context,
    required Widget child,
  }) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + mq.viewInsets.bottom,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.compare_arrows_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Ölçüm Karşılaştırma',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdowns(
    List<BodyMeasurement> measurements,
    int safeA,
    int safeB,
  ) {
    return Row(
      children: [
        // Seçim A
        Expanded(
          child: _buildDropdown(
            label: 'Yeni Ölçüm',
            value: safeA,
            measurements: measurements,
            onChanged: (v) {
              if (v != null) setState(() => _indexA = v);
            },
            accentColor: AppColors.primaryLight,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.compare_arrows_rounded,
            color: Colors.white.withValues(alpha: 0.3),
            size: 20,
          ),
        ),
        // Seçim B
        Expanded(
          child: _buildDropdown(
            label: 'Eski Ölçüm',
            value: safeB,
            measurements: measurements,
            onChanged: (v) {
              if (v != null) setState(() => _indexB = v);
            },
            accentColor: const Color(0xFF64D2FF),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required int value,
    required List<BodyMeasurement> measurements,
    required ValueChanged<int?> onChanged,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: accentColor.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          ),
          child: DropdownButton<int>(
            value: value,
            dropdownColor: AppColors.surfaceElevated,
            underline: const SizedBox.shrink(),
            isExpanded: true,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            iconEnabledColor: Colors.white38,
            items: measurements.asMap().entries.map((e) {
              return DropdownMenuItem<int>(
                value: e.key,
                child: Text(
                  _dateFmt.format(e.value.date),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonTable(BodyMeasurement newer, BodyMeasurement older) {
    final rows = <_CompareRow>[
      _CompareRow(
        label: 'Göğüs',
        icon: Icons.expand_rounded,
        newer: newer.chest,
        older: older.chest,
        positiveIsGood: true, // kas artışı = iyi
      ),
      _CompareRow(
        label: 'Bel',
        icon: Icons.compress_rounded,
        newer: newer.waist,
        older: older.waist,
        positiveIsGood: false, // incelme = iyi
      ),
      _CompareRow(
        label: 'Kalça',
        icon: Icons.airline_seat_recline_normal_rounded,
        newer: newer.hips,
        older: older.hips,
        positiveIsGood: false, // incelme = iyi
      ),
      _CompareRow(
        label: 'Sol Kol',
        icon: Icons.fitness_center_rounded,
        newer: newer.leftArm,
        older: older.leftArm,
        positiveIsGood: true,
      ),
      _CompareRow(
        label: 'Sağ Kol',
        icon: Icons.fitness_center_rounded,
        newer: newer.rightArm,
        older: older.rightArm,
        positiveIsGood: true,
      ),
      _CompareRow(
        label: 'Sol Bacak',
        icon: Icons.directions_walk_rounded,
        newer: newer.leftLeg,
        older: older.leftLeg,
        positiveIsGood: true,
      ),
      _CompareRow(
        label: 'Sağ Bacak',
        icon: Icons.directions_walk_rounded,
        newer: newer.rightLeg,
        older: older.rightLeg,
        positiveIsGood: true,
      ),
    ];

    return Column(
      children: [
        // Başlık satırı
        _buildTableHeader(),
        const SizedBox(height: 8),
        ...rows.map((r) => _buildTableRow(r)),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          const Expanded(
            flex: 3,
            child: Text(
              'Bölge',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Yeni',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Eski',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64D2FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              'Fark',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(_CompareRow row) {
    final hasData = row.newer != null && row.older != null;
    final diff = hasData ? row.newer! - row.older! : null;
    final isPositive = diff != null && diff > 0;
    final isZero = diff != null && diff.abs() < 0.05;

    Color diffColor = Colors.white38;
    IconData arrowIcon = Icons.remove_rounded;

    if (!isZero && diff != null) {
      final goodChange = row.positiveIsGood ? isPositive : !isPositive;
      diffColor = goodChange ? AppColors.primaryLight : AppColors.error;
      arrowIcon = isPositive
          ? Icons.arrow_upward_rounded
          : Icons.arrow_downward_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasData && !isZero
              ? diffColor.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(row.icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              row.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.newer != null
                  ? '${row.newer!.toStringAsFixed(1)} cm'
                  : '—',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.older != null
                  ? '${row.older!.toStringAsFixed(1)} cm'
                  : '—',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64D2FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (diff != null && !isZero)
                  Icon(arrowIcon, color: diffColor, size: 12),
                const SizedBox(width: 2),
                Text(
                  diff != null
                      ? (isZero
                          ? '±0'
                          : '${isPositive ? "+" : ""}${diff.toStringAsFixed(1)}')
                      : '—',
                  style: TextStyle(
                    color: diffColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSameSelectionWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Text(
            'Farklı iki tarih seçin',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotEnoughData() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            Icon(
              Icons.compare_arrows_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'Karşılaştırma için en az\n2 ölçüm gereklidir',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yardımcı Veri Modeli ─────────────────────────────────────────────────────

class _CompareRow {
  final String label;
  final IconData icon;
  final double? newer;
  final double? older;
  final bool positiveIsGood;

  const _CompareRow({
    required this.label,
    required this.icon,
    required this.newer,
    required this.older,
    required this.positiveIsGood,
  });
}
