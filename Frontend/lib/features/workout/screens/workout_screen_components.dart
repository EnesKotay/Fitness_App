part of 'workout_screen.dart';

class _RegionCard extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String imageUrl;
  final VoidCallback onTap;
  final int? exerciseCount;

  const _RegionCard({
    required this.label,
    required this.color,
    required this.icon,
    required this.imageUrl,
    required this.onTap,
    this.exerciseCount,
  });

  @override
  State<_RegionCard> createState() => _RegionCardState();
}

class _RegionCardState extends State<_RegionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Egzersiz sayısını katalogdan al (veya dışarıdan geçirilebilir)
    final count =
        widget.exerciseCount ??
        buildExerciseCatalogForGroup(
          ExerciseParserService.normalizeMuscleGroupCode(widget.label),
        ).length;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: -5,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Arka plan resmi
              widget.imageUrl.startsWith('assets/')
                  ? Image.asset(widget.imageUrl, fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: widget.color.withValues(alpha: 0.3)),
                      errorWidget: (_, _, _) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              widget.color.withValues(alpha: 0.4),
                              widget.color.withValues(alpha: 0.15),
                            ],
                          ),
                        ),
                      ),
                    ),
              // Koyu gradient
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    stops: const [0.1, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst: ikon badge
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 16),
                      ),
                    ),
                    // Alt: label + egzersiz sayısı
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.1,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.color.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '$count hareket',
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
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

/// Kas grubuna göre uygun ikon döner
IconData _iconForMuscleGroup(String? muscleGroup) {
  switch ((muscleGroup ?? '').toUpperCase()) {
    case 'CHEST':
      return Icons.self_improvement_rounded;
    case 'BACK':
      return Icons.back_hand_rounded;
    case 'LEGS':
    case 'GLUTES':
      return Icons.directions_walk_rounded;
    case 'SHOULDERS':
      return Icons.accessibility_new_rounded;
    case 'BICEPS':
    case 'TRICEPS':
    case 'ARMS':
      return Icons.fitness_center_rounded;
    case 'CORE':
    case 'ABS':
      return Icons.circle_outlined;
    case 'CARDIO':
      return Icons.directions_run_rounded;
    default:
      return Icons.fitness_center_rounded;
  }
}

class _ExerciseCard extends StatefulWidget {
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
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor;
    final exercise = widget.exercise;
    final subRegionLabel = widget.subRegionLabel;
    final isFavorite = widget.isFavorite;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    // Sol renk çizgisi
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
                    // Kas grubuna göre ikon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        _iconForMuscleGroup(exercise.muscleGroup),
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // İçerik
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
                                      color: accentColor.withValues(
                                        alpha: 0.15,
                                      ),
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
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
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
                                      color: Colors.amber.withValues(
                                        alpha: 0.75,
                                      ),
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
                    // Sağ: favori + chevron
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: widget.onFavoriteTap,
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                isFavorite
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                key: ValueKey(isFavorite),
                                size: 22,
                                color: isFavorite
                                    ? Colors.amber
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: accentColor.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  Color _muscleColor() {
    final group = workout.muscleGroup?.toUpperCase() ?? '';
    return kMuscleGroupInfo[group]?.color ?? const Color(0xFF2E7D32);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'd MMM, EEEE',
      'tr_TR',
    ).format(workout.workoutDate);
    final timeStr = DateFormat('HH:mm').format(workout.workoutDate);
    final accent = _muscleColor();

    // Volüm hesabı
    final double? volume =
        (workout.weight != null && workout.sets != null && workout.reps != null)
        ? (workout.weight! * workout.sets! * workout.reps!)
        : null;

    return Dismissible(
      key: ValueKey('history_${workout.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Sil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // gerçek silme onDelete içinde yapılıyor
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF131313),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(20),
            splashColor: accent.withValues(alpha: 0.06),
            highlightColor: accent.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Başlık satırı ────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol renk çizgisi
                      Container(
                        width: 4,
                        height: 52,
                        margin: const EdgeInsets.only(right: 14, top: 2),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
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
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (workout.oneRepMax != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.amber.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🏆',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${workout.oneRepMax!.toStringAsFixed(1)} kg',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.amber,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$dateStr • $timeStr',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white.withValues(alpha: 0.38),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── İstatistik satırı ────────────────────────────────────
                  Row(
                    children: [
                      if (workout.weight != null)
                        _StatPill(
                          label: '${workout.weight!.toStringAsFixed(1)} kg',
                          icon: Icons.monitor_weight_outlined,
                          color: accent,
                        ),
                      if (workout.sets != null) ...[
                        if (workout.weight != null) const SizedBox(width: 8),
                        _StatPill(
                          label: '${workout.sets}×${workout.reps ?? '?'}',
                          icon: Icons.layers_rounded,
                          color: Colors.orange,
                        ),
                      ],
                      if (volume != null && volume > 0) ...[
                        const SizedBox(width: 8),
                        _StatPill(
                          label: '${(volume / 1000).toStringAsFixed(1)}t vol',
                          icon: Icons.bar_chart_rounded,
                          color: Colors.purple,
                        ),
                      ],
                      if (workout.durationMinutes != null &&
                          workout.durationMinutes! > 0) ...[
                        const SizedBox(width: 8),
                        _StatPill(
                          label: '${workout.durationMinutes} dk',
                          icon: Icons.timer_rounded,
                          color: Colors.blue,
                        ),
                      ],
                      const Spacer(),
                      // ── Inline aksiyonlar ──────────────────────────────
                      if (onRepeat != null)
                        GestureDetector(
                          onTap: onRepeat,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(
                                  0xFF2E7D32,
                                ).withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.replay_rounded,
                                  size: 14,
                                  color: Color(0xFF66BB6A),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Tekrarla',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF66BB6A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (workout.isSuperset == true &&
                      workout.supersetPartner != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 12,
                          color: Colors.purpleAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Superset: ${workout.supersetPartner}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.purpleAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Text(
                        workout.notes!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.55),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
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

  static const _groupColors = <String, Color>{
    'CHEST': Color(0xFF1E88E5),
    'BACK': Color(0xFF00ACC1),
    'LEGS': Color(0xFFE53935),
    'SHOULDERS': Color(0xFFFFB300),
    'BICEPS': Color(0xFF8E24AA),
    'TRICEPS': Color(0xFF6D4C41),
    'CORE': Color(0xFF43A047),
    'GLUTES': Color(0xFFFF7043),
    'ARMS': Color(0xFF5C6BC0),
    'CARDIO': Color(0xFFEC407A),
  };

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final w in workouts) {
      final mg = w.muscleGroup ?? w.workoutType ?? 'Diğer';
      counts[mg] = (counts[mg] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final top = sorted.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.donut_large_rounded,
                color: Color(0xFF2E7D32),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Kas Grubu Dağılımı',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Mini donut görünümü ────────────────────────────────────
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: top
                        .map(
                          (e) => (
                            value: e.value.toDouble(),
                            color:
                                _groupColors[e.key] ?? const Color(0xFF2E7D32),
                          ),
                        )
                        .toList(),
                  ),
                  child: Center(
                    child: Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // ── Bar listesi ────────────────────────────────────────────
              Expanded(
                child: Column(
                  children: top.map((entry) {
                    final color =
                        _groupColors[entry.key] ?? const Color(0xFF2E7D32);
                    final pct = entry.value / sorted.first.value;
                    final label =
                        kMuscleGroupInfo[entry.key]?.label ?? entry.key;
                    final percent = ((entry.value / total) * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          SizedBox(
                            width: 58,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 6,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<({double value, Color color})> segments;

  const _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final total = segments.fold<double>(0.0, (sum, s) => sum + s.value);
    if (total == 0) return;

    double startAngle = -90 * (3.14159 / 180);
    for (final seg in segments) {
      final sweepAngle = (seg.value / total) * 2 * 3.14159;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle - 0.03, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.segments != segments;
}

// ── Deload Banner ─────────────────────────────────────────────────────────────

class _DeloadBanner extends StatefulWidget {
  const _DeloadBanner();

  @override
  State<_DeloadBanner> createState() => _DeloadBannerState();
}

class _DeloadBannerState extends State<_DeloadBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D2744).withValues(alpha: _pulseAnim.value),
              const Color(0xFF091929),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.blueAccent.withValues(
              alpha: 0.3 + _pulseAnim.value * 0.3,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(
                alpha: 0.08 * _pulseAnim.value,
              ),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              color: Colors.lightBlueAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deload Haftası Zamanı?',
                  style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Son 6 günde sürekli antrenman yaptın. Hafif bir toparlanma haftası performansını artırabilir.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    height: 1.45,
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

typedef _QuickStartExercise = ({String name, int sets, int reps});

typedef _QuickStartPreset = ({
  String label,
  TemplateData templateData,
  String? muscleGroup,
  List<_QuickStartExercise> exercises,
});

const List<_QuickStartPreset> _kQuickStartPresets = [
  // ── PUSH (İtiş) ──────────────────────────────────────────────────────────
  (
    label: 'İtiş (Push) Hipertrofi',
    muscleGroup: 'CHEST',
    exercises: [
      (name: 'Bench Press', sets: 4, reps: 8),
      (name: 'Overhead Press (Barbell)', sets: 4, reps: 8),
      (name: 'Incline Dumbbell Press', sets: 3, reps: 10),
      (name: 'Dumbbell Lateral Raise', sets: 4, reps: 15),
      (name: 'Tricep Pushdown', sets: 3, reps: 12),
      (name: 'Skull Crusher', sets: 3, reps: 12),
    ],
    templateData: (
      exerciseName: 'Bench Press',
      sets: 4,
      reps: 8,
      workoutName: 'İtiş (Push) Hipertrofi',
      duration: 55,
      muscleGroup: 'CHEST',
      difficulty: 'Orta',
    ),
  ),
  // ── PULL (Çekiş) ─────────────────────────────────────────────────────────
  (
    label: 'Çekiş (Pull) Hipertrofi',
    muscleGroup: 'BACK',
    exercises: [
      (name: 'Deadlift', sets: 3, reps: 5),
      (name: 'Pull-Up', sets: 4, reps: 8),
      (name: 'Barbell Row', sets: 4, reps: 10),
      (name: 'Face Pull', sets: 3, reps: 15),
      (name: 'Barbell Curl', sets: 3, reps: 10),
      (name: 'Hammer Curl', sets: 3, reps: 12),
    ],
    templateData: (
      exerciseName: 'Deadlift',
      sets: 3,
      reps: 5,
      workoutName: 'Çekiş (Pull) Hipertrofi',
      duration: 60,
      muscleGroup: 'BACK',
      difficulty: 'İleri',
    ),
  ),
  // ── LEGS (Bacak) ─────────────────────────────────────────────────────────
  (
    label: 'Bacak (Legs) Güç',
    muscleGroup: 'LEGS',
    exercises: [
      (name: 'Back Squat', sets: 4, reps: 6),
      (name: 'Romanian Deadlift', sets: 4, reps: 8),
      (name: 'Leg Press', sets: 3, reps: 12),
      (name: 'Walking Lunge', sets: 3, reps: 10),
      (name: 'Seated Leg Curl', sets: 3, reps: 15),
      (name: 'Standing Calf Raise', sets: 4, reps: 20),
    ],
    templateData: (
      exerciseName: 'Back Squat',
      sets: 4,
      reps: 6,
      workoutName: 'Bacak (Legs) Güç & Hacim',
      duration: 65,
      muscleGroup: 'LEGS',
      difficulty: 'İleri',
    ),
  ),
  // ── UPPER BODY (Üst Vücut) ───────────────────────────────────────────────
  (
    label: 'Üst Vücut (Upper)',
    muscleGroup: 'CHEST',
    exercises: [
      (name: 'Bench Press', sets: 4, reps: 6),
      (name: 'Barbell Row', sets: 4, reps: 8),
      (name: 'Overhead Press (Dumbbell)', sets: 3, reps: 10),
      (name: 'Wide Grip Lat Pulldown', sets: 3, reps: 10),
      (name: 'Dumbbell Curl', sets: 3, reps: 12),
      (name: 'Tricep Extension (Dumbbell)', sets: 3, reps: 12),
    ],
    templateData: (
      exerciseName: 'Bench Press',
      sets: 4,
      reps: 6,
      workoutName: 'Üst Vücut Kompakt Seans',
      duration: 50,
      muscleGroup: 'CHEST',
      difficulty: 'Orta',
    ),
  ),
  // ── LOWER BODY (Alt Vücut) ───────────────────────────────────────────────
  (
    label: 'Alt Vücut (Lower)',
    muscleGroup: 'LEGS',
    exercises: [
      (name: 'Front Squat', sets: 4, reps: 8),
      (name: 'Deadlift (Stiff-Leg)', sets: 3, reps: 10),
      (name: 'Bulgarian Split Squat', sets: 3, reps: 10),
      (name: 'Hip Thrust', sets: 4, reps: 12),
      (name: 'Seated Calf Raise', sets: 3, reps: 15),
    ],
    templateData: (
      exerciseName: 'Front Squat',
      sets: 4,
      reps: 8,
      workoutName: 'Alt Vücut Kompakt Seans',
      duration: 45,
      muscleGroup: 'LEGS',
      difficulty: 'Orta',
    ),
  ),
  // ── FULL BODY (Tüm Vücut) ────────────────────────────────────────────────
  (
    label: 'Full Body (Temel)',
    muscleGroup: 'FULL BODY',
    exercises: [
      (name: 'Back Squat', sets: 3, reps: 8),
      (name: 'Bench Press', sets: 3, reps: 8),
      (name: 'Pull-Up', sets: 3, reps: 8),
      (name: 'Overhead Press (Barbell)', sets: 3, reps: 10),
      (name: 'Romanian Deadlift', sets: 3, reps: 10),
      (name: 'Plank', sets: 3, reps: 60),
    ],
    templateData: (
      exerciseName: 'Back Squat',
      sets: 3,
      reps: 8,
      workoutName: 'Full Body Temel Güç',
      duration: 60,
      muscleGroup: 'FULL BODY',
      difficulty: 'Başlangıç',
    ),
  ),
  // ── CORE & ABS ───────────────────────────────────────────────────────────
  (
    label: 'Core & Karın',
    muscleGroup: 'CORE',
    exercises: [
      (name: 'Hanging Leg Raise', sets: 4, reps: 15),
      (name: 'Cable Crunch', sets: 4, reps: 15),
      (name: 'Russian Twist', sets: 3, reps: 20),
      (name: 'Ab Wheel Rollout', sets: 3, reps: 10),
      (name: 'Plank', sets: 3, reps: 60),
    ],
    templateData: (
      exerciseName: 'Hanging Leg Raise',
      sets: 4,
      reps: 15,
      workoutName: 'Çelik Karın (Core) Seansı',
      duration: 25,
      muscleGroup: 'CORE',
      difficulty: 'Orta',
    ),
  ),
  // ── GLUTES (Kalça) ───────────────────────────────────────────────────────
  (
    label: 'Kalça (Glutes)',
    muscleGroup: 'GLUTES',
    exercises: [
      (name: 'Hip Thrust', sets: 4, reps: 10),
      (name: 'Romanian Deadlift', sets: 4, reps: 12),
      (name: 'Glute Kickback (Cable)', sets: 3, reps: 15),
      (name: 'Hip Abduction (Machine)', sets: 3, reps: 20),
      (name: 'Bulgarian Split Squat', sets: 3, reps: 10),
    ],
    templateData: (
      exerciseName: 'Hip Thrust',
      sets: 4,
      reps: 10,
      workoutName: 'Kalça Odaklı Büyüme',
      duration: 45,
      muscleGroup: 'GLUTES',
      difficulty: 'Orta',
    ),
  ),
  // ── ARMS (Kollar) ────────────────────────────────────────────────────────
  (
    label: 'Kol (Arms) Pump',
    muscleGroup: 'ARMS',
    exercises: [
      (name: 'Barbell Curl', sets: 4, reps: 10),
      (name: 'Skull Crusher', sets: 4, reps: 10),
      (name: 'Hammer Curl', sets: 3, reps: 12),
      (name: 'Tricep Pushdown', sets: 3, reps: 15),
      (name: 'Preacher Curl', sets: 3, reps: 12),
      (name: 'Overhead Tricep Extension', sets: 3, reps: 12),
    ],
    templateData: (
      exerciseName: 'Barbell Curl',
      sets: 4,
      reps: 10,
      workoutName: 'Kol (Arms) Pump',
      duration: 35,
      muscleGroup: 'ARMS',
      difficulty: 'Orta',
    ),
  ),
  (
    label: 'Ev (Ağırlıksız)',
    muscleGroup: 'FULL BODY',
    exercises: [
      (name: 'Push-Up', sets: 4, reps: 15),
      (name: 'Squat', sets: 4, reps: 20),
      (name: 'Walking Lunge', sets: 3, reps: 12),
      (name: 'Plank', sets: 3, reps: 60),
    ],
    templateData: (
      exerciseName: 'Push-Up',
      sets: 4,
      reps: 15,
      workoutName: 'Ev İçi Kondisyon',
      duration: 30,
      muscleGroup: 'FULL BODY',
      difficulty: 'Başlangıç',
    ),
  ),
  (
    label: 'İtme (Push)',
    muscleGroup: 'CHEST',
    exercises: [
      (name: 'Bench Press', sets: 4, reps: 8),
      (name: 'Overhead Press (Barbell)', sets: 4, reps: 8),
      (name: 'Incline Dumbbell Press', sets: 3, reps: 10),
      (name: 'Lateral Raise', sets: 3, reps: 15),
      (name: 'Tricep Pushdown', sets: 3, reps: 12),
    ],
    templateData: (
      exerciseName: 'Bench Press',
      sets: 4,
      reps: 8,
      workoutName: 'Hipertrofi İtme',
      duration: 55,
      muscleGroup: 'CHEST',
      difficulty: 'Orta',
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
  (
    name: 'Dev Kol Günü',
    subtitle: 'Pump Günü',
    difficulty: 'İleri',
    difficultyColor: Color(0xFFE53935),
    color: Color(0xFF8E24AA),
    colorDark: Color(0xFF4A148C),
    icon: Icons.sports_martial_arts,
    estimatedMinutes: 50,
    muscles: ['Biceps', 'Triceps', 'Brachialis', 'Ön Kol'],
    exercises: [
      (
        name: 'Barbell Curl',
        volume: '4×8-10',
        tip: 'Vücudunu sallama, dirsekler sabit',
      ),
      (
        name: 'Skull Crusher',
        volume: '4×10-12',
        tip: 'Triceps uzun başı için alna doğru indir',
      ),
      (
        name: 'Incline Dumbbell Curl',
        volume: '3×12',
        tip: 'Kollar tamamen sarksın, tepe noktasında sık',
      ),
      (
        name: 'Overhead Dumbbell Extension',
        volume: '3×12',
        tip: 'Maksimum esneme (stretch) yakala',
      ),
      (
        name: 'Hammer Curl',
        volume: '3×12-15',
        tip: 'Ön kol hacmi için nötr tutuş',
      ),
      (
        name: 'Tricep Pushdown',
        volume: '3×15',
        tip: 'Halatla dışa doğru açarak kilitle',
      ),
    ],
    description:
        'Kollarını patlama noktasına getirecek izole bir pump programı. Biseps ve trisepsi ardışık süpersetler halinde de yapabilirsin.',
  ),
  (
    name: 'Ev (Dumbbell)',
    subtitle: 'Pratik Seans',
    difficulty: 'Başlangıç',
    difficultyColor: Color(0xFF43A047),
    color: Color(0xFF00897B),
    colorDark: Color(0xFF004D40),
    icon: Icons.home_rounded,
    estimatedMinutes: 45,
    muscles: ['Göğüs', 'Bacak', 'Sırt', 'Omuz', 'Core'],
    exercises: [
      (
        name: 'Dumbbell Goblet Squat',
        volume: '4×12',
        tip: 'Göğsü dik tut, derin çömel',
      ),
      (
        name: 'Push-Up',
        volume: '4×Maks',
        tip: 'Dirsekleri vücuda yakın tut (45 derece)',
      ),
      (
        name: 'Single Arm Dumbbell Row',
        volume: '4×10 (her kol)',
        tip: 'Sırt düz, dambılı kalçaya doğru çek',
      ),
      (
        name: 'Dumbbell Shoulder Press',
        volume: '3×12',
        tip: 'Oturarak veya ayakta, core sıkı',
      ),
      (
        name: 'Dumbbell Romanian Deadlift',
        volume: '3×12',
        tip: 'Kalçayı geriye it, hamstringleri hisset',
      ),
      (name: 'Plank', volume: '3×60 sn', tip: 'Tüm vücudu sık, nefesini tutma'),
    ],
    description:
        'Sadece vücut ağırlığı ve bir çift dambıl ile evde tüm kaslarını çalıştırabileceğin son derece verimli bir full body programı.',
  ),
  (
    name: 'Fonksiyonel Kondisyon',
    subtitle: 'HIIT & Ter Günü',
    difficulty: 'Orta',
    difficultyColor: Color(0xFFF9A825),
    color: Color(0xFFFF6D00),
    colorDark: Color(0xFFE65100),
    icon: Icons.monitor_heart_rounded,
    estimatedMinutes: 40,
    muscles: ['Core', 'Bacak', 'Kardiyovasküler'],
    exercises: [
      (
        name: 'Kettlebell Swing',
        volume: '4×20',
        tip: 'Kolları değil, kalça patlayıcılığını kullan',
      ),
      (
        name: 'Burpee',
        volume: '4×10',
        tip: 'Hızlıca yere in ve sıçrayarak kalk',
      ),
      (
        name: 'Mountain Climber',
        volume: '4×40 sn',
        tip: 'Nabzı yüksek tut, dizleri göğse çek',
      ),
      (name: 'Box Jump', volume: '3×10', tip: 'Yumuşak kon, patlayıcı sıçra'),
      (
        name: 'Farmer\'s Walk',
        volume: '3×45 sn',
        tip: 'Omuzlar geride, core kaya gibi sert',
      ),
      (
        name: 'Battle Rope Slam',
        volume: '3×30 sn',
        tip: 'Tüm gücünle halatları yere çarp',
      ),
    ],
    description:
        'Yağ yakımını maksimize eden, atletik performansı ve kalp-damar sağlığını geliştiren yüksek yoğunluklu (HIIT) istasyon programı.',
  ),
  (
    name: 'Güç: Powerlifting Temel',
    subtitle: 'Ağır Antrenman',
    difficulty: 'İleri',
    difficultyColor: Color(0xFFE53935),
    color: Color(0xFF455A64),
    colorDark: Color(0xFF263238),
    icon: Icons.fitness_center_rounded,
    estimatedMinutes: 80,
    muscles: ['Sırt', 'Göğüs', 'Bacak', 'Omuz', 'Core'],
    exercises: [
      (
        name: 'Back Squat',
        volume: '5×5',
        tip: 'Isınmaya özen göster, ağır ve teknik çalış',
      ),
      (
        name: 'Bench Press',
        volume: '5×5',
        tip: 'Ayaklarla yeri it (leg drive), barda gerilim yarat',
      ),
      (
        name: 'Deadlift',
        volume: '3×5',
        tip: 'Belt kullanabilirsin, formu asla bozma',
      ),
      (
        name: 'Overhead Press (Barbell)',
        volume: '4×6',
        tip: 'Strict press, bacaklardan güç alma',
      ),
      (
        name: 'Barbell Row',
        volume: '4×8',
        tip: 'Sırt kalınlığı ve bench stabilizasyonu için',
      ),
      (
        name: 'Weighted Plank',
        volume: '3×45 sn',
        tip: 'Sırta ağırlık plakası koy, core dayanıklılığı',
      ),
    ],
    description:
        'Temel hareketlerde (Big 3) maksimal kuvvetini artırmayı hedefleyen klasik 5×5 mantığına dayalı, uzun dinlenme aralıklı güç programı.',
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
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.25),
            const Color(0xFF141420),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BUGÜN NE YAPMALIYIM?',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: const Text(
                    'Antrenmana Başla',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: accent.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onExplore,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent.withValues(alpha: 0.6), width: 1.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Bölge Seç',
                  style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w800),
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
  final WorkoutProgram? activeProgram;
  final Set<String> completedDayIds;
  final void Function(WorkoutProgram program, ProgramDay day) onStartDay;

  const _TodayProgramCard({
    required this.programs,
    required this.activeProgram,
    required this.completedDayIds,
    required this.onStartDay,
  });

  @override
  Widget build(BuildContext context) {
    final program = activeProgram ?? _pickProgramForToday(programs);
    if (program == null) return const SizedBox.shrink();
    final selectedProgram = program;
    final startDay = DateTime(
      selectedProgram.createdAt.year,
      selectedProgram.createdAt.month,
      selectedProgram.createdAt.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedForProgram = completedDayIds
        .where((id) => id.startsWith('${selectedProgram.id}_'))
        .length;
    final daysElapsed = today.difference(startDay).inDays;
    final dayIndex = completedForProgram > 0
        ? completedForProgram % selectedProgram.days.length
        : (daysElapsed < 0 ? 0 : daysElapsed) % selectedProgram.days.length;
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
                  '${dayIndex + 1}. gün • ${day.exercises.length} hareket bugün için hazır',
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

  WorkoutProgram? _pickProgramForToday(List<WorkoutProgram> programs) {
    final withDays = programs.where((program) => program.days.isNotEmpty);
    if (withDays.isEmpty) return null;
    return withDays.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
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
    
    // Calculate weekly summary
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekWorkouts = workouts.where((w) {
      final d = DateTime(w.workoutDate.year, w.workoutDate.month, w.workoutDate.day);
      return !d.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day));
    }).toList();
    
    final totalWorkouts = thisWeekWorkouts.length;
    final totalVolume = data.map((d) => d.volume).fold(0.0, (a, b) => a + b);
    final totalDuration = thisWeekWorkouts.map((w) => w.durationMinutes ?? 0).fold(0, (a, b) => a + b);

    if (maxVol == 0 && totalWorkouts == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141420),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insights_rounded, color: Color(0xFF66BB6A), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Haftalık Özet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryItem(
                label: 'Volüm',
                value: '${(totalVolume / 1000).toStringAsFixed(1)}t',
                icon: Icons.monitor_weight_rounded,
                color: Colors.purpleAccent,
              ),
              _buildSummaryItem(
                label: 'Süre',
                value: '${(totalDuration / 60).floor()}s ${totalDuration % 60}d',
                icon: Icons.timer_rounded,
                color: Colors.blueAccent,
              ),
              _buildSummaryItem(
                label: 'Antrenman',
                value: '$totalWorkouts',
                icon: Icons.fitness_center_rounded,
                color: Colors.orangeAccent,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                final barH = maxVol > 0 ? (d.volume / maxVol) * 80 : 0.0;
                final isToday = data.last == d;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: barH.clamp(2.0, 80.0),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFF2E7D32).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: isToday ? [
                              BoxShadow(
                                color: const Color(0xFF66BB6A).withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ] : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
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

  Widget _buildSummaryItem({required String label, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
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

  /// Güncel streak (art arda gün sayısı)
  int _currentStreak() {
    if (workouts.isEmpty) return 0;
    final now = DateTime.now();
    final workedDays =
        workouts
            .map(
              (w) => DateTime(
                w.workoutDate.year,
                w.workoutDate.month,
                w.workoutDate.day,
              ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime cursor = DateTime(now.year, now.month, now.day);

    for (final day in workedDays) {
      final diff = cursor.difference(day).inDays;
      if (diff == 0 || diff == 1) {
        streak++;
        cursor = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// En uzun streak
  int _longestStreak() {
    if (workouts.isEmpty) return 0;
    final days =
        workouts
            .map(
              (w) => DateTime(
                w.workoutDate.year,
                w.workoutDate.month,
                w.workoutDate.day,
              ),
            )
            .toSet()
            .toList()
          ..sort();

    int longest = 1, current = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2E7D32);
    const accentLight = Color(0xFF66BB6A);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    const dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final currentStreak = _currentStreak();
    final longestStreak = _longestStreak();

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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          // ── Üst satır: başlık + streak badge ───────────────────────────
          Row(
            children: [
              Text(
                'Bu Hafta',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.40),
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              if (currentStreak >= 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        '$currentStreak gün seri',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (currentStreak == longestStreak && longestStreak >= 3) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Rekor',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.amber,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Haftanın günleri ────────────────────────────────────────────
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
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? accentLight
                          : Colors.white.withValues(alpha: 0.30),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasWorkout
                          ? accent
                          : isToday
                          ? accent.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: isFuture ? 0.0 : 0.04),
                      border: Border.all(
                        color: isToday
                            ? accentLight
                            : hasWorkout
                            ? accentLight.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: isFuture ? 0.05 : 0.09),
                        width: isToday ? 2 : 1,
                      ),
                      boxShadow: hasWorkout
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.38),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: hasWorkout
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
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
                              color: Colors.white.withValues(alpha: isFuture ? 0.18 : 0.32),
                            ),
                          ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),
          // ── Separator ───────────────────────────────────────────────────
          Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 12),
          // ── 4 eşit stat kutusu ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StreakStatPill(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orange.shade400,
                  bgColor: Colors.orange.withValues(alpha: 0.10),
                  value: '$thisWeekCount',
                  label: 'Bu hafta',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StreakStatPill(
                  icon: Icons.bolt_rounded,
                  iconColor: Colors.amberAccent,
                  bgColor: Colors.amberAccent.withValues(alpha: 0.08),
                  value: longestStreak >= 2 ? '$longestStreak' : '-',
                  label: 'En uzun',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StreakStatPill(
                  icon: Icons.fitness_center_rounded,
                  iconColor: const Color(0xFF1E88E5),
                  bgColor: const Color(0xFF1E88E5).withValues(alpha: 0.08),
                  value: '$totalCount',
                  label: 'Toplam',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StreakStatPill(
                  icon: Icons.emoji_events_rounded,
                  iconColor: Colors.amber,
                  bgColor: Colors.amber.withValues(alpha: 0.08),
                  value: '$prCount',
                  label: 'PR',
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

// ── YENİ: Modernize Edilmiş UI Bileşenleri ─────────────────────────────────────

// ── Ortak Bölüm Başlığı ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _DynamicHeroSection extends StatelessWidget {
  final List<Workout> workouts;
  final TodayWorkoutSuggestion? suggestion;
  final List<WorkoutProgram> programs;
  final WorkoutProgram? activeProgram;
  final Set<String> completedDayIds;
  final VoidCallback onStartSuggested;
  final void Function(WorkoutProgram, ProgramDay) onStartProgramDay;
  final VoidCallback onExplore;

  const _DynamicHeroSection({
    required this.workouts,
    required this.suggestion,
    required this.programs,
    required this.activeProgram,
    required this.completedDayIds,
    required this.onStartSuggested,
    required this.onStartProgramDay,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final hasProgramForToday =
        (activeProgram?.days.isNotEmpty ?? false) ||
        programs.any((program) => program.days.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.electric_bolt_rounded,
            iconColor: Color(0xFF66BB6A),
            title: 'Bugün Ne Çalışayım?',
            subtitle: 'Toparlanmana göre önerildi',
          ),
          const SizedBox(height: 14),
          if (hasProgramForToday)
            _TodayProgramCard(
              programs: programs,
              activeProgram: activeProgram,
              completedDayIds: completedDayIds,
              onStartDay: onStartProgramDay,
            )
          else
            _TodayWorkoutActionCard(
              workouts: workouts,
              suggestion: suggestion,
              onStart: onStartSuggested,
              onExplore: onExplore,
            ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final bool isPremium;
  final List<WorkoutProgram> programs;
  final List<FavoriteExerciseEntry> favorites;
  final void Function(_TemplateData) onStartTemplate;
  final void Function(_TemplateData) onSaveTemplate;
  final VoidCallback onCreateProgramTap;
  final void Function(WorkoutProgram) onProgramTap;
  final void Function(FavoriteExerciseEntry) onFavoriteTap;
  final VoidCallback onUpgradePressed;

  const _QuickActionsRow({
    required this.isPremium,
    required this.programs,
    required this.favorites,
    required this.onStartTemplate,
    required this.onSaveTemplate,
    required this.onCreateProgramTap,
    required this.onProgramTap,
    required this.onFavoriteTap,
    required this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _SectionHeader(
            icon: Icons.dashboard_customize_rounded,
            iconColor: Colors.blueAccent,
            title: 'Hızlı Aksiyonlar',
            subtitle: 'Şablon, program ve favoriler',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              // Şablonlar
              _buildActionPill(
                icon: Icons.list_alt_rounded,
                label: 'Şablonlar',
                color: Colors.orange,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Container(
                      height: MediaQuery.of(context).size.height * 0.75,
                      decoration: const BoxDecoration(
                        color: Color(0xFF111111),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(
                                top: 20,
                                bottom: 40,
                              ),
                              child: _WorkoutTemplatesSection(
                                isPremium: isPremium,
                                compactTitle: false,
                                onStartPressed: (t) {
                                  Navigator.pop(ctx);
                                  onStartTemplate(t);
                                },
                                onSavePressed: (t) {
                                  Navigator.pop(ctx);
                                  onSaveTemplate(t);
                                },
                                onUpgradePressed: () {
                                  Navigator.pop(ctx);
                                  onUpgradePressed();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              // Kendi Programın
              _buildActionPill(
                icon: Icons.add_moderator_rounded,
                label: 'Program Oluştur',
                color: Colors.purpleAccent,
                onTap: onCreateProgramTap,
              ),
              const SizedBox(width: 10),
              // Favoriler
              if (favorites.isNotEmpty)
                _buildActionPill(
                  icon: Icons.star_rounded,
                  label: 'Favoriler (${favorites.length})',
                  color: Colors.amber,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF111111),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _FavoritesQuickStrip(
                                  favorites: favorites,
                                  onTap: (f) {
                                    Navigator.pop(ctx);
                                    onFavoriteTap(f);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsCarouselSection extends StatelessWidget {
  final List<Workout> workouts;
  final Map<String, FatigueStatus> recoveryStatuses;
  final Map<String, dynamic> stats;
  final void Function(_SessionExercisePlan) onStartProgression;
  final void Function(String) onSelectGroup;

  const _InsightsCarouselSection({
    required this.workouts,
    required this.recoveryStatuses,
    required this.stats,
    required this.onStartProgression,
    required this.onSelectGroup,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.purpleAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Analiz ve İlerleme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_graph_rounded,
                      size: 32,
                      color: Colors.purpleAccent.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz Veri Yok',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Antrenman yaptıkça kas gelişimi, toparlanma ve güç analizi grafiklerin burada belirecek.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.purpleAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Analiz ve İlerleme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 300, // Carousel yüksekliği biraz daha genişletildi
          child: PageView(
            controller: PageController(viewportFraction: 0.92),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. İlerleme Fırsatı
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _ProgressionSpotlightCard(
                    workouts: workouts,
                    onStart: onStartProgression,
                  ),
                ),
              ),
              // 2. Toparlanma Insights
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _RecoveryInsightsCard(
                    workoutSuggestion: null, // Hero'da kullanıldığı için
                    recoveryStatuses: recoveryStatuses,
                    totalWorkouts:
                        (stats['totalWorkouts'] as num?)?.toInt() ??
                        workouts.length,
                    totalSets:
                        (stats['totalSets'] as num?)?.toInt() ??
                        workouts.fold<int>(0, (sum, w) => sum + (w.sets ?? 0)),
                    totalCaloriesBurned:
                        (stats['totalCaloriesBurned'] as num?)?.toInt() ??
                        workouts.fold<int>(
                          0,
                          (sum, w) => sum + (w.caloriesBurned ?? 0),
                        ),
                    onSelectGroup: onSelectGroup,
                  ),
                ),
              ),
              // 3. Kas Dengesi
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _WeeklyBalanceCard(
                    workouts: workouts,
                    onSelectGroup: onSelectGroup,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Grafikler arasında geçiş yapmak için kaydır',
            style: TextStyle(color: Colors.white30, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

// ── Hazır Programlar Bölümü ───────────────────────────────────────────────────

class _PresetProgramsSection extends StatefulWidget {
  final void Function(WorkoutProgram program) onAddProgram;

  const _PresetProgramsSection({required this.onAddProgram});

  @override
  State<_PresetProgramsSection> createState() => _PresetProgramsSectionState();
}

class _PresetProgramsSectionState extends State<_PresetProgramsSection> {
  String _filter = 'Tümü';

  static const _filters = ['Tümü', 'Başlangıç', 'Orta', 'İleri', '3 Gün', '4 Gün', '6 Gün', 'Ev'];

  List<PresetProgramMeta> get _filtered {
    if (_filter == 'Tümü') return kPresetPrograms;
    if (_filter == 'Ev') return kPresetPrograms.where((p) => p.tags.contains('Ev')).toList();
    if (_filter.endsWith(' Gün')) {
      final days = int.tryParse(_filter.split(' ').first) ?? 0;
      return kPresetPrograms.where((p) => p.daysPerWeek == days).toList();
    }
    return kPresetPrograms.where((p) => p.level.startsWith(_filter)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final programs = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Başlık ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF9F0A).withValues(alpha: 0.20)),
                ),
                child: const Icon(Icons.auto_stories_rounded, color: Color(0xFFFF9F0A), size: 17),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hazır Programlar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    '${kPresetPrograms.length} bilimsel program, ekle ve başla',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.38), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Filtre çipleri ───────────────────────────────────────────────────
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, sep) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final selected = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFF9F0A).withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFF9F0A).withValues(alpha: 0.50)
                          : Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      color: selected ? const Color(0xFFFF9F0A) : Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // ── Program kartları ─────────────────────────────────────────────────
        if (programs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Bu filtrede program bulunamadı.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
            ),
          )
        else
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: programs.length,
              separatorBuilder: (_, sep) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final meta = programs[i];
                return Consumer<WorkoutProgramProvider>(
                  builder: (ctx, provider, child) {
                    final isAdded = provider.programs.any((p) => p.id == meta.id);
                    return _PresetProgramCard(
                      meta: meta,
                      isAdded: isAdded,
                      onTap: () => _showPreview(context, meta, isAdded),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  void _showPreview(BuildContext context, PresetProgramMeta meta, bool isAdded) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PresetProgramPreviewSheet(
        meta: meta,
        isAdded: isAdded,
        onAdd: () {
          Navigator.of(context).pop();
          widget.onAddProgram(meta.program);
        },
      ),
    );
  }
}

// ── Preset Program Kart ───────────────────────────────────────────────────────

class _PresetProgramCard extends StatelessWidget {
  final PresetProgramMeta meta;
  final bool isAdded;
  final VoidCallback onTap;

  const _PresetProgramCard({
    required this.meta,
    required this.isAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isAdded
                ? const Color(0xFF30D158).withValues(alpha: 0.40)
                : meta.accentColor.withValues(alpha: 0.22),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              meta.accentColor.withValues(alpha: 0.12),
              const Color(0xFF0E0E18),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Üst renkli hero bölgesi ───────────────────────────────────
            Container(
              height: 90,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    meta.accentColor.withValues(alpha: 0.28),
                    meta.accentColor.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Büyük arka plan ikonunu
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      meta.icon,
                      size: 80,
                      color: meta.accentColor.withValues(alpha: 0.10),
                    ),
                  ),
                  // İkon + rozet satırı
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(meta.icon, color: Colors.white, size: 20),
                        ),
                        const Spacer(),
                        if (isAdded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158).withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF30D158).withValues(alpha: 0.40),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded,
                                    size: 9, color: Color(0xFF30D158)),
                                const SizedBox(width: 3),
                                const Text('Eklendi',
                                    style: TextStyle(
                                      color: Color(0xFF30D158),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    )),
                              ],
                            ),
                          )
                        else if (meta.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              meta.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Alt kısım: seviye badge
                  Positioned(
                    bottom: 10,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: meta.levelColor.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: meta.levelColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        meta.level,
                        style: TextStyle(
                          color: meta.levelColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── İçerik ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta.shortDesc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // ── Alt bilgi şeridi ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                children: [
                  _cardStat(Icons.calendar_today_rounded, '${meta.daysPerWeek}g/h'),
                  const SizedBox(width: 10),
                  _cardStat(Icons.timer_outlined, '${meta.avgSessionMinutes}dk'),
                  const SizedBox(width: 10),
                  _cardStat(Icons.fitness_center_rounded, '${meta.totalExercises} hk'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Preset Program Preview Sheet ──────────────────────────────────────────────

class _PresetProgramPreviewSheet extends StatefulWidget {
  final PresetProgramMeta meta;
  final bool isAdded;
  final VoidCallback onAdd;

  const _PresetProgramPreviewSheet({
    required this.meta,
    required this.isAdded,
    required this.onAdd,
  });

  @override
  State<_PresetProgramPreviewSheet> createState() =>
      _PresetProgramPreviewSheetState();
}

class _PresetProgramPreviewSheetState extends State<_PresetProgramPreviewSheet> {
  int _expandedDay = 0;

  // Kas grubuna göre renk
  static Color _muscleColor(String mg) {
    switch (mg.toUpperCase()) {
      case 'CHEST':     return const Color(0xFF5B9BFF);
      case 'BACK':      return const Color(0xFF30D158);
      case 'LEGS':      return const Color(0xFFFF9F0A);
      case 'SHOULDERS': return const Color(0xFFBF5AF2);
      case 'BICEPS':    return const Color(0xFF32ADE6);
      case 'TRICEPS':   return const Color(0xFFFF6B6B);
      case 'CORE':      return const Color(0xFFFFD60A);
      case 'GLUTES':    return const Color(0xFFFF2D55);
      default:          return const Color(0xFF8E8E93);
    }
  }

  static String _muscleShort(String mg) {
    switch (mg.toUpperCase()) {
      case 'CHEST':     return 'Göğüs';
      case 'BACK':      return 'Sırt';
      case 'LEGS':      return 'Bacak';
      case 'SHOULDERS': return 'Omuz';
      case 'BICEPS':    return 'Biseps';
      case 'TRICEPS':   return 'Triseps';
      case 'CORE':      return 'Core';
      case 'GLUTES':    return 'Kalça';
      case 'FULL BODY': return 'Full';
      case 'ARMS':      return 'Kol';
      default:          return mg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final days = meta.program.days;
    final bottom = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF13131E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Hero header ──────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: meta.accentColor.withValues(alpha: 0.20)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    meta.accentColor.withValues(alpha: 0.18),
                    meta.accentColor.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: meta.accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: meta.accentColor.withValues(alpha: 0.30)),
                    ),
                    child: Icon(meta.icon, color: meta.accentColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: meta.levelColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: meta.levelColor.withValues(alpha: 0.30)),
                              ),
                              child: Text(
                                meta.level,
                                style: TextStyle(color: meta.levelColor, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (widget.isAdded) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF30D158).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF30D158).withValues(alpha: 0.30)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_rounded, size: 9, color: Color(0xFF30D158)),
                                    SizedBox(width: 3),
                                    Text('Zaten Eklendi', style: TextStyle(color: Color(0xFF30D158), fontSize: 9, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          meta.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta.goal,
                          style: TextStyle(
                            color: meta.accentColor.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 4 istatistik ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _statBox(Icons.calendar_today_rounded, '${meta.daysPerWeek}', 'gün/hafta', meta.accentColor),
                  const SizedBox(width: 8),
                  _statBox(Icons.timer_outlined, '${meta.avgSessionMinutes}dk', 'seans', meta.accentColor),
                  const SizedBox(width: 8),
                  _statBox(Icons.fitness_center_rounded, '${meta.totalExercises}', 'toplam hk', meta.accentColor),
                  const SizedBox(width: 8),
                  _statBox(Icons.timelapse_rounded, '${meta.durationWeeks}', 'hafta', meta.accentColor),
                ],
              ),
            ),

            // ── Açıklama ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                meta.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
            ),

            // ── Program günleri başlığı ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Container(
                    height: 1,
                    width: 24,
                    color: meta.accentColor.withValues(alpha: 0.40),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Program Günleri',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${days.length} gün',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ── Gün listesi ─────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: days.length,
                separatorBuilder: (_, sep) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final day = days[i];
                  final isOpen = _expandedDay == i;
                  // Egzersizlerdeki benzersiz kas grubu renkleri
                  final muscleColors = day.exercises
                      .map((e) => _muscleColor(e.muscleGroup))
                      .toSet()
                      .take(4)
                      .toList();

                  return GestureDetector(
                    onTap: () => setState(() => _expandedDay = isOpen ? -1 : i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: isOpen
                            ? meta.accentColor.withValues(alpha: 0.07)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOpen
                              ? meta.accentColor.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gün başlığı satırı
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: isOpen
                                        ? meta.accentColor.withValues(alpha: 0.20)
                                        : meta.accentColor.withValues(alpha: 0.10),
                                    shape: BoxShape.circle,
                                    border: isOpen
                                        ? Border.all(color: meta.accentColor.withValues(alpha: 0.40))
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: meta.accentColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        day.name,
                                        style: TextStyle(
                                          color: isOpen ? Colors.white : Colors.white.withValues(alpha: 0.85),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Kas grubu renk noktaları
                                      Row(
                                        children: [
                                          ...muscleColors.map((c) => Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(right: 4),
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                            ),
                                          )),
                                          Text(
                                            '${day.exercises.length} hareket',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.35),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isOpen
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white.withValues(alpha: 0.30),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),

                          // Egzersiz listesi (açılınca)
                          if (isOpen) ...[
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                children: day.exercises.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final ex = entry.value;
                                  final mColor = _muscleColor(ex.muscleGroup);
                                  final mShort = _muscleShort(ex.muscleGroup);
                                  final isLast = idx == day.exercises.length - 1;

                                  return Padding(
                                    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Kas rengi sol şerit
                                        Container(
                                          width: 3,
                                          height: ex.note.isEmpty ? 32 : 44,
                                          decoration: BoxDecoration(
                                            color: mColor,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      ex.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Set×Tekrar badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: mColor.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: Text(
                                                      '${ex.sets}×${ex.reps}',
                                                      style: TextStyle(
                                                        color: mColor,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // Dinlenme
                                                  Text(
                                                    '${ex.restSeconds}s',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.28),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: mColor.withValues(alpha: 0.10),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      mShort,
                                                      style: TextStyle(
                                                        color: mColor.withValues(alpha: 0.80),
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  if (ex.note.isNotEmpty) ...[
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        ex.note,
                                                        style: TextStyle(
                                                          color: Colors.white.withValues(alpha: 0.38),
                                                          fontSize: 10,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Ekle / Zaten Eklendi butonu ──────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
              child: widget.isAdded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF30D158).withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF30D158), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Program Zaten Eklendi',
                            style: TextStyle(
                              color: Color(0xFF30D158),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: widget.onAdd,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [meta.accentColor, meta.accentColor.withValues(alpha: 0.72)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: meta.accentColor.withValues(alpha: 0.38),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Bu Programı Ekle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
