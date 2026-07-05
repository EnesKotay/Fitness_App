import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_models.dart';
import '../../../core/models/workout_set.dart';
import '../../../core/api/services/exercise_service.dart';
import '../../../core/utils/storage_helper.dart';
import '../data/workout_catalog_data.dart';
import '../providers/workout_provider.dart';
import '../providers/workout_program_provider.dart';
import '../models/workout_program.dart';
import 'program_builder_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/premium_screen.dart';
import '../../../core/constants/premium_features.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/ambient_glow_background.dart';
import '../../nutrition/presentation/widgets/date_strip.dart';
import '../services/progression_engine.dart';
import '../services/recovery_engine.dart';
import 'exercise_guide_screen.dart';
import 'add_workout_page.dart';
import '../../../core/services/page_guide_service.dart';
import '../../../core/widgets/page_guide_overlay.dart';
import '../../../core/widgets/page_guide_button.dart';
import '../services/exercise_parser_service.dart';
import '../data/preset_programs_data.dart';
import '../widgets/muscle_heatmap_widget.dart';
import 'exercise_library_screen.dart';

part 'workout_screen_components.dart';
part 'tabs/explore_tab.dart';
part 'tabs/history_tab.dart';
part 'widgets/active_workout_session_sheet.dart';
part 'widgets/pr_highlights_card.dart';

enum _WorkoutHistoryFilter { selectedDay, all, thisWeek, prs }

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

// ── WorkoutScreen Shell ───────────────────────────────────────────────────────
//
// Bu sınıf yalnızca:
//  • AppBar, TabBar ve FAB'ı yönetir
//  • Sekmelere ortak CRUD/navigasyon callback'lerini sağlar
//  • Aktif antrenman seans sheet'ini açar
//  • PR kutlamasını gösterir
//
// Keşfet sekmesi mantığı → _ExploreTab (tabs/explore_tab.dart)
// Geçmişim sekmesi mantığı → _HistoryTab (tabs/history_tab.dart)

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Egzersiz listesi açıkken AppBar gizlenir. _ExploreTab bunu
  // exerciseListOpen notifier'ı üzerinden bildirir.
  final ValueNotifier<bool> _exerciseListOpen = ValueNotifier(false);

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '💪',
      title: 'Kapsamlı Egzersiz Kütüphanesi',
      description:
          'Sayfadaki kas grubu filtrelerini (Göğüs, Sırt, Bacak vb.) kullanarak 500\'den fazla egzersizi keşfedebilirsin:\n\n'
          '• Bir egzersize dokunarak nasıl yapıldığını, form ipuçlarını ve hedef kasları gör\n'
          '• Çoğu egzersiz için 3D animasyonlu veya videolu anlatım mevcut\n'
          '• Yeni hareketler öğrenip programına ekle',
      tip:
          'Yeni başlıyorsan mutlaka egzersizin detay sayfasına girip doğru formu öğren. Yanlış form sakatlığa yol açar.',
    ),
    GuideStep(
      emoji: '🔍',
      title: 'Hızlı Arama ve Filtreleme',
      description:
          'Aradığın spesifik bir hareket varsa üstteki arama çubuğunu kullanabilirsin. Ayrıca kas grubu seçtikten sonra, o kasın alt bölgelerine göre de (Örn: "Üst Göğüs") filtreleme yapabilirsin.',
      tip:
          'İngilizce isimleri de (örn: Bench Press, Deadlift) Türkçe aratarak kolayca bulabilirsin.',
    ),
    GuideStep(
      emoji: '⭐',
      title: 'Favori Egzersizlerini Seç',
      description:
          'Sık yaptığın veya beğendiğin bir egzersizin yanındaki yıldız (⭐) ikonuna dokun. Bu egzersizler üstteki "Favoriler" sekmesinde toplanır. Böylece antrenman esnasında aramakla vakit kaybetmezsin.',
      tip:
          'En temel bileşik egzersizlerini (Squat, Deadlift, Bench Press) favorilere ekleyerek kendi ana cephaneliğini oluştur.',
    ),
    GuideStep(
      emoji: '➕',
      title: 'Serbest Antrenman Kaydetme',
      description:
          'Kendi antrenmanını yaptıysan sağ üstteki "+" butonuna dokun:\n\n'
          '1. Tarih ve saati seç\n'
          '2. Yaptığın egzersizleri listeden ekle\n'
          '3. Set, tekrar ve ağırlık değerlerini gir\n'
          '4. Kaydet ve gelişimi gör',
      tip:
          'Antrenman esnasında notlar alabilir, o günkü yorgunluk seviyeni veya hissiyatını da kaydedebilirsin.',
    ),
    GuideStep(
      emoji: '⚡',
      title: 'Hızlı Başlat Şablonları',
      description:
          'Eğer o gün ne çalışacağına karar veremediysen, sayfanın üst kısmındaki "Hızlı Başlat" şablonlarını kullan. (Full Body, İtme, Çekme, Bacak vb.).\n\n'
          'Bu şablonlar sana hazır egzersizler sunar, sadece ağırlıklarını girip antrenmana başlarsın.',
      tip:
          'Bu şablonları kendi seviyene göre değiştirebilir, egzersiz çıkarıp ekleyebilirsin.',
    ),
    GuideStep(
      emoji: '📅',
      title: 'Antrenman Geçmişi ve Kayıtlar',
      description:
          '"Geçmiş" sekmesine geçerek daha önce kaydettiğin tüm antrenmanları kronolojik sırada görebilirsin:\n\n'
          '• Eski antrenmanlarının detaylarına bakıp kaldırdığın ağırlıkları kontrol et\n'
          '• Bir antrenmanı kolayca kopyalayıp bugüne tekrar ekle\n'
          '• Antrenman hacmini (toplam kaldırılan ağırlık) takip et',
      tip:
          'Aynı antrenmanı kopyalayıp ağırlıkları veya tekrarları bir tık artırmaya çalış (Progressive Overload).',
    ),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadWorkoutsIfNeeded();
      await _checkFirstVisitGuide();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _exerciseListOpen.dispose();
    super.dispose();
  }

  // ── Guide ─────────────────────────────────────────────────────────────────

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('workout')) return;
    await PageGuideService.markGuideSeen('workout');
    if (mounted) await _showGuide();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadWorkoutsIfNeeded() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final userId = authProvider.user?.id;
    if (userId != null) {
      await workoutProvider.loadWorkouts(userId);
    } else {
      workoutProvider.reset();
    }
  }

  // ── Navigasyon yardımcıları ───────────────────────────────────────────────

  void _openAddWorkoutPage(BuildContext ctx, {Workout? workout}) {
    final messenger = ScaffoldMessenger.of(ctx);
    Navigator.of(ctx)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (_) => AddWorkoutPage(workout: workout),
          ),
        )
        .then((message) {
          if (!mounted) return;
          _loadWorkoutsIfNeeded();
          if (message != null && message.isNotEmpty) {
            final isPR = message.contains('Kişisel Rekor');
            if (isPR) _showPRCelebration();
            messenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: isPR
                    ? Colors.amber.shade700
                    : const Color(0xFF2E7D32),
              ),
            );
          }
        });
  }

  void _openExerciseGuide(
    BuildContext context,
    Exercise exercise,
    Color accentColor,
    String? muscleGroupLabel,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => ExerciseGuideScreen(
          exercise: exercise,
          accentColor: accentColor,
          muscleGroupLabel: muscleGroupLabel,
        ),
      ),
    );
  }

  void _openProgramBuilder(BuildContext context, {WorkoutProgram? program}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProgramBuilderScreen(program: program)),
    );
  }

  void _showProgramDetail(BuildContext context, WorkoutProgram program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProgramDetailSheet(
        program: program,
        onStartDay: (day) {
          Navigator.pop(context);
          _startProgramDay(context, program, day);
        },
        onEdit: () {
          Navigator.pop(context);
          _openProgramBuilder(context, program: program);
        },
        onDelete: () {
          Navigator.pop(context);
          context.read<WorkoutProgramProvider>().deleteProgram(program.id);
        },
      ),
    );
  }

  // ── Seans yönetimi ────────────────────────────────────────────────────────

  void _openActiveSession(
    BuildContext context, {
    required String title,
    required List<_SessionExercisePlan> plans,
    required Future<void> Function(_CompletedSessionSummary summary) onFinish,
  }) {
    if (plans.isEmpty) {
      unawaited(
        onFinish(
          _CompletedSessionSummary.fromPlans(title: title, plans: plans),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActiveWorkoutSessionSheet(
        title: title,
        plans: plans,
        onFinish: (summary) {
          Navigator.of(context).pop();
          unawaited(onFinish(summary));
        },
      ),
    );
  }

  Future<void> _saveCompletedSession(
    BuildContext context,
    _CompletedSessionSummary summary, {
    String? difficulty,
    String? fallbackMuscleGroup,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final messenger = ScaffoldMessenger.of(context);
    final userId = authProvider.user?.id;
    if (userId == null) return;

    final exercises = <WorkoutSessionExerciseRequest>[];
    for (final exercise in summary.exercises) {
      final setCount = exercise.completedSets > 0
          ? exercise.completedSets
          : exercise.plannedSets;
      if (setCount <= 0) continue;

      final muscleGroup = exercise.muscleGroup ?? fallbackMuscleGroup;
      final details = exercise.setDetails.take(setCount).toList();
      final maxWeight = details
          .map((set) => set.weight ?? 0)
          .fold<double>(0, (a, b) => a > b ? a : b);
      exercises.add(
        WorkoutSessionExerciseRequest(
          name: exercise.name,
          workoutType: muscleGroup == null
              ? null
              : kMuscleGroupInfo[muscleGroup]?.label ?? muscleGroup,
          plannedSets: exercise.plannedSets,
          completedSets: setCount,
          reps: exercise.reps,
          weight: maxWeight > 0 ? maxWeight : null,
          restSeconds: exercise.restSeconds,
          notes: summary.title,
          setDetails: details,
          muscleGroup: muscleGroup,
        ),
      );
    }

    final request = WorkoutSessionRequest(
      title: summary.title,
      startedAt: summary.startedAt,
      finishedAt: summary.finishedAt,
      plannedSetCount: summary.totalSetCount,
      completedSetCount: summary.completedSetCount,
      difficulty: difficulty,
      notes:
          '${summary.completedSetCount}/${summary.totalSetCount} set tamamlandı',
      exercises: exercises,
    );

    final saved = await workoutProvider.createWorkoutSession(userId, request);
    if (!mounted) return;
    await _loadWorkoutsIfNeeded();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? '${summary.title} seansı kaydedildi'
              : workoutProvider.errorMessage ?? 'Seans kaydedilemedi',
        ),
        backgroundColor: saved ? const Color(0xFF2E7D32) : Colors.redAccent,
      ),
    );
  }

  /// Quick-start preset → birden fazla egzersiz planı oluşturur
  List<_SessionExercisePlan> _plansFromQuickStart(_QuickStartPreset preset) {
    // Preset'in çoklu egzersiz listesi varsa kullan
    if (preset.exercises.isNotEmpty) {
      return preset.exercises
          .map(
            (e) => _SessionExercisePlan(
              name: e.name,
              sets: e.sets,
              reps: e.reps,
              muscleGroup: preset.muscleGroup,
            ),
          )
          .toList();
    }
    // Geriye dönük uyumluluk: templateData'dan tek egzersiz
    return [
      _SessionExercisePlan(
        name: preset.templateData.exerciseName,
        sets: preset.templateData.sets,
        reps: preset.templateData.reps,
        muscleGroup: preset.templateData.muscleGroup,
      ),
    ];
  }

  List<_SessionExercisePlan> _plansFromTemplate(_TemplateData template) {
    return template.exercises.map((exercise) {
      final (sets, reps) = _parseVolume(exercise.volume);
      return _SessionExercisePlan(
        name: exercise.name,
        sets: sets,
        reps: reps,
        muscleGroup: template.muscles.isNotEmpty
            ? _normalizedTemplateMuscleGroup(template.muscles.first)
            : null,
      );
    }).toList();
  }

  List<_SessionExercisePlan> _plansFromProgramDay(ProgramDay day) {
    return day.exercises
        .map(
          (exercise) => _SessionExercisePlan(
            name: exercise.name,
            sets: exercise.sets,
            reps: exercise.reps,
            muscleGroup: exercise.muscleGroup,
            restSeconds: exercise.restSeconds,
          ),
        )
        .toList();
  }

  (int sets, int reps) _parseVolume(String volume) {
    final parts = volume.split('×');
    if (parts.length != 2) return (3, 10);
    return (int.tryParse(parts[0]) ?? 3, int.tryParse(parts[1]) ?? 10);
  }

  String? _normalizedTemplateMuscleGroup(String? raw) {
    final normalized = ExerciseParserService.normalizeMuscleGroupCode(
      raw ?? '',
    );
    return normalized.isEmpty ? null : normalized;
  }

  void _openQuickStartWorkout(BuildContext context, _QuickStartPreset preset) {
    _openActiveSession(
      context,
      title: preset.templateData.workoutName,
      plans: _plansFromQuickStart(preset),
      onFinish: (summary) => _saveCompletedSession(
        context,
        summary,
        difficulty: preset.templateData.difficulty,
        fallbackMuscleGroup: preset.templateData.muscleGroup,
      ),
    );
  }

  void _openTemplateWorkout(BuildContext context, _TemplateData template) {
    final firstEx = template.exercises.isNotEmpty
        ? template.exercises.first
        : null;
    int sets = 3, reps = 10;
    if (firstEx != null) {
      final parts = firstEx.volume.split('×');
      if (parts.length == 2) {
        sets = int.tryParse(parts[0]) ?? 3;
        reps = int.tryParse(parts[1]) ?? 10;
      }
    }
    final templateData = firstEx == null
        ? null
        : (
            exerciseName: firstEx.name,
            sets: sets,
            reps: reps,
            workoutName: template.name,
            duration: template.estimatedMinutes,
            muscleGroup: template.muscles.isNotEmpty
                ? _normalizedTemplateMuscleGroup(template.muscles.first)
                : null,
            difficulty: template.difficulty,
          );
    if (templateData == null) {
      _openAddWorkoutPage(context);
      return;
    }
    _openActiveSession(
      context,
      title: template.name,
      plans: _plansFromTemplate(template),
      onFinish: (summary) => _saveCompletedSession(
        context,
        summary,
        difficulty: templateData.difficulty,
        fallbackMuscleGroup: templateData.muscleGroup,
      ),
    );
  }

  void _startSuggestedSession(BuildContext context, WorkoutProvider provider) {
    final groups = RecoveryEngine.recommendedGroupsToday(provider.workouts);
    final group = groups.isNotEmpty
        ? groups.first
        : kMuscleGroupInfo.keys.first;
    final exercises = buildExerciseCatalogForGroup(group).take(4).toList();
    if (exercises.isEmpty) {
      _openAddWorkoutPage(context);
      return;
    }
    final info = kMuscleGroupInfo[group];
    final plans = exercises
        .map(
          (exercise) => _SessionExercisePlan(
            name: exercise.name,
            sets: 3,
            reps: 10,
            muscleGroup: group,
          ),
        )
        .toList();
    _openActiveSession(
      context,
      title: '${info?.label ?? 'Bugün'} seansı',
      plans: plans,
      onFinish: (summary) => _saveCompletedSession(
        context,
        summary,
        difficulty: 'Orta',
        fallbackMuscleGroup: group,
      ),
    );
  }

  void _startProgramDay(
    BuildContext context,
    WorkoutProgram program,
    ProgramDay day,
  ) {
    if (day.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu günde egzersiz bulunmuyor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final firstEx = day.exercises.first;
    final templateData = (
      exerciseName: firstEx.name,
      sets: firstEx.sets,
      reps: firstEx.reps,
      workoutName: '${program.name} – ${day.name}',
      duration: day.exercises.length * 10,
      muscleGroup: firstEx.muscleGroup,
      difficulty: 'Orta',
    );
    _openActiveSession(
      context,
      title: '${program.name} – ${day.name}',
      plans: _plansFromProgramDay(day),
      onFinish: (summary) async {
        await _saveCompletedSession(
          context,
          summary,
          difficulty: templateData.difficulty,
          fallbackMuscleGroup: templateData.muscleGroup,
        );
        if (mounted) {
          await this.context.read<WorkoutProgramProvider>().markDayCompleted(
            program.id,
            day.id,
          );
        }
      },
    );
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context, Workout workout) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final userId = authProvider.user?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${workout.name} antrenmanını silmek istediğine emin misin?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await workoutProvider.deleteWorkout(userId, workout.id);
      if (ok && mounted) {
        final messenger = ScaffoldMessenger.of(this.context);
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            backgroundColor: const Color(0xFF1F2C1F),
            content: Text('${workout.name} silindi.'),
            action: SnackBarAction(
              label: 'Geri Al',
              textColor: const Color(0xFF66BB6A),
              onPressed: () async {
                final request = WorkoutRequest(
                  name: workout.name,
                  workoutType: workout.workoutType,
                  sets: workout.sets,
                  reps: workout.reps,
                  weight: workout.weight,
                  durationMinutes: workout.durationMinutes,
                  caloriesBurned: workout.caloriesBurned,
                  workoutDate: workout.workoutDate,
                  notes: workout.notes,
                  setDetails: workout.setDetails,
                  muscleGroup: workout.muscleGroup,
                  isSuperset: workout.isSuperset,
                  supersetPartner: workout.supersetPartner,
                  oneRepMax: workout.oneRepMax,
                  difficulty: workout.difficulty,
                );
                final restored = await workoutProvider.createWorkout(
                  userId,
                  request,
                );
                if (restored && mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Antrenman geri yüklendi ✅'),
                      backgroundColor: Color(0xFF2E7D32),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    }
  }

  void _repeatWorkout(BuildContext ctx, Workout workout) {
    final messenger = ScaffoldMessenger.of(ctx);
    Navigator.of(ctx)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (_) => AddWorkoutPage(
              templateData: (
                exerciseName: workout.name,
                sets: workout.sets ?? 3,
                reps: workout.reps ?? 10,
                workoutName: workout.name,
                duration: workout.durationMinutes ?? 45,
                muscleGroup: workout.muscleGroup,
                difficulty: null,
              ),
            ),
          ),
        )
        .then((message) {
          if (!mounted) return;
          _loadWorkoutsIfNeeded();
          if (message != null && message.isNotEmpty) {
            final isPR = message.contains('Kişisel Rekor');
            if (isPR) _showPRCelebration();
            messenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: isPR
                    ? Colors.amber.shade700
                    : const Color(0xFF2E7D32),
              ),
            );
          }
        });
  }

  Future<void> _saveTemplate(
    BuildContext context,
    _TemplateData template,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final messenger = ScaffoldMessenger.of(context);
    final userId = authProvider.user?.id;
    if (userId == null) return;

    int saved = 0;
    for (final ex in template.exercises) {
      int sets = 3, reps = 10;
      final parts = ex.volume.split('×');
      if (parts.length == 2) {
        sets = int.tryParse(parts[0]) ?? 3;
        reps = int.tryParse(parts[1]) ?? 10;
      }
      final request = WorkoutRequest(
        name: ex.name,
        sets: sets,
        reps: reps,
        muscleGroup: template.muscles.isNotEmpty
            ? _normalizedTemplateMuscleGroup(template.muscles.first)
            : null,
        durationMinutes: template.estimatedMinutes ~/ template.exercises.length,
        workoutDate: DateTime.now(),
        notes: template.name,
        difficulty: template.difficulty,
      );
      final ok = await workoutProvider.createWorkout(userId, request);
      if (ok) saved++;
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved == template.exercises.length
              ? '${template.name} antrenmanlarıma kaydedildi ✓'
              : '$saved/${template.exercises.length} egzersiz kaydedildi',
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
    _loadWorkoutsIfNeeded();
  }

  // ── PR Kutlaması ──────────────────────────────────────────────────────────

  void _showPRCelebration() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PR',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A1A00), Color(0xFF1A1A1A)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'Kişisel Rekor!',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Harika! Yeni bir zirveye ulaştın!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Süper! 💪',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPremium = isPremiumTier(
      context.watch<AuthProvider>().user?.premiumTier,
      expiresAt: context.watch<AuthProvider>().user?.premiumExpiresAt,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: _exerciseListOpen,
      builder: (context, exerciseOpen, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          extendBodyBehindAppBar: true,
          appBar: exerciseOpen
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  titleSpacing: 20,
                  title: Consumer<WorkoutProvider>(
                    builder: (context, provider, _) {
                      final today = DateTime.now();
                      final weekStart = today.subtract(
                        Duration(days: today.weekday - 1),
                      );
                      final thisWeekCount = provider.workouts
                          .where(
                            (w) => w.workoutDate.isAfter(
                              weekStart.subtract(const Duration(seconds: 1)),
                            ),
                          )
                          .length;
                      final greeting = _workoutGreeting();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              const Text(
                                'Antrenman',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (thisWeekCount > 0) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2E7D32,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 12,
                                        color: Color(0xFF66BB6A),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Bu hafta $thisWeekCount',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF66BB6A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Center(child: PageGuideButton(onTap: _showGuide)),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.ios_share_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () {
                        final provider = context.read<WorkoutProvider>();
                        final today = DateTime.now();
                        final weekStart = today.subtract(
                          Duration(days: today.weekday - 1),
                        );
                        final thisWeekCount = provider.workouts
                            .where(
                              (w) => w.workoutDate.isAfter(
                                weekStart.subtract(const Duration(seconds: 1)),
                              ),
                            )
                            .length;
                        final totalCount = provider.workouts.length;
                        final text =
                            'PusulaFit\'te bu hafta $thisWeekCount antrenman tamamladım! 💪\n'
                            'Toplamda $totalCount antrenmana ulaştım.\n\n'
                            '📲 PusulaFit — Akıllı Antrenman Takibi';
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
                    ),
                    const SizedBox(width: 8),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(44),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          splashBorderRadius: BorderRadius.circular(10),
                          padding: const EdgeInsets.all(3),
                          labelPadding: EdgeInsets.zero,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withValues(
                            alpha: 0.4,
                          ),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          tabs: const [
                            Tab(text: 'Keşfet'),
                            Tab(text: 'Geçmişim'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          body: AppGradientBackground(
            imagePath: 'assets/images/workout_bg.jpg',
            child: Stack(
              children: [
                const AmbientGlowBackground(),
                SafeArea(
                  child: Column(
                    children: [
                      // ── Haftalık streak satırı & date strip ──────────────
                      Consumer<WorkoutProvider>(
                        builder: (context, provider, _) {
                          final today = DateTime.now();
                          final weekStart = today.subtract(
                            Duration(days: today.weekday - 1),
                          );
                          final thisWeekCount = provider.workouts
                              .where(
                                (w) => w.workoutDate.isAfter(
                                  weekStart.subtract(
                                    const Duration(seconds: 1),
                                  ),
                                ),
                              )
                              .length;
                          final totalCount = provider.workouts.length;
                          final prCount = provider.personalRecords.length;
                          final showHistoryTools = _tabController.index == 1;

                          if (exerciseOpen) return const SizedBox.shrink();

                          return Column(
                            children: [
                              if (showHistoryTools)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    12,
                                    20,
                                    0,
                                  ),
                                  child: DateStrip(
                                    selectedDate: provider.selectedDate,
                                    onDateSelected: (date) =>
                                        provider.setSelectedDate(date),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  showHistoryTools ? 10 : 12,
                                  20,
                                  0,
                                ),
                                child: _WeeklyStreakRow(
                                  workouts: provider.workouts,
                                  totalCount: totalCount,
                                  thisWeekCount: thisWeekCount,
                                  prCount: prCount,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      // ── Sekmeler ─────────────────────────────────────────
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Keşfet
                            _ExploreTab(
                              isPremium: isPremium,
                              onOpenExerciseGuide: _openExerciseGuide,
                              onOpenQuickStart: (preset) =>
                                  _openQuickStartWorkout(context, preset),
                              onOpenTemplateWorkout: (template) =>
                                  _openTemplateWorkout(context, template),
                              onSaveTemplate: (template) =>
                                  _saveTemplate(context, template),
                              onStartSuggestedSession: _startSuggestedSession,
                              onStartProgramDay: (program, day) =>
                                  _startProgramDay(context, program, day),
                              onOpenProgramBuilder: () =>
                                  _openProgramBuilder(context),
                              onShowProgramDetail: (program) =>
                                  _showProgramDetail(context, program),
                            ),
                            // Geçmişim
                            _HistoryTab(
                              onConfirmDelete: (workout) =>
                                  _confirmDelete(context, workout),
                              onOpenAddWorkoutPage: ({workout}) =>
                                  _openAddWorkoutPage(
                                    context,
                                    workout: workout,
                                  ),
                              onRepeatWorkout: (workout) =>
                                  _repeatWorkout(context, workout),
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
          floatingActionButton: _buildFab(context),
        );
      },
    );
  }

  Widget _buildFab(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userId = authProvider.user?.id;
        if (userId == null) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          heroTag: 'workout_add_session_fab',
          onPressed: () => _showAddWorkoutSheet(context),
          backgroundColor: const Color(0xFF2E7D32),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Antrenman kaydet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  void _showAddWorkoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF181820),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  const Text(
                    'Ne yapmak istiyorsun?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            // Seçenek 1: Canlı seans
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _openActiveSession(
                    context,
                    title: 'Serbest Antrenman',
                    plans: [],
                    onFinish: (summary) =>
                        _saveCompletedSession(context, summary),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2E7D32).withValues(alpha: 0.18),
                        const Color(0xFF2E7D32).withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.32),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2E7D32,
                          ).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.play_circle_filled_rounded,
                          color: Color(0xFF66BB6A),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Canlı Seans Başlat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kronometre, set takibi ve anlık kayıt',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.50),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: const Color(0xFF66BB6A).withValues(alpha: 0.60),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Seçenek 2: Geçmiş kayıt
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddWorkoutPage(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.history_edu_rounded,
                          color: Colors.blueAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Geçmiş Kayıt Ekle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Daha önce yaptığın antrenmanı gir',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.50),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.25),
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

  String _workoutGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Günaydın 💪 Güne güçlü başla';
    if (hour < 14) return 'Öğle antrenmanı zamanı 🔥';
    if (hour < 18) return 'Öğleden sonra enerjini boşalt 💥';
    return 'Akşam seansı başlıyor 🌙';
  }
}
