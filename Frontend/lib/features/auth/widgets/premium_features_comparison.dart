import 'package:flutter/material.dart';

/// Premium vs Free özellik karşılaştırma tablosu
class PremiumFeaturesComparison extends StatelessWidget {
  const PremiumFeaturesComparison({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium Özellikleri',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fitness hedeflerine daha hızlı ulaş',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildFeatureRow(
            icon: Icons.psychology,
            title: 'AI Koç',
            description: 'Kişisel antrenman ve beslenme koçu',
            isPremium: true,
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.photo_camera,
            title: 'Foto Analiz',
            description: 'Yemek fotoğrafından kalori tahmini',
            isPremium: true,
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.restaurant_menu,
            title: 'Öğün Planı',
            description: 'AI destekli haftalık beslenme planı',
            isPremium: true,
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.trending_up,
            title: 'Trendler & Analiz',
            description: 'Detaylı ilerleme raporları',
            isPremium: true,
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.calendar_today,
            title: 'Haftalık Antrenman Planı',
            description: 'Hedefine özel otomatik program',
            isPremium: true,
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            icon: Icons.insights,
            title: 'Performans İçgörüleri',
            description: 'Toparlanma ve yoğunluk analizi',
            isPremium: true,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ücretsiz: Temel antrenman ve beslenme takibi',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
    required bool isPremium,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        if (isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
