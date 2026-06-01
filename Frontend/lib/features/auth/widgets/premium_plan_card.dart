import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/services/iap_service.dart';

/// Premium plan seçim kartı - gerçek App Store fiyatlarıyla
class PremiumPlanCard extends StatelessWidget {
  final String productId;
  final ProductDetails? product;
  final bool isSelected;
  final bool isPopular;
  final VoidCallback onTap;
  final bool isLoading;

  const PremiumPlanCard({
    super.key,
    required this.productId,
    this.product,
    required this.isSelected,
    this.isPopular = false,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMonthly = productId == IapProductIds.monthly;
    final title = isMonthly ? 'Aylık' : 'Yıllık';
    final defaultPrice = isMonthly ? '149₺/ay' : '799.99₺/yıl';
    final savingsPercent = isMonthly ? null : '%55 tasarruf';

    // Gerçek App Store fiyatı varsa onu kullan
    final displayPrice = product?.price ?? defaultPrice;
    final currency = product?.currencySymbol ?? '₺';

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    const Color(0xFFD97706),
                    const Color(0xFFFBBF24).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFBBF24)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    else if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  displayPrice,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
                if (savingsPercent != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      savingsPercent,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (!isMonthly) ...[
                  const SizedBox(height: 8),
                  Text(
                    '~${(product != null ? (double.tryParse(product!.price) ?? 800) / 12 : 66.66).toStringAsFixed(2)}$currency/ay',
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
            if (isPopular)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    '🔥 Popüler',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
