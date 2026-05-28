import 'package:flutter/material.dart';

enum TrainingPhase { strength, hypertrophy, deload, power }

class TrainingPhaseInfo {
  final TrainingPhase phase;
  final String label;
  final String emoji;
  final Color color;
  final String sets;
  final String reps;
  final String intensity;
  final String description;
  final int typicalWeeks;

  const TrainingPhaseInfo({
    required this.phase,
    required this.label,
    required this.emoji,
    required this.color,
    required this.sets,
    required this.reps,
    required this.intensity,
    required this.description,
    required this.typicalWeeks,
  });
}

const Map<TrainingPhase, TrainingPhaseInfo> kPhaseInfo = {
  TrainingPhase.hypertrophy: TrainingPhaseInfo(
    phase: TrainingPhase.hypertrophy,
    label: 'Hipertrofi',
    emoji: '💪',
    color: Color(0xFF5E5CE6),
    sets: '4',
    reps: '8–12',
    intensity: '%70–80 1RM',
    description: 'Kas büyümesine odaklan. Yüksek tekrar, orta ağırlık.',
    typicalWeeks: 6,
  ),
  TrainingPhase.strength: TrainingPhaseInfo(
    phase: TrainingPhase.strength,
    label: 'Kuvvet',
    emoji: '🏋️',
    color: Color(0xFFFF6B35),
    sets: '5',
    reps: '3–6',
    intensity: '%85–90 1RM',
    description: 'Maksimal güç geliştir. Düşük tekrar, yüksek ağırlık.',
    typicalWeeks: 4,
  ),
  TrainingPhase.power: TrainingPhaseInfo(
    phase: TrainingPhase.power,
    label: 'Güç-Hız',
    emoji: '⚡',
    color: Color(0xFFFFD60A),
    sets: '5',
    reps: '2–5',
    intensity: '%90+ 1RM',
    description: 'Patlayıcı kuvvet. Çok ağır, az tekrar, tam dinlenme.',
    typicalWeeks: 3,
  ),
  TrainingPhase.deload: TrainingPhaseInfo(
    phase: TrainingPhase.deload,
    label: 'Deload',
    emoji: '🌿',
    color: Color(0xFF30D158),
    sets: '3',
    reps: '5',
    intensity: '%60 1RM',
    description: 'Toparlanma haftası. Düşük ağırlık, hareket kalitesine odak.',
    typicalWeeks: 1,
  ),
};
