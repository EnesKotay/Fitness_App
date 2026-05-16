import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_models.dart';
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

part 'workout_screen_components.dart';

enum _WorkoutHistoryFilter { selectedDay, all, thisWeek, prs }

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  final ExerciseService _exerciseService = ExerciseService();
  final TextEditingController _regionSearchController = TextEditingController();
  final TextEditingController _exerciseSearchController =
      TextEditingController();
  String? _selectedMuscleGroup;
  List<String> _muscleGroups = [];
  List<Exercise> _exercises = [];
  String _selectedSubRegion = 'Tümü';
  String _regionSearchQuery = '';
  String _exerciseSearchQuery = '';
  _WorkoutHistoryFilter _historyFilter = _WorkoutHistoryFilter.selectedDay;
  bool _loadingGroups = true;
  bool _loadingExercises = false;
  String? _errorMessage;
  late TabController _tabController;
  List<FavoriteExerciseEntry> _favoriteExercises = const [];
  bool _sortAZ = false;

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

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('workout')) return;
    await PageGuideService.markGuideSeen('workout');
    if (mounted) await _showGuide();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _favoriteExercises = StorageHelper.getFavoriteExercises();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadMuscleGroups();
      _loadWorkoutsIfNeeded();
      await _checkFirstVisitGuide();
    });
  }

  Future<void> _toggleFavoriteExercise(Exercise exercise) async {
    await StorageHelper.toggleFavoriteExercise(
      exercise.name,
      muscleGroup: _normalizeMuscleGroupCode(exercise.muscleGroup),
      exerciseId: exercise.id,
    );
    setState(() {
      _favoriteExercises = StorageHelper.getFavoriteExercises();
    });
  }

  @override
  void dispose() {
    _regionSearchController.dispose();
    _exerciseSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

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

  bool _isFavoriteExercise(Exercise exercise) {
    return _favoriteExercises.any(
      (favorite) => favorite.matches(
        exercise.name,
        otherMuscleGroup: exercise.muscleGroup,
      ),
    );
  }

  Future<void> _loadMuscleGroups() async {
    setState(() {
      _loadingGroups = true;
      _errorMessage = null;
    });
    try {
      final groups = await _exerciseService.getMuscleGroups();
      if (mounted) {
        final normalizedGroups = groups
            .map(_normalizeMuscleGroupCode)
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList();
        setState(() {
          _muscleGroups = normalizedGroups.isEmpty
              ? kMuscleGroupInfo.keys.toList()
              : normalizedGroups;
          _loadingGroups = false;
          if (normalizedGroups.isEmpty) {
            _errorMessage = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _muscleGroups = kMuscleGroupInfo.keys.toList();
          _loadingGroups = false;
          _errorMessage = null;
        });
      }
    }
  }

  Future<void> _selectMuscleGroup(String group) async {
    final normalizedGroup = _normalizeMuscleGroupCode(group);
    setState(() {
      _selectedMuscleGroup = normalizedGroup;
      _selectedSubRegion = 'Tümü';
      _exerciseSearchQuery = '';
      _exerciseSearchController.clear();
      _exercises = [];
      _loadingExercises = true;
      _errorMessage = null;
    });
    try {
      final list = await _exerciseService.getExercisesByMuscleGroup(
        normalizedGroup,
      );
      if (mounted) {
        final resolved = _mergeWithFallback(list, normalizedGroup);
        final hasLocalCatalog = _exerciseCatalogForGroup(
          normalizedGroup,
        ).isNotEmpty;
        final message = list.isEmpty && !hasLocalCatalog
            ? 'Bu bölge için katalog henüz tanımlı değil.'
            : null;
        setState(() {
          _exercises = resolved;
          _loadingExercises = false;
          _errorMessage = message;
        });
      }
    } catch (e) {
      final fallback = _exerciseCatalogForGroup(normalizedGroup);
      if (mounted) {
        setState(() {
          _exercises = fallback;
          _loadingExercises = false;
          _errorMessage = fallback.isEmpty
              ? 'Bu bölge için katalog henüz tanımlı değil.'
              : null;
        });
      }
    }
  }

  String _normalizeMuscleGroupCode(String raw) =>
      ExerciseParserService.normalizeMuscleGroupCode(raw);

  String _normalizeSearchText(String input) =>
      ExerciseParserService.normalizeSearchText(input);

  String _detectSubRegionLabel(Exercise exercise, String muscleGroup) =>
      ExerciseParserService.detectSubRegionLabel(exercise, muscleGroup);

  List<Exercise> _mergeWithFallback(List<Exercise> apiList, String group) {
    final normalizedApi = apiList
        .where((e) => e.name.trim().isNotEmpty)
        .map(
          (e) => Exercise(
            id: e.id,
            muscleGroup: _normalizeMuscleGroupCode(e.muscleGroup),
            name: e.name.trim(),
            description: e.description,
            instructions: e.instructions,
          ),
        )
        .toList();

    // De-duplicate API list itself by name first
    final List<Exercise> uniqueApi = [];
    final Set<String> apiNames = {};
    for (final e in normalizedApi) {
      final name = e.name.toLowerCase().trim();
      if (!apiNames.contains(name)) {
        apiNames.add(name);
        uniqueApi.add(e);
      }
    }

    final catalog = _exerciseCatalogForGroup(group);
    final extras = catalog
        .where((e) => !apiNames.contains(e.name.toLowerCase().trim()))
        .toList();

    return [...uniqueApi, ...extras];
  }

  List<Exercise> _exerciseCatalogForGroup(String group) {
    return buildExerciseCatalogForGroup(group);
  }

  void _clearSelection() {
    setState(() {
      _selectedMuscleGroup = null;
      _selectedSubRegion = 'Tümü';
      _exerciseSearchQuery = '';
      _exerciseSearchController.clear();
      _exercises = [];
      _errorMessage = null;
    });
  }

  List<dynamic> _buildRenderItems(List<Exercise> filtered, String code) {
    final sorted = _sortAZ
        ? (List<Exercise>.from(filtered)
            ..sort((a, b) => a.name.compareTo(b.name)))
        : filtered;

    if (_selectedSubRegion != 'Tümü' ||
        _exerciseSearchQuery.trim().isNotEmpty) {
      return sorted;
    }

    final Map<String, List<Exercise>> groups = {};
    for (final e in sorted) {
      final label = _detectSubRegionLabel(e, code);
      groups.putIfAbsent(label, () => []).add(e);
    }

    final result = <dynamic>[];
    for (final entry in groups.entries) {
      if (entry.value.isNotEmpty) {
        result.add(entry.key);
        result.addAll(entry.value);
      }
    }
    return result;
  }

  List<Exercise> _filteredExercisesForSelectedRegion() {
    final group = _selectedMuscleGroup;
    if (group == null) return _exercises;
    final normalizedQuery = _normalizeSearchText(_exerciseSearchQuery);

    return _exercises.where((exercise) {
      final detected = _detectSubRegionLabel(exercise, group);
      final matchesSubRegion =
          _selectedSubRegion == 'Tümü' || detected == _selectedSubRegion;
      if (!matchesSubRegion) return false;
      if (normalizedQuery.isEmpty) return true;

      final haystack = _normalizeSearchText(
        '${exercise.name} ${exercise.description ?? ''} ${exercise.instructions ?? ''} $detected',
      );
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  List<String> _filteredMuscleGroups() {
    final normalizedQuery = _normalizeSearchText(_regionSearchQuery);
    if (normalizedQuery.isEmpty) {
      return _muscleGroups.isEmpty
          ? kMuscleGroupInfo.keys.toList()
          : _muscleGroups;
    }

    final source = _muscleGroups.isEmpty
        ? kMuscleGroupInfo.keys.toList()
        : _muscleGroups;
    return source.where((code) {
      final info = kMuscleGroupInfo[code];
      final haystack = _normalizeSearchText('$code ${info?.label ?? ''}');
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  Map<String, int> _subRegionCounts(String group) {
    final options = kSubRegionFilters[group] ?? const ['Tümü'];
    final counts = <String, int>{for (final o in options) o: 0};
    counts['Tümü'] = _exercises.length;
    for (final e in _exercises) {
      final label = _detectSubRegionLabel(e, group);
      if (counts.containsKey(label)) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return counts;
  }

  String _workoutGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Günaydın 💪 Güne güçlü başla';
    if (hour < 14) return 'Öğle antrenmanı zamanı 🔥';
    if (hour < 18) return 'Öğleden sonra enerjini boşalt 💥';
    return 'Akşam seansı başlıyor 🌙';
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

  String? _normalizedTemplateMuscleGroup(String? raw) {
    final normalized = _normalizeMuscleGroupCode(raw ?? '');
    return normalized.isEmpty ? null : normalized;
  }

  Exercise? _findExerciseForFavorite(FavoriteExerciseEntry favorite) {
    Exercise? partialMatch;
    final preferredGroup = _normalizedTemplateMuscleGroup(favorite.muscleGroup);
    final groups = <String>[
      ...[preferredGroup].whereType<String>(),
      ...kMuscleGroupInfo.keys.where((group) => group != preferredGroup),
    ];

    for (final group in groups) {
      final catalog = _exerciseCatalogForGroup(group);
      for (final exercise in catalog) {
        if (exercise.name.toLowerCase() == favorite.name.toLowerCase()) {
          return exercise;
        }
        if (partialMatch == null) {
          final exerciseName = exercise.name.toLowerCase();
          final favoriteName = favorite.name.toLowerCase();
          if (exerciseName.contains(favoriteName) ||
              favoriteName.contains(exerciseName)) {
            partialMatch = exercise;
          }
        }
      }
    }

    return partialMatch;
  }

  void _openQuickStartWorkout(BuildContext context, _QuickStartPreset preset) {
    _openActiveSession(
      context,
      title: preset.templateData.workoutName,
      plans: _plansFromQuickStart(preset.templateData),
      onFinish: () => _pushAddWorkoutFromTemplate(context, preset.templateData),
    );
  }

  void _pushAddWorkoutFromTemplate(
    BuildContext context,
    TemplateData templateData,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (_) => AddWorkoutPage(templateData: templateData),
          ),
        )
        .then((message) {
          if (!mounted) return;
          _loadWorkoutsIfNeeded();
          if (message != null && message.isNotEmpty) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: message.contains('Kişisel Rekor')
                    ? Colors.amber.shade700
                    : const Color(0xFF2E7D32),
              ),
            );
          }
        });
  }

  List<_SessionExercisePlan> _plansFromQuickStart(TemplateData templateData) {
    return [
      _SessionExercisePlan(
        name: templateData.exerciseName,
        sets: templateData.sets,
        reps: templateData.reps,
        muscleGroup: templateData.muscleGroup,
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

  void _openActiveSession(
    BuildContext context, {
    required String title,
    required List<_SessionExercisePlan> plans,
    required VoidCallback onFinish,
  }) {
    if (plans.isEmpty) {
      onFinish();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActiveWorkoutSessionSheet(
        title: title,
        plans: plans,
        onFinish: () {
          Navigator.of(context).pop();
          onFinish();
        },
      ),
    );
  }

  void _startSuggestedSession(BuildContext context, WorkoutProvider provider) {
    final groups = RecoveryEngine.recommendedGroupsToday(provider.workouts);
    final group = groups.isNotEmpty
        ? groups.first
        : kMuscleGroupInfo.keys.first;
    final exercises = _exerciseCatalogForGroup(group).take(4).toList();
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
      onFinish: () => _pushAddWorkoutFromTemplate(context, (
        exerciseName: plans.first.name,
        sets: plans.first.sets,
        reps: plans.first.reps,
        workoutName: '${info?.label ?? 'Akıllı'} Seans',
        duration: plans.length * 10,
        muscleGroup: group,
        difficulty: 'Orta',
      )),
    );
  }

  void _showMuscleGroupPicker(BuildContext context) {
    final groups = _muscleGroups.isEmpty
        ? kMuscleGroupInfo.keys.toList()
        : _muscleGroups;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const Text(
                'Bölge seç',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Çalışmak istediğin kas grubunu seç.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groups.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.55,
                ),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final info =
                      kMuscleGroupInfo[group] ??
                      (
                        label: group,
                        color: const Color(0xFF2E7D32),
                        icon: Icons.fitness_center_rounded,
                        imageUrl: '',
                      );
                  return InkWell(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _selectMuscleGroup(group);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: info.color.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(info.icon, color: info.color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              info.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      extendBodyBehindAppBar: true,
      appBar: _selectedMuscleGroup == null
          ? AppBar(
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
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
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
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () => _openAddWorkoutPage(context),
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
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(10),
                      padding: const EdgeInsets.all(3),
                      labelPadding: EdgeInsets.zero,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
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
            )
          : null,
      body: AppGradientBackground(
        imagePath: 'assets/images/nutrition_bg_dark.png',
        child: Stack(
          children: [
            const AmbientGlowBackground(),
            SafeArea(
              child: Column(
                children: [
                  if (_selectedMuscleGroup == null)
                    Consumer<WorkoutProvider>(
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
                        final totalCount = provider.workouts.length;
                        final prCount = provider.personalRecords.length;
                        final showHistoryTools = _tabController.index == 1;
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
                  Expanded(
                    child: _selectedMuscleGroup == null
                        ? TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRegionGrid(context),
                              _buildHistoryList(context),
                            ],
                          )
                        : _buildExerciseList(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildRegionGrid(BuildContext context) {
    final list = _filteredMuscleGroups();
    final isPremium = isPremiumTier(
      context.watch<AuthProvider>().user?.premiumTier,
    );
    final provider = context.watch<WorkoutProvider>();
    final recovery = RecoveryEngine.computeAll(provider.workouts);
    final stats = provider.workoutStats;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _TodayWorkoutActionCard(
            workouts: provider.workouts,
            suggestion: provider.workoutSuggestion,
            onStart: () => _startSuggestedSession(context, provider),
            onExplore: () => _showMuscleGroupPicker(context),
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer<WorkoutProgramProvider>(
            builder: (context, programProvider, _) => _TodayProgramCard(
              programs: programProvider.programs,
              onStartDay: (program, day) =>
                  _startProgramDay(context, program, day),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _WorkoutTemplatesSection(
            isPremium: isPremium,
            compactTitle: true,
            onStartPressed: (t) => _openTemplateWorkout(context, t),
            onSavePressed: (t) => _saveTemplate(context, t),
            onUpgradePressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
          ),
        ),
        SliverToBoxAdapter(
          child: _ProgressionSpotlightCard(
            workouts: provider.workouts,
            onStart: (plan) => _openActiveSession(
              context,
              title: '${plan.name} ilerleme seansı',
              plans: [plan],
              onFinish: () => _pushAddWorkoutFromTemplate(context, (
                exerciseName: plan.name,
                sets: plan.sets,
                reps: plan.reps,
                workoutName: plan.name,
                duration: 30,
                muscleGroup: plan.muscleGroup,
                difficulty: 'Orta',
              )),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _WeeklyBalanceCard(
            workouts: provider.workouts,
            onSelectGroup: _selectMuscleGroup,
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer<WorkoutProgramProvider>(
            builder: (context, programProvider, _) => _MyProgramsSection(
              programs: programProvider.programs,
              onCreateTap: () => _openProgramBuilder(context),
              onProgramTap: (p) => _showProgramDetail(context, p),
            ),
          ),
        ),
        if (_favoriteExercises.isNotEmpty)
          SliverToBoxAdapter(
            child: _FavoritesQuickStrip(
              favorites: _favoriteExercises,
              onTap: (favorite) {
                final exercise = _findExerciseForFavorite(favorite);
                if (exercise != null) {
                  final code = _normalizeMuscleGroupCode(exercise.muscleGroup);
                  final info = kMuscleGroupInfo[code];
                  _openExerciseGuide(
                    context,
                    exercise,
                    info?.color ?? const Color(0xFF2E7D32),
                    info?.label,
                  );
                } else {
                  // Katalogda bulunarsa kullanıcıyı bilgilendir
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${favorite.name} için rehber bulunamadı.',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF2C2C2C),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
        SliverToBoxAdapter(child: _DailyTipCard()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: Color(0xFF66BB6A),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Kas Grupları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _regionSearchController,
                  onChanged: (value) {
                    setState(() {
                      _regionSearchQuery = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Bölge ara...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white70,
                    ),
                    suffixIcon: _regionSearchQuery.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _regionSearchController.clear();
                              setState(() {
                                _regionSearchQuery = '';
                              });
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                            ),
                          ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loadingGroups)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            ),
          )
        else if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                '"${_regionSearchQuery.trim()}" için bölge bulunamadı.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final code = list[index];
                final info =
                    kMuscleGroupInfo[code] ??
                    (
                      label: code,
                      color: const Color(0xFF2E7D32),
                      icon: Icons.fitness_center,
                      imageUrl: 'assets/images/ust_gogus_kasi_hareketleri.jpg',
                    );
                return _RegionCard(
                  label: info.label,
                  color: info.color,
                  icon: info.icon,
                  imageUrl: info.imageUrl,
                  onTap: () => _selectMuscleGroup(code),
                );
              }, childCount: list.length),
            ),
          ),
        SliverToBoxAdapter(
          child: _RecoveryInsightsCard(
            workoutSuggestion: provider.workoutSuggestion,
            recoveryStatuses: recovery,
            totalWorkouts:
                (stats['totalWorkouts'] as num?)?.toInt() ??
                provider.workouts.length,
            totalSets:
                (stats['totalSets'] as num?)?.toInt() ??
                provider.workouts.fold<int>(
                  0,
                  (sum, workout) => sum + (workout.sets ?? 0),
                ),
            totalCaloriesBurned:
                (stats['totalCaloriesBurned'] as num?)?.toInt() ??
                provider.workouts.fold<int>(
                  0,
                  (sum, workout) => sum + (workout.caloriesBurned ?? 0),
                ),
            onSelectGroup: _selectMuscleGroup,
          ),
        ),
        if (_errorMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  List<Workout> _filteredHistoryWorkouts(WorkoutProvider provider) {
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
        return provider.workouts.where((workout) {
          final day = DateTime(
            workout.workoutDate.year,
            workout.workoutDate.month,
            workout.workoutDate.day,
          );
          return !day.isBefore(weekStart);
        }).toList();
      case _WorkoutHistoryFilter.prs:
        return provider.workouts.where((workout) {
          final pr = provider.personalRecords[workout.name];
          return workout.oneRepMax != null &&
              pr != null &&
              workout.oneRepMax! >= pr - 0.05;
        }).toList();
    }
  }

  Widget _buildHistoryList(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        final selectedWorkouts = _filteredHistoryWorkouts(provider);
        if (provider.isLoading && provider.workouts.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          );
        }

        if (provider.workouts.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              // ── Hero motivation card ───────────────────────────────────────
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
                          color: const Color(
                            0xFF2E7D32,
                          ).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.25),
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
                      onTap: () => _openAddWorkoutPage(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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
              // ── Quick-start section ────────────────────────────────────────
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                      onTap: () => _openQuickStartWorkout(
                        context,
                        _kQuickStartPresets[0],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _QuickStartTypeCard(
                      icon: Icons.directions_run_rounded,
                      label: 'Bacak',
                      subtitle: 'Squat · Leg Press',
                      color: const Color(0xFFE53935),
                      onTap: () => _openQuickStartWorkout(
                        context,
                        _kQuickStartPresets[1],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _QuickStartTypeCard(
                      icon: Icons.self_improvement_rounded,
                      label: 'Full Body',
                      subtitle: 'Tüm kas grupları',
                      color: const Color(0xFF8E24AA),
                      onTap: () => _openQuickStartWorkout(
                        context,
                        _kQuickStartPresets[2],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _QuickStartTypeCard(
                      icon: Icons.bolt_rounded,
                      label: 'Cardio',
                      subtitle: 'Yağ yakım · Kondisyon',
                      color: const Color(0xFFF57C00),
                      onTap: () => _openQuickStartWorkout(
                        context,
                        _kQuickStartPresets[3],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        if (selectedWorkouts.isEmpty) {
          final formattedDate = DateFormat(
            'd MMMM',
            'tr_TR',
          ).format(provider.selectedDate);
          return ListView(
            padding: const EdgeInsets.all(20).copyWith(bottom: 100),
            children: [
              _HistoryFilterBar(
                selected: _historyFilter,
                onChanged: (filter) => setState(() => _historyFilter = filter),
              ),
              const SizedBox(height: 16),
              _WeeklyVolumeChart(workouts: provider.workouts),
              const SizedBox(height: 40),
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

        // Deload tespiti: son 6 günde her gün antrenman yapıldıysa
        final recentDays = <DateTime>{};
        final now = DateTime.now();
        for (final w in provider.workouts) {
          final d = DateTime(
            w.workoutDate.year,
            w.workoutDate.month,
            w.workoutDate.day,
          );
          if (now.difference(d).inDays <= 6) recentDays.add(d);
        }
        final showDeload = recentDays.length >= 6;

        return RefreshIndicator(
          onRefresh: _loadWorkoutsIfNeeded,
          color: const Color(0xFF2E7D32),
          child: ListView.builder(
            padding: const EdgeInsets.all(20).copyWith(bottom: 100),
            itemCount: selectedWorkouts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HistoryFilterBar(
                      selected: _historyFilter,
                      onChanged: (filter) =>
                          setState(() => _historyFilter = filter),
                    ),
                    const SizedBox(height: 16),
                    _WeeklyVolumeChart(workouts: provider.workouts),
                    const SizedBox(height: 16),
                    _MuscleGroupChart(workouts: provider.workouts),
                    if (showDeload) ...[
                      const SizedBox(height: 16),
                      _DeloadBanner(),
                    ],
                    const SizedBox(height: 8),
                  ],
                );
              }
              final workout = selectedWorkouts[index - 1];
              return _HistoryCard(
                workout: workout,
                onDelete: () => _confirmDelete(context, workout),
                onEdit: () => _openAddWorkoutPage(context, workout: workout),
                onRepeat: () => _repeatWorkout(context, workout),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildExerciseList(BuildContext context) {
    final code = _selectedMuscleGroup!;
    final filtered = _filteredExercisesForSelectedRegion();
    final counts = _subRegionCounts(code);
    final info =
        kMuscleGroupInfo[code] ??
        (
          label: code,
          color: const Color(0xFF2E7D32),
          icon: Icons.fitness_center,
          imageUrl: 'assets/images/ust_gogus_kasi_hareketleri.jpg',
        );

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: _clearSelection,
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    info.label,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${filtered.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  info.imageUrl.startsWith('assets/')
                      ? Image.asset(info.imageUrl, fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: info.imageUrl,
                          fit: BoxFit.cover,
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x60000000),
                          Color(0xFF0A0A0A),
                        ],
                        stops: [0.3, 0.65, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 52,
                    child: GestureDetector(
                      onTap: () => _openAddWorkoutPage(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: info.color,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: info.color.withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Antrenman Kaydet',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
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
          ),
        ];
      },
      body: _loadingExercises
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          : _exercises.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu bölge için henüz egzersiz yok.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Builder(
              builder: (context) {
                final renderItems = _buildRenderItems(filtered, code);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                  itemCount: renderItems.isEmpty ? 2 : renderItems.length + 1,
                  itemBuilder: (context, index) {
                    // ── Filter panel ──────────────────────────────────────
                    if (index == 0) {
                      final options = kSubRegionFilters[code] ?? const ['Tümü'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _exerciseSearchController,
                              onChanged: (value) {
                                setState(() => _exerciseSearchQuery = value);
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Hareket ara',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: info.color.withValues(alpha: 0.9),
                                ),
                                suffixIcon: _exerciseSearchQuery.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _exerciseSearchController.clear();
                                          setState(
                                            () => _exerciseSearchQuery = '',
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white54,
                                        ),
                                      ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.04),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: info.color),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: options.map((option) {
                                  final selected = option == _selectedSubRegion;
                                  final count = counts[option] ?? 0;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text('$option ($count)'),
                                      selected: selected,
                                      onSelected: count == 0
                                          ? null
                                          : (_) {
                                              setState(
                                                () =>
                                                    _selectedSubRegion = option,
                                              );
                                            },
                                      showCheckmark: false,
                                      avatar: selected
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.68,
                                              ),
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      selectedColor: info.color,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      side: BorderSide(
                                        color: selected
                                            ? info.color
                                            : Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                        width: 1,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Count + Sort row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _exerciseSearchQuery.trim().isEmpty
                                      ? '${filtered.length} hareket'
                                      : '"${_exerciseSearchQuery.trim()}" → ${filtered.length} sonuç',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _sortAZ = !_sortAZ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _sortAZ
                                          ? info.color.withValues(alpha: 0.15)
                                          : Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _sortAZ
                                            ? info.color.withValues(alpha: 0.5)
                                            : Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.sort_by_alpha_rounded,
                                          size: 13,
                                          color: _sortAZ
                                              ? info.color
                                              : Colors.white.withValues(
                                                  alpha: 0.45,
                                                ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'A–Z',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _sortAZ
                                                ? info.color
                                                : Colors.white.withValues(
                                                    alpha: 0.45,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    // ── Empty state ───────────────────────────────────────
                    if (renderItems.isEmpty) {
                      return Container(
                        margin: const EdgeInsets.only(top: 48),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _exerciseSearchQuery.trim().isEmpty
                                  ? 'Bu bölge için hareket bulunamadı.'
                                  : '"${_exerciseSearchQuery.trim()}" için sonuç yok.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // ── Section header or Exercise card ───────────────────
                    final item = renderItems[index - 1];
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(
                                color: info.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: info.color,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Divider(
                                color: info.color.withValues(alpha: 0.2),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final exercise = item as Exercise;
                    final subRegion = _detectSubRegionLabel(exercise, code);
                    final isFav = _isFavoriteExercise(exercise);
                    return _ExerciseCard(
                      exercise: exercise,
                      accentColor: info.color,
                      subRegionLabel: _selectedSubRegion == 'Tümü'
                          ? null
                          : subRegion,
                      isFavorite: isFav,
                      onFavoriteTap: () => _toggleFavoriteExercise(exercise),
                      onTap: () => _openExerciseGuide(
                        context,
                        exercise,
                        info.color,
                        info.label,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userId = authProvider.user?.id;
        if (userId == null) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => _openAddWorkoutPage(context),
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
                // Silinen antrenmanı geri yükle
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
      onFinish: () => _pushAddWorkoutFromTemplate(context, templateData),
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
      onFinish: () => _pushAddWorkoutFromTemplate(context, templateData),
    );
  }
}
