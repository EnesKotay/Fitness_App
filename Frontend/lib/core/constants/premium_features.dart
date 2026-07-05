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

String? normalizePremiumPlanId(String? planId) {
  final normalized = planId?.toLowerCase().trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.contains('year')) return 'yearly';
  if (normalized.contains('month')) return 'monthly';
  return normalized;
}

bool isPremiumTier(String? tier, {DateTime? expiresAt}) {
  if (tier?.toLowerCase().trim() != 'premium') return false;
  return expiresAt == null || expiresAt.isAfter(DateTime.now());
}

int premiumDaysLeft(DateTime? expiresAt, {required int totalDays}) {
  if (expiresAt == null) return totalDays;
  final remainingSeconds = expiresAt.difference(DateTime.now()).inSeconds;
  if (remainingSeconds <= 0) return 0;
  final days = (remainingSeconds / Duration.secondsPerDay).ceil();
  return days.clamp(1, totalDays).toInt();
}

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
