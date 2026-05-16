import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../../nutrition/domain/entities/meal_type.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../shell/main_shell.dart';
import '../controllers/ai_coach_controller.dart';
import '../models/ai_coach_models.dart';
import 'package:provider/provider.dart';
import 'ai_coach_widgets.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool? _reaction; // null = yok, true = 👍, false = 👎

  @override
  Widget build(BuildContext context) {
    final isAssistant = widget.message.role == ChatRole.assistant;
    final isError = widget.message.isError;
    final isSystemNote = widget.message.isSystemNote;

    // System notes: summary notes (long) → mini card; personality notes (short) → pill
    if (isSystemNote) {
      final isSummary = widget.message.content.length > 80;
      if (isSummary) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF121E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEBC374).withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.summarize_rounded, size: 13, color: Color(0xFFEBC374)),
                    const SizedBox(width: 6),
                    Text(
                      'Konuşma özeti',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFEBC374),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message.content.replaceFirst(RegExp(r'^📝 Önceki konuşma özeti:\n+'), ''),
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2540),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFEBC374).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  widget.message.content,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.95, 0.95)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: isAssistant
          ? _buildAssistantRow(context, isError)
          : _buildUserRow(context),
    );
  }

  Widget _buildAssistantRow(BuildContext context, bool isError) {
    final accentColor = isError
        ? const Color(0xFFFF6B6B)
        : const Color(0xFFEBC374);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar with subtle pulse glow
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring (animated)
            if (!isError)
              Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    begin: 0.9,
                    end: 1.1,
                    duration: 2400.ms,
                    curve: Curves.easeInOut,
                  ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isError
                      ? [const Color(0xFFFF6B6B), const Color(0xFFEF4444)]
                      : [const Color(0xFFEBC374), const Color(0xFFC88934)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.auto_awesome_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: !isError
                    ? () => _copyToClipboard(context, widget.message.content)
                    : null,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  decoration: BoxDecoration(
                    gradient: isError
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF141E30), Color(0xFF0F1822)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isError ? const Color(0xFF2A1318) : null,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: isError
                          ? const Color(0xFFFF6B6B).withValues(alpha: 0.2)
                          : const Color(0xFFEBC374).withValues(alpha: 0.12),
                    ),
                    boxShadow: isError
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(
                                0xFFEBC374,
                              ).withValues(alpha: 0.07),
                              blurRadius: 24,
                              spreadRadius: -4,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isError)
                          Container(
                            height: 2,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEBC374), Color(0xFF73D4FF)],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.message.imagePath != null)
                                _buildSentImage(context),
                              !isError
                                  ? _buildMarkdownContent()
                                  : _buildPlainContent(isError),
                              if (!isError &&
                                  widget.message.taskMode == 'nutrition')
                                _buildMacroRingChart(context),
                              if (!isError &&
                                  widget.message.structuredResponse?.actions !=
                                      null &&
                                  widget
                                      .message
                                      .structuredResponse!
                                      .actions!
                                      .isNotEmpty) ...[
                                for (final a in widget.message.structuredResponse!.actions!)
                                  if (a.type == 'ADD_FOOD' && a.data != null)
                                    SmartMealLogCard(actionData: a.data!)
                                  else if (a.type == 'SAVE_WORKOUT' && a.data != null)
                                    SmartWorkoutSaveCard(actionData: a.data!)
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: _buildActionButton(context, a),
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Timestamp + reactions row
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(widget.message.createdAt),
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isError) ...[
                      const SizedBox(width: 10),
                      _buildReactionButton(
                        icon: Icons.thumb_up_rounded,
                        isActive: _reaction == true,
                        activeColor: const Color(0xFF34D399),
                        onTap: () {
                          final next = _reaction == true ? null : true;
                          setState(() => _reaction = next);
                          if (next == true) {
                            context.read<AiCoachController>().sendFeedback(
                              widget.message,
                              isPositive: true,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildReactionButton(
                        icon: Icons.thumb_down_rounded,
                        isActive: _reaction == false,
                        activeColor: const Color(0xFFFF6B6B),
                        onTap: () {
                          final next = _reaction == false ? null : false;
                          setState(() => _reaction = next);
                          if (next == false) {
                            context.read<AiCoachController>().sendFeedback(
                              widget.message,
                              isPositive: false,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildReactionButton(
                        icon: Icons.copy_rounded,
                        isActive: false,
                        activeColor: const Color(0xFF73D4FF),
                        onTap: () =>
                            _copyToClipboard(context, widget.message.content),
                      ),
                    ],
                  ],
                ),
              ),
              // Reaction feedback badge
              if (_reaction != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child:
                      Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (_reaction!
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFFFF6B6B))
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    (_reaction!
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFFFF6B6B))
                                        .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              _reaction!
                                  ? 'Geri bildirim için teşekkürler!'
                                  : 'Daha iyi olacağız.',
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 200.ms)
                          .slideY(begin: 0.3, end: 0),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 12,
          color: isActive ? activeColor : Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildUserRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onLongPress: () => _copyToClipboard(context, widget.message.content),
                child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A4580), Color(0xFF2B6CB0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2B6CB0).withValues(alpha: 0.28),
                      blurRadius: 18,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.message.imagePath != null)
                      _buildSentImage(context),
                    Text(
                      widget.message.content,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 2),
                child: Text(
                  _formatTime(widget.message.createdAt),
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdownContent() {
    // \n → markdown hard line break (two spaces + newline)
    final data = widget.message.content.replaceAll('\n', '  \n');
    return MarkdownBody(
      data: data,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 15,
          height: 1.7,
          fontWeight: FontWeight.w400,
        ),
        strong: GoogleFonts.dmSans(
          color: const Color(0xFFEBC374),
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        em: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.75),
          fontStyle: FontStyle.italic,
          fontSize: 15,
        ),
        listBullet: GoogleFonts.dmSans(
          color: const Color(0xFFEBC374),
          fontSize: 15,
        ),
        blockquote: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
        h1: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        h2: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
        ),
        h3: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        code: GoogleFonts.dmMono(
          color: const Color(0xFFEBC374),
          backgroundColor: Colors.black26,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
        blockSpacing: 6,
        pPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildMacroRingChart(BuildContext context) {
    final diet = context.read<DietProvider>();
    final p = diet.totals.totalProtein;
    final c = diet.totals.totalCarb;
    final f = diet.totals.totalFat;
    final total = p + c + f;
    if (total < 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 18,
                  sections: [
                    PieChartSectionData(
                      value: p,
                      color: const Color(0xFF34D399),
                      radius: 10,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: c,
                      color: const Color(0xFF73D4FF),
                      radius: 10,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: f,
                      color: const Color(0xFFEBC374),
                      radius: 10,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugünkü Makrolar',
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _macroRow('Protein', p, const Color(0xFF34D399), 'g'),
                  const SizedBox(height: 3),
                  _macroRow('Karb', c, const Color(0xFF73D4FF), 'g'),
                  const SizedBox(height: 3),
                  _macroRow('Yağ', f, const Color(0xFFEBC374), 'g'),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _macroRow(String label, double value, Color color, String unit) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
          ),
        ),
        const Spacer(),
        Text(
          '${value.round()}$unit',
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPlainContent(bool isError) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isError)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.8),
            ),
          ),
        Flexible(
          child: Text(
            widget.message.content,
            style: GoogleFonts.dmSans(
              color: isError
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, CoachAction action) {
    final (color, bgColor) = _getActionColors(action.type);
    return InkWell(
      onTap: () => _handleAction(context, action),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              bgColor.withValues(alpha: 0.18),
              bgColor.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _getActionIcon(action.type, color),
            const SizedBox(width: 8),
            Text(
              action.label,
              style: GoogleFonts.dmSans(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _getActionColors(String type) {
    switch (type) {
      case 'ADD_FOOD':
        return (const Color(0xFF81C784), const Color(0xFF388E3C));
      case 'START_WORKOUT':
      case 'SAVE_WORKOUT':
        return (const Color(0xFF34D399), const Color(0xFF34D399));
      case 'ADD_WATER':
        return (const Color(0xFF73D4FF), const Color(0xFF4FACFE));
      case 'TRACK_WEIGHT':
        return (const Color(0xFFBC74EB), const Color(0xFFBC74EB));
      case 'OPEN_NUTRITION':
      case 'UPDATE_NUTRITION':
        return (const Color(0xFFEBC374), const Color(0xFFEBC374));
      case 'OPEN_TRACKING':
        return (const Color(0xFF73D4FF), const Color(0xFF4FACFE));
      default:
        return (const Color(0xFFEBC374), const Color(0xFFEBC374));
    }
  }

  Icon _getActionIcon(String type, Color color) {
    switch (type) {
      case 'ADD_FOOD':
        return Icon(Icons.add_circle_outline_rounded, size: 15, color: color);
      case 'START_WORKOUT':
        return Icon(Icons.play_arrow_rounded, size: 15, color: color);
      case 'SAVE_WORKOUT':
        return Icon(Icons.fitness_center_rounded, size: 15, color: color);
      case 'ADD_WATER':
        return Icon(Icons.water_drop_rounded, size: 15, color: color);
      case 'TRACK_WEIGHT':
        return Icon(Icons.monitor_weight_rounded, size: 15, color: color);
      case 'OPEN_NUTRITION':
        return Icon(Icons.restaurant_menu_rounded, size: 15, color: color);
      case 'UPDATE_NUTRITION':
        return Icon(Icons.tune_rounded, size: 15, color: color);
      case 'OPEN_TRACKING':
        return Icon(Icons.insights_rounded, size: 15, color: color);
      default:
        return Icon(Icons.launch_rounded, size: 15, color: color);
    }
  }

  void _handleAction(BuildContext context, CoachAction action) {
    switch (action.type) {
      case 'ADD_FOOD':
        _handleFoodAdd(context, action.data);
        break;
      case 'START_WORKOUT':
        _switchToMainTab(context, 1);
        break;
      case 'ADD_WATER':
        context.read<DietProvider>().addWater(0.25);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('250ml su eklendi! 💧')));
        break;
      case 'TRACK_WEIGHT':
        _switchToMainTab(context, 2);
        break;
      case 'OPEN_NUTRITION':
        _switchToMainTab(context, 3);
        break;
      case 'OPEN_TRACKING':
        _switchToMainTab(context, 2);
        break;
      case 'UPDATE_NUTRITION':
        _handleNutritionUpdate(context, action.data);
        break;
      case 'SAVE_WORKOUT':
        _handleWorkoutSave(context, action.data);
        break;
    }
  }

  void _switchToMainTab(BuildContext context, int index) {
    Navigator.popUntil(context, (route) => route.isFirst);
    MainShell.tabSwitchRequest.value = index;
  }

  Future<void> _handleNutritionUpdate(
    BuildContext context,
    String? data,
  ) async {
    if (data == null || data.isEmpty) return;

    final diet = context.read<DietProvider>();
    final profile = diet.profile;
    if (profile == null) return;

    try {
      final Map<String, dynamic> updates = jsonDecode(data);

      Goal? newGoal;
      final goalStr = updates['goal']?.toString();
      if (goalStr != null) {
        newGoal = Goal.values.firstWhere(
          (g) => g.name == goalStr,
          orElse: () => profile.goal,
        );
      }

      double? newKcal;
      if (updates.containsKey('customKcalTarget')) {
        final raw = updates['customKcalTarget'];
        newKcal = raw == null ? null : (raw as num).toDouble();
      }

      final updated = UserProfile(
        name: profile.name,
        age: profile.age,
        weight: profile.weight,
        height: profile.height,
        gender: profile.gender,
        activityLevel: profile.activityLevel,
        goal: newGoal ?? profile.goal,
        customKcalTarget: updates.containsKey('customKcalTarget')
            ? newKcal
            : profile.customKcalTarget,
        targetWeight: profile.targetWeight,
      );

      await diet.saveUserProfile(updated);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Beslenme planın güncellendi.',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF1A2035),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('UPDATE_NUTRITION parse hatası: $e');
    }
  }

  Future<void> _handleFoodAdd(BuildContext context, String? data) async {
    if (data == null || data.isEmpty) return;
    try {
      final Map<String, dynamic> foodData = jsonDecode(data);
      final diet = context.read<DietProvider>();

      final mealTypeStr = foodData['mealType'] as String?;
      MealType mealType = MealType.snack;
      if (mealTypeStr != null) {
        if (mealTypeStr.toLowerCase() == 'breakfast') {
          mealType = MealType.breakfast;
        } else if (mealTypeStr.toLowerCase() == 'lunch') {
          mealType = MealType.lunch;
        } else if (mealTypeStr.toLowerCase() == 'dinner') {
          mealType = MealType.dinner;
        }
      }

      await diet.addAiMealToDiary(
        mealName: foodData['name'] ?? 'AI Öğünü',
        kcal: (foodData['kcal'] as num?)?.toDouble() ?? 0,
        protein: (foodData['protein'] as num?)?.toDouble() ?? 0,
        carbs: (foodData['carbs'] as num?)?.toDouble() ?? 0,
        fat: (foodData['fat'] as num?)?.toDouble() ?? 0,
        mealType: mealType,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${foodData['name']} günlüğüne eklendi! 🍽️',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF388E3C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('ADD_FOOD parse hatası: $e');
    }
  }

  Future<void> _handleWorkoutSave(BuildContext context, String? data) async {
    if (data == null || data.isEmpty) return;
    try {
      final Map<String, dynamic> workoutData = jsonDecode(data);
      final apiClient = ApiClient();
      await apiClient.post(
        ApiConstants.workouts,
        data: {
          'name': workoutData['name'] ?? 'AI Antrenmanı',
          'workoutType': workoutData['workoutType'] ?? 'STRENGTH',
          'muscleGroup': workoutData['muscleGroup'] ?? 'FULL_BODY',
          'durationMinutes': workoutData['durationMinutes'] ?? 45,
          'workoutDate': DateTime.now().toIso8601String(),
          'notes': 'AI Koç tarafından oluşturuldu',
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '💪 Antrenman günlüğüne kaydedildi!',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF1A4580),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('SAVE_WORKOUT parse hatası: $e');
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    final plainText = text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1');
    Clipboard.setData(ClipboardData(text: plainText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kopyalandı',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1A2035),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildSentImage(BuildContext context) {
    final controller = context.read<AiCoachController>();

    ChatMessage? lastUserImageMsg;
    for (final m in controller.messages.reversed) {
      if (m.role == ChatRole.user && m.imagePath != null) {
        lastUserImageMsg = m;
        break;
      }
    }

    final isScanning =
        controller.isAnalyzingImage && (widget.message == lastUserImageMsg);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: 250,
              child: Image.file(
                File(widget.message.imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.white.withValues(alpha: 0.05),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              ),
            ),
            if (isScanning) const _CyberpunkScanOverlay(),
          ],
        ),
      ),
    );
  }
}

class _CyberpunkScanOverlay extends StatelessWidget {
  const _CyberpunkScanOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: Colors.green.withValues(alpha: 0.1)),
          Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 2,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .moveY(
                begin: 0,
                end: 250,
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                      'ANALYZING DATA...',
                      style: GoogleFonts.dmMono(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeOut(duration: 500.ms),
                const SizedBox(height: 8),
                Text(
                  '010110101001...',
                  style: GoogleFonts.dmMono(
                    color: Colors.greenAccent.withValues(alpha: 0.5),
                    fontSize: 10,
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

class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with TickerProviderStateMixin {
  late final List<AnimationController> _dotControllers;

  @override
  void initState() {
    super.initState();
    _dotControllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      );
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _dotControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pulsing avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEBC374).withValues(alpha: 0.3),
                          blurRadius: 18,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    begin: 0.85,
                    end: 1.15,
                    duration: 1800.ms,
                    curve: Curves.easeInOut,
                  ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEBC374), Color(0xFFC88934)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEBC374).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF141E30), Color(0xFF0F1822)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: const Color(0xFFEBC374).withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Analiz ediliyor',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: _dotControllers[i],
                      builder: (context, _) {
                        final v = _dotControllers[i].value;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: 6,
                          height: 6 + v * 7,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              const Color(0xFFEBC374).withValues(alpha: 0.25),
                              const Color(0xFFEBC374),
                              v,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
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
}
