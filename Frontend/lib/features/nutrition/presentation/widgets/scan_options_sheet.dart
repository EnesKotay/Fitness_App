import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/premium_state_badge.dart';
import '../../ai_scan/presentation/pages/barcode_scan_page.dart';
import '../../ai_scan/presentation/pages/label_ocr_scan_page.dart';
import '../../ai_scan/presentation/pages/meal_vision_scan_page.dart';
import '../../domain/entities/meal_type.dart';
import '../../services/premium_feature_gate.dart';
import '../../../auth/providers/auth_provider.dart';

/// FAB'tan açılan "Hızlı Ekle" seçenek menüsü.
/// Yemek Ara, Barkod Tara, AI Fotoğraf Tara seçenekleri sunar.
class ScanOptionsSheet extends StatelessWidget {
  final MealType defaultMealType;
  final VoidCallback onSearchTap;

  const ScanOptionsSheet({
    super.key,
    required this.defaultMealType,
    required this.onSearchTap,
  });

  static Future<void> show(
    BuildContext context, {
    required MealType defaultMealType,
    required VoidCallback onSearchTap,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ScanOptionsSheet(
        defaultMealType: defaultMealType,
        onSearchTap: onSearchTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremiumUser =
        context.watch<AuthProvider>().user?.premiumTier?.toLowerCase().trim() ==
        'premium';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Yemek Ekle',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nasıl eklemek istersin?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),

              // Options
              _buildOption(
                context,
                icon: Icons.search_rounded,
                title: 'Yemek Ara',
                subtitle: 'Veritabanından besin seç',
                color: AppColors.secondary,
                onTap: () {
                  Navigator.pop(context);
                  onSearchTap();
                },
              ),
              const SizedBox(height: 12),
              _buildOption(
                context,
                icon: Icons.qr_code_scanner_rounded,
                title: 'Barkod Tara',
                subtitle: 'Ürün barkodunu okut',
                color: const Color(0xFF5B9BFF),
                onTap: () {
                  Navigator.pop(context);
                  _openBarcodeScan(context);
                },
              ),
              const SizedBox(height: 12),
              _buildOption(
                context,
                icon: Icons.camera_alt_rounded,
                title: 'Besin Etiketi Tara',
                subtitle: isPremiumUser
                    ? 'Premium aktif, etiketi anında okut'
                    : 'Kalori cetvelini okut',
                color: const Color(0xFFBB86FC),
                isPremium: true,
                isUnlocked: isPremiumUser,
                onTap: () {
                  Navigator.pop(context);
                  _openLabelScan(context);
                },
              ),
              const SizedBox(height: 12),
              _buildOption(
                context,
                icon: Icons.restaurant_rounded,
                title: 'Yemek Fotoğrafı Analizi',
                subtitle: isPremiumUser
                    ? 'Premium aktif, AI tahminini kullan'
                    : 'Yemeğin fotoğrafını çek, AI tahmin etsin',
                isPremium: true,
                isUnlocked: isPremiumUser,
                color: const Color(0xFFFF8A65),
                onTap: () {
                  Navigator.pop(context);
                  _openMealVisionScan(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isPremium = false,
    bool isUnlocked = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 8),
                          isUnlocked
                              ? const PremiumStateBadge(
                                  active: true,
                                  compact: true,
                                )
                              : const ProBadge(compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBarcodeScan(BuildContext context) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeScanPage(initialMealType: defaultMealType),
        ),
      );
    } catch (e) {
      debugPrint('ScanOptionsSheet._openBarcodeScan error: $e');
    }
  }

  Future<void> _openLabelScan(BuildContext context) async {
    final allowed = await PremiumFeatureGate.ensureAccess(
      context,
      featureName: 'Besin etiketi tara',
    );
    if (!allowed || !context.mounted) return;
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LabelOcrScanPage(initialMealType: defaultMealType),
        ),
      );
    } catch (e) {
      debugPrint('ScanOptionsSheet._openLabelScan error: $e');
    }
  }

  Future<void> _openMealVisionScan(BuildContext context) async {
    final allowed = await PremiumFeatureGate.ensureAccess(
      context,
      featureName: 'Yemek fotoğrafı analizi',
    );
    if (!allowed || !context.mounted) return;
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealVisionScanPage(initialMealType: defaultMealType),
        ),
      );
    } catch (e) {
      debugPrint('ScanOptionsSheet._openMealVisionScan error: $e');
    }
  }
}
