part of 'workout_screen.dart';

class _RegionCard extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String imageUrl;
  final VoidCallback onTap;

  const _RegionCard({
    required this.label,
    required this.color,
    required this.icon,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.startsWith('assets/')
                  ? Image.asset(imageUrl, fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: color.withValues(alpha: 0.3)),
                      errorWidget: (_, _, _) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.4),
                              color.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: Colors.white, size: 16),
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final Color accentColor;
  final String? subRegionLabel;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.accentColor,
    this.subRegionLabel,
    this.isFavorite = false,
    this.onFavoriteTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          highlightColor: accentColor.withValues(alpha: 0.08),
          splashColor: accentColor.withValues(alpha: 0.06),
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 3,
                height: 72,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (subRegionLabel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                subRegionLabel!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (exercise.description != null &&
                              exercise.description!.trim().isNotEmpty)
                            Expanded(
                              child: Text(
                                exercise.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (exercise.tips != null &&
                          exercise.tips!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 11,
                              color: Colors.amber.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'İpucu var',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.amber.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Right actions
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onFavoriteTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 20,
                          color: isFavorite
                              ? Colors.amber
                              : Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onRepeat;

  const _HistoryCard({
    required this.workout,
    required this.onDelete,
    required this.onEdit,
    this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'd MMMM, EEEE',
      'tr_TR',
    ).format(workout.workoutDate);
    final timeStr = DateFormat('HH:mm').format(workout.workoutDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                workout.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (workout.oneRepMax != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '🏆',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${workout.oneRepMax!.toStringAsFixed(1)} kg',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.amber,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dateStr • $timeStr',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        if (workout.isSuperset == true &&
                            workout.supersetPartner != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 12,
                                color: Colors.purpleAccent.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Superset: ${workout.supersetPartner}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purpleAccent.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    color: const Color(0xFF1F1F1F),
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      if (val == 'delete') onDelete();
                      if (val == 'repeat') onRepeat?.call();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'repeat',
                        child: Row(
                          children: [
                            Icon(
                              Icons.replay_rounded,
                              color: Colors.greenAccent,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Tekrarla',
                              style: TextStyle(color: Colors.greenAccent),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'Düzenle',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Sil', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (workout.workoutType != null)
                    _InfoTag(
                      label: workout.workoutType!,
                      icon: Icons.category,
                      color: const Color(0xFF2E7D32),
                    ),
                  if (workout.sets != null)
                    _InfoTag(
                      label: '${workout.sets} Set',
                      icon: Icons.layers_rounded,
                      color: Colors.orange,
                    ),
                  if (workout.reps != null)
                    _InfoTag(
                      label: '${workout.reps} Tekrar',
                      icon: Icons.repeat_rounded,
                      color: Colors.purple,
                    ),
                  if (workout.durationMinutes != null &&
                      workout.durationMinutes! > 0)
                    _InfoTag(
                      label: '${workout.durationMinutes} dk',
                      icon: Icons.timer_rounded,
                      color: Colors.blue,
                    ),
                ],
              ),
              if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    workout.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Paylaş butonu
              GestureDetector(
                onTap: () {
                  final setInfo = workout.sets != null
                      ? '${workout.sets} set × ${workout.reps ?? '?'} tekrar'
                      : '';
                  final weightInfo = workout.weight != null
                      ? ' — ${workout.weight!.toStringAsFixed(1)} kg'
                      : '';
                  final rmInfo = workout.oneRepMax != null
                      ? '\n🏆 1RM: ${workout.oneRepMax!.toStringAsFixed(1)} kg'
                      : '';
                  final durInfo = workout.durationMinutes != null
                      ? '\n⏱ ${workout.durationMinutes} dk'
                      : '';
                  final text =
                      '💪 ${workout.name}\n$setInfo$weightInfo$rmInfo$durInfo\n\nPusulaFit ile kaydedildi.';
                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null) {
                    Share.share(
                      text,
                      sharePositionOrigin:
                          box.localToGlobal(Offset.zero) & box.size,
                    );
                  } else {
                    Share.share(text);
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.share_rounded,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Paylaş',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InfoTag({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Muscle Group Distribution Chart ─────────────────────────────────────────

class _MuscleGroupChart extends StatelessWidget {
  final List<Workout> workouts;
  const _MuscleGroupChart({required this.workouts});

  @override
  Widget build(BuildContext context) {
    // Kas grubu sayısını hesapla
    final counts = <String, int>{};
    for (final w in workouts) {
      final mg = w.muscleGroup ?? w.workoutType ?? 'Diğer';
      counts[mg] = (counts[mg] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.first.value.toDouble();

    const accent = Color(0xFF2E7D32);
    final groupColors = <String, Color>{
      'CHEST': const Color(0xFF1E88E5),
      'BACK': const Color(0xFF00ACC1),
      'LEGS': const Color(0xFFE53935),
      'SHOULDERS': const Color(0xFFFFB300),
      'BICEPS': const Color(0xFF8E24AA),
      'TRICEPS': const Color(0xFF6D4C41),
      'CORE': const Color(0xFF43A047),
      'GLUTES': const Color(0xFFFF7043),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Kas Grubu Dağılımı',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...sorted.take(6).map((entry) {
            final color = groupColors[entry.key] ?? accent;
            final pct = entry.value / max;
            final label = kMuscleGroupInfo[entry.key]?.label ?? entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.07,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Deload Banner ─────────────────────────────────────────────────────────────

class _DeloadBanner extends StatelessWidget {
  const _DeloadBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bed_rounded, color: Colors.blueAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deload Haftası Zamanı?',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Son 6 günde sürekli antrenman yaptın. Hafif bir toparlanma haftası performansını artırabilir.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Workout Templates ────────────────────────────────────────────────────────

typedef _TemplateExercise = ({String name, String volume, String tip});

typedef _TemplateData = ({
  String name,
  String subtitle,
  String difficulty,
  Color difficultyColor,
  Color color,
  Color colorDark,
  IconData icon,
  int estimatedMinutes,
  List<String> muscles,
  List<_TemplateExercise> exercises,
  String description,
});

typedef _QuickStartPreset = ({String label, TemplateData templateData});

const List<_QuickStartPreset> _kQuickStartPresets = [
  (
    label: 'Üst Vücut',
    templateData: (
      exerciseName: 'Bench Press',
      sets: 4,
      reps: 8,
      workoutName: 'Üst Vücut Hızlı Başlangıç',
      duration: 40,
      muscleGroup: 'CHEST',
      difficulty: 'Orta',
    ),
  ),
  (
    label: 'Bacak',
    templateData: (
      exerciseName: 'Back Squat',
      sets: 4,
      reps: 6,
      workoutName: 'Bacak Güç Seansı',
      duration: 50,
      muscleGroup: 'LEGS',
      difficulty: 'İleri',
    ),
  ),
  (
    label: 'Full Body',
    templateData: (
      exerciseName: 'Romanian Deadlift',
      sets: 3,
      reps: 8,
      workoutName: 'Full Body Hızlı Seans',
      duration: 45,
      muscleGroup: 'BACK',
      difficulty: 'Orta',
    ),
  ),
  (
    label: 'Cardio',
    templateData: (
      exerciseName: 'Air Bike Interval',
      sets: 6,
      reps: 2,
      workoutName: 'Cardio Interval Seansı',
      duration: 20,
      muscleGroup: 'CORE',
      difficulty: 'Başlangıç',
    ),
  ),
];

const List<_TemplateData> _kWorkoutTemplates = [
  (
    name: 'Göğüs & Triceps',
    subtitle: 'İtme Günü',
    difficulty: 'Orta',
    difficultyColor: Color(0xFFF9A825),
    color: Color(0xFFE53935),
    colorDark: Color(0xFF7B1111),
    icon: Icons.fitness_center,
    estimatedMinutes: 65,
    muscles: ['Göğüs', 'Triceps', 'Ön Omuz'],
    exercises: [
      (
        name: 'Bench Press',
        volume: '4×8',
        tip: 'Kürek kemiklerini birbirine yaklaştır',
      ),
      (
        name: 'Incline Dumbbell Press',
        volume: '3×10',
        tip: '30-45° açı, göğüs üstünü hedefler',
      ),
      (
        name: 'Decline Dumbbell Press',
        volume: '3×10',
        tip: 'Alt göğüs dolgunluğu için',
      ),
      (name: 'Cable Fly', volume: '3×12', tip: 'Hareketin sonunda göğsü sık'),
      (
        name: 'Dips (Triceps)',
        volume: '3×12',
        tip: 'Gövdeyi dik tut, dirseklere odaklan',
      ),
      (
        name: 'Tricep Pushdown',
        volume: '3×15',
        tip: 'Dirsekler sabit, tam açılım yap',
      ),
      (
        name: 'Overhead Tricep Extension',
        volume: '3×12',
        tip: 'Yavaş indir, yukarıda kilitle',
      ),
    ],
    description:
        'Göğsün tüm bölgelerini (üst, orta, alt) ve triceps\'i derin çalıştıran itme günü antrenmanı. Her setten sonra 60-90 sn dinlen.',
  ),
  (
    name: 'Sırt & Biceps',
    subtitle: 'Çekme Günü',
    difficulty: 'Orta',
    difficultyColor: Color(0xFFF9A825),
    color: Color(0xFF1E88E5),
    colorDark: Color(0xFF0D47A1),
    icon: Icons.back_hand_rounded,
    estimatedMinutes: 65,
    muscles: ['Sırt', 'Biseps', 'Arka Omuz'],
    exercises: [
      (
        name: 'Deadlift',
        volume: '4×5',
        tip: 'Sırt düz, nefes alıp tut, kalçadan it',
      ),
      (
        name: 'Wide Grip Lat Pulldown',
        volume: '4×10',
        tip: 'Göğüs üstüne çek, lat gerilimi hisset',
      ),
      (
        name: 'Barbell Row',
        volume: '4×8',
        tip: '45° öne eğil, göbeğe doğru çek',
      ),
      (
        name: 'Seated Cable Row',
        volume: '3×12',
        tip: 'Omuzları geri-aşağı al, sıkıştır',
      ),
      (
        name: 'Face Pull',
        volume: '3×15',
        tip: 'Arka omuz ve rotator cuff için kritik',
      ),
      (
        name: 'Barbell Curl',
        volume: '4×10',
        tip: 'Dirsek öne gelmesin, tam ROM',
      ),
      (
        name: 'Hammer Curl',
        volume: '3×12',
        tip: 'Önkol ve brachialis geliştirir',
      ),
    ],
    description:
        'Lat genişliği, sırt kalınlığı ve güçlü biseps için eksiksiz çekme günü. Deadlift\'i ısındıktan sonra yap.',
  ),
  (
    name: 'Bacak',
    subtitle: 'Alt Vücut Günü',
    difficulty: 'İleri',
    difficultyColor: Color(0xFFE53935),
    color: Color(0xFF2E7D32),
    colorDark: Color(0xFF1B5E20),
    icon: Icons.directions_walk,
    estimatedMinutes: 75,
    muscles: ['Quads', 'Hamstring', 'Kalça', 'Baldır'],
    exercises: [
      (
        name: 'Back Squat',
        volume: '5×5',
        tip: 'Diz-ayak aynı yönde, kalça paralele kadar',
      ),
      (
        name: 'Romanian Deadlift',
        volume: '4×8',
        tip: 'Hamstring gerilimini hisset, sırt düz',
      ),
      (
        name: 'Leg Press',
        volume: '4×12',
        tip: 'Diz 90°\'de kilitleme, ayak pozisyonu değiştir',
      ),
      (
        name: 'Walking Lunge',
        volume: '3×12 (her bacak)',
        tip: 'Öne diz ayak parmağını geçmesin',
      ),
      (name: 'Leg Curl', volume: '3×12', tip: 'Kontrollü indir, iki kat yavaş'),
      (
        name: 'Bulgarian Split Squat',
        volume: '3×10 (her bacak)',
        tip: 'Arka ayak yüksekte, denge önemli',
      ),
      (
        name: 'Standing Calf Raise',
        volume: '4×20',
        tip: 'Tepede 1-2 sn tut, tam ROM',
      ),
    ],
    description:
        'Bacakların en zorlu ama en etkili antrenmanı. Squat öncelikli, ağırlıkları kademeli artır. Antrenman sonrası germeyi atla.',
  ),
  (
    name: 'Karın & Core',
    subtitle: 'Core Günü',
    difficulty: 'Başlangıç',
    difficultyColor: Color(0xFF43A047),
    color: Color(0xFF00ACC1),
    colorDark: Color(0xFF006064),
    icon: Icons.self_improvement,
    estimatedMinutes: 35,
    muscles: ['Üst Karın', 'Alt Karın', 'Oblikler', 'Core'],
    exercises: [
      (
        name: 'Plank',
        volume: '3×60 sn',
        tip: 'Kalça ne yukarı ne aşağı, gövde düz',
      ),
      (
        name: 'Hanging Leg Raise',
        volume: '3×12',
        tip: 'Sallanma, yavaş kaldır-indir',
      ),
      (
        name: 'Cable Crunch',
        volume: '4×15',
        tip: 'Alnı dize götür, bel esnesin',
      ),
      (
        name: 'Russian Twist',
        volume: '3×20 (her yön)',
        tip: 'Ayaklar yerden kalkık, omuz döndür',
      ),
      (
        name: 'Ab Wheel Rollout',
        volume: '3×10',
        tip: 'Geri dönerken yavaş, core sıkı',
      ),
      (
        name: 'Side Plank',
        volume: '3×40 sn (her yan)',
        tip: 'Kalça yükselsin, vücut düz',
      ),
      (
        name: 'Reverse Crunch',
        volume: '3×15',
        tip: 'Alt karnı yuvarla, ivme kullanma',
      ),
    ],
    description:
        'Üst-alt karın ve oblik kasları ayrı ayrı çalıştıran kapsamlı core antrenmanı. Haftada 3 kez uygulanabilir.',
  ),
  (
    name: 'Omuz',
    subtitle: 'Delts Günü',
    difficulty: 'Orta',
    difficultyColor: Color(0xFFF9A825),
    color: Color(0xFF7B1FA2),
    colorDark: Color(0xFF4A148C),
    icon: Icons.accessibility_new,
    estimatedMinutes: 55,
    muscles: ['Ön Omuz', 'Yan Omuz', 'Arka Omuz', 'Trapezius'],
    exercises: [
      (
        name: 'Overhead Press (Barbell)',
        volume: '4×8',
        tip: 'Bel hafif öne eğilsin, core sıkı',
      ),
      (
        name: 'Dumbbell Lateral Raise',
        volume: '4×15',
        tip: 'Dirsek hafif bükük, kontrollü indir',
      ),
      (
        name: 'Arnold Press',
        volume: '3×10',
        tip: 'Tüm delt başlarını çalıştırır',
      ),
      (
        name: 'Rear Delt Fly (Dumbbell)',
        volume: '4×15',
        tip: 'Öne eğil, dirsek hafif bükük',
      ),
      (name: 'Face Pull', volume: '3×15', tip: 'İp yüz hizasına, dışa döndür'),
      (
        name: 'Upright Row',
        volume: '3×12',
        tip: 'Dirsekler omuz hizasına kadar',
      ),
      (
        name: 'Barbell Shrug',
        volume: '4×15',
        tip: 'Trapezi yukarı sık, döndürme',
      ),
    ],
    description:
        '3D omuz gelişimi için ön, yan ve arka delt\'i eşit çalıştıran program. Trapezius da dahil, tam omuz antrenmanı.',
  ),
  (
    name: 'Full Body',
    subtitle: 'Tüm Vücut Günü',
    difficulty: 'Orta',
    difficultyColor: Color(0xFFF9A825),
    color: Color(0xFF546E7A),
    colorDark: Color(0xFF263238),
    icon: Icons.accessibility_new_rounded,
    estimatedMinutes: 70,
    muscles: ['Göğüs', 'Sırt', 'Bacak', 'Omuz', 'Core'],
    exercises: [
      (
        name: 'Back Squat',
        volume: '4×6',
        tip: 'Tüm vücudu ısıtır, ağırlığı kademeli artır',
      ),
      (
        name: 'Bench Press',
        volume: '4×8',
        tip: 'Kürek kemiklerini birleştir, kontrollü indir',
      ),
      (
        name: 'Deadlift',
        volume: '3×5',
        tip: 'Sırt düz, nefes alıp tut, kalçadan it',
      ),
      (
        name: 'Overhead Press (Barbell)',
        volume: '3×10',
        tip: 'Core sıkı, bel hafif öne eğilsin',
      ),
      (
        name: 'Wide Grip Lat Pulldown',
        volume: '3×10',
        tip: 'Göğüs üstüne çek, lat gerilimini hisset',
      ),
      (
        name: 'Walking Lunge',
        volume: '3×10 (her bacak)',
        tip: 'Öne diz ayak parmağını geçmesin',
      ),
      (
        name: 'Plank',
        volume: '3×45 sn',
        tip: 'Kalça sabit, gövde düz bir çizgide kalsın',
      ),
    ],
    description:
        'Tüm büyük kas gruplarını tek seansta çalıştıran dengeli full body programı. Haftada 3 kez uygulamak için idealdir; squat ile başla, core ile bitir.',
  ),
];

class _WorkoutTemplatesSection extends StatelessWidget {
  final bool isPremium;
  final bool compactTitle;
  final void Function(_TemplateData) onStartPressed;
  final void Function(_TemplateData) onSavePressed;
  final VoidCallback onUpgradePressed;

  const _WorkoutTemplatesSection({
    required this.isPremium,
    this.compactTitle = false,
    required this.onStartPressed,
    required this.onSavePressed,
    required this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Text(
                compactTitle ? 'Hızlı Başlat' : 'Hazır Programlar',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                isPremium
                    ? '${_kWorkoutTemplates.length} program'
                    : 'Önizleme açık',
                style: TextStyle(
                  fontSize: 12,
                  color: isPremium
                      ? Colors.white.withValues(alpha: 0.4)
                      : const Color(0xFFFBBF24),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _kWorkoutTemplates.length,
            itemBuilder: (context, i) {
              final t = _kWorkoutTemplates[i];
              return _TemplateCard(
                template: t,
                locked: !isPremium,
                onTap: () => isPremium
                    ? _showTemplateDetail(
                        context,
                        t,
                        locked: false,
                        onStartPressed: () => onStartPressed(t),
                        onSavePressed: () => onSavePressed(t),
                        onUpgradePressed: onUpgradePressed,
                      )
                    : _showTemplateDetail(
                        context,
                        t,
                        locked: true,
                        onStartPressed: () => onStartPressed(t),
                        onSavePressed: () => onSavePressed(t),
                        onUpgradePressed: onUpgradePressed,
                      ),
              );
            },
          ),
        ),
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              'Kartları inceleyebilirsin. Başlatmak ve kaydetmek için Premium açılır; böylece sana uygun spliti seçmeden önce ne alacağını görürsün.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  static void _showTemplateDetail(
    BuildContext context,
    _TemplateData t, {
    required bool locked,
    required VoidCallback onStartPressed,
    required VoidCallback onSavePressed,
    required VoidCallback onUpgradePressed,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateDetailSheet(
        template: t,
        locked: locked,
        onStart: onStartPressed,
        onSave: onSavePressed,
        onUpgrade: onUpgradePressed,
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final _TemplateData template;
  final VoidCallback onTap;
  final bool locked;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = template;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: locked
                ? [
                    t.color.withValues(alpha: 0.14),
                    t.colorDark.withValues(alpha: 0.28),
                  ]
                : [
                    t.color.withValues(alpha: 0.25),
                    t.colorDark.withValues(alpha: 0.5),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.color.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      locked ? Icons.lock_rounded : t.icon,
                      color: t.color,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: t.difficultyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: t.difficultyColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      t.difficulty,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: t.difficultyColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                t.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: t.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${t.estimatedMinutes} dk',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.fitness_center,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${t.exercises.length} egz.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: t.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        locked ? 'Önizle' : 'Detay Gör',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: t.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: t.color,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateDetailSheet extends StatelessWidget {
  final _TemplateData template;
  final bool locked;
  final VoidCallback onStart;
  final VoidCallback onSave;
  final VoidCallback onUpgrade;

  const _TemplateDetailSheet({
    required this.template,
    required this.locked,
    required this.onStart,
    required this.onSave,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final t = template;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollC) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F0F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header gradient
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      t.color.withValues(alpha: 0.3),
                      t.colorDark.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(t.icon, color: t.color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: t.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: '${t.estimatedMinutes} dk',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.bar_chart_rounded,
                      label: t.difficulty,
                      color: t.difficultyColor,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.fitness_center,
                      label: '${t.exercises.length} egzersiz',
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Muscles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: t.muscles
                      .map(
                        (m) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: t.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: t.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            m,
                            style: TextStyle(
                              fontSize: 12,
                              color: t.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (locked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.visibility_rounded,
                          color: Color(0xFFFBBF24),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bu bir önizleme. Programın içeriğini inceleyebilirsin; kaydetmek ve antrenmanı tek dokunuşla başlatmak Premium ile açılır.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  t.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Exercise list header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Egzersizler',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Scrollable exercise list
              Expanded(
                child: ListView.builder(
                  controller: scrollC,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: t.exercises.length,
                  itemBuilder: (context, i) {
                    final ex = t.exercises[i];
                    // Catalog'dan Exercise objesini bul (varsa guide'a yönlendir)
                    Exercise? findExercise() {
                      final query = ex.name.toLowerCase();
                      Exercise? partial;
                      for (final group in kMuscleGroupInfo.keys) {
                        final catalog = buildExerciseCatalogForGroup(group);
                        // Exact match
                        for (final e in catalog) {
                          if (e.name.toLowerCase() == query) return e;
                        }
                        // Partial match (either direction)
                        if (partial == null) {
                          for (final e in catalog) {
                            final cat = e.name.toLowerCase();
                            if (cat.contains(query) || query.contains(cat)) {
                              partial = e;
                              break;
                            }
                          }
                        }
                      }
                      return partial;
                    }

                    return GestureDetector(
                      onTap: () {
                        final found = findExercise();
                        if (found == null) return;
                        final muscleLabel = t.muscles.isNotEmpty
                            ? t.muscles.first
                            : null;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ExerciseGuideScreen(
                              exercise: found,
                              accentColor: t.color,
                              muscleGroupLabel: muscleLabel,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: t.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: t.color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ex.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (ex.tip.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '💡 ${ex.tip}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: t.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ex.volume,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: t.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ); // GestureDetector
                  },
                ),
              ),
              // Start button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: locked
                    ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onUpgrade();
                          },
                          icon: const Icon(
                            Icons.workspace_premium_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'Premium ile Bu Programı Aç',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.color,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                onSave();
                              },
                              icon: const Icon(
                                Icons.bookmark_add_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Programı Kaydet',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: t.color,
                                side: BorderSide(
                                  color: t.color.withValues(alpha: 0.45),
                                ),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                onStart();
                              },
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 22,
                              ),
                              label: const Text(
                                'Başlat',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.color,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionExercisePlan {
  const _SessionExercisePlan({
    required this.name,
    required this.sets,
    required this.reps,
    this.muscleGroup,
    this.restSeconds = 90,
  });

  final String name;
  final int sets;
  final int reps;
  final String? muscleGroup;
  final int restSeconds;
}

class _TodayWorkoutActionCard extends StatelessWidget {
  final List<Workout> workouts;
  final TodayWorkoutSuggestion? suggestion;
  final VoidCallback onStart;
  final VoidCallback onExplore;

  const _TodayWorkoutActionCard({
    required this.workouts,
    required this.suggestion,
    required this.onStart,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayCount = workouts.where((workout) {
      final d = workout.workoutDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
    final latest = workouts.isEmpty ? null : workouts.first;
    final daysSince = latest == null
        ? null
        : DateTime(now.year, now.month, now.day)
              .difference(
                DateTime(
                  latest.workoutDate.year,
                  latest.workoutDate.month,
                  latest.workoutDate.day,
                ),
              )
              .inDays;

    String title;
    String detail;
    IconData icon;
    Color accent;
    if (todayCount > 0) {
      title = 'Bugün seans tamam';
      detail =
          '$todayCount antrenman kaydın var. İstersen yardımcı hareket veya mobilite ekleyebilirsin.';
      icon = Icons.verified_rounded;
      accent = const Color(0xFF66BB6A);
    } else if (daysSince == null) {
      title = 'İlk seansı başlat';
      detail = 'Hafif bir full body seansıyla ritmi kur.';
      icon = Icons.play_arrow_rounded;
      accent = const Color(0xFF2E7D32);
    } else if (daysSince >= 3) {
      title = '$daysSince gündür antrenman yok';
      detail = 'Kısa bir dönüş seansı planla; yoğunluğu kontrollü tut.';
      icon = Icons.restart_alt_rounded;
      accent = Colors.orangeAccent;
    } else {
      title = suggestion?.title ?? 'Bugünün önerisi hazır';
      detail = suggestion?.detail ?? 'Toparlanmış bir bölge seçip seansa gir.';
      icon = suggestion?.icon ?? Icons.auto_graph_rounded;
      accent = suggestion?.color ?? const Color(0xFF66BB6A);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.20), const Color(0xFF141414)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BUGÜN NE YAPMALIYIM?',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 13,
              height: 1.38,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Antrenmana Başla',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onExplore,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Bölge Seç',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressionSpotlightCard extends StatelessWidget {
  final List<Workout> workouts;
  final void Function(_SessionExercisePlan plan) onStart;

  const _ProgressionSpotlightCard({
    required this.workouts,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.length < 2) return const SizedBox.shrink();
    final latest = workouts.first;
    final hint = ProgressionEngine.compute(
      history: workouts,
      exerciseName: latest.name,
      targetReps: latest.reps ?? 10,
    );
    if (hint.lastWeight == null && hint.suggestedWeight <= 0) {
      return const SizedBox.shrink();
    }
    final accent = hint.readilyProgressed
        ? Colors.amber
        : hint.trendDirection == TrendDirection.down
        ? Colors.orangeAccent
        : const Color(0xFF66BB6A);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.trending_up_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${latest.name}: ${hint.weightLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => onStart(
              _SessionExercisePlan(
                name: latest.name,
                sets: latest.sets ?? 3,
                reps: hint.suggestedReps,
                muscleGroup: latest.muscleGroup,
              ),
            ),
            child: Text(
              'Dene',
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBalanceCard extends StatelessWidget {
  final List<Workout> workouts;
  final void Function(String group) onSelectGroup;

  const _WeeklyBalanceCard({
    required this.workouts,
    required this.onSelectGroup,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final workedGroups = workouts
        .where((workout) => !workout.workoutDate.isBefore(weekStart))
        .map((workout) => workout.muscleGroup ?? workout.workoutType)
        .whereType<String>()
        .map((group) => ExerciseParserService.normalizeMuscleGroupCode(group))
        .where((group) => group.isNotEmpty)
        .toSet();
    final missing = kMuscleGroupInfo.keys
        .where((group) => !workedGroups.contains(group))
        .take(4)
        .toList();
    if (missing.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.balance_rounded, color: Color(0xFF66BB6A), size: 18),
              SizedBox(width: 8),
              Text(
                'Haftalık denge',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bu hafta eksik kalan bölgeleri tamamlamak planı dengeler.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: missing.map((group) {
              final info = kMuscleGroupInfo[group];
              final color = info?.color ?? const Color(0xFF66BB6A);
              return GestureDetector(
                onTap: () => onSelectGroup(group),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    info?.label ?? group,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TodayProgramCard extends StatelessWidget {
  final List<WorkoutProgram> programs;
  final void Function(WorkoutProgram program, ProgramDay day) onStartDay;

  const _TodayProgramCard({required this.programs, required this.onStartDay});

  @override
  Widget build(BuildContext context) {
    WorkoutProgram? program;
    for (final item in programs) {
      if (item.days.isNotEmpty) {
        program = item;
        break;
      }
    }
    if (program == null) return const SizedBox.shrink();
    final selectedProgram = program;
    final dayIndex = (DateTime.now().weekday - 1) % selectedProgram.days.length;
    final day = selectedProgram.days[dayIndex];
    final first = day.exercises.isEmpty ? null : day.exercises.first;
    final accent = first == null
        ? const Color(0xFF66BB6A)
        : kMuscleGroupInfo[first.muscleGroup]?.color ?? const Color(0xFF66BB6A);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.16), const Color(0xFF121212)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${program.name}: ${day.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.exercises.length} hareket bugün için hazır',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: day.exercises.isEmpty
                ? null
                : () => onStartDay(selectedProgram, day),
            child: Text(
              'Başlat',
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  final _WorkoutHistoryFilter selected;
  final ValueChanged<_WorkoutHistoryFilter> onChanged;

  const _HistoryFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _chip('Seçili gün', _WorkoutHistoryFilter.selectedDay),
          _chip('Tümü', _WorkoutHistoryFilter.all),
          _chip('Bu hafta', _WorkoutHistoryFilter.thisWeek),
          _chip('PR', _WorkoutHistoryFilter.prs),
        ],
      ),
    );
  }

  Widget _chip(String label, _WorkoutHistoryFilter filter) {
    final isSelected = selected == filter;
    return GestureDetector(
      onTap: () => onChanged(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2E7D32).withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF66BB6A).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF66BB6A) : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ActiveWorkoutSessionSheet extends StatefulWidget {
  final String title;
  final List<_SessionExercisePlan> plans;
  final VoidCallback onFinish;

  const _ActiveWorkoutSessionSheet({
    required this.title,
    required this.plans,
    required this.onFinish,
  });

  @override
  State<_ActiveWorkoutSessionSheet> createState() =>
      _ActiveWorkoutSessionSheetState();
}

class _ActiveWorkoutSessionSheetState
    extends State<_ActiveWorkoutSessionSheet> {
  late final Set<String> _completedSets = <String>{};
  Timer? _timer;
  int _remaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleSet(String key, int restSeconds) {
    setState(() {
      if (_completedSets.contains(key)) {
        _completedSets.remove(key);
      } else {
        _completedSets.add(key);
        _startRest(restSeconds);
      }
    });
  }

  void _startRest(int seconds) {
    _timer?.cancel();
    _remaining = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _remaining = 0;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = widget.plans.fold<int>(0, (sum, plan) => sum + plan.sets);
    final progress = totalSets == 0 ? 0.0 : _completedSets.length / totalSets;
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.timer_rounded, color: Color(0xFF66BB6A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_remaining > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$minutes:$seconds',
                      style: const TextStyle(
                        color: Color(0xFF66BB6A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_completedSets.length}/$totalSets set tamamlandı',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.plans.asMap().entries.map((entry) {
              final exerciseIndex = entry.key;
              final plan = entry.value;
              final color =
                  kMuscleGroupInfo[plan.muscleGroup]?.color ??
                  const Color(0xFF66BB6A);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(plan.sets, (setIndex) {
                        final key = '$exerciseIndex-$setIndex';
                        final done = _completedSets.contains(key);
                        return InkWell(
                          onTap: () => _toggleSet(key, plan.restSeconds),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: done
                                  ? color.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: done
                                    ? color.withValues(alpha: 0.55)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  done
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: done ? color : Colors.white38,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${setIndex + 1}. set · ${plan.reps} tekrar',
                                  style: TextStyle(
                                    color: done ? Colors.white : Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onFinish,
                icon: const Icon(Icons.save_rounded, color: Colors.white),
                label: const Text(
                  'Kayda Geçir',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _RecoveryInsightsCard extends StatelessWidget {
  final TodayWorkoutSuggestion? workoutSuggestion;
  final Map<String, FatigueStatus> recoveryStatuses;
  final int totalWorkouts;
  final int totalSets;
  final int totalCaloriesBurned;
  final void Function(String group) onSelectGroup;

  const _RecoveryInsightsCard({
    required this.workoutSuggestion,
    required this.recoveryStatuses,
    required this.totalWorkouts,
    required this.totalSets,
    required this.totalCaloriesBurned,
    required this.onSelectGroup,
  });

  @override
  Widget build(BuildContext context) {
    final freshEntries = recoveryStatuses.entries
        .where((entry) => entry.value.level == FatigueLevel.fresh)
        .take(3)
        .toList();
    final highlightEntries = freshEntries.isNotEmpty
        ? freshEntries
        : recoveryStatuses.entries.take(3).toList();
    final accent = workoutSuggestion?.color ?? const Color(0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.18), const Color(0xFF121212)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  workoutSuggestion?.icon ?? Icons.auto_graph_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workoutSuggestion?.title ?? 'Bugün için akıllı öneri',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workoutSuggestion?.detail ??
                          'Toparlanma durumuna göre hazır bölgeler burada listelenir.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(label: 'Toplam', value: '$totalWorkouts'),
              const SizedBox(width: 8),
              _MiniStat(label: 'Set', value: '$totalSets'),
              const SizedBox(width: 8),
              _MiniStat(label: 'Kcal', value: '$totalCaloriesBurned'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Hazır Bölgeler',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: highlightEntries.map((entry) {
              final info = kMuscleGroupInfo[entry.key];
              final status = entry.value;
              final isFresh = status.level == FatigueLevel.fresh;
              final chipColor = isFresh
                  ? accent
                  : status.level == FatigueLevel.recovering
                  ? Colors.amber
                  : Colors.redAccent;
              return GestureDetector(
                onTap: () => onSelectGroup(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: chipColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info?.label ?? entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status.levelLabel,
                        style: TextStyle(
                          color: chipColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weekly Volume Chart ──────────────────────────────────────────────────────

class _WeeklyVolumeChart extends StatelessWidget {
  final List<Workout> workouts;

  const _WeeklyVolumeChart({required this.workouts});

  /// Returns the last 7 days' total volume (weight × reps × sets) per day.
  List<({String label, double volume})> _weeklyData() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final dayWorkouts = workouts.where((w) {
        final d = w.workoutDate;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      });
      double vol = 0;
      for (final w in dayWorkouts) {
        final weight = w.weight ?? 0;
        final reps = w.reps ?? 0;
        final sets = w.sets ?? 1;
        vol += weight * reps * sets;
      }
      const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return (label: days[day.weekday - 1], volume: vol);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _weeklyData();
    final maxVol = data.map((d) => d.volume).fold(0.0, (a, b) => a > b ? a : b);
    if (maxVol == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Haftalık Antrenman Hacmi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 86,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                final barH = maxVol > 0 ? (d.volume / maxVol) * 64 : 0.0;
                final isToday = data.last == d;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: barH.clamp(2.0, 64.0),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF2E7D32)
                                : const Color(
                                    0xFF2E7D32,
                                  ).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Streak Row ────────────────────────────────────────────────────────

class _WeeklyStreakRow extends StatelessWidget {
  final List<Workout> workouts;
  final int totalCount;
  final int thisWeekCount;
  final int prCount;

  const _WeeklyStreakRow({
    required this.workouts,
    required this.totalCount,
    required this.thisWeekCount,
    required this.prCount,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2E7D32);
    const accentLight = Color(0xFF66BB6A);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    const dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    final workedDays = workouts
        .where(
          (w) =>
              !w.workoutDate.isBefore(
                weekStart.subtract(const Duration(seconds: 1)),
              ) &&
              w.workoutDate.isBefore(weekStart.add(const Duration(days: 7))),
        )
        .map((w) => w.workoutDate.weekday)
        .toSet();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final dayNum = i + 1;
              final date = weekStart.add(Duration(days: i));
              final hasWorkout = workedDays.contains(dayNum);
              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isFuture = date.isAfter(now);

              return Column(
                children: [
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? accentLight
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasWorkout
                          ? accent
                          : isToday
                          ? accent.withValues(alpha: 0.12)
                          : Colors.white.withValues(
                              alpha: isFuture ? 0.0 : 0.04,
                            ),
                      border: Border.all(
                        color: isToday
                            ? accentLight
                            : hasWorkout
                            ? accent
                            : Colors.white.withValues(
                                alpha: isFuture ? 0.06 : 0.1,
                              ),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: hasWorkout
                        ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          )
                        : isToday
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentLight,
                            ),
                          )
                        : Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(
                                alpha: isFuture ? 0.2 : 0.35,
                              ),
                            ),
                          ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),
          // ── Stat pills ──────────────────────────────────────────────────
          Row(
            children: [
              _StreakStatPill(
                icon: Icons.local_fire_department_rounded,
                iconColor: Colors.orange.shade400,
                bgColor: Colors.orange.withValues(alpha: 0.1),
                value: '$thisWeekCount',
                label: 'bu hafta',
              ),
              const Spacer(),
              _StreakStatPill(
                icon: Icons.fitness_center_rounded,
                iconColor: const Color(0xFF1E88E5),
                bgColor: const Color(0xFF1E88E5).withValues(alpha: 0.08),
                value: '$totalCount',
                label: 'toplam',
              ),
              const SizedBox(width: 8),
              _StreakStatPill(
                icon: Icons.emoji_events_rounded,
                iconColor: Colors.amber,
                bgColor: Colors.amber.withValues(alpha: 0.08),
                value: '$prCount',
                label: 'PR',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Streak Stat Pill ─────────────────────────────────────────────────────────

class _StreakStatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;

  const _StreakStatPill({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick-Start Type Card ─────────────────────────────────────────────────────

class _QuickStartTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickStartTypeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily Tip Card ───────────────────────────────────────────────────────────

class _DailyTipCard extends StatelessWidget {
  static const _tips = [
    (
      icon: '💧',
      text: 'Antrenman öncesi 500 ml su iç — performansını %10 artırır.',
    ),
    (
      icon: '😴',
      text:
          'Kas gelişimi antrenman sırasında değil, uyurken olur. 7-9 saat uyu.',
    ),
    (
      icon: '🥩',
      text: 'Her öğün bir avuç protein al — tokluk ve kas için idealdir.',
    ),
    (
      icon: '⏱️',
      text:
          'Setler arası 60-90 sn dinlenme hipertrofi için en verimli aralıktır.',
    ),
    (
      icon: '📈',
      text:
          'Her haftada bir ağırlık veya tekrar artır — lineer ilerleme şarttır.',
    ),
    (
      icon: '🔥',
      text:
          'Isınmayı atlama. 5 dk dinamik ısınma sakatlık riskini %50 azaltır.',
    ),
    (icon: '🧘', text: 'Germe egzersizleri antrenman sonrası yap, önce değil.'),
  ];

  const _DailyTipCard();

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().weekday % _tips.length];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Text(tip.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Günün İpucu',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF66BB6A),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Favorites Quick Strip ────────────────────────────────────────────────────

class _FavoritesQuickStrip extends StatelessWidget {
  final List<FavoriteExerciseEntry> favorites;
  final void Function(FavoriteExerciseEntry favorite) onTap;

  const _FavoritesQuickStrip({required this.favorites, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Favorilerim',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${favorites.length} egzersiz',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            itemBuilder: (context, i) {
              final favorite = favorites[i];
              return GestureDetector(
                onTap: () => onTap(favorite),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        favorite.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Programlarım section ──────────────────────────────────────────────────────

class _MyProgramsSection extends StatelessWidget {
  final List<WorkoutProgram> programs;
  final VoidCallback onCreateTap;
  final void Function(WorkoutProgram) onProgramTap;

  const _MyProgramsSection({
    required this.programs,
    required this.onCreateTap,
    required this.onProgramTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
          child: Row(
            children: [
              const Text(
                'Programlarım',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onCreateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Color(0xFF4CAF50)),
                      SizedBox(width: 4),
                      Text(
                        'Oluştur',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (programs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: onCreateTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.post_add_rounded,
                        color: Color(0xFF4CAF50),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kendi programını oluştur',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Günlere göre egzersiz planla',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 130,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: programs.length + 1,
              itemBuilder: (context, i) {
                if (i == programs.length) {
                  return _AddProgramCard(onTap: onCreateTap);
                }
                return _ProgramCard(
                  program: programs[i],
                  onTap: () => onProgramTap(programs[i]),
                );
              },
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _AddProgramCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddProgramCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF4CAF50), size: 28),
            SizedBox(height: 8),
            Text(
              'Yeni\nProgram',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final WorkoutProgram program;
  final VoidCallback onTap;

  const _ProgramCard({required this.program, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uniqueMuscles = program.days
        .expand((d) => d.exercises.map((e) => e.muscleGroup))
        .toSet()
        .take(3)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2C1A), Color(0xFF0E1614)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.fitness_center_rounded,
                  size: 14,
                  color: Color(0xFF4CAF50),
                ),
                const SizedBox(width: 6),
                Text(
                  '${program.days.length} Gün',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              program.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: uniqueMuscles.map((g) {
                final color = kMuscleGroupInfo[g]?.color ?? Colors.grey;
                final label = kMuscleGroupInfo[g]?.label ?? g;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Program detail sheet ──────────────────────────────────────────────────────

class _ProgramDetailSheet extends StatelessWidget {
  final WorkoutProgram program;
  final void Function(ProgramDay) onStartDay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProgramDetailSheet({
    required this.program,
    required this.onStartDay,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (program.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          program.description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: Colors.white38,
                ),
                const SizedBox(width: 6),
                Text(
                  '${program.days.length} antrenman günü',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: program.days.length,
              itemBuilder: (context, i) => _DayListTile(
                day: program.days[i],
                number: i + 1,
                onStart: () => onStartDay(program.days[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Programı Sil',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '"${program.name}" programını silmek istediğine emin misin?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _DayListTile extends StatelessWidget {
  final ProgramDay day;
  final int number;
  final VoidCallback onStart;

  const _DayListTile({
    required this.day,
    required this.number,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final muscleTags = day.exercises
        .map((e) => e.muscleGroup)
        .toSet()
        .take(3)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        title: Text(
          day.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: day.exercises.isEmpty
            ? const Text(
                'Egzersiz eklenmemiş',
                style: TextStyle(color: Colors.white30, fontSize: 11),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: [
                    Text(
                      '${day.exercises.length} egzersiz',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    ...muscleTags.map((g) {
                      final color = kMuscleGroupInfo[g]?.color ?? Colors.grey;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          kMuscleGroupInfo[g]?.label ?? g,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
        trailing: ElevatedButton(
          onPressed: onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Başlat', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
