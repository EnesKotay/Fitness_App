import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/ai_coach_controller.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key, required this.controller});
  final AiCoachController controller;

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await widget.controller.getSessionHistory();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(date).inDays;
      if (diff == 0) return 'Bugün';
      if (diff == 1) return 'Dün';
      if (diff < 7) return '$diff gün önce';
      const months = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
      return '${date.day} ${months[date.month]}';
    } catch (_) {
      return dateStr;
    }
  }

  String _dayLabel(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return '';
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const weekdays = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return weekdays[date.weekday];
    } catch (_) {
      return '';
    }
  }

  Future<void> _openSession(Map<String, dynamic> session) async {
    final date = session['date'] as String? ?? '';
    if (date.isEmpty) return;

    await widget.controller.loadHistorySession(date);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _deleteSession(String date, int index) async {
    await widget.controller.deleteHistorySession(date);
    setState(() => _sessions.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sohbet Geçmişi',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_sessions.length} konuşma kaydedildi',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_sessions.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF111827),
                    title: Text('Tüm geçmişi sil?',
                        style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
                    content: Text('Bu işlem geri alınamaz.',
                        style: GoogleFonts.dmSans(color: Colors.white60)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Vazgeç', style: GoogleFonts.dmSans(color: Colors.white60)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Sil', style: GoogleFonts.dmSans(color: const Color(0xFFFF6B6B))),
                      ),
                    ],
                  ),
                );
                if (ok == true && mounted) {
                  for (final s in List.of(_sessions)) {
                    await widget.controller.deleteHistorySession(s['date'] as String? ?? '');
                  }
                  setState(() => _sessions.clear());
                }
              },
              child: Text(
                'Temizle',
                style: GoogleFonts.dmSans(color: const Color(0xFFFF6B6B), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEBC374)))
          : _sessions.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFEBC374).withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFEBC374), size: 32),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.07, 1.07), duration: 1800.ms),
          const SizedBox(height: 20),
          Text(
            'Henüz kaydedilmiş sohbet yok',
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'AI Koç ile sohbet ettikçe\nburada günlük olarak kaydedilir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: Colors.white.withValues(alpha: 0.42), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final date = session['date'] as String? ?? '';
        final preview = session['preview'] as String? ?? '';
        final count = int.tryParse(session['count']?.toString() ?? '0') ?? 0;
        final turns = (count / 2).ceil();
        final isToday = _formatDate(date) == 'Bugün';

        return Dismissible(
          key: ValueKey(date),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete_rounded, color: Color(0xFFFF6B6B), size: 22),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF111827),
                title: Text('Bu sohbeti sil?',
                    style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
                content: Text('"${_formatDate(date)}" tarihli konuşma silinecek.',
                    style: GoogleFonts.dmSans(color: Colors.white60)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Vazgeç', style: GoogleFonts.dmSans(color: Colors.white60)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Sil', style: GoogleFonts.dmSans(color: const Color(0xFFFF6B6B))),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => _deleteSession(date, index),
          child: GestureDetector(
            onTap: () => _openSession(session),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isToday
                      ? [const Color(0xFF1A2E42), const Color(0xFF0F1822)]
                      : [const Color(0xFF131D2D), const Color(0xFF0C1321)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isToday
                      ? const Color(0xFFEBC374).withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  // Date badge
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFFEBC374).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday
                            ? const Color(0xFFEBC374).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dayLabel(date),
                          style: GoogleFonts.dmSans(
                            color: isToday
                                ? const Color(0xFFEBC374)
                                : Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isToday ? 'Bugün' : _formatDate(date),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: isToday ? const Color(0xFFEBC374) : Colors.white,
                            fontSize: isToday ? 9 : 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isToday)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBC374).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Aktif',
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFFEBC374),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            Text(
                              '$turns konuşma turu',
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          preview.isNotEmpty ? '"$preview"' : 'Sohbet başlatıldı',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            fontStyle: preview.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: (index * 50).ms, duration: 300.ms)
                .slideX(begin: 0.05, end: 0, curve: Curves.easeOut),
          ),
        );
      },
    );
  }
}
