import 'package:flutter/material.dart';

class PremiumFeature {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final String tag;
  final String shortLabel;

  const PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.tag,
    required this.shortLabel,
  });
}

bool isPremiumTier(String? tier) => tier?.toLowerCase().trim() == 'premium';

const premiumFeatures = <PremiumFeature>[
  PremiumFeature(
    icon: Icons.smart_toy_rounded,
    title: 'AI Koç ve Adaptif Planlar',
    description:
        'Claude destekli kişisel koçluk al, hedefin değiştikçe önerilerini otomatik güncelle.',
    accent: Color(0xFFFFB74D),
    tag: 'AI KOÇ',
    shortLabel: 'AI Koç',
  ),
  PremiumFeature(
    icon: Icons.insights_rounded,
    title: 'Gelişmiş Analiz ve Grafikler',
    description:
        'Beslenme trendlerini, ilerleme ritmini ve raporlarını daha derin verilerle incele.',
    accent: Color(0xFF64B5F6),
    tag: 'ANALİZ',
    shortLabel: 'Derin Analiz',
  ),
  PremiumFeature(
    icon: Icons.restaurant_menu_rounded,
    title: 'Haftalık Öğün Planı ve Akıllı Liste',
    description:
        'Kişisel hedeflerine göre öğün planı kur, alışveriş listesini akıllı şekilde üret.',
    accent: Color(0xFF81C784),
    tag: 'PLANLAMA',
    shortLabel: 'Öğün Planı',
  ),
  PremiumFeature(
    icon: Icons.fitness_center_rounded,
    title: 'Hazır Antrenman Programları',
    description:
        'Hedef bazlı premium programları aç, güçlü bir başlangıç için hazır splitleri kullan.',
    accent: Color(0xFFF06292),
    tag: 'WORKOUT',
    shortLabel: 'Programlar',
  ),
];
