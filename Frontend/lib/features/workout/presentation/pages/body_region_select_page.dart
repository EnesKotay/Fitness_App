import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../data/models/body_region.dart';
import '../providers/workout_catalog_provider.dart';

/// 1) Bölge Seç ekranı: Grid ile Göğüs, Sırt, Omuz, Kol, Bacak, Karın (+ Kardiyo, Full Body).
class BodyRegionSelectPage extends StatefulWidget {
  final VoidCallback? onRegionSelected;

  const BodyRegionSelectPage({super.key, this.onRegionSelected});

  @override
  State<BodyRegionSelectPage> createState() => _BodyRegionSelectPageState();
}

class _BodyRegionSelectPageState extends State<BodyRegionSelectPage> {
  static final Map<String, IconData> _iconMap = {
    'fitness_center': Icons.fitness_center,
    'back_hand': Icons.back_hand,
    'accessibility_new': Icons.accessibility_new,
    'sports_martial_arts': Icons.sports_martial_arts,
    'directions_walk': Icons.directions_walk,
    'self_improvement': Icons.self_improvement,
    'directions_run': Icons.directions_run,
  };

  /// Premium gradient accent renkleri (her kart için farklı ton).
  static final List<List<Color>> _regionGradients = [
    [AppColors.secondary.withValues(alpha: 0.35), AppColors.secondary.withValues(alpha: 0.08)],
    [AppColors.primary.withValues(alpha: 0.4), AppColors.primary.withValues(alpha: 0.1)],
    [const Color(0xFF2196F3).withValues(alpha: 0.35), const Color(0xFF2196F3).withValues(alpha: 0.08)],
    [const Color(0xFF4CAF50).withValues(alpha: 0.35), const Color(0xFF4CAF50).withValues(alpha: 0.08)],
    [const Color(0xFF00BCD4).withValues(alpha: 0.35), const Color(0xFF00BCD4).withValues(alpha: 0.08)],
    [const Color(0xFF7C4DFF).withValues(alpha: 0.35), const Color(0xFF7C4DFF).withValues(alpha: 0.08)],
    [AppColors.secondary.withValues(alpha: 0.3), AppColors.secondary.withValues(alpha: 0.06)],
    [AppColors.primary.withValues(alpha: 0.35), AppColors.primary.withValues(alpha: 0.1)],
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutCatalogProvider>().loadRegions();
    });
  }

  IconData _iconFor(BodyRegion r) {
    final name = r.iconName ?? 'fitness_center';
    return _iconMap[name] ?? Icons.fitness_center;
  }

  List<Color> _gradientFor(int index) {
    return _regionGradients[index % _regionGradients.length];
  }

  /// Bölge id'sine göre arka plan fotoğrafı
  static String? _imagePathFor(String regionId) {
    switch (regionId) {
      case 'chest': return 'assets/images/region_chest.jpg';
      case 'back': return 'assets/images/region_back.jpg';
      case 'shoulders': return 'assets/images/region_shoulders.jpg';
      case 'arms': return 'assets/images/region_arms.jpg';
      case 'legs': return 'assets/images/region_legs.jpg';
      case 'core': return 'assets/images/region_core.jpg';
      case 'cardio': return 'assets/images/region_cardio.jpg';
      case 'fullbody': return 'assets/images/region_fullbody.jpg';
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppGradientBackground(
        imagePath: 'assets/images/workout_bg.jpg',
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Antrenman', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 6),
                      Text('Hangi bölgeyi çalışacaksın?', style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ),
              Consumer<WorkoutCatalogProvider>(
                builder: (context, provider, _) {
                  if (provider.loadingRegions) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    );
                  }
                  if (provider.error != null) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(provider.error!, style: AppTextStyles.bodyMedium),
                      ),
                    );
                  }
                  final list = provider.regions;
                  if (list.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Bölge listesi yüklenemedi.', style: AppTextStyles.bodyMedium),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.88,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final region = list[index];
                          final gradientColors = _gradientFor(index);
                          return _RegionCard(
                            region: region,
                            gradientColors: gradientColors,
                            imagePath: _imagePathFor(region.id),
                            icon: _iconFor(region),
                            exerciseLabel: 'Hareketler',
                            onTap: () {
                              widget.onRegionSelected?.call();
                              Navigator.of(context).pushNamed(
                                'workout/exercises',
                                arguments: region,
                              );
                            },
                          ).animate().fadeIn(delay: (50 * index).ms, duration: 200.ms).slideY(begin: 0.05, end: 0, duration: 200.ms, curve: Curves.easeOut);
                        },
                        childCount: list.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionCard extends StatefulWidget {
  final BodyRegion region;
  final List<Color> gradientColors;
  final String? imagePath;
  final IconData icon;
  final String exerciseLabel;
  final VoidCallback onTap;

  const _RegionCard({
    required this.region,
    required this.gradientColors,
    this.imagePath,
    required this.icon,
    required this.exerciseLabel,
    required this.onTap,
  });

  @override
  State<_RegionCard> createState() => _RegionCardState();
}

class _RegionCardState extends State<_RegionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.gradientColors.first;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: _isPressed ? 12 : 20,
                  offset: Offset(0, _isPressed ? 4 : 8),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fotoğraf tüm kartı kaplasın
                  if (widget.imagePath != null)
                    Image.asset(
                      widget.imagePath!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.gradientColors,
                        ),
                      ),
                    ),
                  // Altta metin okunabilirliği için gradient
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 110,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // İçerik (başlık + Hareketler) altta
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.region.name,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.sectionSubtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              widget.exerciseLabel,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
