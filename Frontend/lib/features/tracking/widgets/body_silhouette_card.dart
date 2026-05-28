import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/body_measurement.dart';

class BodySilhouetteCard extends StatefulWidget {
  final BodyMeasurement? measurement;

  const BodySilhouetteCard({super.key, this.measurement});

  @override
  State<BodySilhouetteCard> createState() => _BodySilhouetteCardState();
}

class _BodySilhouetteCardState extends State<BodySilhouetteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.measurement;

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
            // ── Başlık ──────────────────────────────────────────────────────
            Row(
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
                const SizedBox(width: 12),
                const Text(
                  'Vücut Haritası',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                if (m == null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ölçüm yok',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── İçerik: Siluet + Ölçüm Listesi ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Siluet
                SizedBox(
                  width: 140,
                  height: 260,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => CustomPaint(
                      painter: _BodySilhouettePainter(
                        measurement: m,
                        dotPulse: _pulseAnim.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Ölçüm değerleri listesi
                Expanded(
                  child: _MeasurementList(measurement: m),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ölçüm Değerleri Listesi ──────────────────────────────────────────────────

class _MeasurementList extends StatelessWidget {
  final BodyMeasurement? measurement;

  const _MeasurementList({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    final items = <_MeasureItem>[
      _MeasureItem('Göğüs', m?.chest, Icons.expand_rounded),
      _MeasureItem('Bel', m?.waist, Icons.compress_rounded),
      _MeasureItem('Kalça', m?.hips, Icons.airline_seat_recline_normal_rounded),
      _MeasureItem('Sol Kol', m?.leftArm, Icons.fitness_center_rounded),
      _MeasureItem('Sağ Kol', m?.rightArm, Icons.fitness_center_rounded),
      _MeasureItem('Sol Bacak', m?.leftLeg, Icons.directions_walk_rounded),
      _MeasureItem('Sağ Bacak', m?.rightLeg, Icons.directions_walk_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => _buildRow(item)).toList(),
    );
  }

  Widget _buildRow(_MeasureItem item) {
    final hasValue = item.value != null;
    final color = hasValue ? AppColors.primaryLight : Colors.white30;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            hasValue ? '${item.value!.toStringAsFixed(1)} cm' : '—',
            style: TextStyle(
              color: hasValue ? Colors.white : Colors.white30,
              fontSize: 12,
              fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasureItem {
  final String label;
  final double? value;
  final IconData icon;

  const _MeasureItem(this.label, this.value, this.icon);
}

// ── CustomPainter ────────────────────────────────────────────────────────────

class _BodySilhouettePainter extends CustomPainter {
  final BodyMeasurement? measurement;
  final double dotPulse;

  _BodySilhouettePainter({required this.measurement, required this.dotPulse});

  static const _dotActive = AppColors.primaryLight;
  static const _dotInactive = Color(0xFF555566);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fill = Paint()
      ..color = const Color(0x30FFFFFF)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = const Color(0x55FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // ── Oransal noktalar ────────────────────────────────────────────────────
    final headCx = w * 0.50;
    final headCy = h * 0.068;
    final headR  = w * 0.115;

    final neckTopY    = headCy + headR * 0.80;
    final neckBottomY = neckTopY + h * 0.042;

    final torsoTopY    = neckBottomY;
    final torsoBottomY = h * 0.620;

    final shlLX = w * 0.155;
    final shlRX = w * 0.845;
    final shlY  = torsoTopY + h * 0.026;

    final aptLX = w * 0.210;
    final aptRX = w * 0.790;
    final aptY  = torsoTopY + h * 0.095;

    final wstLX = w * 0.300;
    final wstRX = w * 0.700;
    final wstY  = torsoTopY + h * 0.230;

    final hipLX = w * 0.255;
    final hipRX = w * 0.745;
    final hipY  = torsoBottomY;

    // ── Baş ─────────────────────────────────────────────────────────────────
    canvas.drawCircle(Offset(headCx, headCy), headR, fill);
    canvas.drawCircle(Offset(headCx, headCy), headR, stroke);

    // ── Boyun (hafif trapez) ─────────────────────────────────────────────────
    final neckPath = Path()
      ..moveTo(w * 0.453, neckTopY)
      ..lineTo(w * 0.432, neckBottomY)
      ..lineTo(w * 0.568, neckBottomY)
      ..lineTo(w * 0.547, neckTopY)
      ..close();
    canvas.drawPath(neckPath, fill);
    canvas.drawPath(neckPath, stroke);

    // ── Gövde (bezier eğrileri) ──────────────────────────────────────────────
    final torso = Path()
      ..moveTo(w * 0.432, torsoTopY)
      // sol: boyun tabanı → omuz
      ..cubicTo(w * 0.33, torsoTopY, shlLX, torsoTopY, shlLX, shlY)
      // sol: omuz kapağı → koltukaltı
      ..cubicTo(shlLX - w * 0.015, shlY + h * 0.030,
                aptLX - w * 0.015, aptY - h * 0.010,
                aptLX, aptY)
      // sol: koltukaltı → bel (içe kavis)
      ..cubicTo(aptLX, aptY + h * 0.060,
                wstLX, wstY - h * 0.030,
                wstLX, wstY)
      // sol: bel → kalça (dışa kavis)
      ..cubicTo(wstLX, wstY + h * 0.055,
                hipLX, hipY - h * 0.040,
                hipLX, hipY)
      // kasık (V şekli)
      ..cubicTo(hipLX + w * 0.035, hipY + h * 0.022,
                w * 0.44,          hipY + h * 0.016,
                w * 0.50,          hipY)
      ..cubicTo(w * 0.56,          hipY + h * 0.016,
                hipRX - w * 0.035, hipY + h * 0.022,
                hipRX, hipY)
      // sağ: kalça → bel
      ..cubicTo(hipRX, hipY - h * 0.040,
                wstRX, wstY + h * 0.055,
                wstRX, wstY)
      // sağ: bel → koltukaltı
      ..cubicTo(wstRX, wstY - h * 0.030,
                aptRX, aptY + h * 0.060,
                aptRX, aptY)
      // sağ: koltukaltı → omuz kapağı
      ..cubicTo(aptRX + w * 0.015, aptY - h * 0.010,
                shlRX + w * 0.015, shlY + h * 0.030,
                shlRX, shlY)
      // sağ: omuz → boyun tabanı
      ..cubicTo(shlRX, torsoTopY, w * 0.67, torsoTopY, w * 0.568, torsoTopY)
      ..close();
    canvas.drawPath(torso, fill);
    canvas.drawPath(torso, stroke);

    // ── Kollar ───────────────────────────────────────────────────────────────
    final elbowLX = w * 0.072;
    final elbowLY = aptY + h * 0.150;
    final wristLX = w * 0.062;
    final wristLY = aptY + h * 0.295;

    final elbowRX = w * 0.928;
    final elbowRY = aptY + h * 0.150;
    final wristRX = w * 0.938;
    final wristRY = aptY + h * 0.295;

    // Sol üst kol
    _drawTaperedLimb(canvas,
      start: Offset(shlLX + w * 0.025, shlY + h * 0.010),
      end: Offset(elbowLX, elbowLY),
      startWidth: w * 0.082, endWidth: w * 0.069,
      fill: fill, stroke: stroke);
    // Sol önkol
    _drawTaperedLimb(canvas,
      start: Offset(elbowLX, elbowLY),
      end: Offset(wristLX, wristLY),
      startWidth: w * 0.067, endWidth: w * 0.052,
      fill: fill, stroke: stroke);

    // Sağ üst kol
    _drawTaperedLimb(canvas,
      start: Offset(shlRX - w * 0.025, shlY + h * 0.010),
      end: Offset(elbowRX, elbowRY),
      startWidth: w * 0.082, endWidth: w * 0.069,
      fill: fill, stroke: stroke);
    // Sağ önkol
    _drawTaperedLimb(canvas,
      start: Offset(elbowRX, elbowRY),
      end: Offset(wristRX, wristRY),
      startWidth: w * 0.067, endWidth: w * 0.052,
      fill: fill, stroke: stroke);

    // ── Bacaklar ─────────────────────────────────────────────────────────────
    final kneeLX  = w * 0.355;
    final kneeLY  = h * 0.778;
    final ankleLX = w * 0.338;
    final ankleLY = h * 0.958;

    final kneeRX  = w * 0.645;
    final kneeRY  = h * 0.778;
    final ankleRX = w * 0.662;
    final ankleRY = h * 0.958;

    // Sol uyluk
    _drawTaperedLimb(canvas,
      start: Offset(hipLX + w * 0.065, hipY),
      end: Offset(kneeLX, kneeLY),
      startWidth: w * 0.118, endWidth: w * 0.090,
      fill: fill, stroke: stroke);
    // Sol baldır
    _drawTaperedLimb(canvas,
      start: Offset(kneeLX, kneeLY),
      end: Offset(ankleLX, ankleLY),
      startWidth: w * 0.088, endWidth: w * 0.062,
      fill: fill, stroke: stroke);

    // Sağ uyluk
    _drawTaperedLimb(canvas,
      start: Offset(hipRX - w * 0.065, hipY),
      end: Offset(kneeRX, kneeRY),
      startWidth: w * 0.118, endWidth: w * 0.090,
      fill: fill, stroke: stroke);
    // Sağ baldır
    _drawTaperedLimb(canvas,
      start: Offset(kneeRX, kneeRY),
      end: Offset(ankleRX, ankleRY),
      startWidth: w * 0.088, endWidth: w * 0.062,
      fill: fill, stroke: stroke);

    // ── Ölçüm Noktaları ─────────────────────────────────────────────────────
    final m = measurement;
    _drawDot(canvas, Offset(w * 0.50, torsoTopY + h * 0.085), m?.chest    != null); // Göğüs
    _drawDot(canvas, Offset(w * 0.50, wstY),                  m?.waist    != null); // Bel
    _drawDot(canvas, Offset(w * 0.50, hipY - h * 0.020),      m?.hips     != null); // Kalça
    _drawDot(canvas, Offset(elbowLX + w * 0.022, elbowLY - h * 0.038), m?.leftArm  != null); // Sol Kol
    _drawDot(canvas, Offset(elbowRX - w * 0.022, elbowRY - h * 0.038), m?.rightArm != null); // Sağ Kol
    _drawDot(canvas, Offset(kneeLX + w * 0.010, kneeLY - h * 0.042),   m?.leftLeg  != null); // Sol Bacak
    _drawDot(canvas, Offset(kneeRX - w * 0.010, kneeRY - h * 0.042),   m?.rightLeg != null); // Sağ Bacak
  }

  void _drawTaperedLimb(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required double startWidth,
    required double endWidth,
    required Paint fill,
    required Paint stroke,
  }) {
    final dir  = end - start;
    final dist = dir.distance;
    if (dist < 0.1) return;
    final perp = Offset(-dir.dy / dist, dir.dx / dist);
    final p1 = start + perp * (startWidth / 2);
    final p2 = start - perp * (startWidth / 2);
    final p3 = end   - perp * (endWidth   / 2);
    final p4 = end   + perp * (endWidth   / 2);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawDot(Canvas canvas, Offset center, bool active) {
    final color  = active ? _dotActive : _dotInactive;
    final outerR = active ? 7.0 * dotPulse : 5.0;
    final innerR = active ? 4.5 : 3.5;

    if (active) {
      final glowPaint = Paint()
        ..color = _dotActive.withValues(alpha: 0.25 * dotPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, outerR + 2, glowPaint);
    }
    canvas.drawCircle(center, outerR, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(center, innerR, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BodySilhouettePainter old) =>
      old.measurement != measurement || old.dotPulse != dotPulse;
}

// end of body_silhouette_card.dart
