import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../../../core/widgets/ambient_glow_background.dart';
import '../../../../core/widgets/premium_state_badge.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/repositories/diary_repository.dart';
import '../state/diet_provider.dart';

class NutritionTrendsPage extends StatefulWidget {
  const NutritionTrendsPage({super.key});

  @override
  State<NutritionTrendsPage> createState() => _NutritionTrendsPageState();
}

class _NutritionTrendsPageState extends State<NutritionTrendsPage> {
  int _selectedDays = 7;
  Map<String, DiaryTotals> _trendData = {};
  bool _loading = true;
  bool _hasError = false;
  bool _isPremium = false;

  // Makro sekme: 0=Kalori, 1=Protein, 2=Karb, 3=Yağ
  int _activeTab = 0;

  static const _tabs = ['Kalori', 'Protein', 'Karb', 'Yağ'];
  static const _tabColors = [
    AppColors.secondary,
    Color(0xFF5B9BFF),
    Color(0xFF4CD1A3),
    Color(0xFFFFB74D),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _loading = true; _hasError = false; });
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final isPremium =
          Provider.of<AuthProvider>(context, listen: false).user?.premiumTier ==
          'premium';
      // Tüm günler için gerçek veri çek (weeklySummary değil)
      final data = await provider.getSummaryForRange(_selectedDays);
      if (mounted) {
        setState(() {
          _isPremium = isPremium;
          _trendData = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('NutritionTrendsPage._loadData error: $e');
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  // ─── Hesaplanan değerler ─────────────────────────────────────────────────

  List<String> get _sortedKeys => _trendData.keys.toList()..sort();

  List<double> _valuesFor(int tab) => _sortedKeys.map((k) {
        final t = _trendData[k]!;
        return switch (tab) {
          0 => t.totalKcal,
          1 => t.totalProtein,
          2 => t.totalCarb,
          3 => t.totalFat,
          _ => t.totalKcal,
        };
      }).toList();

  bool get _hasAnyData =>
      _trendData.values.any((t) => t.totalKcal > 0);

  int get _streakDays {
    final keys = _sortedKeys.reversed.toList();
    int streak = 0;
    for (final k in keys) {
      if ((_trendData[k]?.totalKcal ?? 0) > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Beslenme Trendleri',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: AppGradientBackground(
        child: Stack(
          children: [
            const AmbientGlowBackground(),
            Positioned.fill(
              child: SafeArea(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.secondary),
                        ),
                      )
                    : _hasError
                        ? _buildErrorState()
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: AppColors.secondary,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_isPremium) _buildPremiumBadge(),
                                  const SizedBox(height: 12),
                                  _buildDaySelector(),
                                  const SizedBox(height: 16),
                                  if (!_hasAnyData)
                                    _buildEmptyState()
                                  else ...[
                                    _buildSummaryRow(),
                                    const SizedBox(height: 14),
                                    _buildTrendCard(),
                                    const SizedBox(height: 14),
                                    _buildTargetHitRateCard(),
                                    const SizedBox(height: 14),
                                    _buildMacroDistributionCard(),
                                    const SizedBox(height: 14),
                                    _buildStatsCard(),
                                  ],
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Boş durum ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_rounded,
              size: 52, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'Henüz veri yok',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Öğün ekledikçe trend grafiklerin\nburada belirmeye başlayacak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 56, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          const Text('Veriler yüklenemedi',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }

  // ─── Premium banner ──────────────────────────────────────────────────────

  Widget _buildPremiumBadge() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const PremiumStateBadge(active: true, compact: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Premium analiz açık. Daha derin trend verilerini görüntülüyorsun.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── Gün seçici ─────────────────────────────────────────────────────────

  Widget _buildDaySelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              _dayChip(7, 'Son 7 Gün'),
              _dayChip(14, 'Son 14 Gün'),
              _dayChip(30, 'Son 30 Gün'),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _dayChip(int days, String label) {
    final isSelected = _selectedDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedDays == days) return;
          setState(() => _selectedDays = days);
          _loadData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.secondary.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Özet satırı (streak + aktif gün) ──────────────────────────────────

  Widget _buildSummaryRow() {
    final nonZero = _trendData.values.where((t) => t.totalKcal > 0).length;
    final streak = _streakDays;
    final avgKcal = nonZero > 0
        ? _trendData.values
                .map((t) => t.totalKcal)
                .reduce((a, b) => a + b) /
            nonZero
        : 0.0;

    return Row(
      children: [
        _summaryTile(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF6B35),
          label: 'Seri',
          value: '$streak gün',
        ),
        const SizedBox(width: 10),
        _summaryTile(
          icon: Icons.calendar_today_rounded,
          color: const Color(0xFF4CD1A3),
          label: 'Aktif Gün',
          value: '$nonZero / $_selectedDays',
        ),
        const SizedBox(width: 10),
        _summaryTile(
          icon: Icons.analytics_rounded,
          color: AppColors.secondary,
          label: 'Günlük Ort.',
          value: '${avgKcal.round()} kcal',
        ),
      ],
    ).animate().fadeIn(delay: 50.ms, duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _summaryTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Trend çizgi/çubuk grafiği ──────────────────────────────────────────

  Widget _buildTrendCard() {
    final values = _valuesFor(_activeTab);
    final maxVal = values.isNotEmpty
        ? values.reduce((a, b) => a > b ? a : b)
        : 100.0;
    final color = _tabColors[_activeTab];
    final targetKcal = _activeTab == 0
        ? Provider.of<DietProvider>(context, listen: false).dailyTargetKcal
        : null;
    final unit = _activeTab == 0 ? 'kcal' : 'g';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık + hedef
              Row(
                children: [
                  Text(
                    'Trend Grafiği',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (targetKcal != null) ...[
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 2,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.chartRed.withValues(alpha: 0.7),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Hedef ${targetKcal.round()} kcal',
                          style: TextStyle(
                            color: AppColors.chartRed.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Makro sekmeleri
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final isActive = _activeTab == i;
                    return GestureDetector(
                      onTap: () => setState(() => _activeTab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _tabColors[i].withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? _tabColors[i].withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            color: isActive
                                ? _tabColors[i]
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // Grafik
              SizedBox(
                height: 190,
                child: LineChart(
                  duration: const Duration(milliseconds: 300),
                  LineChartData(
                    minY: 0,
                    maxY: maxVal > 0 ? maxVal * 1.25 : 100,
                    extraLinesData: targetKcal != null
                        ? ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: targetKcal,
                                color: AppColors.chartRed.withValues(alpha: 0.55),
                                strokeWidth: 1.5,
                                dashArray: [6, 4],
                                label: HorizontalLineLabel(show: false),
                              ),
                            ],
                          )
                        : const ExtraLinesData(),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 38,
                          interval: maxVal > 0 ? maxVal / 3 : 33,
                          getTitlesWidget: (v, m) => Text(
                            v.round().toString(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: _selectedDays <= 7
                              ? 1
                              : _selectedDays <= 14
                                  ? 2
                                  : 5,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            final keys = _sortedKeys;
                            if (idx < 0 || idx >= keys.length) {
                              return const SizedBox.shrink();
                            }
                            final parts = keys[idx].split('-');
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                parts.length >= 3
                                    ? '${parts[2]}/${parts[1]}'
                                    : '',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxVal > 0 ? maxVal / 4 : 25,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.white.withValues(alpha: 0.06),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          _sortedKeys.length,
                          (i) => FlSpot(i.toDouble(), values[i]),
                        ),
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: color,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: _selectedDays <= 14,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: spot.y > 0 ? 4 : 2,
                                color: spot.y > 0 ? color : Colors.white24,
                                strokeWidth: 2,
                                strokeColor: AppColors.surface,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.25),
                              color.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 10,
                        tooltipBgColor:
                            AppColors.surface.withValues(alpha: 0.92),
                        getTooltipItems: (spots) => spots
                            .map(
                              (s) => LineTooltipItem(
                                s.y > 0
                                    ? '${s.y.round()} $unit'
                                    : 'Veri yok',
                                TextStyle(
                                  color: s.y > 0 ? color : Colors.white38,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 400.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ─── Hedef isabet oranı ─────────────────────────────────────────────────

  Widget _buildTargetHitRateCard() {
    final targetKcal =
        Provider.of<DietProvider>(context, listen: false).dailyTargetKcal;
    if (targetKcal == null || targetKcal <= 0) return const SizedBox.shrink();

    final sortedKeys = _sortedKeys;
    final activeDays =
        sortedKeys.where((k) => _trendData[k]!.totalKcal > 0).toList();
    if (activeDays.isEmpty) return const SizedBox.shrink();

    int hitCount = 0;
    final dotData = <({String date, double kcal, Color color})>[];
    for (final key in sortedKeys) {
      final kcal = _trendData[key]!.totalKcal;
      if (kcal <= 0) {
        dotData.add((date: key, kcal: 0, color: Colors.white12));
        continue;
      }
      final ratio = kcal / targetKcal;
      Color col;
      if (ratio >= 0.8 && ratio <= 1.2) {
        col = AppColors.chartGreen;
        hitCount++;
      } else if (ratio >= 0.65 && ratio <= 1.35) {
        col = AppColors.secondary;
      } else {
        col = AppColors.chartRed;
      }
      dotData.add((date: key, kcal: kcal, color: col));
    }

    final hitRate = (hitCount / activeDays.length * 100).round();
    final Color rateColor;
    final String rateLabel;
    if (hitRate >= 80) {
      rateColor = AppColors.chartGreen;
      rateLabel = 'Mükemmel tutarlılık!';
    } else if (hitRate >= 60) {
      rateColor = AppColors.secondary;
      rateLabel = 'İyi gidiyorsun';
    } else {
      rateColor = AppColors.chartRed;
      rateLabel = 'Daha tutarlı olmaya çalış';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: rateColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.track_changes_rounded,
                        color: rateColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hedef İsabet Oranı',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '±%20 aralığında hedef: ${targetKcal.round()} kcal',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '%$hitRate',
                    style: TextStyle(
                      color: rateColor,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rateLabel,
                            style: TextStyle(
                                color: rateColor.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text('$hitCount / ${activeDays.length} aktif gün',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: dotData.map((d) {
                  return Tooltip(
                    message: d.kcal > 0
                        ? '${d.date.substring(5)}: ${d.kcal.round()} kcal'
                        : d.date.substring(5),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: d.color.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: d.color.withValues(alpha: 0.6), width: 1.5),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _dotLegend(AppColors.chartGreen, '±%20 içinde'),
                  const SizedBox(width: 14),
                  _dotLegend(AppColors.secondary, '±%35 içinde'),
                  const SizedBox(width: 14),
                  _dotLegend(AppColors.chartRed, 'Uzak'),
                  const SizedBox(width: 14),
                  _dotLegend(Colors.white12, 'Veri yok'),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 400.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _dotLegend(Color color, String label) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 10)),
        ],
      );

  // ─── Makro dağılımı pasta ────────────────────────────────────────────────

  Widget _buildMacroDistributionCard() {
    double totalP = 0, totalC = 0, totalF = 0;
    for (final t in _trendData.values) {
      totalP += t.totalProtein;
      totalC += t.totalCarb;
      totalF += t.totalFat;
    }
    final total = totalP + totalC + totalF;
    if (total <= 0) return const SizedBox.shrink();

    final activeDays =
        _trendData.values.where((t) => t.totalKcal > 0).length.clamp(1, 999);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Makro Dağılımı (Ortalama)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 30,
                          sections: [
                            _pieSection(totalP, total, 'P',
                                const Color(0xFF5B9BFF)),
                            _pieSection(totalC, total, 'K',
                                const Color(0xFF4CD1A3)),
                            _pieSection(totalF, total, 'Y',
                                const Color(0xFFFFB74D)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _macroLegend('Protein', const Color(0xFF5B9BFF),
                            '${(totalP / activeDays).round()}g/gün',
                            '${(totalP / total * 100).round()}%'),
                        const SizedBox(height: 12),
                        _macroLegend('Karbonhidrat', const Color(0xFF4CD1A3),
                            '${(totalC / activeDays).round()}g/gün',
                            '${(totalC / total * 100).round()}%'),
                        const SizedBox(height: 12),
                        _macroLegend('Yağ', const Color(0xFFFFB74D),
                            '${(totalF / activeDays).round()}g/gün',
                            '${(totalF / total * 100).round()}%'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.04, end: 0);
  }

  PieChartSectionData _pieSection(
      double value, double total, String label, Color color) {
    return PieChartSectionData(
      value: value,
      title: '${(value / total * 100).round()}%',
      color: color,
      radius: 40,
      titleStyle: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
    );
  }

  Widget _macroLegend(
      String label, Color color, String perDay, String percent) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(percent,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            Text(perDay,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
          ],
        ),
      ],
    );
  }

  // ─── İstatistikler ──────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    final values = _trendData.values.map((e) => e.totalKcal).toList();
    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    final avg = nonZero.reduce((a, b) => a + b) / nonZero.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = nonZero.reduce((a, b) => a < b ? a : b);
    final totalKcal = nonZero.reduce((a, b) => a + b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İstatistikler',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statItem('Ortalama', '${avg.round()} kcal',
                      Icons.analytics_rounded, AppColors.secondary),
                  const SizedBox(width: 12),
                  _statItem('En Yüksek', '${max.round()} kcal',
                      Icons.arrow_upward_rounded, const Color(0xFFFF6B6B)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statItem('En Düşük', '${min.round()} kcal',
                      Icons.arrow_downward_rounded, const Color(0xFF5B9BFF)),
                  const SizedBox(width: 12),
                  _statItem('Toplam', '${totalKcal.round()} kcal',
                      Icons.summarize_rounded, const Color(0xFF4CD1A3)),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 400.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11)),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
