import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../controllers/daily_tasks_controller.dart';
import '../models/daily_task.dart';

class DailyTasksScreen extends StatelessWidget {
  const DailyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DailyTasksController>(
      builder: (context, controller, _) {
        final tasks = controller.filteredTasks;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Gunluk Gorevler',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProgressCard(
                    completed: controller.completedCount,
                    total: controller.totalCount,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Tumu',
                        selected: controller.filter == DailyTasksFilter.all,
                        onTap: () => controller.setFilter(DailyTasksFilter.all),
                      ),
                      _FilterChip(
                        label: 'Yapilacak',
                        selected: controller.filter == DailyTasksFilter.todo,
                        onTap: () =>
                            controller.setFilter(DailyTasksFilter.todo),
                      ),
                      _FilterChip(
                        label: 'Tamamlanan',
                        selected: controller.filter == DailyTasksFilter.done,
                        onTap: () =>
                            controller.setFilter(DailyTasksFilter.done),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (controller.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(minHeight: 4),
                    ),
                  Expanded(
                    child: tasks.isEmpty
                        ? _EmptyState(filter: controller.filter)
                        : ListView.separated(
                            itemCount: tasks.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return _TaskTile(
                                task: task,
                                onToggle: () =>
                                    controller.toggleTaskDone(task.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF101926),
        border: Border.all(color: const Color(0xFF2B3E5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$completed/$total tamamlandi',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            borderRadius: const BorderRadius.all(Radius.circular(99)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onToggle});

  final DailyTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0F1624),
        border: Border.all(color: const Color(0xFF2C3F5E)),
      ),
      child: ListTile(
        leading: Checkbox(value: task.isDone, onChanged: (_) => onToggle()),
        title: Text(
          task.title,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            decoration: task.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          task.createdAt.toLocal().toIso8601String().substring(11, 16),
          style: GoogleFonts.dmSans(
            color: const Color(0xFF98ACC9),
            fontSize: 12,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF162744),
            border: Border.all(color: const Color(0xFF3B5D95)),
          ),
          child: Text(
            _sourceLabel(task.source),
            style: GoogleFonts.dmSans(
              color: const Color(0xFFCBE0FF),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  String _sourceLabel(String source) {
    if (source == 'ai_coach') {
      return 'AI';
    }
    return source.toUpperCase();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final DailyTasksFilter filter;

  @override
  Widget build(BuildContext context) {
    final text = switch (filter) {
      DailyTasksFilter.all => 'Bugun icin kayitli gorev yok.',
      DailyTasksFilter.todo => 'Yapilacak gorev kalmadi.',
      DailyTasksFilter.done => 'Tamamlanan gorev yok.',
    };

    return Center(
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          color: const Color(0xFFAFC3E1),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
