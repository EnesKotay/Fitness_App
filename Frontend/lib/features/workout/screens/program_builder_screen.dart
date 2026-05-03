import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_program.dart';
import '../providers/workout_program_provider.dart';
import '../data/workout_catalog_data.dart';

class ProgramBuilderScreen extends StatefulWidget {
  final WorkoutProgram? program;

  const ProgramBuilderScreen({super.key, this.program});

  @override
  State<ProgramBuilderScreen> createState() => _ProgramBuilderScreenState();
}

class _ProgramBuilderScreenState extends State<ProgramBuilderScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<_DayEntry> _days = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.program;
    if (p != null) {
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description;
      _days.addAll(p.days.map(_DayEntry.fromDay));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final d in _days) {
      d.dispose();
    }
    super.dispose();
  }

  void _addDay() {
    setState(() => _days.add(_DayEntry.fresh(_days.length + 1)));
  }

  void _removeDay(int index) {
    setState(() {
      _days[index].dispose();
      _days.removeAt(index);
    });
  }

  Future<void> _addExercise(int dayIndex) async {
    final exercise = await showModalBottomSheet<ProgramExercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ExercisePickerSheet(),
    );
    if (exercise != null && mounted) {
      setState(() => _days[dayIndex].exercises.add(exercise));
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Program adı gerekli'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az bir antrenman günü ekle'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final program = WorkoutProgram(
      id: widget.program?.id,
      name: name,
      description: _descCtrl.text.trim(),
      days: _days.map((d) => d.toProgramDay()).toList(),
      createdAt: widget.program?.createdAt,
    );

    await context.read<WorkoutProgramProvider>().saveProgram(program);

    if (!mounted) return;
    Navigator.pop(context, program);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1014),
        elevation: 0,
        title: Text(
          widget.program == null ? 'Program Oluştur' : 'Programı Düzenle',
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _saving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildField(_nameCtrl, 'Program Adı *', 'Örn: Push-Pull-Legs'),
          const SizedBox(height: 12),
          _buildField(
            _descCtrl,
            'Açıklama (opsiyonel)',
            'Program hakkında kısa bir not...',
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Antrenman Günleri',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addDay,
                icon: const Icon(Icons.add, size: 18, color: Color(0xFF4CAF50)),
                label: const Text(
                  'Gün Ekle',
                  style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_days.isEmpty)
            _EmptyDaysPlaceholder(onAdd: _addDay)
          else
            for (int i = 0; i < _days.length; i++)
              _DayCard(
                key: ValueKey(_days[i].id),
                entry: _days[i],
                number: i + 1,
                onDelete: () => _removeDay(i),
                onAddExercise: () => _addExercise(i),
                onDeleteExercise: (ei) =>
                    setState(() => _days[i].exercises.removeAt(ei)),
                onChanged: () => setState(() {}),
              ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
        ),
      ),
    );
  }
}

// ── Internal state helper ────────────────────────────────────────────────────

class _DayEntry {
  final String id;
  final TextEditingController nameCtrl;
  final List<ProgramExercise> exercises;

  _DayEntry({required this.id, required String name, List<ProgramExercise>? exercises})
      : nameCtrl = TextEditingController(text: name),
        exercises = exercises != null ? List.from(exercises) : [];

  factory _DayEntry.fresh(int n) =>
      _DayEntry(id: const Uuid().v4(), name: 'Gün $n');

  factory _DayEntry.fromDay(ProgramDay day) =>
      _DayEntry(id: day.id, name: day.name, exercises: day.exercises);

  ProgramDay toProgramDay() => ProgramDay(
        id: id,
        name: nameCtrl.text.trim().isEmpty ? 'Gün' : nameCtrl.text.trim(),
        exercises: List.from(exercises),
      );

  void dispose() => nameCtrl.dispose();
}

// ── Empty placeholder ────────────────────────────────────────────────────────

class _EmptyDaysPlaceholder extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyDaysPlaceholder({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_today_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Henüz gün eklenmedi',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('İlk Günü Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day card ─────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final _DayEntry entry;
  final int number;
  final VoidCallback onDelete;
  final VoidCallback onAddExercise;
  final void Function(int) onDeleteExercise;
  final VoidCallback onChanged;

  const _DayCard({
    super.key,
    required this.entry,
    required this.number,
    required this.onDelete,
    required this.onAddExercise,
    required this.onDeleteExercise,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
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
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: entry.nameCtrl,
                    onChanged: (_) => onChanged(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Gün adı (örn: Göğüs Günü)',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 20),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (entry.exercises.isNotEmpty) ...[
            const Divider(height: 1, color: Colors.white10),
            for (int i = 0; i < entry.exercises.length; i++)
              _ExerciseRow(
                exercise: entry.exercises[i],
                onDelete: () => onDeleteExercise(i),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: TextButton.icon(
              onPressed: onAddExercise,
              icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF4CAF50)),
              label: const Text(
                'Egzersiz Ekle',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ProgramExercise exercise;
  final VoidCallback onDelete;

  const _ExerciseRow({required this.exercise, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = kMuscleGroupInfo[exercise.muscleGroup]?.color ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              exercise.name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${exercise.sets}×${exercise.reps}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: Colors.white30),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exercise picker bottom sheet ─────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String? _selectedGroup;
  ({String name, String group})? _selected;
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _sets = 3;
  int _reps = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<({String name, String group})> get _filtered {
    final result = <({String name, String group})>[];
    for (final entry in kMassExerciseNames.entries) {
      if (_selectedGroup == null || entry.key == _selectedGroup) {
        for (final name in entry.value) {
          result.add((name: name, group: entry.key));
        }
      }
    }
    if (_query.isEmpty) return result;
    final q = _query.toLowerCase();
    return result.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (_selected != null)
                  GestureDetector(
                    onTap: () => setState(() => _selected = null),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _selected == null ? 'Egzersiz Seç' : _selected!.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: _selected == null ? _buildPicker() : _buildSetsReps(),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    final items = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Egzersiz ara...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: Colors.white10,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              _groupChip(null, 'Tümü'),
              for (final e in kMuscleGroupInfo.entries)
                _groupChip(e.key, e.value.label),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'Egzersiz bulunamadı',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final ex = items[i];
                    final color = kMuscleGroupInfo[ex.group]?.color ?? Colors.grey;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 5, backgroundColor: color),
                      title: Text(
                        ex.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        kMuscleGroupInfo[ex.group]?.label ?? ex.group,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      onTap: () => setState(() => _selected = ex),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSetsReps() {
    final groupLabel = kMuscleGroupInfo[_selected!.group]?.label ?? _selected!.group;
    final groupColor = kMuscleGroupInfo[_selected!.group]?.color ?? Colors.green;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: groupColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              groupLabel,
              style: TextStyle(color: groupColor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 28),
          _CounterRow(
            label: 'Set Sayısı',
            value: _sets,
            min: 1,
            max: 20,
            onChanged: (v) => setState(() => _sets = v),
          ),
          const SizedBox(height: 20),
          _CounterRow(
            label: 'Tekrar Sayısı',
            value: _reps,
            min: 1,
            max: 100,
            onChanged: (v) => setState(() => _reps = v),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                ProgramExercise(
                  name: _selected!.name,
                  muscleGroup: _selected!.group,
                  sets: _sets,
                  reps: _reps,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Egzersizi Ekle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupChip(String? group, String label) {
    final selected = _selectedGroup == group;
    final color = group != null ? kMuscleGroupInfo[group]?.color : Colors.white;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedGroup = group;
        _query = '';
        _searchCtrl.clear();
      }),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? Colors.white).withValues(alpha: 0.18)
              : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (color ?? Colors.white).withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (color ?? Colors.white) : Colors.white54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Counter row widget ────────────────────────────────────────────────────────

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: Icon(
                  Icons.remove,
                  color: value > min ? Colors.white : Colors.white30,
                ),
                iconSize: 18,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: Icon(
                  Icons.add,
                  color: value < max ? Colors.white : Colors.white30,
                ),
                iconSize: 18,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
