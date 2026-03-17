import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../controllers/ai_coach_controller.dart';
import '../models/ai_coach_models.dart';
import 'package:provider/provider.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: isAssistant
          ? _buildAssistantRow(context, isError)
          : _buildUserRow(context),
    );
  }

  Widget _buildAssistantRow(BuildContext context, bool isError) {
    final accentColor =
        isError ? const Color(0xFFFF6B6B) : const Color(0xFFEBC374);
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: isError
                        ? const Color(0xFF2A1318)
                        : const Color(0xFF101826),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(22),
                    ),
                    border: Border.all(
                      color: isError
                          ? const Color(0xFFFF6B6B).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.07),
                    ),
                    boxShadow: isError
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFFEBC374).withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(-3, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.message.imagePath != null) _buildSentImage(context),
                      !isError
                          ? _buildMarkdownContent()
                          : _buildPlainContent(isError),
                      if (!isError && widget.message.structuredResponse != null)
                        _buildRichContent(context, widget.message.structuredResponse!),
                    ],
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
                        onTap: () => setState(() {
                          _reaction = _reaction == true ? null : true;
                        }),
                      ),
                      const SizedBox(width: 6),
                      _buildReactionButton(
                        icon: Icons.thumb_down_rounded,
                        isActive: _reaction == false,
                        activeColor: const Color(0xFFFF6B6B),
                        onTap: () => setState(() {
                          _reaction = _reaction == false ? null : false;
                        }),
                      ),
                      const SizedBox(width: 6),
                      _buildReactionButton(
                        icon: Icons.copy_rounded,
                        isActive: false,
                        activeColor: const Color(0xFF73D4FF),
                        onTap: () => _copyToClipboard(context, widget.message.content),
                      ),
                    ],
                  ],
                ),
              ),
              // Reaction feedback badge
              if (_reaction != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (_reaction! ? const Color(0xFF34D399) : const Color(0xFFFF6B6B))
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: (_reaction! ? const Color(0xFF34D399) : const Color(0xFFFF6B6B))
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _reaction! ? 'Geri bildirim için teşekkürler!' : 'Daha iyi olacağız.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0),
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
          color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
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
              Container(
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
                    if (widget.message.imagePath != null) _buildSentImage(context),
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
    return MarkdownBody(
      data: widget.message.content,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
          height: 1.6,
        ),
        strong: GoogleFonts.dmSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        em: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.85),
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
        listBullet: GoogleFonts.dmSans(
          color: const Color(0xFFEBC374),
          fontSize: 14,
        ),
        blockquote: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
        h1: GoogleFonts.dmSans(
          color: const Color(0xFFEBC374),
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
        ),
        h2: GoogleFonts.dmSans(
          color: const Color(0xFFEBC374),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        h3: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
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
        blockSpacing: 10,
      ),
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

  Widget _buildRichContent(BuildContext context, CoachResponse response) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (response.focus.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildStructuredCard(
            icon: Icons.track_changes_rounded,
            title: 'BUGÜNÜN ODAĞI',
            color: const Color(0xFFEBC374),
            child: Text(
              response.focus,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (response.todoItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildStructuredCard(
            icon: Icons.checklist_rounded,
            title: 'YAPILACAKLAR',
            color: const Color(0xFF34D399),
            child: Column(
              children: response.todoItems
                  .take(4)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34D399).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF34D399).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: GoogleFonts.dmMono(
                                  color: const Color(0xFF34D399),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (response.nutritionNote.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildStructuredCard(
            icon: Icons.restaurant_rounded,
            title: 'BESLENME NOTU',
            color: const Color(0xFF73D4FF),
            child: Text(
              response.nutritionNote,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (response.media != null && response.media!.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...response.media!.map((m) => _buildMediaCard(m)),
        ],
        if (response.actions != null && response.actions!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: response.actions!
                .map((a) => _buildActionButton(context, a))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStructuredCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: GoogleFonts.dmMono(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMediaCard(CoachMedia media) {
    if (media.type == 'IMAGE') {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: media.url,
            placeholder: (context, url) => Container(
              height: 150,
              color: Colors.white.withValues(alpha: 0.05),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
      );
    }
    if (media.type == 'VIDEO_LINK') {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEBC374).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFFEBC374),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                media.title ?? 'Eğitici İçerik',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
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
          border: Border.all(
            color: color.withValues(alpha: 0.35),
          ),
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
      case 'START_WORKOUT':
        return (const Color(0xFF34D399), const Color(0xFF34D399));
      case 'ADD_WATER':
        return (const Color(0xFF73D4FF), const Color(0xFF4FACFE));
      case 'TRACK_WEIGHT':
        return (const Color(0xFFBC74EB), const Color(0xFFBC74EB));
      case 'OPEN_NUTRITION':
        return (const Color(0xFFEBC374), const Color(0xFFEBC374));
      default:
        return (const Color(0xFFEBC374), const Color(0xFFEBC374));
    }
  }

  Icon _getActionIcon(String type, Color color) {
    switch (type) {
      case 'START_WORKOUT':
        return Icon(Icons.fitness_center_rounded, size: 15, color: color);
      case 'ADD_WATER':
        return Icon(Icons.water_drop_rounded, size: 15, color: color);
      case 'TRACK_WEIGHT':
        return Icon(Icons.monitor_weight_rounded, size: 15, color: color);
      case 'OPEN_NUTRITION':
        return Icon(Icons.restaurant_menu_rounded, size: 15, color: color);
      case 'OPEN_TRACKING':
        return Icon(Icons.insights_rounded, size: 15, color: color);
      default:
        return Icon(Icons.launch_rounded, size: 15, color: color);
    }
  }

  void _handleAction(BuildContext context, CoachAction action) {
    switch (action.type) {
      case 'START_WORKOUT':
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Antrenman ekranına yönlendiriliyorsunuz...'),
          ),
        );
        break;
      case 'ADD_WATER':
        context.read<DietProvider>().addWater(0.25);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('250ml su eklendi! 💧')));
        break;
      case 'TRACK_WEIGHT':
        Navigator.pushNamed(context, '/tracking');
        break;
      case 'OPEN_NUTRITION':
        Navigator.pushNamed(context, '/home');
        break;
      case 'OPEN_TRACKING':
        Navigator.pushNamed(context, '/tracking');
        break;
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

class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with glow
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
              .scaleXY(begin: 0.85, end: 1.15, duration: 1800.ms, curve: Curves.easeInOut),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF101826),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(
                  3,
                  (i) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEBC374),
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .scaleXY(
                        begin: 0.4,
                        end: 1.0,
                        duration: 600.ms,
                        delay: (i * 200).ms,
                        curve: Curves.easeInOut,
                      ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Koç düşünüyor...',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
