import 'package:flutter/material.dart';
import '../../data/models/exercise_catalog.dart';

/// 3) Hareket Detay: Ad, hedef kas, ekipman, zorluk, media placeholder, adımlar, hatalar, ipuçları, güvenlik.
class ExerciseDetailPage extends StatelessWidget {
  final ExerciseCatalog exercise;

  const ExerciseDetailPage({super.key, required this.exercise});

  static const Color _accentColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _MediaPlaceholder(mediaUrl: exercise.mediaUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (exercise.primaryMuscles.isNotEmpty) ...[
                    _SectionTitle(label: 'Hedef kas(lar)', color: _accentColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: exercise.primaryMuscles
                          .map((m) => Chip(
                                label: Text(m, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                backgroundColor: _accentColor.withValues(alpha: 0.25),
                                side: BorderSide(color: _accentColor.withValues(alpha: 0.5)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (exercise.equipment.isNotEmpty) ...[
                    _SectionTitle(label: 'Ekipman', color: _accentColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: exercise.equipment
                          .map((e) => Chip(
                                label: Text(e, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _SectionTitle(label: 'Zorluk', color: _accentColor),
                  const SizedBox(height: 6),
                  Text(
                    exercise.difficulty,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (exercise.steps.isNotEmpty) ...[
                    _SectionTitle(label: 'Nasıl yapılır?', color: _accentColor),
                    const SizedBox(height: 12),
                    ...exercise.steps.asMap().entries.map((e) {
                      final i = e.key + 1;
                      final step = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$i',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                step,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                  if (exercise.commonMistakes.isNotEmpty) ...[
                    _SectionTitle(label: 'Yaygın hatalar', color: _accentColor),
                    const SizedBox(height: 10),
                    ...exercise.commonMistakes.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 16,
                                color: _accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                m,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (exercise.tips.isNotEmpty) ...[
                    _SectionTitle(label: 'İpuçları', color: _accentColor),
                    const SizedBox(height: 10),
                    ...exercise.tips.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, size: 18, color: _accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (exercise.safetyWarning != null &&
                      exercise.safetyWarning!.trim().isNotEmpty) ...[
                    _SectionTitle(label: 'Güvenlik uyarısı', color: Colors.orange),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              exercise.safetyWarning!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final String? mediaUrl;

  const _MediaPlaceholder({this.mediaUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A1A),
      child: mediaUrl != null && mediaUrl!.isNotEmpty
          ? Image.network(
              mediaUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderContent(),
            )
          : _placeholderContent(),
    );
  }

  Widget _placeholderContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Video / GIF (placeholder)',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
