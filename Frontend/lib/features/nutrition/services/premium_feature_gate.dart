import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
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
    if (auth.user?.premiumTier?.toLowerCase().trim() == 'premium') {
      return true;
    }

    // 2. Yavaş yol: backend'e sor, AuthProvider'ı güncelle
    final isPremium = await _fetchAndSyncPremium(auth);
    if (isPremium) return true;

    if (!context.mounted) return false;

    // Güzel bir Premium Popup gösterimi (Bottom Sheet)
    final goPremium = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFB74D).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB74D).withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFB74D),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Premium Özellik',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$featureName özelliği sadece Premium kullanıcılara özeldir. Hemen Premium\'a geç ve tüm özelliklerin kilidini aç!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Vazgeç',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB74D),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Premium Ol',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
      auth.setPremiumActive(
        isActive,
        premiumPlan: data['planId']?.toString(),
        premiumExpiresAt: data['expiresAt'] != null
            ? DateTime.tryParse(data['expiresAt'].toString())
            : null,
        premiumCancelAtPeriodEnd: data['cancelAtPeriodEnd'] == true,
      );
      return isActive;
    } catch (_) {
      return false;
    }
  }
}
