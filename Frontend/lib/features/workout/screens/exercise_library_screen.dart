import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise_library_model.dart';
import '../providers/exercise_library_provider.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final String? initialSearch;

  const ExerciseLibraryScreen({super.key, this.initialSearch});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedEquipment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ExerciseLibraryProvider>();
      provider.loadMetadata();
      final search = widget.initialSearch?.trim();
      if (search != null && search.isNotEmpty) {
        _searchController.text = search;
        provider.searchExercises(search);
      } else {
        provider.loadExercises();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Egzersiz Kütüphanesi'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Egzersiz ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ExerciseLibraryProvider>().loadExercises();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  context.read<ExerciseLibraryProvider>().searchExercises(value);
                }
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildExerciseList()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Consumer<ExerciseLibraryProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Category filter
              PopupMenuButton<String>(
                child: Chip(
                  avatar: const Icon(Icons.fitness_center, size: 18),
                  label: Text(
                    _selectedCategory != null
                        ? ExerciseCategory.getDisplayName(_selectedCategory!)
                        : 'Kategori',
                  ),
                  deleteIcon: _selectedCategory != null
                      ? const Icon(Icons.close, size: 18)
                      : null,
                  onDeleted: _selectedCategory != null
                      ? () {
                          setState(() => _selectedCategory = null);
                          provider.clearFilter();
                        }
                      : null,
                ),
                itemBuilder: (context) => provider.categories
                    .map((cat) => PopupMenuItem(
                          value: cat,
                          child: Text(ExerciseCategory.getDisplayName(cat)),
                        ))
                    .toList(),
                onSelected: (value) {
                  setState(() => _selectedCategory = value);
                  provider.filterByCategory(value);
                },
              ),
              const SizedBox(width: 8),
              // Equipment filter
              PopupMenuButton<String>(
                child: Chip(
                  avatar: const Icon(Icons.build, size: 18),
                  label: Text(
                    _selectedEquipment != null
                        ? ExerciseEquipment.getDisplayName(_selectedEquipment!)
                        : 'Ekipman',
                  ),
                  deleteIcon: _selectedEquipment != null
                      ? const Icon(Icons.close, size: 18)
                      : null,
                  onDeleted: _selectedEquipment != null
                      ? () {
                          setState(() => _selectedEquipment = null);
                          provider.clearFilter();
                        }
                      : null,
                ),
                itemBuilder: (context) => provider.equipmentTypes
                    .map((eq) => PopupMenuItem(
                          value: eq,
                          child: Text(ExerciseEquipment.getDisplayName(eq)),
                        ))
                    .toList(),
                onSelected: (value) {
                  setState(() => _selectedEquipment = value);
                  provider.filterByEquipment(value);
                },
              ),
              const SizedBox(width: 8),
              // Bodyweight quick filter
              FilterChip(
                label: const Text('Ekipmansız'),
                selected: _selectedEquipment == ExerciseEquipment.bodyWeight,
                onSelected: (selected) {
                  if (selected) {
                    setState(() =>
                        _selectedEquipment = ExerciseEquipment.bodyWeight);
                    provider.loadBodyweightExercises();
                  } else {
                    setState(() => _selectedEquipment = null);
                    provider.clearFilter();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExerciseList() {
    return Consumer<ExerciseLibraryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(provider.error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadExercises(),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          );
        }

        if (provider.exercises.isEmpty) {
          return const Center(
            child: Text('Egzersiz bulunamadı'),
          );
        }

        return ListView.builder(
          itemCount: provider.exercises.length,
          itemBuilder: (context, index) {
            final exercise = provider.exercises[index];
            return _buildExerciseCard(exercise);
          },
        );
      },
    );
  }

  Widget _buildExerciseCard(ExerciseLibrary exercise) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showExerciseDetail(exercise),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _getEquipmentIcon(exercise.equipment),
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(
                      ExerciseCategory.getDisplayName(exercise.category),
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (exercise.target != null)
                    Chip(
                      label: Text(
                        exercise.target!,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getEquipmentIcon(String equipment) {
    return switch (equipment) {
      'body weight' => Icons.accessibility_new,
      'dumbbell' => Icons.fitness_center,
      'barbell' => Icons.fitness_center,
      'cable' => Icons.line_weight,
      _ => Icons.sports_gymnastics,
    };
  }

  void _showExerciseDetail(ExerciseLibrary exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ExerciseLibraryDetailSheet(
          exercise: exercise,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class ExerciseLibraryDetailSheet extends StatelessWidget {
  final ExerciseLibrary exercise;
  final ScrollController? scrollController;

  const ExerciseLibraryDetailSheet({
    super.key,
    required this.exercise,
    this.scrollController,
  });

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Kategori',
            ExerciseCategory.getDisplayName(exercise.category),
          ),
          _buildInfoRow(
            'Ekipman',
            ExerciseEquipment.getDisplayName(exercise.equipment),
          ),
          if (exercise.target != null) _buildInfoRow('Hedef Kas', exercise.target!),
          if (exercise.muscleGroup != null)
            _buildInfoRow('Kas Grubu', exercise.muscleGroup!),
          const SizedBox(height: 24),
          const Text(
            'Nasıl Yapılır',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (exercise.instructionSteps.isNotEmpty)
            ...exercise.instructionSteps.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 14, child: Text('${entry.key + 1}')),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              );
            })
          else if (exercise.instructions != null)
            Text(exercise.instructions!)
          else
            const Text('Talimat bulunamadı'),
        ],
      ),
    );
  }
}
