import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_coach_models.dart';
import '../../tasks/models/daily_task.dart';
import 'coach_premium_panel.dart';

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
    final itemCount = _itemCount(advice);

    return CoachPremiumPanel(
      baseColor: const Color(0xFF121D36),
      edgeColor: const Color(0xFF38507C),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7EA8FF).withValues(alpha: 0.38),
                        const Color(0xFF7EA8FF).withValues(alpha: 0.06),
                      ],
                    ),
                    border: Border.all(color: const Color(0xFF8FB3FA)),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: Color(0xFFC6D9FF),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Oneriler',
                  style: GoogleFonts.cormorantGaramond(
                    color: const Color(0xFFF3ECD7),
                    fontWeight: FontWeight.w700,
                    fontSize: 27,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFF14223E),
                    border: Border.all(color: const Color(0xFF3B5688)),
                  ),
                  child: Text(
                    '$itemCount madde',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFD9E5FF),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(99)),
                minHeight: 6,
                color: Color(0xFFEAB95E),
                backgroundColor: Color(0xFF2A3A59),
              ),
            ),
          if (showCooldown)
            _CooldownBar(secondsRemaining: cooldown)
          else if (hasError)
            _ErrorBar(
              message: errorMessage!,
              canRetry: canRetry,
              onRetry: onRetry,
              showLoginButton: showLoginButton,
              onLoginRequired: onLoginRequired,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: 'Bugunun Odagi'),
                const SizedBox(height: 8),
                _SingleAdviceCard(title: 'Odak', content: advice.focus),
                const SizedBox(height: 12),
                const _SectionHeader(title: 'Yapilacaklar'),
                const SizedBox(height: 8),
                if (advice.actions.isEmpty)
                  const _EmptyAdviceCard()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: advice.actions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final action = advice.actions[index];
                      final task =
                          plannedActionsByTitle[DailyTask.normalizeTitle(
                            action,
                          )];
                      return _ActionSuggestionCard(
                        index: index + 1,
                        action: action,
                        task: task,
                        onAddToPlan: onAddActionToPlan,
                        onToggleDone: onToggleActionTaskDone,
                      );
                    },
                  ),
                const SizedBox(height: 12),
                const _SectionHeader(title: 'Beslenme Notu'),
                const SizedBox(height: 8),
                _SingleAdviceCard(title: 'Not', content: advice.nutritionNote),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _itemCount(CoachAdviceView advice) {
  var count = advice.actions.length;
  if (advice.focus.trim().isNotEmpty) {
    count += 1;
  }
  if (advice.nutritionNote.trim().isNotEmpty) {
    count += 1;
  }
  return count;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        color: const Color(0xFFE6EEFF),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }
}

class _SingleAdviceCard extends StatelessWidget {
  const _SingleAdviceCard({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final normalized = content.trim();
    if (normalized.isEmpty) {
      return const _EmptyAdviceCard();
    }
    return _SuggestionBubble(
      item: CoachSuggestion(title: title, description: normalized),
    );
  }
}

class _EmptyAdviceCard extends StatelessWidget {
  const _EmptyAdviceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0D1428),
        border: Border.all(color: const Color(0xFF2F4673)),
      ),
      child: Text(
        'Henuz yok',
        style: GoogleFonts.dmSans(
          color: const Color(0xFFC8D6F0),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CooldownBar extends StatelessWidget {
  const _CooldownBar({required this.secondsRemaining});

  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E283F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4C6DA5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: Color(0xFFB7D3FF),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rate limit. ${secondsRemaining}s sonra tekrar deneyebilirsin.',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFD8E7FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            borderRadius: BorderRadius.all(Radius.circular(99)),
            minHeight: 4,
            color: Color(0xFF8CB5FF),
            backgroundColor: Color(0xFF2F4267),
          ),
        ],
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF311B25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF73384A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFCA5A5),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                color: const Color(0xFFFDB6B6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showLoginButton && onLoginRequired != null)
            TextButton(
              onPressed: onLoginRequired,
              child: Text(
                'Giris yap',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF90D7AE),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (canRetry && onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Tekrar dene',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF90D7AE),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionSuggestionCard extends StatelessWidget {
  const _ActionSuggestionCard({
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
    final isInPlan = task != null;
    final title = 'Aksiyon $index';

    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A2A48).withValues(alpha: 0.97),
            const Color(0xFF121F38).withValues(alpha: 0.97),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF3F5E96)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFF4F7FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: isInPlan || onAddToPlan == null
                    ? null
                    : () => onAddToPlan!(action),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  foregroundColor: const Color(0xFFAED0FF),
                  disabledForegroundColor: const Color(0xFFB8D5FF),
                  side: const BorderSide(color: Color(0xFF4368A8)),
                  textStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                child: Text(isInPlan ? 'Plan\'da \u2705' : 'Plan\'a ekle'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action,
            style: GoogleFonts.dmSans(
              color: const Color(0xFFD4E0F8),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: task?.isDone ?? false,
                onChanged: isInPlan && onToggleDone != null
                    ? (_) => onToggleDone!(task!.id)
                    : null,
              ),
              Text(
                isInPlan ? 'Gorev tamamlandi' : 'Once plan\'a ekle',
                style: GoogleFonts.dmSans(
                  color: isInPlan
                      ? const Color(0xFFBED5FF)
                      : const Color(0xFF8AA1CC),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF112444),
                  border: Border.all(color: const Color(0xFF3F5E96)),
                ),
                child: IconButton(
                  tooltip: 'Kopyala',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: Color(0xFFAAC6FF),
                    size: 17,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: '$title: $action'),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Oneri panoya kopyalandi.')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionBubble extends StatelessWidget {
  const _SuggestionBubble({required this.item});

  final CoachSuggestion item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A2A48).withValues(alpha: 0.97),
            const Color(0xFF121F38).withValues(alpha: 0.97),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF3F5E96)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            margin: const EdgeInsets.only(top: 2, bottom: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [Color(0xFFE6BC70), Color(0xFF8AB4F8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFF4F7FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFD4E0F8),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF112444),
              border: Border.all(color: const Color(0xFF3F5E96)),
            ),
            child: IconButton(
              tooltip: 'Kopyala',
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.copy_rounded,
                color: Color(0xFFAAC6FF),
                size: 17,
              ),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${item.title}: ${item.description}'),
                );
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Oneri panoya kopyalandi.')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
