import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../tasks/models/daily_task.dart';
import '../models/ai_coach_models.dart';

class SuggestionList extends StatelessWidget {
  const SuggestionList({
    super.key,
    required this.advice,
    this.isLoading = false,
    this.errorMessage,
    this.canRetry = false,
    this.onRetry,
    this.showLoginButton = false,
    this.onLoginRequired,
    this.cooldownSecondsRemaining,
    this.plannedActionsByTitle = const <String, DailyTask>{},
    this.onAddActionToPlan,
    this.onToggleActionTaskDone,
  });

  final CoachAdviceView advice;
  final bool isLoading;
  final String? errorMessage;
  final bool canRetry;
  final VoidCallback? onRetry;
  final bool showLoginButton;
  final VoidCallback? onLoginRequired;
  final int? cooldownSecondsRemaining;
  final Map<String, DailyTask> plannedActionsByTitle;
  final ValueChanged<String>? onAddActionToPlan;
  final ValueChanged<String>? onToggleActionTaskDone;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && errorMessage!.trim().isNotEmpty;
    final cooldown = cooldownSecondsRemaining;
    final showCooldown = cooldown != null && cooldown > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koç önerileri',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Odak, yapılacaklar ve beslenme notları burada görünür.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Text(
                  '${_itemCount(advice)} madde',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(
              minHeight: 4,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ],
          if (showCooldown) ...[
            const SizedBox(height: 14),
            _InlineMessage(
              icon: Icons.timer_outlined,
              text: 'Tekrar denemek için ${cooldown}s bekle.',
            ),
          ] else if (hasError) ...[
            const SizedBox(height: 14),
            _ErrorMessage(
              message: errorMessage!,
              canRetry: canRetry,
              onRetry: onRetry,
              showLoginButton: showLoginButton,
              onLoginRequired: onLoginRequired,
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Bugünün odağı',
            child: _InfoBlock(
              text: advice.focus.trim().isEmpty ? 'Henüz oluşturulmadı.' : advice.focus,
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Yapılacaklar',
            child: advice.actions.isEmpty
                ? const _InfoBlock(text: 'Henüz öneri yok.')
                : Column(
                    children: advice.actions
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.key == advice.actions.length - 1 ? 0 : 10,
                            ),
                            child: _ActionRow(
                              index: entry.key + 1,
                              action: entry.value,
                              task: plannedActionsByTitle[
                                  DailyTask.normalizeTitle(entry.value)],
                              onAddToPlan: onAddActionToPlan,
                              onToggleDone: onToggleActionTaskDone,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Beslenme notu',
            child: _InfoBlock(
              text: advice.nutritionNote.trim().isEmpty
                  ? 'Henüz not yok.'
                  : advice.nutritionNote,
            ),
          ),
        ],
      ),
    );
  }
}

int _itemCount(CoachAdviceView advice) {
  var count = advice.actions.length;
  if (advice.focus.trim().isNotEmpty) count += 1;
  if (advice.nutritionNote.trim().isNotEmpty) count += 1;
  return count;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        color: Colors.white.withValues(alpha: 0.74),
        fontSize: 13,
        height: 1.45,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.index,
    required this.action,
    required this.task,
    required this.onAddToPlan,
    required this.onToggleDone,
  });

  final int index;
  final String action;
  final DailyTask? task;
  final ValueChanged<String>? onAddToPlan;
  final ValueChanged<String>? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final isPlanned = task != null;
    final isDone = task?.isDone ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF73A7FF).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$index',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF73A7FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isPlanned && onAddToPlan != null)
            TextButton(
              onPressed: () => onAddToPlan!(action),
              child: const Text('Ekle'),
            )
          else if (isPlanned && onToggleDone != null)
            IconButton(
              onPressed: () => onToggleDone!(task!.id),
              icon: Icon(
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isDone ? const Color(0xFF53D3B4) : Colors.white.withValues(alpha: 0.52),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF0B54C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.showLoginButton,
    required this.onLoginRequired,
  });

  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;
  final bool showLoginButton;
  final VoidCallback? onLoginRequired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1318),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B2831)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (canRetry || showLoginButton) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (canRetry && onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Tekrar dene'),
                  ),
                if (showLoginButton && onLoginRequired != null)
                  TextButton(
                    onPressed: onLoginRequired,
                    child: const Text('Giriş yap'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
