import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../providers/tracking_provider.dart';
import '../../../core/models/body_measurement.dart';

class BodyFatCalculatorCard extends StatefulWidget {
  const BodyFatCalculatorCard({super.key});

  @override
  State<BodyFatCalculatorCard> createState() => _BodyFatCalculatorCardState();
}

class _BodyFatCalculatorCardState extends State<BodyFatCalculatorCard> {
  static const _prefsKey = 'body_fat_neck_cm';
  String get _userPrefsKey => StorageHelper.userScopedKey(_prefsKey);

  double? _neckCm;

  @override
  void initState() {
    super.initState();
    _loadNeck();
  }

  Future<void> _loadNeck() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_userPrefsKey);
    if (v != null && mounted) setState(() => _neckCm = v);
  }

  Future<void> _saveNeck(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_userPrefsKey, v);
  }

  // ── Navy Formülü ─────────────────────────────────────────────────────────────
  static double? _calcFat({
    required Gender gender,
    required double heightCm,
    required double waistCm,
    required double? hipCm,
    required double neckCm,
  }) {
    try {
      if (gender == Gender.male) {
        final diff = waistCm - neckCm;
        if (diff <= 0) return null;
        return 86.010 * log(diff) / ln10 -
            70.041 * log(heightCm) / ln10 +
            36.76;
      } else {
        final sum = waistCm + (hipCm ?? waistCm * 1.05) - neckCm;
        if (sum <= 0) return null;
        return 163.205 * log(sum) / ln10 -
            97.684 * log(heightCm) / ln10 -
            78.387;
      }
    } catch (_) {
      return null;
    }
  }

  static const double ln10 = 2.302585092994046;

  // Erkek: <6 Atlet, 6-17 Fit, 18-24 Orta, >25 Yüksek
  // Kadın: <14 Atlet, 14-24 Fit, 25-31 Orta, >32 Yüksek
  static _FatCategory _categorize(double fat, Gender gender) {
    if (gender == Gender.male) {
      if (fat < 6) return _FatCategory.athlete;
      if (fat < 18) return _FatCategory.fit;
      if (fat < 25) return _FatCategory.average;
      return _FatCategory.high;
    } else {
      if (fat < 14) return _FatCategory.athlete;
      if (fat < 25) return _FatCategory.fit;
      if (fat < 32) return _FatCategory.average;
      return _FatCategory.high;
    }
  }

  void _editNeck() async {
    final ctrl = TextEditingController(
      text: _neckCm != null ? _neckCm!.toStringAsFixed(1) : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Boyun Ölçüsü',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Boyun çevresini santimetre olarak gir.\nAdam\'s apple hizasından ölç.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                suffixText: 'cm',
                suffixStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && v > 10 && v < 70) Navigator.pop(ctx, v);
            },
            child: const Text(
              'Kaydet',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _neckCm = result);
      await _saveNeck(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DietProvider, TrackingProvider>(
      builder: (context, diet, tracking, _) {
        final profile = diet.profile;
        final measurements = tracking.bodyMeasurements;

        BodyMeasurement? latest;
        if (measurements.isNotEmpty) latest = measurements.first;

        final waist = latest?.waist;
        final hips = latest?.hips;
        final heightCm = profile?.height;
        final gender = profile?.gender ?? Gender.male;

        double? fatPercent;
        if (waist != null && heightCm != null && _neckCm != null) {
          fatPercent = _calcFat(
            gender: gender,
            heightCm: heightCm,
            waistCm: waist,
            hipCm: hips,
            neckCm: _neckCm!,
          );
          if (fatPercent != null) {
            fatPercent = fatPercent.clamp(3.0, 60.0);
          }
        }

        final category = fatPercent != null
            ? _categorize(fatPercent, gender)
            : null;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Başlık ──────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF64D2FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: Color(0xFF64D2FF),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vücut Yağ Oranı',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Navy Formülü ile hesaplanır',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Boyun girişi ─────────────────────────────────────────────
                GestureDetector(
                  onTap: _editNeck,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _neckCm == null
                          ? AppColors.primary.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _neckCm == null
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.straighten_rounded,
                          size: 15,
                          color: _neckCm == null
                              ? AppColors.primary
                              : Colors.white38,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Boyun ölçüsü',
                          style: TextStyle(
                            color: _neckCm == null
                                ? AppColors.primary
                                : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _neckCm != null
                              ? '${_neckCm!.toStringAsFixed(1)} cm'
                              : 'Gir →',
                          style: TextStyle(
                            color: _neckCm != null
                                ? Colors.white
                                : AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (waist == null)
                  _buildNoDataState()
                else if (_neckCm == null)
                  _buildNeckMissingState()
                else
                  _buildResult(fatPercent, category, gender),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(
              Icons.straighten_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Bel ölçüsü gerekmektedir',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeckMissingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary.withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              'Yukarıdan boyun ölçüsünü gir',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Navy formülü için zorunludur',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(
    double? fatPercent,
    _FatCategory? category,
    Gender gender,
  ) {
    if (fatPercent == null || category == null) {
      return _buildNoDataState();
    }

    final catColor = category.color;
    final catLabel = category.turkishLabel;
    final progress = (fatPercent / 50.0).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(110, 110),
                painter: _CircularFatPainter(
                  progress: progress,
                  color: catColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${fatPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: catColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Yağ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: catColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  catLabel,
                  style: TextStyle(
                    color: catColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildRefRow(
                gender == Gender.male ? '< 6%' : '< 14%',
                'Atlet',
                const Color(0xFF64D2FF),
              ),
              _buildRefRow(
                gender == Gender.male ? '6–17%' : '14–24%',
                'Fit / Orta',
                AppColors.primaryLight,
              ),
              _buildRefRow(
                gender == Gender.male ? '> 25%' : '> 32%',
                'Yüksek',
                AppColors.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefRow(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            range,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kategori Enum ────────────────────────────────────────────────────────────

enum _FatCategory { athlete, fit, average, high }

extension _FatCategoryX on _FatCategory {
  Color get color {
    switch (this) {
      case _FatCategory.athlete:
        return const Color(0xFF64D2FF);
      case _FatCategory.fit:
        return AppColors.primaryLight;
      case _FatCategory.average:
        return const Color(0xFFFFA56E);
      case _FatCategory.high:
        return AppColors.error;
    }
  }

  String get turkishLabel {
    switch (this) {
      case _FatCategory.athlete:
        return 'Atlet';
      case _FatCategory.fit:
        return 'Fit';
      case _FatCategory.average:
        return 'Orta';
      case _FatCategory.high:
        return 'Yüksek';
    }
  }
}

// ── Dairesel İlerleme Painter ────────────────────────────────────────────────

class _CircularFatPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CircularFatPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularFatPainter old) =>
      old.progress != progress || old.color != color;
}
