import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/services/water_reminder_service.dart';

// ── Okyanus paleti — parlak değil, derin ve şık ──────────────────────────────
const _kOcean1 = Color(0xFF061118); // kart bg üst
const _kOcean2 = Color(0xFF0B1D2E); // kart bg alt
const _kDeep = Color(0xFF1A4E6E); // derin mavi
const _kMid = Color(0xFF2E7DAD); // orta mavi
const _kSurface = Color(0xFF6DB8D9); // yüzey / açık mavi
const _kDone = Color(0xFF3DBF8A); // tamamlandı — yeşil

class WaterTracker extends StatefulWidget {
  const WaterTracker({
    super.key,
    required this.currentGlasses,
    required this.onChanged,
    this.goalGlasses = 10,
    this.onGoalTap,
  });

  final int currentGlasses;
  final int goalGlasses;
  final Function(int) onChanged;
  final VoidCallback? onGoalTap;

  @override
  State<WaterTracker> createState() => _WaterTrackerState();
}

class _WaterTrackerState extends State<WaterTracker>
    with SingleTickerProviderStateMixin {
  bool _reminderEnabled = false;
  int _intervalHours = 2;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _loadReminderState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReminderState() async {
    final enabled = await WaterReminderService.instance.isEnabled();
    final interval = await WaterReminderService.instance.getIntervalHours();
    if (mounted) {
      setState(() {
        _reminderEnabled = enabled;
        _intervalHours = interval;
      });
    }
  }

  Future<void> _toggleReminder(bool newState) async {
    await WaterReminderService.instance.setEnabled(newState);
    if (mounted) {
      setState(() => _reminderEnabled = newState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState ? 'Su hatırlatıcı $_intervalHours saatte bir olarak ayarlandı 💧' : 'Su hatırlatıcı kapatıldı',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: newState ? _kMid : Colors.grey[800],
        ),
      );
    }
  }

  Future<void> _pickReminderInterval() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0B1D2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Su hatırlatma aralığı',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (final hours in [0, 1, 2, 3, 4])
                ListTile(
                  onTap: () => Navigator.pop(ctx, hours),
                  leading: Icon(
                    hours == 0 ? Icons.notifications_off_rounded : Icons.schedule_rounded,
                    color: (hours == 0 && !_reminderEnabled) || (hours != 0 && _reminderEnabled && hours == _intervalHours) ? _kSurface : Colors.white38,
                  ),
                  title: Text(
                    hours == 0 ? 'Kapalı' : '$hours saatte bir',
                    style: TextStyle(
                      color: (hours == 0 && !_reminderEnabled) ? Colors.white54 : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: (hours == 0 && !_reminderEnabled) || (hours != 0 && _reminderEnabled && hours == _intervalHours)
                      ? const Icon(Icons.check_rounded, color: _kSurface)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;
    
    if (selected == 0) {
      await _toggleReminder(false);
    } else {
      await WaterReminderService.instance.setIntervalHours(selected);
      if (mounted) {
        setState(() => _intervalHours = selected);
      }
      await _toggleReminder(true);
    }
  }

  void _setGlasses(int value) {
    widget.onChanged(value.clamp(0, widget.goalGlasses));
  }

  @override
  Widget build(BuildContext context) {
    final currentMl = widget.currentGlasses * 250;
    final goalMl = widget.goalGlasses * 250;
    final progress = widget.goalGlasses <= 0
        ? 0.0
        : (widget.currentGlasses / widget.goalGlasses).clamp(0.0, 1.0);
    final isDone = widget.currentGlasses >= widget.goalGlasses;
    final remainingL = ((goalMl - currentMl).clamp(0, goalMl) / 1000)
        .toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kOcean1, _kOcean2],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kDeep.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF051018).withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kDeep.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _kMid.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: _kSurface,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Su Takibi',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      isDone ? '✓ Hedef tamamlandı' : '$remainingL L kaldı',
                      style: TextStyle(
                        color: isDone ? _kDone : _kSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _Chip(
                icon: _reminderEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                color: _reminderEnabled ? _kSurface : Colors.white30,
                label: _reminderEnabled ? '${_intervalHours}s' : null,
                onTap: _pickReminderInterval,
              ),
              const SizedBox(width: 6),
              _Chip(
                icon: Icons.tune_rounded,
                color: _kSurface.withValues(alpha: 0.7),
                onTap: widget.onGoalTap,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Amount + progress ────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${(currentMl / 1000).toStringAsFixed(1)} L',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '/ ${(goalMl / 1000).toStringAsFixed(1)} L',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone
                      ? _kDone.withValues(alpha: 0.12)
                      : _kDeep.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDone
                        ? _kDone.withValues(alpha: 0.3)
                        : _kMid.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${widget.currentGlasses}/${widget.goalGlasses} bardak',
                  style: TextStyle(
                    color: isDone ? _kDone : _kSurface,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Dalga progress bar ───────────────────────────────────────────
          SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (context, _) => ClipPath(
                    clipper: _WaveClipper(
                      progress: progress,
                      phase: _waveCtrl.value * 2 * math.pi,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDone
                              ? [_kDone.withValues(alpha: 0.85), const Color(0xFF1A9B60)]
                              : [_kSurface.withValues(alpha: 0.75), _kDeep],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Su damlası ikonları ──────────────────────────────────────────
          SizedBox(
            height: 22,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.goalGlasses,
              separatorBuilder: (context, i) => const SizedBox(width: 3),
              itemBuilder: (context, index) {
                final isFilled = index < widget.currentGlasses;
                return GestureDetector(
                  onTap: () {
                    final tapped = index + 1;
                    _setGlasses(
                      widget.currentGlasses == tapped ? index : tapped,
                    );
                  },
                  child: AnimatedScale(
                    scale: isFilled ? 1.0 : 0.85,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: isFilled ? 1.0 : 0.2,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isFilled
                            ? Icons.water_drop_rounded
                            : Icons.water_drop_outlined,
                        color: isFilled ? _kSurface : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // ── Butonlar ─────────────────────────────────────────────────────
          Row(
            children: [
              _WaterBtn(
                icon: Icons.remove_rounded,
                label: '−1',
                onTap: () => _setGlasses(widget.currentGlasses - 1),
                style: _BtnStyle.danger,
              ),
              const SizedBox(width: 6),
              _WaterBtn(
                icon: Icons.add_rounded,
                label: '+1 bardak',
                onTap: () => _setGlasses(widget.currentGlasses + 1),
                style: _BtnStyle.primary,
              ),
              const SizedBox(width: 6),
              _WaterBtn(
                icon: Icons.local_drink_rounded,
                label: '+500 ml',
                onTap: () => _setGlasses(widget.currentGlasses + 2),
                style: _BtnStyle.ghost,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dalga clipper ─────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  const _WaveClipper({required this.progress, required this.phase});

  final double progress;
  final double phase;

  @override
  Path getClip(Size size) {
    if (progress <= 0) return Path();
    final fillX = size.width * progress;
    final path = Path()..moveTo(0, 0);

    // Dalga kenarı
    for (double y = 0; y <= size.height; y++) {
      final x = fillX + math.sin(y / size.height * math.pi * 3 + phase) * 3.5;
      path.lineTo(x, y);
    }

    path
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) =>
      old.progress != progress || old.phase != phase;
}

// ── Buton ─────────────────────────────────────────────────────────────────────

enum _BtnStyle { primary, ghost, danger }

class _WaterBtn extends StatelessWidget {
  const _WaterBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.style,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _BtnStyle style;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    final Color border;

    switch (style) {
      case _BtnStyle.primary:
        fg = Colors.white;
        bg = _kMid.withValues(alpha: 0.55);
        border = _kSurface.withValues(alpha: 0.3);
      case _BtnStyle.danger:
        fg = const Color(0xFFEF9A9A);
        bg = const Color(0xFF3B0F0F);
        border = const Color(0xFF7B2020).withValues(alpha: 0.5);
      case _BtnStyle.ghost:
        fg = _kSurface.withValues(alpha: 0.8);
        bg = _kDeep.withValues(alpha: 0.3);
        border = _kDeep.withValues(alpha: 0.5);
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Üst ikon chip ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.color,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 9 : 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
