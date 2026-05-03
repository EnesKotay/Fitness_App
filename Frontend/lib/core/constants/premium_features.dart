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
        'Claude destekli koçlukla sadece cevap alma; verilerini yorumlayan ve sonraki adımı öneren bir rehber kazan.',
    accent: Color(0xFFFFB74D),
    tag: 'AI KOÇ',
    shortLabel: 'AI Koç',
  ),
  PremiumFeature(
    icon: Icons.insights_rounded,
    title: 'Gelişmiş Analiz ve Grafikler',
    description:
        'Kayıtlarını sadece görmekle kalma; hangi günler iyi gittiğini ve nerede koptuğunu net biçimde fark et.',
    accent: Color(0xFF64B5F6),
    tag: 'ANALİZ',
    shortLabel: 'Derin Analiz',
  ),
  PremiumFeature(
    icon: Icons.restaurant_menu_rounded,
    title: 'Haftalık Öğün Planı ve Akıllı Liste',
    description:
        'Hedefine göre haftayı hazır gör, market listesini otomatik çıkar ve “ne yiyeceğim” yükünü azalt.',
    accent: Color(0xFF81C784),
    tag: 'PLANLAMA',
    shortLabel: 'Öğün Planı',
  ),
  PremiumFeature(
    icon: Icons.fitness_center_rounded,
    title: 'Hazır Antrenman Programları',
    description:
        'Hedefine uygun hazır splitleri incele, beğendiğini tek dokunuşla başlat ve sıfırdan plan kurma derdini azalt.',
    accent: Color(0xFFF06292),
    tag: 'WORKOUT',
    shortLabel: 'Programlar',
  ),
];
