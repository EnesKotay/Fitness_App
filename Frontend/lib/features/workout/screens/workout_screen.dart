import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/workout.dart';
import '../../../core/api/services/exercise_service.dart';
import '../../../core/utils/storage_helper.dart';
import '../data/workout_catalog_data.dart';
import '../providers/workout_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../nutrition/presentation/widgets/date_strip.dart';
import 'exercise_guide_screen.dart';
import 'add_workout_page.dart';

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
  bool _loadingGroups = true;
  bool _loadingExercises = false;
  String? _errorMessage;
  late TabController _tabController;
  Set<String> _favoriteExercises = {};
  bool _sortAZ = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _favoriteExercises = StorageHelper.getFavoriteExerciseNames().toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMuscleGroups();
      _loadWorkoutsIfNeeded();
    });
  }

  Future<void> _toggleFavoriteExercise(String name) async {
    await StorageHelper.toggleFavoriteExercise(name);
    setState(() {
      _favoriteExercises = StorageHelper.getFavoriteExerciseNames().toSet();
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
            _errorMessage =
                'Sunucudan bölgeler alınamadı. Yerel katalog gösteriliyor.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _muscleGroups = kMuscleGroupInfo.keys.toList();
          _loadingGroups = false;
          _errorMessage =
              'Sunucudan bölgeler alınamadı. Yerel katalog gösteriliyor.';
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
        final message = list.isEmpty
            ? hasLocalCatalog
                  ? 'Bu bölge için sunucu verisi boş döndü. Yerel katalog gösteriliyor.'
                  : 'Bu bölge için katalog henüz tanımlı değil.'
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
              : 'Egzersizler şu an sunucudan alınamadı. Yerel katalog gösteriliyor.';
        });
      }
    }
  }

  String _normalizeMuscleGroupCode(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final upper = value.toUpperCase();

    if (kMuscleGroupInfo.containsKey(upper)) return upper;

    const aliases = <String, String>{
      'GÖĞÜS': 'CHEST',
      'GOGUS': 'CHEST',
      'CHEST': 'CHEST',
      'SIRT': 'BACK',
      'BACK': 'BACK',
      'BACAK': 'LEGS',
      'LEG': 'LEGS',
      'LEGS': 'LEGS',
      'OMUZ': 'SHOULDERS',
      'SHOULDER': 'SHOULDERS',
      'SHOULDERS': 'SHOULDERS',
      'BİSEPS': 'BICEPS',
      'BISEPS': 'BICEPS',
      'BICEP': 'BICEPS',
      'BICEPS': 'BICEPS',
      'TRİCEPS': 'TRICEPS',
      'TRICEP': 'TRICEPS',
      'TRICEPS': 'TRICEPS',
      'KARIN': 'CORE',
      'CORE': 'CORE',
      'ABS': 'CORE',
      'KALÇA': 'GLUTES',
      'KALCA': 'GLUTES',
      'GLUTE': 'GLUTES',
      'GLUTES': 'GLUTES',
    };

    final direct = aliases[upper];
    if (direct != null) return direct;

    if (upper.contains('GÖĞ') || upper.contains('GOG')) return 'CHEST';
    if (upper.contains('SIRT') || upper.contains('BACK')) return 'BACK';
    if (upper.contains('BACAK') || upper.contains('LEG')) return 'LEGS';
    if (upper.contains('OMUZ') || upper.contains('SHOUL')) return 'SHOULDERS';
    if (upper.contains('BİS') ||
        upper.contains('BIS') ||
        upper.contains('BICEP')) {
      return 'BICEPS';
    }
    if (upper.contains('TRİ') ||
        upper.contains('TRI') ||
        upper.contains('TRICEP')) {
      return 'TRICEPS';
    }
    if (upper.contains('KARIN') ||
        upper.contains('ABS') ||
        upper.contains('CORE')) {
      return 'CORE';
    }
    if (upper.contains('KALÇ') ||
        upper.contains('KALC') ||
        upper.contains('GLUTE')) {
      return 'GLUTES';
    }

    return upper;
  }

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

  String _normalizeSearchText(String input) {
    return input
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  bool _containsToken(String text, String token) {
    final t = token.trim();
    if (t.isEmpty) return false;
    if (t.contains(' ')) return text.contains(t);
    final escaped = RegExp.escape(t);
    const suffix = r'([^a-z0-9]|$)';
    final pattern = RegExp('(^|[^a-z0-9])$escaped$suffix');
    return pattern.hasMatch(text);
  }

  bool _containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (_containsToken(text, _normalizeSearchText(n))) return true;
    }
    return false;
  }

  String _detectSubRegionLabel(Exercise exercise, String muscleGroup) {
    final text = _normalizeSearchText(
      '${exercise.name} ${exercise.description ?? ''} ${exercise.instructions ?? ''}',
    );

    switch (muscleGroup) {
      case 'CHEST':
        if (_containsAny(text, ['incline', 'upper', 'ust', 'clavicular'])) {
          return 'Üst Göğüs';
        }
        if (_containsAny(text, ['decline', 'dip', 'alt', 'lower'])) {
          return 'Alt Göğüs';
        }
        if (_containsAny(text, [
          'fly',
          'crossover',
          'pec deck',
          'pec fly',
          'svend',
        ])) {
          return 'İç Göğüs';
        }
        return 'Orta Göğüs';
      case 'BACK':
        if (_containsAny(text, ['lat', 'pulldown', 'pull-up', 'pullup'])) {
          return 'Lat';
        }
        if (_containsAny(text, [
          'lower back',
          'hip hinge',
          'deadlift',
          'back extension',
          'bel',
          'lumbar',
          'erector',
          'spinal',
          'hyperextension',
        ])) {
          return 'Alt Sırt';
        }
        if (_containsAny(text, [
          'face pull',
          'rear',
          'upper back',
          'trap',
          'shrug',
          'scapula',
          'ust sirt',
          'trapez',
        ])) {
          return 'Üst Sırt';
        }
        return 'Orta Sırt';
      case 'LEGS':
        if (_containsAny(text, [
          'curl',
          'romanian',
          'rdl',
          'hamstring',
          'arka',
        ])) {
          return 'Arka Bacak';
        }
        if (_containsAny(text, ['calf', 'baldir'])) return 'Baldır';
        return 'Ön Bacak';
      case 'SHOULDERS':
        if (_containsAny(text, ['front raise', 'front', 'on'])) {
          return 'Ön Omuz';
        }
        if (_containsAny(text, ['rear', 'face pull', 'arka'])) {
          return 'Arka Omuz';
        }
        return 'Yan Omuz';
      case 'BICEPS':
        if (_containsAny(text, [
          'hammer',
          'brachialis',
          'reverse',
          'neutral',
          'pronated',
        ])) {
          return 'Brachialis';
        }
        if (_containsAny(text, [
          'incline',
          'narrow',
          'outer',
          'long head',
          'uzun',
          'drag',
        ])) {
          return 'Uzun Baş';
        }
        return 'Kısa Baş';
      case 'TRICEPS':
        if (_containsAny(text, ['overhead', 'long head', 'uzun'])) {
          return 'Uzun Baş';
        }
        if (_containsAny(text, ['pushdown', 'rope'])) return 'Lateral Baş';
        return 'Medial Baş';
      case 'CORE':
        if (_containsAny(text, [
          'leg raise',
          'lower abs',
          'alt',
          'mountain',
          'scissor',
          'pulse',
          'hanging knee',
        ])) {
          return 'Alt Karın';
        }
        if (_containsAny(text, [
          'twist',
          'oblique',
          'oblik',
          'wiper',
          'heel',
          'side crunch',
          'woodchopper',
          'side bend',
        ])) {
          return 'Oblik';
        }
        if (_containsAny(text, [
          'plank',
          'dead bug',
          'stabil',
          'hollow',
          'l-sit',
          'bird dog',
          'suitcase',
        ])) {
          return 'Core Stabilite';
        }
        return 'Üst Karın';
      case 'GLUTES':
        if (_containsAny(text, [
          'med',
          'abduction',
          'yan',
          'fire hydrant',
          'side lying',
          'abduction',
        ])) {
          return 'Glute Med';
        }
        if (_containsAny(text, [
          'min',
          'mini',
          'clamshell',
          'lateral',
          'monster',
          'kickstand',
        ])) {
          return 'Glute Min';
        }
        return 'Glute Max';
      default:
        return 'Tümü';
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _selectedMuscleGroup == null
          ? AppBar(
              backgroundColor: const Color(0xFF0A0A0A),
              elevation: 0,
              titleSpacing: 20,
              title: Consumer<WorkoutProvider>(
                builder: (context, provider, _) {
                  final today = DateTime.now();
                  final weekStart = today.subtract(Duration(days: today.weekday - 1));
                  final thisWeekCount = provider.workouts.where((w) =>
                    w.workoutDate.isAfter(weekStart.subtract(const Duration(seconds: 1)))).length;
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF2E7D32).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department_rounded,
                                      size: 12, color: Color(0xFF66BB6A)),
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
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedMuscleGroup == null)
              Consumer<WorkoutProvider>(
                builder: (context, provider, _) {
                  final today = DateTime.now();
                  final weekStart = today.subtract(Duration(days: today.weekday - 1));
                  final thisWeekCount = provider.workouts.where((w) =>
                    w.workoutDate.isAfter(weekStart.subtract(const Duration(seconds: 1)))).length;
                  final totalCount = provider.workouts.length;
                  final prCount = provider.personalRecords.length;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: DateStrip(
                          selectedDate: provider.selectedDate,
                          onDateSelected: (date) => provider.setSelectedDate(date),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
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
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildRegionGrid(BuildContext context) {
    final list = _filteredMuscleGroups();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _DailyTipCard()),
        SliverToBoxAdapter(
          child: _WorkoutTemplatesSection(
            onStartPressed: () => _openTemplateWorkout(context, []),
          ),
        ),
        if (_favoriteExercises.isNotEmpty)
          SliverToBoxAdapter(
            child: _FavoritesQuickStrip(
              names: _favoriteExercises.toList(),
              onTap: (name) {
                // find exercise and open guide
                final ex = _exercises.where((e) => e.name == name).firstOrNull;
                if (ex != null) {
                  final code = _selectedMuscleGroup ?? 'CHEST';
                  final info = kMuscleGroupInfo[code];
                  _openExerciseGuide(context, ex, info?.color ?? const Color(0xFF2E7D32), info?.label);
                }
              },
            ),
          ),
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
                      child: const Icon(Icons.grid_view_rounded,
                          color: Color(0xFF66BB6A), size: 18),
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

  Widget _buildHistoryList(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        final selectedWorkouts = provider.workoutsForSelectedDate;
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
                      onTap: () => _openAddWorkoutPage(context),
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
                      onTap: () => _openAddWorkoutPage(context),
                    ),
                    const SizedBox(width: 10),
                    _QuickStartTypeCard(
                      icon: Icons.directions_run_rounded,
                      label: 'Bacak',
                      subtitle: 'Squat · Leg Press',
                      color: const Color(0xFFE53935),
                      onTap: () => _openAddWorkoutPage(context),
                    ),
                    const SizedBox(width: 10),
                    _QuickStartTypeCard(
                      icon: Icons.self_improvement_rounded,
                      label: 'Full Body',
                      subtitle: 'Tüm kas grupları',
                      color: const Color(0xFF8E24AA),
                      onTap: () => _openAddWorkoutPage(context),
                    ),
                    const SizedBox(width: 10),
                    _QuickStartTypeCard(
                      icon: Icons.bolt_rounded,
                      label: 'Cardio',
                      subtitle: 'Yağ yakım · Kondisyon',
                      color: const Color(0xFFF57C00),
                      onTap: () => _openAddWorkoutPage(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        if (selectedWorkouts.isEmpty) {
          final formattedDate = DateFormat('d MMMM', 'tr_TR').format(provider.selectedDate);
          return ListView(
            padding: const EdgeInsets.all(20).copyWith(bottom: 100),
            children: [
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
                      child: Icon(Icons.event_available_rounded,
                          size: 42, color: Colors.white.withValues(alpha: 0.2)),
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

        return RefreshIndicator(
          onRefresh: _loadWorkoutsIfNeeded,
          color: const Color(0xFF2E7D32),
          child: ListView.builder(
            padding: const EdgeInsets.all(20).copyWith(bottom: 100),
            itemCount: selectedWorkouts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _WeeklyVolumeChart(workouts: provider.workouts);
              }
              final workout = selectedWorkouts[index - 1];
              return _HistoryCard(
                workout: workout,
                onDelete: () => _confirmDelete(context, workout),
                onEdit: () => _openAddWorkoutPage(context, workout: workout),
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
                          horizontal: 7, vertical: 3),
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
                            horizontal: 14, vertical: 9),
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
                            const Icon(Icons.add_rounded,
                                color: Colors.white, size: 16),
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
                      final options =
                          kSubRegionFilters[code] ?? const ['Tümü'];
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
                                              () => _exerciseSearchQuery = '');
                                        },
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white54,
                                        ),
                                      ),
                                filled: true,
                                fillColor:
                                    Colors.white.withValues(alpha: 0.04),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: info.color),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: options.map((option) {
                                  final selected =
                                      option == _selectedSubRegion;
                                  final count = counts[option] ?? 0;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text('$option ($count)'),
                                      selected: selected,
                                      onSelected: count == 0
                                          ? null
                                          : (_) {
                                              setState(() =>
                                                  _selectedSubRegion =
                                                      option);
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
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.68),
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      selectedColor: info.color,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.05),
                                      side: BorderSide(
                                        color: selected
                                            ? info.color
                                            : Colors.white
                                                .withValues(alpha: 0.12),
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
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _exerciseSearchQuery.trim().isEmpty
                                      ? '${filtered.length} hareket'
                                      : '"${_exerciseSearchQuery.trim()}" → ${filtered.length} sonuç',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _sortAZ = !_sortAZ),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _sortAZ
                                          ? info.color
                                              .withValues(alpha: 0.15)
                                          : Colors.white
                                              .withValues(alpha: 0.05),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _sortAZ
                                            ? info.color
                                                .withValues(alpha: 0.5)
                                            : Colors.white
                                                .withValues(alpha: 0.1),
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
                                                  alpha: 0.45),
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
                                                    alpha: 0.45),
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
                    final subRegion =
                        _detectSubRegionLabel(exercise, code);
                    final isFav =
                        _favoriteExercises.contains(exercise.name);
                    return _ExerciseCard(
                      exercise: exercise,
                      accentColor: info.color,
                      subRegionLabel: _selectedSubRegion == 'Tümü'
                          ? null
                          : subRegion,
                      isFavorite: isFav,
                      onFavoriteTap: () =>
                          _toggleFavoriteExercise(exercise.name),
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
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
            content: Text('Silindi'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    }
  }

  void _openAddWorkoutPage(BuildContext context, {Workout? workout}) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (_) => AddWorkoutPage(workout: workout),
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

  void _openTemplateWorkout(
    BuildContext context,
    List<String> exercises,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    // Open AddWorkoutPage; exercises list is informational
    Navigator.of(context)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (_) => const AddWorkoutPage(),
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
}

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
                      placeholder: (_, _) => Container(
                        color: color.withValues(alpha: 0.3),
                      ),
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
                                  horizontal: 7, vertical: 2),
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

  const _HistoryCard({
    required this.workout,
    required this.onDelete,
    required this.onEdit,
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
                                    const Text('🏆', style: TextStyle(fontSize: 10)),
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
                                color: Colors.purpleAccent.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Superset: ${workout.supersetPartner}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purpleAccent.withValues(alpha: 0.8),
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
                    },
                    itemBuilder: (ctx) => [
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
              Row(
                children: [
                  if (workout.workoutType != null)
                    _InfoTag(
                      label: workout.workoutType!,
                      icon: Icons.category,
                      color: const Color(0xFF2E7D32),
                    ),
                  if (workout.sets != null) ...[
                    const SizedBox(width: 8),
                    _InfoTag(
                      label: '${workout.sets} Set',
                      icon: Icons.layers_rounded,
                      color: Colors.orange,
                    ),
                  ],
                  if (workout.reps != null) ...[
                    const SizedBox(width: 8),
                    _InfoTag(
                      label: '${workout.reps} Tekrar',
                      icon: Icons.repeat_rounded,
                      color: Colors.purple,
                    ),
                  ],
                  if (workout.durationMinutes != null &&
                      workout.durationMinutes! > 0) ...[
                    const SizedBox(width: 8),
                    _InfoTag(
                      label: '${workout.durationMinutes} dk',
                      icon: Icons.timer_rounded,
                      color: Colors.blue,
                    ),
                  ],
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
      (name: 'Bench Press', volume: '4×8', tip: 'Kürek kemiklerini birbirine yaklaştır'),
      (name: 'Incline Dumbbell Press', volume: '3×10', tip: '30-45° açı, göğüs üstünü hedefler'),
      (name: 'Decline Dumbbell Press', volume: '3×10', tip: 'Alt göğüs dolgunluğu için'),
      (name: 'Cable Fly', volume: '3×12', tip: 'Hareketin sonunda göğsü sık'),
      (name: 'Dips (Triceps)', volume: '3×12', tip: 'Gövdeyi dik tut, dirseklere odaklan'),
      (name: 'Tricep Pushdown', volume: '3×15', tip: 'Dirsekler sabit, tam açılım yap'),
      (name: 'Overhead Tricep Extension', volume: '3×12', tip: 'Yavaş indir, yukarıda kilitle'),
    ],
    description: 'Göğsün tüm bölgelerini (üst, orta, alt) ve triceps\'i derin çalıştıran itme günü antrenmanı. Her setten sonra 60-90 sn dinlen.',
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
      (name: 'Deadlift', volume: '4×5', tip: 'Sırt düz, nefes alıp tut, kalçadan it'),
      (name: 'Wide Grip Lat Pulldown', volume: '4×10', tip: 'Göğüs üstüne çek, lat gerilimi hisset'),
      (name: 'Barbell Row', volume: '4×8', tip: '45° öne eğil, göbeğe doğru çek'),
      (name: 'Seated Cable Row', volume: '3×12', tip: 'Omuzları geri-aşağı al, sıkıştır'),
      (name: 'Face Pull', volume: '3×15', tip: 'Arka omuz ve rotator cuff için kritik'),
      (name: 'Barbell Curl', volume: '4×10', tip: 'Dirsek öne gelmesin, tam ROM'),
      (name: 'Hammer Curl', volume: '3×12', tip: 'Önkol ve brachialis geliştirrir'),
    ],
    description: 'Lat genişliği, sırt kalınlığı ve güçlü biseps için eksiksiz çekme günü. Deadlift\'i ısındıktan sonra yap.',
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
      (name: 'Back Squat', volume: '5×5', tip: 'Diz-ayak aynı yönde, kalça paralele kadar'),
      (name: 'Romanian Deadlift', volume: '4×8', tip: 'Hamstring gerilimini hisset, sırt düz'),
      (name: 'Leg Press', volume: '4×12', tip: 'Diz 90°\'de kilitleme, ayak pozisyonu değiştir'),
      (name: 'Walking Lunge', volume: '3×12 (her bacak)', tip: 'Öne diz ayak parmağını geçmesin'),
      (name: 'Leg Curl', volume: '3×12', tip: 'Kontrollü indir, iki kat yavaş'),
      (name: 'Bulgarian Split Squat', volume: '3×10 (her bacak)', tip: 'Arka ayak yüksekte, denge önemli'),
      (name: 'Standing Calf Raise', volume: '4×20', tip: 'Tepede 1-2 sn tut, tam ROM'),
    ],
    description: 'Bacakların en zorlu ama en etkili antrenmanı. Squat öncelikli, ağırlıkları kademeli artır. Antrenman sonrası germeyi atla.',
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
      (name: 'Plank', volume: '3×60 sn', tip: 'Kalça ne yukarı ne aşağı, gövde düz'),
      (name: 'Hanging Leg Raise', volume: '3×12', tip: 'Sallanma, yavaş kaldır-indir'),
      (name: 'Cable Crunch', volume: '4×15', tip: 'Alnı dize götür, bel esnesin'),
      (name: 'Russian Twist', volume: '3×20 (her yön)', tip: 'Ayaklar yerden kalkık, omuz döndür'),
      (name: 'Ab Wheel Rollout', volume: '3×10', tip: 'Geri dönerken yavaş, core sıkı'),
      (name: 'Side Plank', volume: '3×40 sn (her yan)', tip: 'Kalça yükselsin, vücut düz'),
      (name: 'Reverse Crunch', volume: '3×15', tip: 'Alt karnı yuvarla, ivme kullanma'),
    ],
    description: 'Üst-alt karın ve oblik kasları ayrı ayrı çalıştıran kapsamlı core antrenmanı. Haftada 3 kez uygulanabilir.',
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
      (name: 'Overhead Press (Barbell)', volume: '4×8', tip: 'Bel hafif öne eğilsin, core sıkı'),
      (name: 'Dumbbell Lateral Raise', volume: '4×15', tip: 'Dirsek hafif bükük, kontrollü indir'),
      (name: 'Arnold Press', volume: '3×10', tip: 'Tüm delt başlarını çalıştırır'),
      (name: 'Rear Delt Fly (Dumbbell)', volume: '4×15', tip: 'Öne eğil, dirsek hafif bükük'),
      (name: 'Face Pull', volume: '3×15', tip: 'İp yüz hizasına, dışa döndür'),
      (name: 'Upright Row', volume: '3×12', tip: 'Dirsekler omuz hizasına kadar'),
      (name: 'Barbell Shrug', volume: '4×15', tip: 'Trapezi yukarı sık, döndürme'),
    ],
    description: '3D omuz gelişimi için ön, yan ve arka delt\'i eşit çalıştıran program. Trapezius da dahil, tam omuz antrenmanı.',
  ),
];

class _WorkoutTemplatesSection extends StatelessWidget {
  final VoidCallback onStartPressed;

  const _WorkoutTemplatesSection({required this.onStartPressed});

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
                'Hazır Programlar',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${_kWorkoutTemplates.length} program',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
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
                onTap: () => _showTemplateDetail(context, t, onStartPressed),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  static void _showTemplateDetail(
    BuildContext context,
    _TemplateData t,
    VoidCallback onStartPressed,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateDetailSheet(
        template: t,
        onStart: onStartPressed,
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final _TemplateData template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

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
            colors: [t.color.withValues(alpha: 0.25), t.colorDark.withValues(alpha: 0.5)],
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
                    child: Icon(t.icon, color: t.color, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.difficultyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.difficultyColor.withValues(alpha: 0.5)),
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
                  Icon(Icons.timer_outlined, size: 12, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    '${t.estimatedMinutes} dk',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const Spacer(),
                  Icon(Icons.fitness_center, size: 12, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    '${t.exercises.length} egz.',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
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
                        'Detay Gör',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: t.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: t.color),
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
  final VoidCallback onStart;

  const _TemplateDetailSheet({required this.template, required this.onStart});

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
                    colors: [t.color.withValues(alpha: 0.3), t.colorDark.withValues(alpha: 0.6)],
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
                  children: t.muscles.map((m) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(fontSize: 12, color: t.color, fontWeight: FontWeight.w600),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                                      color: Colors.white.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    );
                  },
                ),
              ),
              // Start button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onStart();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text(
                      'Antrenmanı Başlat',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
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

  const _StatChip({required this.icon, required this.label, required this.color});

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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
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
                                : const Color(0xFF2E7D32).withValues(alpha: 0.4),
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
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
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
        .where((w) =>
            !w.workoutDate
                .isBefore(weekStart.subtract(const Duration(seconds: 1))) &&
            w.workoutDate
                .isBefore(weekStart.add(const Duration(days: 7))))
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
              final isToday = date.year == now.year &&
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
                              : Colors.white.withValues(alpha: isFuture ? 0.0 : 0.04),
                      border: Border.all(
                        color: isToday
                            ? accentLight
                            : hasWorkout
                                ? accent
                                : Colors.white.withValues(alpha: isFuture ? 0.06 : 0.1),
                        width: isToday ? 2 : 1,
                      ),
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
                                  color: Colors.white.withValues(alpha: isFuture ? 0.2 : 0.35),
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
    (icon: '💧', text: 'Antrenman öncesi 500 ml su iç — performansını %10 artırır.'),
    (icon: '😴', text: 'Kas gelişimi antrenman sırasında değil, uyurken olur. 7-9 saat uyu.'),
    (icon: '🥩', text: 'Her öğün bir avuç protein al — tokluk ve kas için idealdir.'),
    (icon: '⏱️', text: 'Setler arası 60-90 sn dinlenme hipertrofi için en verimli aralıktır.'),
    (icon: '📈', text: 'Her haftada bir ağırlık veya tekrar artır — lineer ilerleme şarttır.'),
    (icon: '🔥', text: 'Isınmayı atlama. 5 dk dinamik ısınma sakatlık riskini %50 azaltır.'),
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
  final List<String> names;
  final void Function(String name) onTap;

  const _FavoritesQuickStrip({required this.names, required this.onTap});

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
                '${names.length} egzersiz',
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
            itemCount: names.length,
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () => onTap(names[i]),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
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
                      const Icon(Icons.star_rounded,
                          size: 12, color: Colors.amber),
                      const SizedBox(width: 5),
                      Text(
                        names[i],
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
