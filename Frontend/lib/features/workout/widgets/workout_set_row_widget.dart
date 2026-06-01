import 'dart:async';
import 'package:flutter/material.dart';
import '../services/progression_engine.dart';

// Set tipleri
const kSetTypes = ['Isınma', 'Normal', 'Drop-Set', 'Failure'];

class SetEntry {
  final TextEditingController weightC;
  final TextEditingController repsC;
  String setType;
  bool isDone;
  int rpe;

  SetEntry()
    : weightC = TextEditingController(),
      repsC = TextEditingController(),
      setType = 'Normal',
      isDone = false,
      rpe = 7;

  SetEntry.fromValues(String weight, String reps, {String type = 'Normal'})
    : weightC = TextEditingController(text: weight),
      repsC = TextEditingController(text: reps),
      setType = type,
      isDone = false,
      rpe = 7;

  void dispose() {
    weightC.dispose();
    repsC.dispose();
  }
}

class WorkoutSetRow extends StatefulWidget {
  final int index;
  final SetEntry setEntry;
  final Color accentColor;
  final bool isLast;
  final VoidCallback onToggleDone;
  final VoidCallback onSetTypeChanged;
  final VoidCallback onCopyNextClicked;
  final VoidCallback onRpeChanged;
  final VoidCallback onChanged;

  const WorkoutSetRow({
    super.key,
    required this.index,
    required this.setEntry,
    required this.accentColor,
    required this.isLast,
    required this.onToggleDone,
    required this.onSetTypeChanged,
    required this.onCopyNextClicked,
    required this.onRpeChanged,
    required this.onChanged,
  });

  @override
  State<WorkoutSetRow> createState() => _WorkoutSetRowState();
}

class _WorkoutSetRowState extends State<WorkoutSetRow> {
  static const _card = Color(0xFF0E1318);
  static const _cardBorder = Color(0xFF1C2530);

  @override
  void initState() {
    super.initState();
    widget.setEntry.weightC.addListener(_onFieldChanged);
    widget.setEntry.repsC.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    widget.setEntry.weightC.removeListener(_onFieldChanged);
    widget.setEntry.repsC.removeListener(_onFieldChanged);
    super.dispose();
  }

  void _onFieldChanged() {
    widget.onChanged();
  }

  Widget _buildStepper({
    required String label,
    required TextEditingController controller,
    required double step,
    required bool isDecimal,
  }) {
    void change(double delta) {
      if (!mounted) return;
      final raw = controller.text.trim().replaceAll(',', '.');
      final current = double.tryParse(raw) ?? 0.0;
      final next = (current + delta).clamp(0.0, 999.0);
      setState(() {
        controller.text = isDecimal
            ? (next % 1 == 0 ? next.toStringAsFixed(1) : next.toString())
            : next.toInt().toString();
      });
      widget.onChanged();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).toInt())),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withAlpha((0.4 * 255).toInt()),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: () => change(-step),
                onLongPress: () {
                  Timer.periodic(const Duration(milliseconds: 120), (t) {
                    if (!mounted) {
                      t.cancel();
                      return;
                    }
                    change(-step);
                    if (t.tick > 20) t.cancel();
                  });
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.07 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white70,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IntrinsicWidth(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 40),
                  child: TextField(
                    controller: controller,
                    keyboardType: isDecimal
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => change(step),
                onLongPress: () {
                  Timer.periodic(const Duration(milliseconds: 120), (t) {
                    if (!mounted) {
                      t.cancel();
                      return;
                    }
                    change(step);
                    if (t.tick > 20) t.cancel();
                  });
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withAlpha((0.2 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, color: widget.accentColor, size: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.setEntry;
    final accent = widget.accentColor;
    
    Color typeColor = accent;
    if (s.setType == 'Isınma') typeColor = Colors.amber;
    if (s.setType == 'Drop-Set') typeColor = Colors.deepOrangeAccent;
    if (s.setType == 'Failure') typeColor = Colors.redAccent;
    
    final bool isSpecialSet = s.setType != 'Normal';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: s.isDone ? typeColor.withAlpha((0.09 * 255).toInt()) : (isSpecialSet ? typeColor.withAlpha((0.03 * 255).toInt()) : _card),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: s.isDone ? typeColor.withAlpha((0.4 * 255).toInt()) : (isSpecialSet ? typeColor.withAlpha((0.15 * 255).toInt()) : _cardBorder),
          width: s.isDone ? 1.5 : 1,
        ),
        boxShadow: s.isDone || isSpecialSet
            ? [
                BoxShadow(
                  color: typeColor.withAlpha((s.isDone ? 0.1 * 255 : 0.05 * 255).toInt()),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: s.isDone ? typeColor : typeColor.withAlpha((0.13 * 255).toInt()),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: s.isDone
                      ? [BoxShadow(color: typeColor.withAlpha((0.35 * 255).toInt()), blurRadius: 8)]
                      : null,
                ),
                child: Center(
                  child: s.isDone
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : Text(
                          '${widget.index + 1}',
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: kSetTypes.map((type) {
                      final sel = s.setType == type;
                      return GestureDetector(
                        onTap: () {
                          setState(() => s.setType = type);
                          widget.onSetTypeChanged();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel ? typeColor.withAlpha((0.25 * 255).toInt()) : Colors.white.withAlpha((0.05 * 255).toInt()),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? typeColor : Colors.white.withAlpha((0.1 * 255).toInt()),
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.white38,
                              fontSize: 10,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onToggleDone,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: s.isDone ? typeColor : Colors.white.withAlpha((0.06 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.isDone ? 'Tamam ✓' : 'Tamam',
                    style: TextStyle(
                      color: s.isDone ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildStepper(label: 'tekrar', controller: s.repsC, step: 1, isDecimal: false),
                    const SizedBox(height: 10),
                    _buildStepper(label: 'kg', controller: s.weightC, step: 2.5, isDecimal: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) {
                      final w = double.tryParse(s.weightC.text.replaceAll(',', '.')) ?? 0;
                      final r = int.tryParse(s.repsC.text) ?? 0;
                      final oneRm = ProgressionEngine.calculate1RM(w, r);
                      if (oneRm <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withAlpha((0.3 * 255).toInt())),
                        ),
                        child: Text(
                          '1RM: ${oneRm.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                  ),
                  if (!widget.isLast)
                    GestureDetector(
                      onTap: widget.onCopyNextClicked,
                      child: Tooltip(
                        message: 'Sonraki sete kopyala',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: typeColor.withAlpha((0.12 * 255).toInt()),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: typeColor.withAlpha((0.3 * 255).toInt())),
                          ),
                          child: Icon(Icons.arrow_downward_rounded, color: typeColor, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.03 * 255).toInt()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha((0.06 * 255).toInt())),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu seti nasıl hissettin?',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.45 * 255).toInt()),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(10, (i) {
                    final val = i + 1;
                    final sel = s.rpe == val;
                    return GestureDetector(
                      onTap: () {
                        setState(() => s.rpe = val);
                        widget.onRpeChanged();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel ? _rpeColor(val) : Colors.white.withAlpha((0.04 * 255).toInt()),
                          boxShadow: sel
                              ? [BoxShadow(color: _rpeColor(val).withAlpha((0.5 * 255).toInt()), blurRadius: 6)]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$val',
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.white54,
                              fontSize: 11,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _rpeColor(int rpe) {
    if (rpe <= 5) return Colors.greenAccent.shade400;
    if (rpe == 6) return Colors.lightGreenAccent;
    if (rpe == 7) return Colors.yellow;
    if (rpe == 8) return Colors.orange;
    if (rpe == 9) return Colors.deepOrangeAccent;
    return Colors.redAccent;
  }
}
