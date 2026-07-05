part of '../workout_screen.dart';

// ── Explore Tab ───────────────────────────────────────────────────────────────
//
// "Keşfet" sekmesidir. Kas grubu seçimi, egzersiz listesi ve tüm filtreleme
// mantığı burada kapsüllenir. Navigasyon ve seans başlatma işlemleri callback
// olarak parent'tan alınır.

class _ExploreTab extends StatefulWidget {
  /// Egzersiz kütüphane detay sayfası
  final void Function(
    BuildContext context,
    Exercise exercise,
    Color accentColor,
    String? muscleGroupLabel,
  )
  onOpenExerciseGuide;

  /// Hızlı başlat preset seansı
  final void Function(_QuickStartPreset preset) onOpenQuickStart;

  /// Şablon seansı
  final void Function(_TemplateData template) onOpenTemplateWorkout;

  /// Şablon kaydetme
  final void Function(_TemplateData template) onSaveTemplate;

  /// Bugün önerilen seansı başlat
  final void Function(BuildContext ctx, WorkoutProvider provider)
  onStartSuggestedSession;

  /// Program günü seansı başlat
  final void Function(WorkoutProgram program, ProgramDay day) onStartProgramDay;

  /// Program builder sayfası
  final VoidCallback onOpenProgramBuilder;

  /// Program detay sheet
  final void Function(WorkoutProgram program) onShowProgramDetail;

  /// Premium flag
  final bool isPremium;

  const _ExploreTab({
    required this.onOpenExerciseGuide,
    required this.onOpenQuickStart,
    required this.onOpenTemplateWorkout,
    required this.onSaveTemplate,
    required this.onStartSuggestedSession,
    required this.onStartProgramDay,
    required this.onOpenProgramBuilder,
    required this.onShowProgramDetail,
    required this.isPremium,
  });

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _regionSearchController = TextEditingController();
  final TextEditingController _exerciseSearchController =
      TextEditingController();

  // ── Kas grubu ve egzersiz listesi ────────────────────────────────────────
  String? _selectedMuscleGroup;
  List<String> _muscleGroups = [];
  List<Exercise> _exercises = [];
  String _selectedSubRegion = 'Tümü';
  String _regionSearchQuery = '';
  String _exerciseSearchQuery = '';
  String _libraryQuickFilter = 'Tümü';
  bool _loadingGroups = true;
  bool _loadingExercises = false;
  String? _errorMessage;
  bool _sortAZ = false;

  // ── Favoriler ─────────────────────────────────────────────────────────────
  List<FavoriteExerciseEntry> _favoriteExercises = const [];
  late final List<({Exercise exercise, String group, String haystack})>
  _exerciseSearchIndex;

  final ExerciseService _exerciseService = ExerciseService();

  // ── AppBar görünürlüğü ────────────────────────────────────────────────────
  // parent _WorkoutScreenState._exerciseListOpen notifier'ı direkt güncellenir
  // (part of aynı kütüphane olduğu için private erişim mümkün).
  void _setExerciseListOpen(bool value) {
    // Egzersiz listesi açılınca parent AppBar'ı gizler.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
              .findAncestorStateOfType<_WorkoutScreenState>()
              ?._exerciseListOpen
              .value =
          value;
    });
  }

  @override
  void initState() {
    super.initState();
    _favoriteExercises = StorageHelper.getFavoriteExercises();
    _exerciseSearchIndex = _buildExerciseSearchIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMuscleGroups());
  }

  @override
  void dispose() {
    _regionSearchController.dispose();
    _exerciseSearchController.dispose();
    super.dispose();
  }

  // ── Service helpers ───────────────────────────────────────────────────────

  String _normalizeMuscleGroupCode(String raw) =>
      ExerciseParserService.normalizeMuscleGroupCode(raw);

  String _normalizeSearchText(String input) =>
      ExerciseParserService.normalizeSearchText(input);

  String _detectSubRegionLabel(Exercise exercise, String muscleGroup) =>
      ExerciseParserService.detectSubRegionLabel(exercise, muscleGroup);

  List<Exercise> _exerciseCatalogForGroup(String group) =>
      buildExerciseCatalogForGroup(group);

  // ── Veri yükleme ─────────────────────────────────────────────────────────

  Future<void> _loadMuscleGroups() async {
    setState(() {
      _loadingGroups = true;
      _errorMessage = null;
    });
    try {
      final groups = await _exerciseService.getMuscleGroups();
      if (mounted) {
        final normalized = groups
            .map(_normalizeMuscleGroupCode)
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList();
        setState(() {
          _muscleGroups = normalized.isEmpty
              ? kMuscleGroupInfo.keys.toList()
              : normalized;
          _loadingGroups = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _muscleGroups = kMuscleGroupInfo.keys.toList();
          _loadingGroups = false;
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
    _setExerciseListOpen(true);
    try {
      final list = await _exerciseService.getExercisesByMuscleGroup(
        normalizedGroup,
      );
      if (mounted) {
        final resolved = _mergeWithFallback(list, normalizedGroup);
        final hasLocal = _exerciseCatalogForGroup(normalizedGroup).isNotEmpty;
        setState(() {
          _exercises = resolved;
          _loadingExercises = false;
          _errorMessage = list.isEmpty && !hasLocal
              ? 'Bu bölge için katalog henüz tanımlı değil.'
              : null;
        });
      }
    } catch (_) {
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

  void _clearSelection() {
    setState(() {
      _selectedMuscleGroup = null;
      _selectedSubRegion = 'Tümü';
      _exerciseSearchQuery = '';
      _exerciseSearchController.clear();
      _exercises = [];
      _errorMessage = null;
    });
    _setExerciseListOpen(false);
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

  // ── Filtre yardımcıları ───────────────────────────────────────────────────

  List<String> _filteredMuscleGroups() {
    final normalizedQuery = _normalizeSearchText(_regionSearchQuery);
    final source = _muscleGroups.isEmpty
        ? kMuscleGroupInfo.keys.toList()
        : _muscleGroups;
    final quickFiltered = source.where((code) {
      final normalizedCode = _normalizeMuscleGroupCode(code);
      return switch (_libraryQuickFilter) {
        'Üst Vücut' => const {
          'CHEST',
          'BACK',
          'SHOULDERS',
          'BICEPS',
          'TRICEPS',
          'FOREARMS',
        }.contains(normalizedCode),
        'Alt Vücut' => const {'LEGS', 'GLUTES'}.contains(normalizedCode),
        'Core' => const {'CORE', 'CARDIO'}.contains(normalizedCode),
        'Favoriler' => _favoriteExercises.any(
          (fav) =>
              fav.muscleGroup != null &&
              _normalizeMuscleGroupCode(fav.muscleGroup!) == normalizedCode,
        ),
        _ => true,
      };
    }).toList();
    if (normalizedQuery.isEmpty) return quickFiltered;
    return quickFiltered.where((code) {
      final info = kMuscleGroupInfo[code];
      final haystack = _normalizeSearchText('$code ${info?.label ?? ''}');
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  int _exerciseCountForGroup(String code) =>
      _exerciseCatalogForGroup(_normalizeMuscleGroupCode(code)).length;

  int _exerciseCountForGroups(List<String> groups) => groups.fold<int>(
    0,
    (total, group) => total + _exerciseCountForGroup(group),
  );

  void _openFullExerciseLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(
          initialSearch: _regionSearchQuery.trim().isEmpty
              ? null
              : _regionSearchQuery.trim(),
        ),
      ),
    );
  }

  List<Exercise> _filteredExercisesForSelectedRegion() {
    final group = _selectedMuscleGroup;
    if (group == null) return _exercises;
    final normalizedQuery = _normalizeSearchText(_exerciseSearchQuery);
    return _exercises.where((exercise) {
      final detected = _detectSubRegionLabel(exercise, group);
      final matchesSub =
          _selectedSubRegion == 'Tümü' || detected == _selectedSubRegion;
      if (!matchesSub) return false;
      if (normalizedQuery.isEmpty) return true;
      final haystack = _normalizeSearchText(
        '${exercise.name} ${exercise.description ?? ''} ${exercise.instructions ?? ''} $detected',
      );
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

  List<({Exercise exercise, String group, String haystack})>
  _buildExerciseSearchIndex() {
    final results = <({Exercise exercise, String group, String haystack})>[];
    final seen = <String>{};
    for (final group in kMuscleGroupInfo.keys) {
      for (final exercise in _exerciseCatalogForGroup(group)) {
        final key = '${group}_${exercise.name.toLowerCase()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        final subRegion = _detectSubRegionLabel(exercise, group);
        final haystack = _normalizeSearchText(
          '${exercise.name} ${exercise.description ?? ''} ${exercise.instructions ?? ''} $group ${kMuscleGroupInfo[group]?.label ?? ''} $subRegion',
        );
        results.add((exercise: exercise, group: group, haystack: haystack));
      }
    }
    return results;
  }

  List<({Exercise exercise, String group})> _globalExerciseMatches() {
    final normalizedQuery = _normalizeSearchText(_regionSearchQuery);
    if (normalizedQuery.isEmpty) return const [];

    final results = <({Exercise exercise, String group})>[];
    for (final item in _exerciseSearchIndex) {
      if (item.haystack.contains(normalizedQuery)) {
        results.add((exercise: item.exercise, group: item.group));
      }
      if (results.length >= 8) return results;
    }
    return results;
  }

  // ── Favori işlemleri ─────────────────────────────────────────────────────

  bool _isFavoriteExercise(Exercise exercise) {
    return _favoriteExercises.any(
      (fav) =>
          fav.matches(exercise.name, otherMuscleGroup: exercise.muscleGroup),
    );
  }

  Future<void> _toggleFavoriteExercise(Exercise exercise) async {
    await StorageHelper.toggleFavoriteExercise(
      exercise.name,
      muscleGroup: _normalizeMuscleGroupCode(exercise.muscleGroup),
      exerciseId: exercise.id,
    );
    if (mounted) {
      setState(() {
        _favoriteExercises = StorageHelper.getFavoriteExercises();
      });
    }
  }

  Exercise? _findExerciseForFavorite(FavoriteExerciseEntry favorite) {
    Exercise? partial;
    final preferred = _normalizeMuscleGroupCode(favorite.muscleGroup ?? '');
    final preferredGroup = preferred.isEmpty ? null : preferred;
    final groups = <String>[
      ...[preferredGroup].whereType<String>(),
      ...kMuscleGroupInfo.keys.where((g) => g != preferredGroup),
    ];
    for (final group in groups) {
      final catalog = _exerciseCatalogForGroup(group);
      for (final exercise in catalog) {
        if (exercise.name.toLowerCase() == favorite.name.toLowerCase()) {
          return exercise;
        }
        if (partial == null) {
          final eName = exercise.name.toLowerCase();
          final fName = favorite.name.toLowerCase();
          if (eName.contains(fName) || fName.contains(eName)) {
            partial = exercise;
          }
        }
      }
    }
    return partial;
  }

  // ── Muscle group picker (bottom sheet) ───────────────────────────────────

  void _showMuscleGroupPicker() {
    final groups = _muscleGroups.isEmpty
        ? kMuscleGroupInfo.keys.toList()
        : _muscleGroups;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(sheetCtx).padding.bottom,
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
                    Navigator.of(sheetCtx).pop();
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
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return _selectedMuscleGroup == null
        ? _buildRegionGrid()
        : _buildExerciseList();
  }

  // ── Bölge grid görünümü ───────────────────────────────────────────────────

  Widget _buildRegionGrid() {
    final list = _filteredMuscleGroups();
    final globalMatches = _globalExerciseMatches();
    final totalExercises = _exerciseCountForGroups(list);
    final provider = context.watch<WorkoutProvider>();

    return CustomScrollView(
      slivers: [
        // 1. Dinamik Hero (Günün Odak Noktası)
        SliverToBoxAdapter(
          child: Consumer<WorkoutProgramProvider>(
            builder: (context, programProvider, _) => _DynamicHeroSection(
              workouts: provider.workouts,
              suggestion: provider.workoutSuggestion,
              programs: programProvider.programs,
              activeProgram: programProvider.activeProgram,
              completedDayIds: programProvider.completedDayIds,
              onStartSuggested: () =>
                  widget.onStartSuggestedSession(context, provider),
              onStartProgramDay: (program, day) =>
                  widget.onStartProgramDay(program, day),
              onExplore: _showMuscleGroupPicker,
            ),
          ),
        ),
        // 2. Hızlı Aksiyonlar (Yatay Scroll)
        SliverToBoxAdapter(
          child: Consumer<WorkoutProgramProvider>(
            builder: (context, programProvider, _) => _QuickActionsRow(
              isPremium: widget.isPremium,
              programs: programProvider.programs,
              favorites: _favoriteExercises,
              onStartTemplate: widget.onOpenTemplateWorkout,
              onSaveTemplate: widget.onSaveTemplate,
              onCreateProgramTap: widget.onOpenProgramBuilder,
              onProgramTap: widget.onShowProgramDetail,
              onFavoriteTap: (favorite) {
                final exercise = _findExerciseForFavorite(favorite);
                if (exercise != null) {
                  final code = _normalizeMuscleGroupCode(exercise.muscleGroup);
                  final info = kMuscleGroupInfo[code];
                  widget.onOpenExerciseGuide(
                    context,
                    exercise,
                    info?.color ?? const Color(0xFF2E7D32),
                    info?.label,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${favorite.name} için rehber bulunamadı.'),
                      backgroundColor: const Color(0xFF2C2C2C),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              onUpgradePressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
            ),
          ),
        ),
        // 3. Egzersiz Kütüphanesi
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          toolbarHeight:
              _regionSearchQuery.trim().isNotEmpty && globalMatches.isNotEmpty
              ? 148
              : 96,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A).withValues(alpha: 0.8),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: Color(0xFF66BB6A),
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Egzersiz Kütüphanesi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _regionSearchController,
                        onChanged: (value) =>
                            setState(() => _regionSearchQuery = value),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          hintText: 'Bölge veya hareket ara...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          suffixIcon: _regionSearchQuery.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _regionSearchController.clear();
                                    setState(() => _regionSearchQuery = '');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF2E7D32),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_regionSearchQuery.trim().isNotEmpty &&
                        globalMatches.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildGlobalExerciseMatches(globalMatches),
                    ],
                  ],
                ),
              ),
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
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _buildLibraryControlPanel(
                  visibleGroupCount: list.length,
                  visibleExerciseCount: totalExercises,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.9,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final code = list[index];
                    final info =
                        kMuscleGroupInfo[code] ??
                        (
                          label: code,
                          color: const Color(0xFF2E7D32),
                          icon: Icons.fitness_center,
                          imageUrl:
                              'assets/images/ust_göğüs_kasi_hareketleri.jpg',
                        );
                    return _RegionCard(
                      label: info.label,
                      color: info.color,
                      icon: info.icon,
                      imageUrl: info.imageUrl,
                      exerciseCount: _exerciseCountForGroup(code),
                      onTap: () => _selectMuscleGroup(code),
                    );
                  }, childCount: list.length),
                ),
              ),
            ],
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Consumer<WorkoutProgramProvider>(
              builder: (context, programProvider, _) => _PresetProgramsSection(
                onAddProgram: (program) {
                  programProvider.saveProgram(program);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"${program.name}" programına eklendi!',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: const Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
              ),
            ),
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
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final bottomInset = MediaQuery.paddingOf(context).bottom;
              return SizedBox(height: bottomInset + 156);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalExerciseMatches(
    List<({Exercise exercise, String group})> matches,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hareket sonuçları',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = matches[index];
              final info = kMuscleGroupInfo[item.group];
              final color = info?.color ?? const Color(0xFF2E7D32);
              return InkWell(
                onTap: () => widget.onOpenExerciseGuide(
                  context,
                  item.exercise,
                  color,
                  info?.label,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 176,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        info?.icon ?? Icons.fitness_center_rounded,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.exercise.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              info?.label ?? item.group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryControlPanel({
    required int visibleGroupCount,
    required int visibleExerciseCount,
  }) {
    const filters = ['Tümü', 'Üst Vücut', 'Alt Vücut', 'Core', 'Favoriler'];
    final hasFavorites = _favoriteExercises.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _LibraryMetricPill(
                          icon: Icons.grid_view_rounded,
                          value: '$visibleGroupCount',
                          label: 'bölge',
                          color: const Color(0xFF66BB6A),
                        ),
                        _LibraryMetricPill(
                          icon: Icons.fitness_center_rounded,
                          value: '$visibleExerciseCount',
                          label: 'hareket',
                          color: const Color(0xFF5AC8FA),
                        ),
                        _LibraryMetricPill(
                          icon: Icons.star_rounded,
                          value: '${_favoriteExercises.length}',
                          label: 'favori',
                          color: const Color(0xFFEBC374),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _LibraryIconButton(
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Tüm hareketleri aç',
                    onTap: _openFullExerciseLibrary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: filters.map((filter) {
                    final disabled = filter == 'Favoriler' && !hasFavorites;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _LibraryFilterChip(
                        label: filter,
                        selected: _libraryQuickFilter == filter,
                        disabled: disabled,
                        onTap: disabled
                            ? null
                            : () {
                                setState(() => _libraryQuickFilter = filter);
                              },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Egzersiz listesi görünümü ─────────────────────────────────────────────

  Widget _buildExerciseList() {
    final code = _selectedMuscleGroup!;
    final filtered = _filteredExercisesForSelectedRegion();
    final counts = _subRegionCounts(code);
    final info =
        kMuscleGroupInfo[code] ??
        (
          label: code,
          color: const Color(0xFF2E7D32),
          icon: Icons.fitness_center,
          imageUrl: 'assets/images/ust_göğüs_kasi_hareketleri.jpg',
        );

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
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
              ],
            ),
          ),
        ),
      ],
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
                    // ── Filtre paneli ──────────────────────────────────
                    if (index == 0) {
                      final options = kSubRegionFilters[code] ?? const ['Tümü'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: TextField(
                                  controller: _exerciseSearchController,
                                  onChanged: (value) => setState(
                                    () => _exerciseSearchQuery = value,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Hareket ara...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: 15,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: info.color.withValues(alpha: 0.8),
                                    ),
                                    suffixIcon:
                                        _exerciseSearchQuery.trim().isEmpty
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
                                    fillColor: Colors.white.withValues(
                                      alpha: 0.05,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: info.color.withValues(
                                          alpha: 0.6,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
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
                                          : (_) => setState(
                                              () => _selectedSubRegion = option,
                                            ),
                                      showCheckmark: false,
                                      avatar: selected
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      selectedColor: info.color.withValues(
                                        alpha: 0.9,
                                      ),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
                                      side: BorderSide(
                                        color: selected
                                            ? info.color
                                            : Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                        width: selected ? 1.5 : 1.0,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),
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
                                          ? info.color.withValues(alpha: 0.2)
                                          : Colors.white.withValues(
                                              alpha: 0.04,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _sortAZ
                                            ? info.color.withValues(alpha: 0.6)
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

                    // ── Boş durum ──────────────────────────────────────
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

                    // ── Bölüm başlığı veya egzersiz kartı ────────────
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
                      onTap: () => widget.onOpenExerciseGuide(
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
}
