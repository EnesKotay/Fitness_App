part of '../workout_screen.dart';

// ── History Tab ───────────────────────────────────────────────────────────────
//
// Antrenman geçmişini listeleyen sekmedir.
// Filtre state'i ve geçmiş mantığı burada yönetilir; CRUD callback'leri
// parent olan _WorkoutScreenState'ten alınır.

class _HistoryTab extends StatefulWidget {
  final void Function(Workout workout) onConfirmDelete;
  final void Function({Workout? workout}) onOpenAddWorkoutPage;
  final void Function(Workout workout) onRepeatWorkout;

  const _HistoryTab({
    required this.onConfirmDelete,
    required this.onOpenAddWorkoutPage,
    required this.onRepeatWorkout,
  });

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  _WorkoutHistoryFilter _historyFilter = _WorkoutHistoryFilter.selectedDay;
  bool _showAnalytics = false;

  List<Workout> _filteredWorkouts(WorkoutProvider provider) {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    switch (_historyFilter) {
      case _WorkoutHistoryFilter.selectedDay:
        return provider.workoutsForSelectedDate;
      case _WorkoutHistoryFilter.all:
        return provider.workouts;
      case _WorkoutHistoryFilter.thisWeek:
        return provider.workouts.where((w) {
          final day = DateTime(
            w.workoutDate.year,
            w.workoutDate.month,
            w.workoutDate.day,
          );
          return !day.isBefore(weekStart);
        }).toList();
      case _WorkoutHistoryFilter.prs:
        return provider.workouts.where((w) {
          final pr = provider.personalRecords[w.name];
          return w.oneRepMax != null && pr != null && w.oneRepMax! >= pr - 0.05;
        }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        final selectedWorkouts = _filteredWorkouts(provider);

        // ── Yükleniyor ────────────────────────────────────────────────────
        if (provider.isLoading && provider.workouts.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          );
        }

        // ── Hiç antrenman yok — onboarding durumu ─────────────────────────
        if (provider.workouts.isEmpty) {
          return _EmptyHistoryView(
            onAddTap: () => widget.onOpenAddWorkoutPage(),
          );
        }

        // ── Seçili tarih/filtre için antrenman yok ────────────────────────
        if (selectedWorkouts.isEmpty) {
          final formattedDate = DateFormat(
            'd MMMM',
            'tr_TR',
          ).format(provider.selectedDate);
          final showDeload = RecoveryEngine.isDeloadRecommended(
            provider.workouts,
          );
          return ListView(
            padding: const EdgeInsets.all(20).copyWith(bottom: 100),
            children: [
              _HistoryFilterBar(
                selected: _historyFilter,
                onChanged: (f) => setState(() => _historyFilter = f),
              ),
              const SizedBox(height: 16),
              _HistoryAnalyticsSection(
                workouts: provider.workouts,
                records: provider.personalRecords,
                showDeload: showDeload,
                isExpanded: _showAnalytics,
                onToggle: () =>
                    setState(() => _showAnalytics = !_showAnalytics),
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.event_available_rounded,
                        size: 42,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$formattedDate antrenman yok',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bu gün için bir seans kaydetmek ister misin?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sağ alttaki + butonunu kullan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // ── Deload tespiti ────────────────────────────────────────────────
        final showDeload = RecoveryEngine.isDeloadRecommended(
          provider.workouts,
        );

        // ── Dolu liste ────────────────────────────────────────────────────
        return RefreshIndicator(
          onRefresh: () async {
            if (!mounted) return;
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final workoutProvider = Provider.of<WorkoutProvider>(
              context,
              listen: false,
            );
            final userId = authProvider.user?.id;
            if (userId != null) await workoutProvider.loadWorkouts(userId);
          },
          color: const Color(0xFF2E7D32),
          child: ListView.builder(
            padding: const EdgeInsets.all(20).copyWith(bottom: 100),
            itemCount: selectedWorkouts.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HistoryFilterBar(
                      selected: _historyFilter,
                      onChanged: (f) => setState(() => _historyFilter = f),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${selectedWorkouts.length} kayıt',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
              if (index == selectedWorkouts.length + 1) {
                return _HistoryAnalyticsSection(
                  workouts: provider.workouts,
                  records: provider.personalRecords,
                  showDeload: showDeload,
                  isExpanded: _showAnalytics,
                  onToggle: () =>
                      setState(() => _showAnalytics = !_showAnalytics),
                );
              }
              final workout = selectedWorkouts[index - 1];
              return _HistoryCard(
                workout: workout,
                onDelete: () => widget.onConfirmDelete(workout),
                onEdit: () => widget.onOpenAddWorkoutPage(workout: workout),
                onRepeat: () => widget.onRepeatWorkout(workout),
              );
            },
          ),
        );
      },
    );
  }
}

class _HistoryAnalyticsSection extends StatelessWidget {
  final List<Workout> workouts;
  final Map<String, double> records;
  final bool showDeload;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _HistoryAnalyticsSection({
    required this.workouts,
    required this.records,
    required this.showDeload,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Colors.purpleAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Analiz ve toparlanma',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Hacim, PR, kas dengesi ve yorgunluk',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              children: [
                _WeeklyVolumeChart(workouts: workouts),
                if (records.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _PrHighlightsCard(records: records),
                ],
                const SizedBox(height: 14),
                _MuscleGroupChart(workouts: workouts),
                const SizedBox(height: 14),
                MuscleHeatmapWidget(
                  fatigueByGroup: RecoveryEngine.computeAll(workouts),
                ),
                if (showDeload) ...[
                  const SizedBox(height: 14),
                  _DeloadBanner(),
                ],
              ],
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

// ── Empty History Onboarding View ─────────────────────────────────────────────

class _EmptyHistoryView extends StatelessWidget {
  final VoidCallback onAddTap;

  const _EmptyHistoryView({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        // ── Hero motivation card ─────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2E1A), Color(0xFF0D1A0D)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 38,
                  color: Color(0xFF66BB6A),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Yolculuğuna başla!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'İlk antrenmanını ekleyerek\ngüç ve dayanıklılığını takip etmeye başla.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onAddTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'İlk Antrenmanı Ekle',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ── Quick-start section ──────────────────────────────────────────
        Row(
          children: [
            const Text(
              'Popüler Başlangıç',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Hızlı başla',
                style: TextStyle(
                  color: Color(0xFF66BB6A),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _QuickStartTypeCard(
                icon: Icons.fitness_center_rounded,
                label: 'Üst Vücut',
                subtitle: 'Göğüs · Sırt · Kol',
                color: const Color(0xFF1E88E5),
                onTap: () => onAddTap(),
              ),
              const SizedBox(width: 10),
              _QuickStartTypeCard(
                icon: Icons.directions_run_rounded,
                label: 'Bacak',
                subtitle: 'Squat · Leg Press',
                color: const Color(0xFFE53935),
                onTap: () => onAddTap(),
              ),
              const SizedBox(width: 10),
              _QuickStartTypeCard(
                icon: Icons.self_improvement_rounded,
                label: 'Full Body',
                subtitle: 'Tüm kas grupları',
                color: const Color(0xFF8E24AA),
                onTap: () => onAddTap(),
              ),
              const SizedBox(width: 10),
              _QuickStartTypeCard(
                icon: Icons.bolt_rounded,
                label: 'Cardio',
                subtitle: 'Yağ yakım · Kondisyon',
                color: const Color(0xFFF57C00),
                onTap: () => onAddTap(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
