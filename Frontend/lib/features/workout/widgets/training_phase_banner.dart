import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/training_phase.dart';
import '../services/training_phase_service.dart';

class TrainingPhaseBanner extends StatefulWidget {
  const TrainingPhaseBanner({super.key});

  @override
  State<TrainingPhaseBanner> createState() => _TrainingPhaseBannerState();
}

class _TrainingPhaseBannerState extends State<TrainingPhaseBanner> {
  final _service = TrainingPhaseService();
  TrainingPhase _phase = TrainingPhase.hypertrophy;
  DateTime? _startDate;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final phase = await _service.loadPhase();
    final start = await _service.loadStartDate();
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _startDate = start;
    });
  }

  Future<void> _selectPhase(TrainingPhase phase) async {
    await _service.savePhase(phase);
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _startDate = DateTime.now();
      _expanded = false;
    });
  }

  int get _weekNumber {
    if (_startDate == null) return 1;
    return (DateTime.now().difference(_startDate!).inDays / 7).floor() + 1;
  }

  @override
  Widget build(BuildContext context) {
    final info = kPhaseInfo[_phase]!;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: info.color.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: info.color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Özet satır ──
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    info.color.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(18),
                  bottom: Radius.circular(_expanded ? 0 : 18),
                ),
              ),
              child: Row(
                children: [
                  Text(info.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              info.label,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: info.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: info.color.withValues(alpha: 0.30),
                                ),
                              ),
                              child: Text(
                                'H$_weekNumber',
                                style: TextStyle(
                                  color: info.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${info.sets} set  •  ${info.reps} tekrar  •  ${info.intensity}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.50),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.40),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Genişletilmiş içerik ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _ExpandedContent(
              currentPhase: _phase,
              onSelect: _selectPhase,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  final TrainingPhase currentPhase;
  final ValueChanged<TrainingPhase> onSelect;

  const _ExpandedContent({
    required this.currentPhase,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final info = kPhaseInfo[currentPhase]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Text(
            info.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),

        // Faz seçici
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fazı değiştir',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrainingPhase.values.map((phase) {
                  final pInfo = kPhaseInfo[phase]!;
                  final selected = phase == currentPhase;
                  return GestureDetector(
                    onTap: () => onSelect(phase),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? pInfo.color.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? pInfo.color.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.08),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pInfo.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pInfo.label,
                                style: TextStyle(
                                  color: selected
                                      ? pInfo.color
                                      : Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${pInfo.reps} × ${pInfo.sets}  ${pInfo.intensity}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.30),
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
