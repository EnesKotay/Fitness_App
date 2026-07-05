import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/premium_features.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/premium_screen.dart';

class PremiumFeatureGate {
  const PremiumFeatureGate._();

  /// Tek yetkili premium kontrol noktası.
  ///
  /// Önce AuthProvider'daki önbelleklenmiş tier'e bakar (hızlı, ağ yok).
  /// Bulunamazsa backend'e `/api/user/premium-status` isteği atar,
  /// gelen sonucu AuthProvider'a yazar ve bir sonraki çağrıda ağ gitmez.
  static Future<bool> ensureAccess(
    BuildContext context, {
    required String featureName,
  }) async {
    final auth = context.read<AuthProvider>();

    // 1. Hızlı yol: önbelleklenmiş tier
    if (isPremiumTier(
      auth.user?.premiumTier,
      expiresAt: auth.user?.premiumExpiresAt,
    )) {
      return true;
    }

    // 2. Yavaş yol: backend'e sor, AuthProvider'ı güncelle
    final isPremium = await _fetchAndSyncPremium(auth);
    if (isPremium) return true;

    if (!context.mounted) return false;

    // Premium Paywall Bottom Sheet
    final goPremium = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        const gold = Color(0xFFFFB74D);
        const darkGold = Color(0xFFD97706);
        const bg = Color(0xFF111318);

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: gold.withValues(alpha: 0.28), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.14),
                blurRadius: 40,
                spreadRadius: -8,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: gold.withValues(alpha: 0.28)),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: gold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kilitli Özellik',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          featureName,
                          style: TextStyle(
                            color: gold.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Temel takip açık kalır. Bu özellikler daha detaylı analiz isteyenler için kilitlidir:',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _GateFeatureRow(
                icon: Icons.smart_toy_rounded,
                label: 'AI Koç için daha uzun ve detaylı analiz',
                color: gold,
              ),
              const SizedBox(height: 8),
              _GateFeatureRow(
                icon: Icons.restaurant_menu_rounded,
                label: 'Hazır öğün planı ve otomatik alışveriş listesi',
                color: const Color(0xFF81C784),
              ),
              const SizedBox(height: 8),
              _GateFeatureRow(
                icon: Icons.insights_rounded,
                label: 'Veriyi içgörüye çeviren gelişmiş trend analizleri',
                color: const Color(0xFF64B5F6),
              ),
              const SizedBox(height: 8),
              _GateFeatureRow(
                icon: Icons.fitness_center_rounded,
                label: 'Hazır antrenman programları',
                color: const Color(0xFFF06292),
              ),
              const SizedBox(height: 22),
              // CTA butonu
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFBBF24), darkGold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(sheetContext).pop(true),
                      child: const Center(
                        child: Text(
                          'Premium\'u Aç',
                          style: TextStyle(
                            color: Color(0xFF1A0F00),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: Text(
                    'Şimdi değil',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.32),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (goPremium == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    }
    return false;
  }

  /// Backend'den premium durumunu çekip AuthProvider'a yazar.
  static Future<bool> _fetchAndSyncPremium(AuthProvider auth) async {
    try {
      final response = await ApiClient().get(ApiConstants.premiumStatus);
      final data = response.data;
      if (data is! Map) return false;
      final isActive = data['isActive'] == true;
      final expiresAt = data['expiresAt'] != null
          ? DateTime.tryParse(data['expiresAt'].toString())
          : null;
      auth.setPremiumActive(
        isActive ||
            isPremiumTier(data['tier']?.toString(), expiresAt: expiresAt),
        premiumPlan: normalizePremiumPlanId(data['planId']?.toString()),
        premiumExpiresAt: expiresAt,
        premiumCancelAtPeriodEnd: data['cancelAtPeriodEnd'] == true,
      );
      return isActive ||
          isPremiumTier(data['tier']?.toString(), expiresAt: expiresAt);
    } catch (_) {
      return false;
    }
  }
}

class _GateFeatureRow extends StatelessWidget {
  const _GateFeatureRow({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          Icons.check_rounded,
          size: 15,
          color: color.withValues(alpha: 0.65),
        ),
      ],
    );
  }
}
