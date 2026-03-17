import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../controllers/daily_tasks_controller.dart';
import '../models/daily_task.dart';

import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

IconData _categoryIcon(TaskCategory cat) {
  switch (cat) {
    case TaskCategory.sport:
      return Icons.fitness_center_rounded;
    case TaskCategory.nutrition:
      return Icons.restaurant_rounded;
    case TaskCategory.water:
      return Icons.water_drop_rounded;
    case TaskCategory.other:
      return Icons.task_alt_rounded;
  }
}

Color _categoryColor(TaskCategory cat) {
  switch (cat) {
    case TaskCategory.sport:
      return const Color(0xFF7BCBFF);
    case TaskCategory.nutrition:
      return const Color(0xFF5FD8B7);
    case TaskCategory.water:
      return const Color(0xFF74C0FC);
    case TaskCategory.other:
      return const Color(0xFFEBC374);
  }
}

String _categoryLabel(TaskCategory cat) {
  switch (cat) {
    case TaskCategory.sport:
      return 'Spor';
    case TaskCategory.nutrition:
      return 'Beslenme';
    case TaskCategory.water:
      return 'Su';
    case TaskCategory.other:
      return 'Diğer';
  }
}

Color _priorityColor(TaskPriority p) {
  switch (p) {
    case TaskPriority.high:
      return const Color(0xFFFF6B6B);
    case TaskPriority.medium:
      return const Color(0xFFEBC374);
    case TaskPriority.low:
      return Colors.white30;
  }
}

String _priorityLabel(TaskPriority p) {
  switch (p) {
    case TaskPriority.high:
      return 'Yüksek';
    case TaskPriority.medium:
      return 'Orta';
    case TaskPriority.low:
      return 'Düşük';
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<DailyTasksController>(
      builder: (context, controller, _) {
        final tasks = controller.filteredTasks;
        return Scaffold(
          backgroundColor: const Color(0xFF070B16),
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTaskDialog(context, controller),
            backgroundColor: const Color(0xFFEBC374),
            child: const Icon(Icons.add, color: Color(0xFF070B16)),
          ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),
          body: Stack(
            children: [
              const _AnimatedMeshBackground(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _ProgressCard(
                        completed: controller.completedCount,
                        total: controller.totalCount,
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 16),
                      _buildHeader(controller),
                      const SizedBox(height: 12),
                      if (controller.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEBC374)),
                            minHeight: 2,
                          ),
                        ),
                      Expanded(
                        child: tasks.isEmpty
                            ? _EmptyState(filter: controller.filter)
                                .animate()
                                .fadeIn(delay: 300.ms)
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 120),
                                itemCount: tasks.length,
                                separatorBuilder: (_, i) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  return Dismissible(
                                    key: Key(task.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    ),
                                    onDismissed: (_) => controller.deleteTask(task.id),
                                    child: _TaskTile(
                                      task: task,
                                      onToggle: () => controller.toggleTaskDone(task.id),
                                    ),
                                  ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.08, end: 0);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(color: Colors.black.withValues(alpha: 0.2)),
        ),
      ),
      title: Text(
        'GÜNLÜK GÖREVLER',
        style: GoogleFonts.cinzel(
          color: const Color(0xFFEBC374),
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.repeat_rounded, color: Color(0xFFEBC374), size: 22),
          tooltip: 'Tekrarlayan Görevler',
          onPressed: () {
            final ctrl = context.read<DailyTasksController>();
            _showRecurringSheet(context, ctrl);
          },
        ),
      ],
    );
  }

  Widget _buildHeader(DailyTasksController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Görevlerin',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        _buildFilterToggle(controller),
      ],
    );
  }

  Widget _buildFilterToggle(DailyTasksController controller) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterButton(
            label: 'Hepsi',
            selected: controller.filter == DailyTasksFilter.all,
            onTap: () => controller.setFilter(DailyTasksFilter.all),
          ),
          _FilterButton(
            label: 'Kalan',
            selected: controller.filter == DailyTasksFilter.todo,
            onTap: () => controller.setFilter(DailyTasksFilter.todo),
          ),
          _FilterButton(
            label: 'Bitti',
            selected: controller.filter == DailyTasksFilter.done,
            onTap: () => controller.setFilter(DailyTasksFilter.done),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, DailyTasksController controller) {
    final addController = TextEditingController();
    TaskPriority selectedPriority = TaskPriority.medium;
    TaskCategory selectedCategory = TaskCategory.other;
    bool makeRecurring = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setStateDialog) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F1528),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            title: Text(
              'Yeni Görev',
              style: GoogleFonts.dmSans(color: const Color(0xFFEBC374), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Başlık girişi
                  TextField(
                    controller: addController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ne yapacaksın?',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFEBC374)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Kategori seçici
                  Text(
                    'Kategori',
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TaskCategory.values.map((cat) {
                      final selected = selectedCategory == cat;
                      final color = _categoryColor(cat);
                      return GestureDetector(
                        onTap: () => setStateDialog(() => selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: 180.ms,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? color : Colors.white24,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_categoryIcon(cat), size: 14, color: selected ? color : Colors.white38),
                              const SizedBox(width: 5),
                              Text(
                                _categoryLabel(cat),
                                style: GoogleFonts.dmSans(
                                  color: selected ? color : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // ── Öncelik seçici
                  Text(
                    'Öncelik',
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: TaskPriority.values.map((p) {
                      final selected = selectedPriority == p;
                      final color = _priorityColor(p);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setStateDialog(() => selectedPriority = p),
                          child: AnimatedContainer(
                            duration: 180.ms,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? color : Colors.white.withValues(alpha: 0.1),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _priorityLabel(p),
                                  style: GoogleFonts.dmSans(
                                    color: selected ? color : Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── Tekrarlayan toggle
                  GestureDetector(
                    onTap: () => setStateDialog(() => makeRecurring = !makeRecurring),
                    child: AnimatedContainer(
                      duration: 180.ms,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: makeRecurring
                            ? const Color(0xFFEBC374).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: makeRecurring ? const Color(0xFFEBC374) : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 16,
                            color: makeRecurring ? const Color(0xFFEBC374) : Colors.white38,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Her gün tekrarla',
                              style: GoogleFonts.dmSans(
                                color: makeRecurring ? const Color(0xFFEBC374) : Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch(
                            value: makeRecurring,
                            onChanged: (v) => setStateDialog(() => makeRecurring = v),
                            activeThumbColor: const Color(0xFFEBC374),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEBC374),
                  foregroundColor: const Color(0xFF070B16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final text = addController.text.trim();
                  if (text.isNotEmpty) {
                    controller.addTask(
                      text,
                      priority: selectedPriority,
                      category: selectedCategory,
                      makeRecurring: makeRecurring,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecurringSheet(BuildContext context, DailyTasksController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _RecurringSheet(controller: controller),
    );
  }
}

// ─── Recurring Sheet ──────────────────────────────────────────────────────────

class _RecurringSheet extends StatelessWidget {
  const _RecurringSheet({required this.controller});
  final DailyTasksController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) {
        final templates = controller.recurringTemplates;
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (_, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: const Color(0xFF0F1528).withValues(alpha: 0.97),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.repeat_rounded, color: Color(0xFFEBC374), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tekrarlayan Görevler',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Bu görevler her gün otomatik eklenir.',
                        style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: templates.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.repeat_rounded, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Henüz tekrarlayan görev yok.\nGörev eklerken "Her gün tekrarla"yı aç.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: templates.length,
                              separatorBuilder: (_, i) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final t = templates[i];
                                final color = _categoryColor(t.category);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: color.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(_categoryIcon(t.category), size: 16, color: color),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.title,
                                              style: GoogleFonts.dmSans(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _priorityColor(t.priority),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${_categoryLabel(t.category)} · ${_priorityLabel(t.priority)}',
                                                  style: GoogleFonts.dmSans(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () => controller.removeRecurringTemplate(t.id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Filter Button ────────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEBC374) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: selected ? const Color(0xFF070B16) : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─── Progress Card ────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEBC374).withValues(alpha: 0.15),
            const Color(0xFFBC74EB).withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugünkü İlerlemen',
                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'Bugün henüz görev yok'
                        : '$completed/$total görev tamamlandı',
                    style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEBC374).withValues(alpha: 0.1),
                ),
                child: Text(
                  '${(ratio * 100).toInt()}%',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFEBC374),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEBC374)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Task Tile ────────────────────────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onToggle});

  final DailyTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(task.category);
    final prioColor = _priorityColor(task.priority);

    return AnimatedContainer(
      duration: 300.ms,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: task.isDone ? Colors.white.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: task.isDone
              ? Colors.white.withValues(alpha: 0.05)
              : catColor.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Priority dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isDone ? Colors.white12 : prioColor,
              ),
            ),
            const SizedBox(width: 10),
            // Category icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: task.isDone
                    ? Colors.white.withValues(alpha: 0.03)
                    : catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _categoryIcon(task.category),
                size: 16,
                color: task.isDone ? Colors.white24 : catColor,
              ),
            ),
          ],
        ),
        title: Text(
          task.title,
          style: GoogleFonts.dmSans(
            color: task.isDone ? Colors.white38 : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: task.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              _categoryLabel(task.category),
              style: GoogleFonts.dmSans(
                color: task.isDone ? Colors.white24 : catColor.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (task.isRecurring) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.repeat_rounded,
                size: 11,
                color: task.isDone ? Colors.white24 : Colors.white38,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSourceBadge(),
            const SizedBox(width: 6),
            Transform.scale(
              scale: 1.1,
              child: Checkbox(
                value: task.isDone,
                activeColor: const Color(0xFFEBC374),
                checkColor: const Color(0xFF070B16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (_) => onToggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge() {
    final isAi = task.source == 'ai_coach';
    final isRecurring = task.source == 'recurring';
    final Color color;
    final IconData icon;
    final String label;

    if (isAi) {
      color = const Color(0xFFEBC374);
      icon = Icons.auto_awesome;
      label = 'AI';
    } else if (isRecurring) {
      color = const Color(0xFF7BCBFF);
      icon = Icons.repeat_rounded;
      label = 'GÜN';
    } else {
      color = Colors.white38;
      icon = Icons.person_outline;
      label = 'SEN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background ───────────────────────────────────────────────────────────────

class _AnimatedMeshBackground extends StatelessWidget {
  const _AnimatedMeshBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildOrb(const Color(0xFF1A1F35), 400, alignment: Alignment.topLeft, offset: const Offset(-100, -100)),
        _buildOrb(const Color(0xFF1F1235), 350, alignment: Alignment.bottomRight, offset: const Offset(50, 50)),
        _buildOrb(const Color(0xFF352A1A), 300, alignment: Alignment.centerLeft, offset: const Offset(-50, 100)),
      ],
    );
  }

  Widget _buildOrb(Color color, double size, {required Alignment alignment, required Offset offset}) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, Colors.transparent]),
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .move(begin: const Offset(0, 0), end: const Offset(30, 30), duration: 5.seconds, curve: Curves.easeInOut)
        .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 5.seconds);
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final DailyTasksFilter filter;

  @override
  Widget build(BuildContext context) {
    final text = switch (filter) {
      DailyTasksFilter.all =>
        'Bugün için henüz görev yok.\nAI Koç\'tan tavsiye alabilir veya manuel ekleyebilirsin.',
      DailyTasksFilter.todo => 'Harika! Yapılacak tüm görevleri bitirdin.',
      DailyTasksFilter.done => 'Henüz tamamlanan bir görev yok.',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
