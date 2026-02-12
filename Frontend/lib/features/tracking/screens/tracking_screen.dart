import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/utils/app_snack.dart';
import '../../../core/theme/app_theme.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../widgets/premium_summary_card.dart';
import '../widgets/stats_grid.dart';
import '../widgets/neon_line_chart.dart';
import '../widgets/history_list.dart';
import '../widgets/weight_ruler_picker.dart';
import '../widgets/consistency_heatmap.dart';

/// Takip sayfası: kilo girişi, özet, grafik, ısı haritası, geçmiş. Baştan tasarlandı.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final ValueNotifier<int> _chartRangeIndex = ValueNotifier<int>(1);
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void dispose() {
    _chartRangeIndex.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<DietProvider>(context, listen: false).init();
      Provider.of<WeightProvider>(context, listen: false).loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
      floatingActionButton: _buildFAB(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Kilo Takibi',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: false,
      leading: null,
      automaticallyImplyLeading: false,
      actions: [
        Selector<WeightProvider, WeightEntry?>(
          selector: (_, p) => p.latestEntry,
          builder: (_, latest, __) {
            if (latest == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8, top: 12, bottom: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${latest.weightKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        IconButton(
          onPressed: () => _showAddWeightSheet(context),
          icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight, size: 26),
          tooltip: 'Kilo ekle',
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Selector<WeightProvider, bool>(
      selector: (_, p) => p.entries.isEmpty,
      builder: (context, isEmpty, _) {
        final provider = context.read<WeightProvider>();
        if (provider.isLoading && isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Yükleniyor...',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                ),
              ],
            ),
          );
        }
        if (isEmpty) return _buildEmptyState(context, provider);
        return _buildMainContent(context, provider);
      },
    );
  }

  Widget _buildMainContent(BuildContext context, WeightProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF13161A),
            Color(0xFF0A0B0E),
          ],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: provider.loadEntries,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: PremiumSummaryCard(
                    provider: provider,
                    screenshotController: _screenshotController,
                    onShare: () => _shareProgress(context),
                    onSettingsTap: () {},
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildInsightStrip(context, provider)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: StatsGrid(provider: provider)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: ConsistencyHeatmap(provider: provider),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _buildChartCard(provider),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _buildHistoryHeader(context)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            HistoryList(
              provider: provider,
              onDelete: (entry) => _confirmDelete(context, provider, entry),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightStrip(BuildContext context, WeightProvider provider) {
    final diet = context.read<DietProvider>();
    final target = diet.profile?.targetWeight;
    final current = provider.latestEntry?.weightKg;
    final weekly = provider.weeklyChange;
    if (current == null) return const SizedBox.shrink();

    String text;
    IconData icon = Icons.trending_flat_rounded;
    Color color = Colors.white70;

    if (target != null && (current - target).abs() > 0.1) {
      final diff = current - target;
      if (diff > 0) {
        text = 'Hedefine ${diff.toStringAsFixed(1)} kg kaldı';
        icon = Icons.flag_rounded;
        color = AppColors.primaryLight;
      } else {
        text = 'Hedefinin ${(-diff).toStringAsFixed(1)} kg altındasın';
        icon = Icons.celebration_rounded;
        color = AppColors.success;
      }
    } else if (weekly.abs() >= 0.05) {
      if (weekly < 0) {
        text = 'Son 7 günde ${(-weekly).toStringAsFixed(1)} kg verdin';
        icon = Icons.trending_down_rounded;
        color = AppColors.success;
      } else {
        text = 'Son 7 günde +${weekly.toStringAsFixed(1)} kg';
        icon = Icons.trending_up_rounded;
        color = AppColors.warning;
      }
    } else {
      text = 'Kilon stabil';
      icon = Icons.balance_rounded;
      color = Colors.white54;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(WeightProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'İlerleme',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              _buildRangeChips(),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<int>(
            valueListenable: _chartRangeIndex,
            builder: (_, index, __) => NeonLineChart(
              provider: provider,
              selectedFilterIndex: index,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChips() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _rangeChip('1 Hafta', 0),
        const SizedBox(width: 6),
        _rangeChip('1 Ay', 1),
        const SizedBox(width: 6),
        _rangeChip('3 Ay', 2),
      ],
    );
  }

  Widget _rangeChip(String label, int index) {
    return ValueListenableBuilder<int>(
      valueListenable: _chartRangeIndex,
      builder: (_, selected, __) {
        final isSelected = selected == index;
        return GestureDetector(
          onTap: () => _chartRangeIndex.value = index,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primaryLight : Colors.white70,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryHeader(BuildContext context) {
    final count = context.read<WeightProvider>().entries.length;
    return Row(
      children: [
        Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text(
          'Geçmiş Kayıtlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '$count kayıt',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _showAddWeightSheet(context),
          icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primaryLight),
          label: const Text('Ekle', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, WeightProvider provider) {
    final profileWeight = context.read<DietProvider>().profile?.weightKg;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13161A), Color(0xFF0A0B0E)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2),
                ),
                child: Icon(Icons.monitor_weight_rounded, size: 52, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Kilo takibine başla',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'İlk kilonu ekle; grafik ve istatistiklerle ilerlemeni takip et.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15, height: 1.4),
              ),
              if (profileWeight != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Profil kilon: ${profileWeight.toStringAsFixed(1)} kg',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  text: 'İlk kiloyu ekle',
                  onPressed: () => _showAddWeightSheet(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Selector<WeightProvider, bool>(
      selector: (_, p) => p.entries.isEmpty,
      builder: (_, isEmpty, __) {
        if (isEmpty) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => _showAddWeightSheet(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Kilo Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        );
      },
    );
  }

  void _showAddWeightSheet(BuildContext context) {
    final dateController = TextEditingController(text: DateFormat('d.MM.yyyy').format(DateTime.now()));
    DateTime selectedDate = DateTime.now();
    final lastWeight = context.read<WeightProvider>().latestEntry?.weightKg;
    final profileWeight = context.read<DietProvider>().profile?.weightKg;
    double currentWeight = lastWeight ?? profileWeight ?? 70.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('Kilo ekle', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(data: AppTheme.darkTheme, child: child!),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          selectedDate = picked;
                          dateController.text = DateFormat('d.MM.yyyy').format(picked);
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(dateController.text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currentWeight.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -2),
                      ),
                      const SizedBox(width: 6),
                      Text('kg', style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: WeightRulerPicker(
                      initialValue: currentWeight,
                      minValue: 30,
                      maxValue: 250,
                      onChanged: (v) => setSheetState(() => currentWeight = v),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      text: 'Kaydet',
                      onPressed: () async {
                        if (currentWeight <= 0) {
                          AppSnack.showError(context, 'Geçerli bir değer girin');
                          return;
                        }
                        final entry = WeightEntry(
                          id: const Uuid().v4(),
                          date: selectedDate,
                          weightKg: currentWeight,
                        );
                        final wp = context.read<WeightProvider>();
                        final dp = context.read<DietProvider>();
                        await wp.addEntry(entry);
                        await dp.updateProfileWeightFromTracking(entry.weightKg);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        AppSnack.showSuccess(context, 'Kaydedildi');
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareProgress(BuildContext context) async {
    try {
      final image = await _screenshotController.capture(delay: const Duration(milliseconds: 100));
      if (image == null || !context.mounted) return;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/tracking_share.png');
      await file.writeAsBytes(image);
      await Share.shareXFiles([XFile(file.path)], text: 'Kilo takibim 🎯 #Fitness');
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) AppSnack.showError(context, 'Paylaşım hatası');
    }
  }

  void _confirmDelete(BuildContext context, WeightProvider provider, WeightEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kaydı sil?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${entry.weightKg.toStringAsFixed(1)} kg silinecek.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () async {
              await provider.deleteEntry(entry.id);
              if (!ctx.mounted) return;
              
              // Eğer silinen kayıt en güncel kayıt id'si ile eşleşiyorsa profili güncelle
              final dietProvider = context.read<DietProvider>();
              final newLatest = provider.latestEntry;
              if (newLatest != null) {
                await dietProvider.updateProfileWeightFromTracking(newLatest.weightKg);
              }
              
              Navigator.pop(ctx);
              if (!context.mounted) return;
              AppSnack.showSuccess(context, 'Silindi');
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
