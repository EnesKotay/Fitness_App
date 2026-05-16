import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../models/workout_program.dart';
import '../providers/workout_program_provider.dart';
import '../data/workout_catalog_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kGreen = Color(0xFF4CAF50);
const _kBg = Color(0xFF080A0E);
const _kCard = Color(0xFF13161C);
const _kSurface = Color(0xFF1A1E26);

const _kDayPalette = [
  Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFE91E63),
  Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFF00BCD4),
  Color(0xFFFF5722),
];

const _kFitnessEmojis = [
  '💪', '🏋️', '🔥', '⚡', '🎯', '🏆', '🚀', '💥',
  '🦁', '🐉', '⚔️', '🛡️', '🌊', '❄️', '🌪️', '🎖️',
  '🧠', '💎', '🥇', '🏅', '💫', '✨', '🎪', '🎭',
];

// ─────────────────────────────────────────────────────────────────────────────
// Split presets
// ─────────────────────────────────────────────────────────────────────────────

enum _Split { custom, ppl, upperLower, fullBody, bro, athletic }

extension _SplitExt on _Split {
  String get label => switch (this) {
        _Split.custom => 'Özel',
        _Split.ppl => 'Push/Pull/Legs',
        _Split.upperLower => 'Üst/Alt',
        _Split.fullBody => 'Full Body',
        _Split.bro => 'Bro Split',
        _Split.athletic => 'Atletik',
      };
  String get emoji => switch (this) {
        _Split.custom => '✏️',
        _Split.ppl => '🔀',
        _Split.upperLower => '↕️',
        _Split.fullBody => '💥',
        _Split.bro => '💪',
        _Split.athletic => '⚡',
      };
  String get description => switch (this) {
        _Split.custom => 'Sıfırdan oluştur',
        _Split.ppl => '3 gün / hafta',
        _Split.upperLower => '4 gün / hafta',
        _Split.fullBody => '3 gün / hafta',
        _Split.bro => '5 gün / hafta',
        _Split.athletic => '4 gün / hafta',
      };
  List<String> get dayNames => switch (this) {
        _Split.custom => [],
        _Split.ppl => ['Push (İtiş)', 'Pull (Çekiş)', 'Legs (Bacak)'],
        _Split.upperLower => ['Üst Vücut A', 'Alt Vücut A', 'Üst Vücut B', 'Alt Vücut B'],
        _Split.fullBody => ['Full Body A', 'Full Body B', 'Full Body C'],
        _Split.bro => ['Göğüs', 'Sırt', 'Omuz', 'Bacak', 'Kol'],
        _Split.athletic => ['Güç A', 'Hız & Çeviklik', 'Güç B', 'Kondisyon'],
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal state helper
// ─────────────────────────────────────────────────────────────────────────────

class _DayEntry {
  final String id;
  final TextEditingController nameCtrl;
  final List<ProgramExercise> exercises;
  Color color;
  bool isExpanded = true;

  _DayEntry({
    required this.id,
    required String name,
    List<ProgramExercise>? exercises,
    required this.color,
  })  : nameCtrl = TextEditingController(text: name),
        exercises = exercises != null ? List.from(exercises) : [];

  factory _DayEntry.fresh(int n, Color color) =>
      _DayEntry(id: const Uuid().v4(), name: 'Gün $n', color: color);

  factory _DayEntry.fromDay(ProgramDay day, Color color) =>
      _DayEntry(id: day.id, name: day.name, exercises: day.exercises, color: color);

  ProgramDay toProgramDay() => ProgramDay(
        id: id,
        name: nameCtrl.text.trim().isEmpty ? 'Gün' : nameCtrl.text.trim(),
        exercises: List.from(exercises),
      );

  void dispose() => nameCtrl.dispose();

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets);

  String get volumeLabel {
    if (exercises.isEmpty) return '';
    if (exercises.length <= 3) return 'Hafif';
    if (exercises.length <= 6) return 'Orta';
    return 'Yoğun';
  }

  Color get volumeColor {
    if (exercises.isEmpty) return Colors.white38;
    if (exercises.length <= 3) return const Color(0xFF4CAF50);
    if (exercises.length <= 6) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class ProgramBuilderScreen extends StatefulWidget {
  final WorkoutProgram? program;
  const ProgramBuilderScreen({super.key, this.program});

  @override
  State<ProgramBuilderScreen> createState() => _ProgramBuilderScreenState();
}

class _ProgramBuilderScreenState extends State<ProgramBuilderScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<_DayEntry> _days = [];
  bool _saving = false;
  _Split _split = _Split.custom;
  String _emoji = '💪';

  late final AnimationController _bgAnim;
  late final AnimationController _statsAnim;

  int get _totalExercises => _days.fold(0, (s, d) => s + d.exercises.length);
  int get _estimatedMinutes => (_totalExercises * 4.5).round();
  Color _colorForIndex(int i) => _kDayPalette[i % _kDayPalette.length];

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _statsAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    final p = widget.program;
    if (p != null) {
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description;
      for (int i = 0; i < p.days.length; i++) {
        _days.add(_DayEntry.fromDay(p.days[i], _colorForIndex(i)));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _statsAnim.forward());
  }

  @override
  void dispose() {
    _bgAnim.dispose();
    _statsAnim.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final d in _days) { d.dispose(); }
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _applySplit(_Split split) {
    HapticFeedback.selectionClick();
    setState(() {
      _split = split;
      if (split == _Split.custom) return;
      for (final d in _days) { d.dispose(); }
      _days.clear();
      for (int i = 0; i < split.dayNames.length; i++) {
        _days.add(_DayEntry(
          id: const Uuid().v4(),
          name: split.dayNames[i],
          color: _colorForIndex(i),
        ));
      }
    });
    if (_days.isNotEmpty) _statsAnim.forward(from: 0);
  }

  void _addDay() {
    HapticFeedback.selectionClick();
    setState(() => _days.add(_DayEntry.fresh(_days.length + 1, _colorForIndex(_days.length))));
    _statsAnim.forward(from: 0);
  }

  void _removeDay(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _days[index].dispose();
      _days.removeAt(index);
    });
    _statsAnim.forward(from: 0);
  }

  void _copyDay(int index) {
    HapticFeedback.lightImpact();
    final src = _days[index];
    final copy = _DayEntry(
      id: const Uuid().v4(),
      name: '${src.nameCtrl.text} (Kopya)',
      exercises: List.from(src.exercises),
      color: _colorForIndex(_days.length),
    );
    setState(() => _days.insert(index + 1, copy));
    _statsAnim.forward(from: 0);
  }

  Future<void> _addExercise(int dayIndex) async {
    final exercise = await showModalBottomSheet<ProgramExercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ExercisePickerSheet(),
    );
    if (exercise != null && mounted) {
      HapticFeedback.lightImpact();
      setState(() => _days[dayIndex].exercises.add(exercise));
      _statsAnim.forward(from: 0);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _snack('Program adı gerekli'); return; }
    if (_days.isEmpty) { _snack('En az bir antrenman günü ekle'); return; }
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

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
  );

  void _pickEmoji() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EmojiPickerSheet(
        current: _emoji,
        onPick: (e) { setState(() => _emoji = e); Navigator.pop(context); },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          _AnimatedBackground(controller: _bgAnim),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeaderSection()),
                      if (_days.isNotEmpty)
                        SliverToBoxAdapter(child: _buildStatsBar()),
                      SliverToBoxAdapter(child: _buildDaysHeader()),
                      if (_days.isEmpty)
                        SliverToBoxAdapter(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _EmptyDaysPlaceholder(onAdd: _addDay),
                        ))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                          sliver: _buildDaysList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: BoxDecoration(
        color: _kBg.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              widget.program == null ? 'Program Oluştur' : 'Programı Düzenle',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          _saving
              ? const SizedBox(
                  width: 60,
                  child: Center(child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
                  )),
                )
              : GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF1B8A3A)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji + Name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickEmoji,
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                  ),
                  child: Stack(
                    children: [
                      Center(child: Text(_emoji, style: const TextStyle(fontSize: 28))),
                      Positioned(
                        right: 4, bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 9, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(width: 14),
              Expanded(
                child: _GlassTextField(
                  controller: _nameCtrl,
                  hint: 'Program Adı',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          _GlassTextField(
            controller: _descCtrl,
            hint: 'Açıklama (opsiyonel) — hedef, notlar...',
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Split selector label
          Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              const Text('Program Tipi', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 12),

          // Split chips
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _Split.values.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final sel = _split == s;
                return GestureDetector(
                  onTap: () => _applySplit(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 110,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? LinearGradient(
                              colors: [_kGreen.withValues(alpha: 0.25), _kGreen.withValues(alpha: 0.08)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            )
                          : null,
                      color: sel ? null : _kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: sel ? _kGreen.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.07),
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${s.emoji}  ${s.label}',
                            style: TextStyle(
                              color: sel ? _kGreen : Colors.white70,
                              fontSize: 11.5,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(s.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 10.5,
                            )),
                      ],
                    ),
                  ),
                ).animate(delay: Duration(milliseconds: 50 * i)).fadeIn(duration: 300.ms).slideX(begin: 0.15);
              }).toList(),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: AnimatedBuilder(
        animation: _statsAnim,
        builder: (_, _) => GlassmorphicContainer(
          blur: 12,
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          borderColor: _kGreen.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              _StatCell(
                icon: Icons.calendar_today_rounded,
                value: '${_days.length}',
                label: 'gün',
                color: _kGreen,
                anim: _statsAnim.value,
              ),
              _VertDivider(),
              _StatCell(
                icon: Icons.fitness_center_rounded,
                value: '$_totalExercises',
                label: 'egzersiz',
                color: const Color(0xFF2196F3),
                anim: _statsAnim.value,
              ),
              _VertDivider(),
              _StatCell(
                icon: Icons.timer_rounded,
                value: '~$_estimatedMinutes',
                label: 'dk',
                color: const Color(0xFFFF9800),
                anim: _statsAnim.value,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, curve: Curves.easeOut);
  }

  Widget _buildDaysHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          const Text('Antrenman Günleri',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: _addDay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kGreen.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 15, color: _kGreen),
                  SizedBox(width: 4),
                  Text('Gün Ekle', style: TextStyle(color: _kGreen, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysList() {
    return SliverReorderableList(
      itemCount: _days.length,
      onReorder: (oldIdx, newIdx) {
        setState(() {
          if (newIdx > oldIdx) newIdx--;
          final item = _days.removeAt(oldIdx);
          _days.insert(newIdx, item);
        });
      },
      proxyDecorator: (child, idx, anim) => Material(color: Colors.transparent, child: child),
      itemBuilder: (context, i) => _DayCard(
        key: ValueKey(_days[i].id),
        entry: _days[i],
        number: i + 1,
        onDelete: () => _removeDay(i),
        onCopy: () => _copyDay(i),
        onAddExercise: () => _addExercise(i),
        onDeleteExercise: (ei) => setState(() {
          _days[i].exercises.removeAt(ei);
          _statsAnim.forward(from: 0);
        }),
        onChanged: () => setState(() {}),
        onToggleExpand: () => setState(() => _days[i].isExpanded = !_days[i].isExpanded),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated background
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _BgPainter(controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  const _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _kBg);
    final rng = math.Random(1);
    final orbs = [
      (dx: 0.15, dy: 0.08, r: 220.0, c: const Color(0xFF4CAF50)),
      (dx: 0.85, dy: 0.35, r: 160.0, c: const Color(0xFF2196F3)),
      (dx: 0.5, dy: 0.75, r: 180.0, c: const Color(0xFF9C27B0)),
    ];
    for (final orb in orbs) {
      final ox = math.sin(t * math.pi * 2 + rng.nextDouble()) * 30;
      final oy = math.cos(t * math.pi * 2 + rng.nextDouble()) * 20;
      canvas.drawCircle(
        Offset(size.width * orb.dx + ox, size.height * orb.dy + oy),
        orb.r,
        Paint()
          ..shader = RadialGradient(colors: [
            orb.c.withValues(alpha: 0.07),
            orb.c.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(
            center: Offset(size.width * orb.dx + ox, size.height * orb.dy + oy),
            radius: orb.r,
          )),
      );
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat cell
// ─────────────────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final double anim;

  const _StatCell({required this.icon, required this.value, required this.label, required this.color, required this.anim});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              )),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.08));
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass text field
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final double? fontSize;
  final FontWeight? fontWeight;
  final ValueChanged<String>? onChanged;

  const _GlassTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.fontSize,
    this.fontWeight,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: fontSize ?? 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kGreen, width: 1.5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Emoji picker
// ─────────────────────────────────────────────────────────────────────────────

class _EmojiPickerSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onPick;
  const _EmojiPickerSheet({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Program İkonu', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 8,
            shrinkWrap: true,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: _kFitnessEmojis.map((e) {
              final sel = e == current;
              return GestureDetector(
                onTap: () => onPick(e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: sel ? _kGreen.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? _kGreen : Colors.transparent, width: 1.5),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyDaysPlaceholder extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyDaysPlaceholder({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      blur: 10,
      backgroundColor: Colors.white.withValues(alpha: 0.03),
      borderColor: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_note_rounded, color: _kGreen, size: 44),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 2000.ms, curve: Curves.easeInOut),
          const SizedBox(height: 20),
          const Text('Henüz gün eklenmedi',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Bir split tipi seç ya da manuel olarak\nantrenman günlerini ekle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13.5, height: 1.55),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF1B8A3A)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('İlk Günü Ekle', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day card
// ─────────────────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final _DayEntry entry;
  final int number;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onAddExercise;
  final void Function(int) onDeleteExercise;
  final VoidCallback onChanged;
  final VoidCallback onToggleExpand;

  const _DayCard({
    super.key,
    required this.entry,
    required this.number,
    required this.onDelete,
    required this.onCopy,
    required this.onAddExercise,
    required this.onDeleteExercise,
    required this.onChanged,
    required this.onToggleExpand,
  });

  List<String> get _uniqueGroups {
    final seen = <String>{};
    return entry.exercises.map((e) => e.muscleGroup).where(seen.add).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
          BoxShadow(color: entry.color.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: -4),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [entry.color, entry.color.withValues(alpha: 0.4)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                      child: Row(
                        children: [
                          // Drag handle
                          ReorderableDragStartListener(
                            index: number - 1,
                            child: Icon(Icons.drag_handle_rounded, color: Colors.white.withValues(alpha: 0.25), size: 20),
                          ),
                          const SizedBox(width: 10),
                          // Day badge
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: entry.color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: entry.color.withValues(alpha: 0.4)),
                            ),
                            child: Center(child: Text('$number',
                                style: TextStyle(color: entry.color, fontWeight: FontWeight.w800, fontSize: 13))),
                          ),
                          const SizedBox(width: 10),
                          // Name
                          Expanded(
                            child: TextField(
                              controller: entry.nameCtrl,
                              onChanged: (_) => onChanged(),
                              style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(
                                hintText: 'Gün adı...',
                                hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          // Volume badge
                          if (entry.exercises.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: entry.volumeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(entry.volumeLabel,
                                  style: TextStyle(color: entry.volumeColor, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          const SizedBox(width: 4),
                          // Expand toggle
                          GestureDetector(
                            onTap: onToggleExpand,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: AnimatedRotation(
                                turns: entry.isExpanded ? 0 : -0.5,
                                duration: const Duration(milliseconds: 250),
                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white.withValues(alpha: 0.5), size: 20),
                              ),
                            ),
                          ),
                          // 3-dot menu
                          PopupMenuButton<String>(
                            color: const Color(0xFF1E2028),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            icon: Icon(Icons.more_vert_rounded, color: Colors.white.withValues(alpha: 0.4), size: 19),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 16, color: Colors.white60), SizedBox(width: 10), Text('Günü Kopyala', style: TextStyle(color: Colors.white, fontSize: 13))])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent), SizedBox(width: 10), Text('Günü Sil', style: TextStyle(color: Colors.redAccent, fontSize: 13))])),
                            ],
                            onSelected: (v) {
                              if (v == 'copy') onCopy();
                              if (v == 'delete') onDelete();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Expanded content
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      firstCurve: Curves.easeOut,
                      secondCurve: Curves.easeIn,
                      crossFadeState: entry.isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      firstChild: _ExpandedContent(
                        entry: entry,
                        uniqueGroups: _uniqueGroups,
                        onAddExercise: onAddExercise,
                        onDeleteExercise: onDeleteExercise,
                      ),
                      secondChild: entry.exercises.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: Text(
                                '${entry.exercises.length} egzersiz • ${entry.totalSets} set toplam',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                              ),
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

class _ExpandedContent extends StatelessWidget {
  final _DayEntry entry;
  final List<String> uniqueGroups;
  final VoidCallback onAddExercise;
  final void Function(int) onDeleteExercise;

  const _ExpandedContent({
    required this.entry,
    required this.uniqueGroups,
    required this.onAddExercise,
    required this.onDeleteExercise,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Muscle group tags
        if (uniqueGroups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(
              spacing: 6, runSpacing: 5,
              children: uniqueGroups.map((g) {
                final info = kMuscleGroupInfo[g];
                final c = info?.color ?? Colors.grey;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(info?.label ?? g, style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Exercises
        if (entry.exercises.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < entry.exercises.length; i++)
            _ExerciseRow(
              exercise: entry.exercises[i],
              index: i + 1,
              onDelete: () => onDeleteExercise(i),
            ),
          const SizedBox(height: 6),
        ],

        // Add exercise button
        InkWell(
          onTap: onAddExercise,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded, size: 17, color: entry.color),
                const SizedBox(width: 6),
                Text('Egzersiz Ekle', style: TextStyle(color: entry.color, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exercise row
// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  final ProgramExercise exercise;
  final int index;
  final VoidCallback onDelete;

  const _ExerciseRow({required this.exercise, required this.index, required this.onDelete});

  String _restLabel() {
    final s = exercise.restSeconds;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rem = s % 60;
    return rem == 0 ? '${m}dk' : '$m:${rem.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = kMuscleGroupInfo[exercise.muscleGroup]?.color ?? Colors.grey;

    return Dismissible(
      key: ValueKey('${exercise.name}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Index dot
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Center(child: Text('$index', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(exercise.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  // Sets × Reps
                  _Badge(text: '${exercise.sets}×${exercise.reps}', color: Colors.white.withValues(alpha: 0.12), textColor: Colors.white),
                  const SizedBox(width: 6),
                  // Rest
                  _Badge(
                    icon: Icons.timer_outlined,
                    text: _restLabel(),
                    color: _kGreen.withValues(alpha: 0.12),
                    textColor: _kGreen,
                    iconColor: _kGreen,
                  ),
                ],
              ),
              if (exercise.note.isNotEmpty) ...[
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 34),
                  child: Text('📝 ${exercise.note}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5, fontStyle: FontStyle.italic)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final Color? iconColor;

  const _Badge({required this.text, required this.color, required this.textColor, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: iconColor ?? textColor), const SizedBox(width: 3)],
          Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exercise picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String? _selectedGroup;
  ({String name, String group})? _selected;
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _query = '';
  int _sets = 3;
  int _reps = 10;
  int _restSeconds = 60;

  static const _restOptions = [
    (s: 30, label: '30sn', desc: 'Süper set'),
    (s: 45, label: '45sn', desc: 'Dayanıklılık'),
    (s: 60, label: '1dk', desc: 'Hipertrofi'),
    (s: 90, label: '1.5dk', desc: 'Optimal'),
    (s: 120, label: '2dk', desc: 'Güç'),
    (s: 180, label: '3dk', desc: 'Maksimal'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<({String name, String group})> get _filtered {
    final result = <({String name, String group})>[];
    for (final entry in kMassExerciseNames.entries) {
      if (_selectedGroup == null || entry.key == _selectedGroup) {
        for (final name in entry.value) { result.add((name: name, group: entry.key)); }
      }
    }
    if (_query.isEmpty) return result;
    final q = _query.toLowerCase();
    return result.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1116),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                if (_selected != null)
                  GestureDetector(
                    onTap: () => setState(() => _selected = null),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 16),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _selected == null
                        ? (_selectedGroup == null ? 'Egzersiz Seç' : (kMuscleGroupInfo[_selectedGroup]?.label ?? ''))
                        : _selected!.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedGroup != null && _selected == null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedGroup = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
                      child: const Text('Tümü', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(child: _selected == null ? _buildPicker() : _buildConfig()),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    if (_selectedGroup == null && _query.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SearchField(ctrl: _searchCtrl, onChanged: (v) => setState(() => _query = v)),
          ),
          if (_query.isNotEmpty)
            Expanded(child: _buildExerciseList())
          else
            Expanded(child: _buildMuscleGroupGrid()),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _SearchField(ctrl: _searchCtrl, onChanged: (v) => setState(() => _query = v)),
        ),
        Expanded(child: _buildExerciseList()),
      ],
    );
  }

  Widget _buildMuscleGroupGrid() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: kMuscleGroupInfo.entries.map((e) {
        final color = e.value.color;
        return GestureDetector(
          onTap: () => setState(() { _selectedGroup = e.key; _searchCtrl.clear(); _query = ''; }),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                  ),
                  child: Icon(e.value.icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(e.value.label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                      Text('${kMassExerciseNames[e.key]?.length ?? 0} hareket',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExerciseList() {
    final items = _filtered;
    if (items.isEmpty) {
      return const Center(child: Text('Egzersiz bulunamadı', style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final ex = items[i];
        final color = kMuscleGroupInfo[ex.group]?.color ?? Colors.grey;
        return ListTile(
          dense: true,
          leading: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
            child: Icon(kMuscleGroupInfo[ex.group]?.icon ?? Icons.fitness_center, color: color, size: 16),
          ),
          title: Text(ex.name, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
          subtitle: Text(kMuscleGroupInfo[ex.group]?.label ?? ex.group,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5)),
          onTap: () { HapticFeedback.selectionClick(); setState(() => _selected = ex); },
        );
      },
    );
  }

  Widget _buildConfig() {
    final color = kMuscleGroupInfo[_selected!.group]?.color ?? Colors.green;
    final label = kMuscleGroupInfo[_selected!.group]?.label ?? _selected!.group;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Muscle badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(kMuscleGroupInfo[_selected!.group]?.icon ?? Icons.fitness_center, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Sets & Reps
          Row(
            children: [
              Expanded(child: _CounterBlock(label: 'Set', value: _sets, min: 1, max: 20, onChanged: (v) => setState(() => _sets = v))),
              const SizedBox(width: 14),
              Expanded(child: _CounterBlock(label: 'Tekrar', value: _reps, min: 1, max: 100, onChanged: (v) => setState(() => _reps = v))),
            ],
          ),
          const SizedBox(height: 24),

          // Rest time
          Row(children: [
            Container(width: 3, height: 14, decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('Dinlenme Süresi', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _restOptions.map((opt) {
              final sel = _restSeconds == opt.s;
              return GestureDetector(
                onTap: () => setState(() => _restSeconds = opt.s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? _kGreen.withValues(alpha: 0.18) : _kSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? _kGreen.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.07), width: sel ? 1.5 : 1),
                  ),
                  child: Column(
                    children: [
                      Text(opt.label, style: TextStyle(color: sel ? _kGreen : Colors.white60, fontSize: 13, fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
                      Text(opt.desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Note
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Not ekle (opsiyonel)',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28), fontSize: 13),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white30, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kGreen, width: 1.5)),
            ),
          ),
          const SizedBox(height: 24),

          // Add button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.pop(context, ProgramExercise(
                name: _selected!.name,
                muscleGroup: _selected!.group,
                sets: _sets,
                reps: _reps,
                restSeconds: _restSeconds,
                note: _noteCtrl.text.trim(),
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF1B8A3A)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Egzersizi Ekle', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Counter block (sets/reps)
// ─────────────────────────────────────────────────────────────────────────────

class _CounterBlock extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _CounterBlock({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleBtn(icon: Icons.remove, active: value > min, onTap: value > min ? () => onChanged(value - 1) : null),
              Text('$value', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              _CircleBtn(icon: Icons.add, active: value < max, onTap: value < max ? () => onChanged(value + 1) : null),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _CircleBtn({required this.icon, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: active ? _kGreen.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: active ? _kGreen.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Icon(icon, color: active ? _kGreen : Colors.white24, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search field
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Egzersiz ara...',
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
