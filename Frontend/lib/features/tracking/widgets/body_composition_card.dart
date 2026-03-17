import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/body_measurement.dart';
import '../../nutrition/domain/entities/user_profile.dart';

/// Vücut kompozisyonu hesaplayıcısı — Deurenberg Formula.
/// Girişler: Kilo (kg), Boy (cm), Yaş, Cinsiyet
/// BF% = 1.20 × BMI + 0.23 × yaş − 10.8 × (erkek?1:0) − 5.4
class BodyCompositionCard extends StatefulWidget {
  final UserProfile? profile;
  final List<BodyMeasurement> measurements;

  const BodyCompositionCard({
    super.key,
    this.profile,
    required this.measurements,
  });

  @override
  State<BodyCompositionCard> createState() => _BodyCompositionCardState();
}

class _BodyCompositionCardState extends State<BodyCompositionCard> {
  late final TextEditingController _weightC;
  late final TextEditingController _heightC;
  late final TextEditingController _ageC;
  bool _isMale = true;
  double? _fatPct;
  double? _bmi;
  String? _category;
  Color _categoryColor = AppColors.chartGreen;

  @override
  void initState() {
    super.initState();
    final heightCm = widget.profile?.height.toDouble();
    final weightKg = widget.profile?.weight.toDouble();
    final age = widget.profile?.age;

    _weightC = TextEditingController(
        text: weightKg != null ? weightKg.toStringAsFixed(1) : '');
    _heightC = TextEditingController(
        text: heightCm != null ? heightCm.toStringAsFixed(0) : '');
    _ageC = TextEditingController(
        text: age != null ? age.toString() : '');

    if (widget.profile?.gender != null) {
      _isMale = widget.profile!.gender != Gender.female;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculate();
    });
  }

  @override
  void dispose() {
    _weightC.dispose();
    _heightC.dispose();
    _ageC.dispose();
    super.dispose();
  }

  void _calculate() {
    final weight = double.tryParse(_weightC.text.replaceAll(',', '.'));
    final height = double.tryParse(_heightC.text.replaceAll(',', '.'));
    final age = double.tryParse(_ageC.text.replaceAll(',', '.'));

    if (weight == null || height == null || age == null) return;
    if (weight < 20 || weight > 300) return;
    if (height < 100 || height > 250) return;
    if (age < 5 || age > 120) return;

    final heightM = height / 100.0;
    final bmi = weight / (heightM * heightM);
    final sex = _isMale ? 1.0 : 0.0;

    // Deurenberg: BF% = 1.20×BMI + 0.23×yaş − 10.8×cinsiyet − 5.4
    double fat = 1.20 * bmi + 0.23 * age - 10.8 * sex - 5.4;
    fat = fat.clamp(3.0, 60.0);

    // Kategori eşikleri (erkek; kadın +8)
    final offset = _isMale ? 0 : 8;
    String cat;
    Color col;
    if (fat < 6 + offset) {
      cat = 'Düşük Yağ';
      col = AppColors.chartBlue;
    } else if (fat < 14 + offset) {
      cat = 'Atletik';
      col = AppColors.chartGreen;
    } else if (fat < 18 + offset) {
      cat = 'Fit';
      col = const Color(0xFF8BC34A);
    } else if (fat < 25 + offset) {
      cat = 'Ortalama';
      col = AppColors.secondary;
    } else {
      cat = 'Yüksek Yağ';
      col = AppColors.chartRed;
    }

    setState(() {
      _fatPct = fat;
      _bmi = bmi;
      _category = cat;
      _categoryColor = col;
    });
  }

  @override
  Widget build(BuildContext context) {
    final leanMassKg = _fatPct != null
        ? (double.tryParse(_weightC.text.replaceAll(',', '.')) ?? 0) *
            (1 - (_fatPct! / 100))
        : null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top accent bar ──────────────────────────────────────────────
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondary, Color(0xFFFF8A65)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ───────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(Icons.monitor_weight_rounded,
                            color: AppColors.secondary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vücut Kompozisyonu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Deurenberg Formülü · Yağ % tahmini',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bu hesaplama için vücut ölçüsü gerekmez. Kilo, boy, yaş ve cinsiyetle tahmini yağ oranı hesaplanır; ölçü kayıtları ise ekstra takip içindir.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Gender toggle ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    child: Row(
                      children: [
                        _genderBtn(Icons.male_rounded, 'Erkek', true),
                        const SizedBox(width: 4),
                        _genderBtn(Icons.female_rounded, 'Kadın', false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Input fields ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _inputField(_weightC, 'Kilo', 'kg', hint: 'Sabah aç karnına')),
                      const SizedBox(width: 8),
                      Expanded(child: _inputField(_heightC, 'Boy', 'cm', hint: 'Ayakkabısız')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _inputField(_ageC, 'Yaş', 'yıl')),
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Calculate button ──────────────────────────────────────
                  GestureDetector(
                    onTap: _calculate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.secondary, Color(0xFFFF7043)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calculate_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Yağ Oranını Hesapla',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Result ────────────────────────────────────────────────
                  if (_fatPct != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _categoryColor.withValues(alpha: 0.1),
                            _categoryColor.withValues(alpha: 0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _categoryColor.withValues(alpha: 0.28)),
                      ),
                      child: Column(
                        children: [
                          // Main numbers
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 420;
                              final itemWidth = compact
                                  ? (constraints.maxWidth - 12) / 2
                                  : (constraints.maxWidth - 24) / 3;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  _resultMetricCard(
                                    width: itemWidth,
                                    value: '%${_fatPct!.toStringAsFixed(1)}',
                                    label: 'Yağ Oranı',
                                    color: _categoryColor,
                                    big: true,
                                  ),
                                  _resultMetricCard(
                                    width: itemWidth,
                                    value: _bmi!.toStringAsFixed(1),
                                    label: 'VKİ (BMI)',
                                    color: Colors.white,
                                  ),
                                  _resultMetricCard(
                                    width: itemWidth,
                                    value: '${(leanMassKg ?? 0).toStringAsFixed(1)} kg',
                                    label: 'Yağsız Kütle',
                                    color: const Color(0xFF9AD9FF),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                            decoration: BoxDecoration(
                              color: _categoryColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _categoryColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              _category!,
                              style: TextStyle(
                                color: _categoryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Spectrum bar
                          _buildCategorySpectrum(),
                          const SizedBox(height: 10),
                          Text(
                            '* Tahminî değer. Gerçek ölçüm için DEXA gereklidir.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.28),
                              fontSize: 10,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySpectrum() {
    final offset = _isMale ? 0 : 8;
    final double maxVal = 45.0 + offset;
    final segments = [
      (label: 'Düşük', end: (6 + offset).toDouble(), color: AppColors.chartBlue),
      (label: 'Atletik', end: (14 + offset).toDouble(), color: AppColors.chartGreen),
      (label: 'Fit', end: (18 + offset).toDouble(), color: const Color(0xFF8BC34A)),
      (label: 'Ortalama', end: (25 + offset).toDouble(), color: AppColors.secondary),
      (label: 'Yüksek', end: maxVal, color: AppColors.chartRed),
    ];

    final fracs = <double>[];
    double prev = 0;
    for (final s in segments) {
      fracs.add((s.end - prev) / maxVal);
      prev = s.end;
    }
    final markerFrac = (_fatPct! / maxVal).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (context, constraints) {
      final totalW = constraints.maxWidth;
      return Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: List.generate(segments.length, (i) {
                    return Expanded(
                      flex: (fracs[i] * 100).round().clamp(1, 100),
                      child: Container(
                        height: 12,
                        color: segments[i].color.withValues(alpha: 0.45),
                      ),
                    );
                  }),
                ),
              ),
              Positioned(
                left: (markerFrac * totalW - 3).clamp(0, totalW - 6),
                top: -2,
                child: Container(
                  width: 6,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(segments.length, (i) {
              return Expanded(
                flex: (fracs[i] * 100).round().clamp(1, 100),
                child: Text(
                  segments[i].label,
                  style: TextStyle(
                    color: segments[i].color.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
      );
    });
  }

  Widget _resultMetricCard({
    required double width,
    required String value,
    required String label,
    required Color color,
    bool big = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: big ? 40 : 28,
                fontWeight: FontWeight.w900,
                letterSpacing: big ? -1.8 : -0.8,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.46),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderBtn(IconData icon, String label, bool isMale) {
    final selected = _isMale == isMale;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _isMale = isMale;
          _fatPct = null;
          _bmi = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.secondary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.secondary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? AppColors.secondary : Colors.white38),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.secondary : Colors.white38,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController c, String label, String unit, {String? hint}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: '$label ($unit)',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
        ),
        helperText: hint,
        helperStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontSize: 10,
        ),
        suffixText: unit,
        suffixStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 12,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
      ),
    );
  }
}
