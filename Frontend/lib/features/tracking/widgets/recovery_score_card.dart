import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../workout/services/recovery_engine.dart';
import '../providers/tracking_provider.dart';

class RecoveryScoreCard extends StatefulWidget {
  final WorkoutProvider workoutProvider;
  final double waterLiters;

  const RecoveryScoreCard({
    super.key,
    required this.workoutProvider,
    required this.waterLiters,
  });

  @override
  State<RecoveryScoreCard> createState() => _RecoveryScoreCardState();
}

class _RecoveryScoreCardState extends State<RecoveryScoreCard> {
  static const _green = Color(0xFF30D158);
  static const _purple = Color(0xFFBF5AF2);
  static const _cyan = Color(0xFF32ADE6);
  static const _orange = Color(0xFFFF9F0A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackingProvider>().loadSleep();
    });
  }

  Future<void> _saveSleep(double hours) async {
    await context.read<TrackingProvider>().saveSleep(hours);
  }

  int _computeScore(Map<String, FatigueStatus> fatigue, double sleepHours) {
    final muscleAvg = fatigue.isEmpty
        ? 1.0
        : fatigue.values.map((s) => s.recoveryPercent).reduce((a, b) => a + b) /
              fatigue.length;
    final sleepScore = (sleepHours / 8.0).clamp(0.0, 1.0);
    final hydrationScore = (widget.waterLiters / 2.5).clamp(0.0, 1.0);
    return ((muscleAvg * 0.55 + sleepScore * 0.30 + hydrationScore * 0.15) *
            100)
        .round()
        .clamp(0, 100);
  }

  Color _scoreColor(int score) {
    if (score >= 75) return _green;
    if (score >= 50) return const Color(0xFFFFD60A);
    return const Color(0xFFFF453A);
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Hazır';
    if (score >= 65) return 'İyi';
    if (score >= 45) return 'Orta';
    return 'Yorgun';
  }

  String _scoreMessage(int score) {
    if (score >= 80) return 'Ağır antrenman için\niyi bir gün.';
    if (score >= 65) return 'Planlı antrenmanı\nkontrollü uygula.';
    if (score >= 45) return 'Orta tempo ve\nteknik odak iyi olur.';
    return 'Bugün dinlenmeyi\nöne almak daha iyi.';
  }

  String _readinessHint({
    required int score,
    required double muscleAvg,
    required double sleepPct,
    required double hydrationPct,
  }) {
    final gaps = <({String label, double value})>[
      (label: 'Uyku', value: sleepPct),
      (label: 'Hidrasyon', value: hydrationPct),
      (label: 'Kas toparlanması', value: muscleAvg),
    ]..sort((a, b) => a.value.compareTo(b.value));
    if (score >= 80) return 'Hazırlık güçlü';
    return '${gaps.first.label} skoru düşürüyor';
  }

  @override
  Widget build(BuildContext context) {
    final trackingProv = context.watch<TrackingProvider>();
    final sleepHours = trackingProv.sleepHours;

    final fatigue = RecoveryEngine.computeAll(widget.workoutProvider.workouts);
    final muscleAvg = fatigue.isEmpty
        ? 1.0
        : fatigue.values.map((s) => s.recoveryPercent).reduce((a, b) => a + b) /
              fatigue.length;
    final sleepPct = (sleepHours / 8.0).clamp(0.0, 1.0);
    final hydrationPct = (widget.waterLiters / 2.5).clamp(0.0, 1.0);
    final score = _computeScore(fatigue, sleepHours);
    final color = _scoreColor(score);
    final hint = _readinessHint(
      score: score,
      muscleAvg: muscleAvg,
      sleepPct: sleepPct,
      hydrationPct: hydrationPct,
    );
    final freshGroups = fatigue.entries
        .where((e) => e.value.level == FatigueLevel.fresh)
        .take(4)
        .toList();
    final tiredGroups = fatigue.entries
        .where((e) => e.value.level == FatigueLevel.fatigued)
        .take(3)
        .toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.09),
            const Color(0xFF13131F),
            const Color(0xFF0F0F1C),
          ],
          stops: const [0.0, 0.38, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Colored accent strip ─────────────────────────────────────────────
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.15)],
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  child: Icon(
                    Icons.monitor_heart_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toparlanma Skoru',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Ring + sağ panel ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ring (tıklanabilir → breakdown)
                GestureDetector(
                  onTap: () => _showBreakdownSheet(
                    context,
                    score: score,
                    muscleAvg: muscleAvg,
                    sleepPct: sleepPct,
                    hydrationPct: hydrationPct,
                  ),
                  child: Column(
                    children: [
                      _ScoreRing(score: score, color: color, size: 112),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: color.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          _scoreLabel(score),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 9,
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'detay',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.16),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Sağ kolon: mesaj + metrikler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mesaj kutusu — sol şeritli quote card
                      Container(
                        padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 44,
                              margin: const EdgeInsets.only(
                                left: 12,
                                right: 10,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _scoreMessage(score),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  fontSize: 12.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _miniMetric(
                        icon: Icons.fitness_center_rounded,
                        label: 'Kas',
                        value: '${(muscleAvg * 100).round()}%',
                        pct: muscleAvg,
                        metricColor: _green,
                        weightLabel: '%55',
                      ),
                      const SizedBox(height: 7),
                      _miniMetric(
                        icon: Icons.bedtime_rounded,
                        label: 'Uyku',
                        value: sleepHours == 0
                            ? '--'
                            : '${sleepHours.toStringAsFixed(1)}s',
                        pct: sleepPct,
                        metricColor: _purple,
                        weightLabel: '%30',
                        missing: sleepHours == 0,
                      ),
                      const SizedBox(height: 7),
                      _miniMetric(
                        icon: Icons.water_drop_rounded,
                        label: 'Su',
                        value: '${widget.waterLiters.toStringAsFixed(1)}L',
                        pct: hydrationPct,
                        metricColor: _cyan,
                        weightLabel: '%15',
                        missing: widget.waterLiters == 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Uyku eksik uyarısı ──────────────────────────────────────────────
          if (true && sleepHours == 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orange.withValues(alpha: 0.22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bedtime_rounded,
                        size: 14,
                        color: _orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Uyku girilmedi',
                            style: TextStyle(
                              color: _orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Skor eksik hesaplanıyor — aşağıdan gir',
                            style: TextStyle(
                              color: _orange.withValues(alpha: 0.65),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Uyku girişi ─────────────────────────────────────────────────────
          if (true) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sleepHours > 0
                      ? _purple.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sleepHours > 0
                        ? _purple.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bedtime_rounded,
                          size: 14,
                          color: sleepHours > 0
                              ? _purple
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Dün gece kaç saat uyudun?',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Text(
                            sleepHours == 0
                                ? 'Gir'
                                : '${sleepHours.toStringAsFixed(1)} saat',
                            key: ValueKey(sleepHours == 0),
                            style: TextStyle(
                              color: sleepHours == 0
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : _purple,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 9,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                        tickMarkShape: SliderTickMarkShape.noTickMark,
                        activeTrackColor: sleepHours > 0
                            ? _purple.withValues(alpha: 0.70)
                            : Colors.white.withValues(alpha: 0.22),
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.07,
                        ),
                        thumbColor: sleepHours > 0 ? _purple : Colors.white,
                        overlayColor: _purple.withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        value: sleepHours,
                        min: 0,
                        max: 12,
                        divisions: 24,
                        onChanged: _saveSleep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _SleepChip(
                          label: '6s',
                          selected: sleepHours == 6,
                          color: _purple,
                          onTap: () => _saveSleep(6),
                        ),
                        const SizedBox(width: 7),
                        _SleepChip(
                          label: '7.5s',
                          selected: sleepHours == 7.5,
                          color: _purple,
                          onTap: () => _saveSleep(7.5),
                        ),
                        const SizedBox(width: 7),
                        _SleepChip(
                          label: '8s',
                          selected: sleepHours == 8,
                          color: _purple,
                          onTap: () => _saveSleep(8),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 10,
                              color: _purple.withValues(alpha: 0.38),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hedef 8s',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.28),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Kas durumu ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        size: 12,
                        color: _green.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Kas Durumu',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    if (freshGroups.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: _green.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          '${freshGroups.length} hazır',
                          style: TextStyle(
                            color: _green.withValues(alpha: 0.80),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (freshGroups.isEmpty && tiredGroups.isEmpty)
                  Text(
                    'Antrenman geçmişi geldikçe kas toparlanması burada görünür.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      ...freshGroups.map(
                        (e) => _MuscleChip(
                          label: _muscleLabel(e.key),
                          ready: true,
                        ),
                      ),
                      ...tiredGroups.map(
                        (e) => _MuscleChip(
                          label: _muscleLabel(e.key),
                          ready: false,
                          remainingHours: e.value.remainingHours,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric({
    required IconData icon,
    required String label,
    required String value,
    required double pct,
    required Color metricColor,
    required String weightLabel,
    bool missing = false,
  }) {
    final effectiveColor = missing ? _orange : metricColor;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: effectiveColor),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 27,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: missing
              ? Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: _orange.withValues(alpha: 0.14),
                    border: Border.all(
                      color: _orange.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: val,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation(
                        metricColor.withValues(alpha: 0.85),
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: missing ? _orange : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            weightLabel,
            style: TextStyle(
              color: effectiveColor.withValues(alpha: 0.70),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  void _showBreakdownSheet(
    BuildContext context, {
    required int score,
    required double muscleAvg,
    required double sleepPct,
    required double hydrationPct,
  }) {
    final musclePoints = (muscleAvg * 55).round();
    final sleepPoints = (sleepPct * 30).round();
    final hydPoints = (hydrationPct * 15).round();
    final color = _scoreColor(score);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).padding.bottom + 28,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF181828),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Icon(
                    Icons.monitor_heart_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Skor Nasıl Hesaplanır?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Üç faktör farklı ağırlıklarla etkiler',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.40),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _breakdownRow(
              icon: Icons.fitness_center_rounded,
              label: 'Kas Toparlanması',
              color: _green,
              weight: '%55 etki',
              points: musclePoints,
              maxPoints: 55,
              hint: 'Son antrenmanlarına göre hesaplanır.',
            ),
            const SizedBox(height: 16),
            _breakdownRow(
              icon: Icons.bedtime_rounded,
              label: 'Uyku Süresi',
              color: _purple,
              weight: '%30 etki',
              points: sleepPoints,
              maxPoints: 30,
              hint: sleepPct == 0
                  ? 'Uyku girilmedi — 0 puan alıyor'
                  : 'Hedef 8 saat üzerinden hesaplanır.',
              warning: sleepPct == 0,
            ),
            const SizedBox(height: 16),
            _breakdownRow(
              icon: Icons.water_drop_rounded,
              label: 'Hidrasyon',
              color: _cyan,
              weight: '%15 etki',
              points: hydPoints,
              maxPoints: 15,
              hint: 'Hedef 2.5L üzerinden hesaplanır.',
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Text(
                    'Toplam Skor',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$musclePoints + $sleepPoints + $hydPoints',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '  =  ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    ' /100',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.30),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow({
    required IconData icon,
    required String label,
    required Color color,
    required String weight,
    required int points,
    required int maxPoints,
    required String hint,
    bool warning = false,
  }) {
    final effectiveColor = warning ? _orange : color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: effectiveColor.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, color: effectiveColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '$points / $maxPoints puan',
                      style: TextStyle(
                        color: effectiveColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: maxPoints == 0 ? 0 : points / maxPoints,
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, val, child) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: val,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(
                      effectiveColor.withValues(alpha: 0.80),
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$weight  ·  $hint',
                style: TextStyle(
                  color: warning
                      ? _orange.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _muscleLabel(String key) {
    const map = {
      'LEGS': 'Bacak',
      'BACK': 'Sırt',
      'CHEST': 'Göğüs',
      'SHOULDERS': 'Omuz',
      'BICEPS': 'Biseps',
      'TRICEPS': 'Triseps',
      'CORE': 'Core',
      'GLUTES': 'Kalça',
    };
    return map[key] ?? key;
  }
}

// ── Score Ring ───────────────────────────────────────────────────────────────

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  final double size;

  const _ScoreRing({
    required this.score,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: size * 0.88,
            height: size * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          // Outer faint track ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 1.5,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          // Animated progress ring
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100.0),
              duration: const Duration(milliseconds: 1300),
              curve: Curves.easeOutCubic,
              builder: (_, val, child) => CircularProgressIndicator(
                value: val,
                strokeWidth: 9,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: score),
                duration: const Duration(milliseconds: 1300),
                curve: Curves.easeOutCubic,
                builder: (_, val, child) => Text(
                  '$val',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.28,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
              Text(
                '/100',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: size * 0.10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sleep Chip ───────────────────────────────────────────────────────────────

class _SleepChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SleepChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.09),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Muscle Chip ──────────────────────────────────────────────────────────────

class _MuscleChip extends StatelessWidget {
  final String label;
  final bool ready;
  final int? remainingHours;

  const _MuscleChip({
    required this.label,
    required this.ready,
    this.remainingHours,
  });

  static const _green = Color(0xFF30D158);
  static const _red = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final color = ready ? _green : _red;
    final bgColor = color.withValues(alpha: 0.08);
    final borderColor = color.withValues(alpha: ready ? 0.22 : 0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_rounded : Icons.schedule_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            remainingHours != null ? '$label  ${remainingHours}s' : label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
