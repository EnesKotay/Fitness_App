import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../controllers/daily_tasks_controller.dart';
import '../models/daily_task.dart';
import '../../workout/providers/streak_provider.dart';

import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/page_guide_service.dart';
import '../../../core/widgets/page_guide_overlay.dart';
import '../../../core/widgets/page_guide_button.dart';

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
  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '📋',
      title: 'Günlük Görev Listesi',
      description:
          'Bu sayfa, o gün tamamlaman gereken fitness ve yaşam hedeflerini listeler.\n\n'
          'Sistem her sabah sana özel bazı temel görevler atar (örneğin: Su hedefini tamamla, 2 öğün kaydet vb.). Amacın gün bitmeden tüm görevleri tamamlayıp ilerleme çubuğunu %100 yapmaktır.',
      tip:
          'Görevler her gece yarısı sıfırlanır. Yeni güne temiz bir sayfayla başlarsın.',
    ),
    GuideStep(
      emoji: '👆',
      title: 'Görevleri Tamamlama',
      description:
          'Bir görevi bitirdiğinde yanındaki boş çembere (veya görevin üstüne) dokun. Görev yeşile döner ve altı çizilir.\n\n'
          'Yanlışlıkla işaretlediysen tekrar dokunarak geri alabilirsin.',
      tip:
          'Tüm görevleri %100 tamamladığında başarı animasyonu seni karşılar ve günlük "Seri" kazanmana yardımcı olur.',
    ),
    GuideStep(
      emoji: '➕',
      title: 'Kendi Özel Görevlerini Ekle',
      description:
          'Sadece sistemin verdikleriyle sınırlı değilsin. Sağ alttaki sarı "+" butonuna dokunarak kendi görevlerini ekleyebilirsin:\n\n'
          '• Göreve isim ver (Örn: "Sabah 30 dk yürüyüş")\n'
          '• Kategori seç (Spor, Beslenme, Su, Diğer)\n'
          '• Öncelik belirle (Yüksek, Orta, Düşük)',
      tip:
          'Görevleri önceliklendirerek gün içinde ilk neye odaklanman gerektiğini belirleyebilirsin. Yüksek öncelikliler kırmızı görünür.',
    ),
    GuideStep(
      emoji: '🔄',
      title: 'Alışkanlık ve Rutin Oluşturma',
      description:
          'Eğer eklediğin görev her gün yapman gereken bir şeyse (örn: "Uyanınca 2 bardak su iç"), görev eklerken alt kısımdaki "Her gün tekrarla" anahtarını aç.\n\n'
          'Bu sayede görev, her sabah otomatik olarak listene eklenir ve harika bir rutine dönüşür.',
      tip:
          'Tekrarlayan görevlerini yönetmek veya silmek istersen sağ üstteki (🔄) ikonuna dokunabilirsin.',
    ),
    GuideStep(
      emoji: '🧹',
      title: 'Görev Silme',
      description:
          'Eklediğin bir görevi silmek istersen, görevi sağdan sola doğru kaydır (swipe). Ekrandan silinecektir.\n\n'
          'Yanlışlıkla sildiysen ekranın altında çıkan "Geri Al" butonunu kullanabilirsin.',
      tip:
          'Üstteki butonları (Hepsi, Kalan, Bitti) kullanarak listeni filtreleyebilir ve sadece yapman gerekenleri görebilirsin.',
    ),
  ];

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('daily_tasks')) return;
    await PageGuideService.markGuideSeen('daily_tasks');
    if (mounted) await _showGuide();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<DailyTasksController>().loadToday();
      await _checkFirstVisitGuide();
    });
  }

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
            heroTag: 'daily_tasks_add_task_fab',
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
                            title: controller.progressTitle,
                            subtitle: controller.progressSubtitle,
                            milestones: controller.milestones,
                            nextMilestone: controller.nextMilestone,
                          )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 16),
                      _buildHeader(controller),
                      const SizedBox(height: 12),
                      if (controller.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFEBC374),
                            ),
                            minHeight: 2,
                          ),
                        ),
                      Expanded(
                        child: tasks.isEmpty
                            ? _EmptyState(
                                filter: controller.filter,
                                onAddPressed: () =>
                                    _showAddTaskDialog(context, controller),
                              ).animate().fadeIn(delay: 300.ms)
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 120),
                                itemCount: tasks.length,
                                separatorBuilder: (_, i) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  return Dismissible(
                                        key: Key(task.id),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(
                                            right: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        onDismissed: (_) {
                                          final deleted = task;
                                          controller.deleteTask(deleted.id);
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '"${deleted.title}" silindi',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.dmSans(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                backgroundColor: const Color(
                                                  0xFF1A1F35,
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                action: SnackBarAction(
                                                  label: 'Geri Al',
                                                  textColor: const Color(
                                                    0xFFEBC374,
                                                  ),
                                                  onPressed: () => controller
                                                      .restoreTask(deleted),
                                                ),
                                                duration: const Duration(
                                                  seconds: 4,
                                                ),
                                              ),
                                            );
                                        },
                                        child: _TaskTile(
                                          task: task,
                                          onToggle: () async {
                                            final allDone = await controller
                                                .toggleTaskDone(task.id);
                                            if (!allDone || !context.mounted) {
                                              return;
                                            }
                                            final badge = await context
                                                .read<StreakProvider>()
                                                .onDailyTasksAllCompleted();
                                            if (badge != null &&
                                                context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                ..hideCurrentSnackBar()
                                                ..showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Rozet kazandın: ${badge.title}',
                                                    ),
                                                    backgroundColor:
                                                        const Color(0xFF1A1F35),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                            }
                                          },
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(delay: (index * 40).ms)
                                      .slideX(begin: 0.08, end: 0);
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
        'Günlük Görevler',
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(child: PageGuideButton(onTap: _showGuide)),
        ),
        IconButton(
          icon: const Icon(
            Icons.repeat_rounded,
            color: Color(0xFFEBC374),
            size: 22,
          ),
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

  void _showAddTaskDialog(
    BuildContext context,
    DailyTasksController controller,
  ) {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            title: Text(
              'Yeni Görev',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFEBC374),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
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
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
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
                        onTap: () =>
                            setStateDialog(() => selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: 180.ms,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? color : Colors.white24,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _categoryIcon(cat),
                                size: 14,
                                color: selected ? color : Colors.white38,
                              ),
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
                          onTap: () =>
                              setStateDialog(() => selectedPriority = p),
                          child: AnimatedContainer(
                            duration: 180.ms,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : Colors.white.withValues(alpha: 0.1),
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
                    onTap: () =>
                        setStateDialog(() => makeRecurring = !makeRecurring),
                    child: AnimatedContainer(
                      duration: 180.ms,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: makeRecurring
                            ? const Color(0xFFEBC374).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: makeRecurring
                              ? const Color(0xFFEBC374)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 16,
                            color: makeRecurring
                                ? const Color(0xFFEBC374)
                                : Colors.white38,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Her gün tekrarla',
                              style: GoogleFonts.dmSans(
                                color: makeRecurring
                                    ? const Color(0xFFEBC374)
                                    : Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch(
                            value: makeRecurring,
                            onChanged: (v) =>
                                setStateDialog(() => makeRecurring = v),
                            activeThumbColor: const Color(0xFFEBC374),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
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
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEBC374),
                  foregroundColor: const Color(0xFF070B16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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

  void _showRecurringSheet(
    BuildContext context,
    DailyTasksController controller,
  ) {
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
                          const Icon(
                            Icons.repeat_rounded,
                            color: Color(0xFFEBC374),
                            size: 20,
                          ),
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
                        style: GoogleFonts.dmSans(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: templates.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.repeat_rounded,
                                    size: 48,
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Henüz tekrarlayan görev yok.\nGörev eklerken "Her gün tekrarla"yı aç.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white30,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: templates.length,
                              separatorBuilder: (_, i) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final t = templates[i];
                                final color = _categoryColor(t.category);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          _categoryIcon(t.category),
                                          size: 16,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                    color: _priorityColor(
                                                      t.priority,
                                                    ),
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
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () => controller
                                            .removeRecurringTemplate(t.id),
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

  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.title,
    required this.subtitle,
    required this.milestones,
    required this.nextMilestone,
  });

  final int completed;
  final int total;
  final String title;
  final String subtitle;
  final List<DailyTaskMilestone> milestones;
  final DailyTaskMilestone? nextMilestone;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFEBC374),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GÜNLÜK ÖZET',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFEBC374),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? subtitle
                      : '$completed/$total görev tamamlandı · $subtitle',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (milestones.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: milestones
                        .map(
                          (milestone) => _MilestoneChip(
                            milestone: milestone,
                            isNext: nextMilestone?.id == milestone.id,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: const Color(0xFFEBC374),
                ),
                Center(
                  child: Text(
                    '${(ratio * 100).toInt()}%',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFEBC374),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({required this.milestone, required this.isNext});

  final DailyTaskMilestone milestone;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final unlocked = milestone.isUnlocked;
    final color = unlocked
        ? const Color(0xFFEBC374)
        : isNext
        ? const Color(0xFF7BCBFF)
        : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: unlocked ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: unlocked ? 0.42 : 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.verified_rounded : Icons.lock_open_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            milestone.title,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Task Tile ────────────────────────────────────────────────────────────────

class _TaskTextSummary {
  const _TaskTextSummary({
    required this.title,
    required this.steps,
    required this.extraStepCount,
  });

  final String title;
  final List<String> steps;
  final int extraStepCount;
}

_TaskTextSummary _summarizeTaskText(String rawTitle) {
  final raw = rawTitle.trim();
  if (raw.isEmpty) {
    return const _TaskTextSummary(
      title: 'Görev',
      steps: <String>[],
      extraStepCount: 0,
    );
  }

  final titleFromBold = RegExp(r'\*\*(.+?)\*\*').firstMatch(raw)?.group(1);
  final plainLines = raw
      .replaceAll('**', '')
      .split(RegExp(r'[\n\r]+'))
      .map(_cleanTaskLine)
      .where((line) => line.isNotEmpty)
      .toList();

  final fallbackTitle = plainLines.isNotEmpty ? plainLines.first : raw;
  final title = _shortenTaskTitle(
    _cleanTaskLine(titleFromBold ?? fallbackTitle),
  );

  final steps = <String>[];
  final boldMatches = RegExp(
    r'\*\*(.+?)\*\*\s*:?\s*([^*]*)',
    dotAll: true,
  ).allMatches(raw).toList();

  for (var i = 0; i < boldMatches.length; i++) {
    final label = _cleanTaskLine(boldMatches[i].group(1) ?? '');
    final detail = _cleanTaskLine(boldMatches[i].group(2) ?? '');
    if (label.isEmpty || _looksLikeTitle(label, title)) continue;
    final step = detail.isEmpty ? label : '$label: $detail';
    steps.add(_compactTaskStep(step));
  }

  if (steps.isEmpty) {
    for (final line in plainLines.skip(1)) {
      if (_looksLikeTitle(line, title)) continue;
      steps.add(_compactTaskStep(line));
    }
  }

  final uniqueSteps = <String>[];
  final seen = <String>{};
  for (final step in steps) {
    final key = step.toLowerCase();
    if (step.isEmpty || !seen.add(key)) continue;
    uniqueSteps.add(step);
  }

  return _TaskTextSummary(
    title: title,
    steps: uniqueSteps,
    extraStepCount: uniqueSteps.length > 3 ? uniqueSteps.length - 3 : 0,
  );
}

String _cleanTaskLine(String value) {
  return value
      .replaceAll(RegExp(r'^[\s*•\-–]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' :', ':')
      .trim();
}

String _shortenTaskTitle(String value) {
  var title = value;
  final colonIndex = title.indexOf(':');
  if (colonIndex > 8 && colonIndex < 70) {
    title = title.substring(0, colonIndex);
  }
  title = title.replaceAll(RegExp(r'\s*\([^)]{20,}\)'), '').trim();
  if (title.length <= 58) return title;
  return '${title.substring(0, 55).trimRight()}...';
}

String _compactTaskStep(String value) {
  var step = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (step.length <= 86) return step;
  return '${step.substring(0, 83).trimRight()}...';
}

bool _looksLikeTitle(String value, String title) {
  final a = DailyTask.normalizeTitle(value);
  final b = DailyTask.normalizeTitle(title);
  return a == b || a.contains(b) || b.contains(a);
}

TaskCategory _displayCategoryForTask(DailyTask task) {
  if (task.category != TaskCategory.other) return task.category;
  final text = task.title.toLowerCase();
  final sportTokens = [
    'antrenman',
    'squat',
    'press',
    'deadlift',
    'row',
    'bench',
    'ısınma',
    'isinma',
    'set',
    'tekrar',
    'bacak',
    'göğüs',
    'gogus',
    'sırt',
    'sirt',
    'omuz',
  ];
  if (sportTokens.any(text.contains)) return TaskCategory.sport;
  final nutritionTokens = ['öğün', 'ogun', 'kalori', 'protein', 'yemek'];
  if (nutritionTokens.any(text.contains)) return TaskCategory.nutrition;
  final waterTokens = ['su iç', 'su ic', 'litre', 'bardak'];
  if (waterTokens.any(text.contains)) return TaskCategory.water;
  return TaskCategory.other;
}

class _TaskTile extends StatefulWidget {
  const _TaskTile({required this.task, required this.onToggle});

  final DailyTask task;
  final VoidCallback onToggle;

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _expanded = false;

  DailyTask get task => widget.task;
  VoidCallback get onToggle => widget.onToggle;

  @override
  Widget build(BuildContext context) {
    final displayCategory = _displayCategoryForTask(task);
    final catColor = _categoryColor(displayCategory);
    final prioColor = _priorityColor(task.priority);
    final summary = _summarizeTaskText(task.title);
    final visibleSteps = _expanded
        ? summary.steps
        : summary.steps.take(3).toList();
    final hiddenStepCount = _expanded ? 0 : summary.extraStepCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: summary.steps.length > 3
            ? () => setState(() => _expanded = !_expanded)
            : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: 250.ms,
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: task.isDone
                ? Colors.white.withValues(alpha: 0.025)
                : const Color(0xFF111827).withValues(alpha: 0.88),
            border: Border.all(
              color: task.isDone
                  ? Colors.white.withValues(alpha: 0.05)
                  : catColor.withValues(alpha: 0.25),
            ),
            boxShadow: [
              if (!task.isDone)
                BoxShadow(
                  color: catColor.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: task.isDone
                          ? Colors.white.withValues(alpha: 0.035)
                          : catColor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: task.isDone
                            ? Colors.white.withValues(alpha: 0.04)
                            : catColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(
                      _categoryIcon(displayCategory),
                      size: 18,
                      color: task.isDone ? Colors.white24 : catColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isDone ? Colors.white12 : prioColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            summary.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: task.isDone
                                  ? Colors.white38
                                  : Colors.white.withValues(alpha: 0.94),
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              height: 1.18,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Checkbox(
                          value: task.isDone,
                          activeColor: const Color(0xFFEBC374),
                          checkColor: const Color(0xFF070B16),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onChanged: (_) => onToggle(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _metaChip(
                          icon: _categoryIcon(displayCategory),
                          label: _categoryLabel(displayCategory),
                          color: catColor,
                        ),
                        _metaChip(
                          icon: Icons.flag_rounded,
                          label: _priorityLabel(task.priority),
                          color: prioColor,
                        ),
                        if (task.isRecurring)
                          _metaChip(
                            icon: Icons.repeat_rounded,
                            label: 'Tekrar',
                            color: const Color(0xFF7BCBFF),
                          ),
                        _buildSourceBadge(),
                      ],
                    ),
                    if (summary.steps.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 13,
                            color: catColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _expanded
                                ? 'Tüm adımlar'
                                : 'İlk ${visibleSteps.length} adım',
                            style: GoogleFonts.dmSans(
                              color: catColor.withValues(alpha: 0.86),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.055),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...visibleSteps.indexed.map(
                              (entry) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      entry.$1 == visibleSteps.length - 1 &&
                                          hiddenStepCount <= 0
                                      ? 0
                                      : 6,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      alignment: Alignment.center,
                                      margin: const EdgeInsets.only(top: 1),
                                      decoration: BoxDecoration(
                                        color: task.isDone
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : catColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: task.isDone
                                              ? Colors.white.withValues(
                                                  alpha: 0.06,
                                                )
                                              : catColor.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        '${entry.$1 + 1}',
                                        style: GoogleFonts.dmSans(
                                          color: task.isDone
                                              ? Colors.white24
                                              : catColor,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.$2,
                                        maxLines: _expanded ? 4 : 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(
                                          color: task.isDone
                                              ? Colors.white30
                                              : Colors.white.withValues(
                                                  alpha: 0.68,
                                                ),
                                          fontSize: 12.2,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (hiddenStepCount > 0 || _expanded)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => _expanded = !_expanded),
                                child: Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: catColor.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _expanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: catColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _expanded
                                            ? 'Daha az göster'
                                            : '+$hiddenStepCount adım daha göster',
                                        style: GoogleFonts.dmSans(
                                          color: catColor,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: task.isDone ? 0.05 : 0.12),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: task.isDone ? Colors.white24 : color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: task.isDone ? Colors.white24 : color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
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
        _buildOrb(
          const Color(0xFF1A1F35),
          400,
          alignment: Alignment.topLeft,
          offset: const Offset(-100, -100),
        ),
        _buildOrb(
          const Color(0xFF1F1235),
          350,
          alignment: Alignment.bottomRight,
          offset: const Offset(50, 50),
        ),
        _buildOrb(
          const Color(0xFF352A1A),
          300,
          alignment: Alignment.centerLeft,
          offset: const Offset(-50, 100),
        ),
      ],
    );
  }

  Widget _buildOrb(
    Color color,
    double size, {
    required Alignment alignment,
    required Offset offset,
  }) {
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
        .move(
          begin: const Offset(0, 0),
          end: const Offset(30, 30),
          duration: 5.seconds,
          curve: Curves.easeInOut,
        )
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.2, 1.2),
          duration: 5.seconds,
        );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.onAddPressed});

  final DailyTasksFilter filter;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    if (filter != DailyTasksFilter.all) {
      final isTodo = filter == DailyTasksFilter.todo;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTodo
                  ? Icons.celebration_rounded
                  : Icons.history_toggle_off_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 20),
            Text(
              isTodo
                  ? 'Harika! Yapılacak tüm\ngörevleri bitirdin.'
                  : 'Henüz tamamlanan\nbir görev yok.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // Default Empty State for "All"
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 40,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'Gününüzü Planlayın',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Su içme, antrenman veya öğün hedeflerini ekleyerek gününü organize et.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 32),
            OutlinedButton.icon(
                  onPressed: onAddPressed,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('İlk Görevini Ekle'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEBC374),
                    side: BorderSide(
                      color: const Color(0xFFEBC374).withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    textStyle: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 500.ms)
                .scale(begin: const Offset(0.9, 0.9)),
          ],
        ),
      ),
    );
  }
}
