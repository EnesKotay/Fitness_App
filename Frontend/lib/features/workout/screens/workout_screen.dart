import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/workout.dart';
import '../../../core/models/workout_models.dart';
import '../../../core/api/services/exercise_service.dart';
import '../providers/workout_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'exercise_guide_screen.dart';

/// Kas grubu → Türkçe ad, renk, ikon ve arka plan fotoğrafı
const Map<String, ({String label, Color color, IconData icon, String imageUrl})> kMuscleGroupInfo = {
  'CHEST':    (label: 'Göğüs',   color: Color(0xFFE53935), icon: Icons.fitness_center, imageUrl: 'https://images.unsplash.com/photo-1534368959876-26bf04f2c947?w=600&q=80'),
  'BACK':     (label: 'Sırt',    color: Color(0xFF7B1FA2), icon: Icons.back_hand,      imageUrl: 'https://images.unsplash.com/photo-1517964609433-4636190af475?w=600&q=80'),
  'LEGS':     (label: 'Bacak',  color: Color(0xFF1976D2), icon: Icons.directions_walk, imageUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600&q=80'),
  'SHOULDERS': (label: 'Omuz',  color: Color(0xFF00897B), icon: Icons.accessibility_new, imageUrl: 'https://images.unsplash.com/photo-1581009146145-2d25900a69f3?w=600&q=80'),
  'BICEPS':   (label: 'Biseps', color: Color(0xFF43A047), icon: Icons.sports_martial_arts, imageUrl: 'https://images.unsplash.com/photo-1583454110551-21f2fa2bef61?w=600&q=80'),
  'TRICEPS':  (label: 'Triceps', color: Color(0xFFFB8C00), icon: Icons.sports, imageUrl: 'https://images.unsplash.com/photo-1517836351103-9149a7310646?w=600&q=80'),
  'CORE':     (label: 'Karın',  color: Color(0xFF00ACC1), icon: Icons.self_improvement, imageUrl: 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=600&q=80'),
  'GLUTES':   (label: 'Kalça',  color: Color(0xFFE91E63), icon: Icons.directions_run, imageUrl: 'https://images.unsplash.com/photo-1549060279-7e168fcee0c2?w=600&q=80'),
};

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final ExerciseService _exerciseService = ExerciseService();
  String? _selectedMuscleGroup;
  List<String> _muscleGroups = [];
  List<Exercise> _exercises = [];
  bool _loadingGroups = true;
  bool _loadingExercises = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMuscleGroups();
      _loadWorkoutsIfNeeded();
    });
  }

  Future<void> _loadWorkoutsIfNeeded() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    if (userId != null) {
      await workoutProvider.loadWorkouts(userId);
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
        setState(() {
          _muscleGroups = groups;
          _loadingGroups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _muscleGroups = kMuscleGroupInfo.keys.toList();
          _loadingGroups = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _selectMuscleGroup(String group) async {
    setState(() {
      _selectedMuscleGroup = group;
      _exercises = [];
      _loadingExercises = true;
      _errorMessage = null;
    });
    try {
      final list = await _exerciseService.getExercisesByMuscleGroup(group);
      if (mounted) {
        setState(() {
          _exercises = list;
          _loadingExercises = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingExercises = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedMuscleGroup = null;
      _exercises = [];
      _errorMessage = null;
    });
  }

  void _openExerciseGuide(BuildContext context, Exercise exercise, Color accentColor, String? muscleGroupLabel) {
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
      body: SafeArea(
        child: _selectedMuscleGroup == null
            ? _buildRegionGrid(context)
            : _buildExerciseList(context),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildRegionGrid(BuildContext context) {
    final list = _muscleGroups.isEmpty ? kMuscleGroupInfo.keys.toList() : _muscleGroups;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Antrenman',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.98),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hangi bölgeyi çalışacaksın?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.6),
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
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final code = list[index];
                  final info = kMuscleGroupInfo[code] ?? (
                    label: code,
                    color: const Color(0xFF2E7D32),
                    icon: Icons.fitness_center,
                    imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
                  );
                  return _RegionCard(
                    label: info.label,
                    color: info.color,
                    icon: info.icon,
                    imageUrl: info.imageUrl,
                    onTap: () => _selectMuscleGroup(code),
                  );
                },
                childCount: list.length,
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
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildExerciseList(BuildContext context) {
    final code = _selectedMuscleGroup!;
    final info = kMuscleGroupInfo[code] ?? (
      label: code,
      color: const Color(0xFF2E7D32),
      icon: Icons.fitness_center,
      imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                onPressed: _clearSelection,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(info.icon, color: info.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  info.label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingExercises
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                )
              : _exercises.isEmpty
                  ? Center(
                      child: Text(
                        'Bu bölge için henüz egzersiz yok.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
                          .copyWith(bottom: 100),
                      itemCount: _exercises.length,
                      itemBuilder: (context, index) {
                        return _ExerciseCard(
                          exercise: _exercises[index],
                          accentColor: info.color,
                          onTap: () => _openExerciseGuide(context, _exercises[index], info.color, info.label),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFab(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userId = authProvider.user?.id;
        if (userId == null) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => _showAddWorkoutSheet(context, userId),
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

  void _showAddWorkoutSheet(BuildContext context, int userId) {
    final nameC = TextEditingController();
    final typeC = TextEditingController();
    final durationC = TextEditingController();
    final notesC = TextEditingController();
    DateTime pickedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Antrenman kaydet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameC,
                  decoration: _inputDeco('Antrenman adı'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeC,
                  decoration: _inputDeco('Tür (örn. Göğüs, Bacak)'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationC,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco('Süre (dk)'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Tarih: ${DateFormat('d MMM yyyy', 'tr_TR').format(pickedDate)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: Color(0xFF2E7D32)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      pickedDate = d;
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesC,
                  maxLines: 2,
                  decoration: _inputDeco('Not'),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final request = WorkoutRequest(
                      name: nameC.text.trim().isEmpty ? null : nameC.text.trim(),
                      workoutType: typeC.text.trim().isEmpty ? null : typeC.text.trim(),
                      durationMinutes: int.tryParse(durationC.text.trim()),
                      caloriesBurned: null,
                      workoutDate: pickedDate,
                      notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                    );
                    final p = Provider.of<WorkoutProvider>(context, listen: false);
                    final ok = await p.createWorkout(userId, request);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (ok) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Kaydedildi'),
                            backgroundColor: Color(0xFF2E7D32),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
      ),
    );
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
              // Arka plan: internetten çekilen fotoğraf
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: color.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
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
              // Üzerine koyu gradient (yazı okunaklı olsun)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              // İkon ve bölge adı
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
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
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fitness_center, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (exercise.description != null &&
                        exercise.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        exercise.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: accentColor.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
