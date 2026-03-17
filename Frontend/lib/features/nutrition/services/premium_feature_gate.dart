import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/ai_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/premium_screen.dart';
import '../presentation/state/diet_provider.dart';

class PremiumFeatureGate {
  const PremiumFeatureGate._();

  static Future<bool> ensureAccess(
    BuildContext context, {
    required String featureName,
  }) async {
    final auth = context.read<AuthProvider>();
    final tier = auth.user?.premiumTier?.toLowerCase().trim();
    if (tier == 'premium') {
      return true;
    }

    final aiService = context.read<DietProvider>().aiService;
    final isPremium = await _checkPremium(aiService);
    if (isPremium) {
      auth.setPremiumActive(true);
      return true;
    }

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

  static Future<bool> _checkPremium(AIService? aiService) async {
    if (aiService == null) return false;
    try {
      return await aiService.checkPremiumStatus() ?? false;
    } catch (_) {
      return false;
    }
  }
}
