import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'coach_premium_panel.dart';

class CoachPromptBox extends StatefulWidget {
  const CoachPromptBox({
    super.key,
    required this.onSend,
    this.isLoading = false,
    this.cooldownSecondsRemaining,
    this.maxLength = 500,
    this.quickPrompts = const <String>[],
  });

  final ValueChanged<String> onSend;
  final bool isLoading;
  final int? cooldownSecondsRemaining;
  final int maxLength;
  final List<String> quickPrompts;

  @override
  State<CoachPromptBox> createState() => _CoachPromptBoxState();
}

class _CoachPromptBoxState extends State<CoachPromptBox> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isInputBlocked || text.length > widget.maxLength) {
      return;
    }
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  bool get _isCooldownActive =>
      widget.cooldownSecondsRemaining != null &&
      widget.cooldownSecondsRemaining! > 0;

  bool get _isInputBlocked => widget.isLoading || _isCooldownActive;

  bool get _canSubmit {
    final text = _controller.text.trim();
    return text.isNotEmpty &&
        text.length <= widget.maxLength &&
        !_isInputBlocked;
  }

  int get _length => _controller.text.trim().length;

  @override
  Widget build(BuildContext context) {
    return CoachPremiumPanel(
      baseColor: const Color(0xFF13213D),
      edgeColor: const Color(0xFF3E588A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE9BA66).withValues(alpha: 0.42),
                      const Color(0xFFE9BA66).withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFEBC374)),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFFF3DBA8),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Koca Sor',
                style: GoogleFonts.cormorantGaramond(
                  color: const Color(0xFFF6F0DE),
                  fontWeight: FontWeight.w700,
                  fontSize: 27,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF0E1B35),
                  border: Border.all(color: const Color(0xFF314D7E)),
                ),
                child: Text(
                  'pro prompt',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFA6C6FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            enabled: !_isInputBlocked,
            minLines: 1,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: GoogleFonts.dmSans(
              color: const Color(0xFFF4F8FF),
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0B152C),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFF304B7C)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFF304B7C)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFFE8BA67)),
              ),
              hintStyle: GoogleFonts.dmSans(
                color: const Color(0xFF98AFDE),
                fontWeight: FontWeight.w500,
              ),
              hintText: 'Ornek: Bugun icin 35 dakikalik itis antrenmani yaz.',
              prefixIcon: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF9BBCFF),
                size: 19,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.quickPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = widget.quickPrompts[index];
                return _QuickPromptChip(
                  label: prompt,
                  enabled: !_isInputBlocked,
                  onTap: () {
                    _controller.text = prompt;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: _controller.text.length),
                    );
                    setState(() {});
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_length/${widget.maxLength}',
                style: GoogleFonts.dmSans(
                  color: _length > widget.maxLength
                      ? const Color(0xFFFBA9A9)
                      : const Color(0xFFA8BBDF),
                  fontWeight: FontWeight.w600,
                ),
              ),
              _SendButton(
                enabled: _canSubmit,
                loading: widget.isLoading,
                cooldownSecondsRemaining: widget.cooldownSecondsRemaining,
                onTap: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: enabled ? const Color(0xFF152746) : const Color(0xFF101A2D),
            border: Border.all(
              color: enabled
                  ? const Color(0xFF3C5F9B)
                  : const Color(0xFF2D3F61),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: enabled
                  ? const Color(0xFFDAE6FF)
                  : const Color(0xFF7F93BB),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.cooldownSecondsRemaining,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final int? cooldownSecondsRemaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: enabled
            ? const LinearGradient(
                colors: [Color(0xFFE9BD70), Color(0xFFC88934)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF3D4A65), Color(0xFF2B364D)],
              ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFFE6B45A).withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: -5,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: enabled
              ? const Color(0xFF1F1203)
              : const Color(0xFFA3AFC6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
        ),
        child: Text(
          _label,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  String get _label {
    if (loading) {
      return 'Hazirlaniyor...';
    }
    if (cooldownSecondsRemaining != null && cooldownSecondsRemaining! > 0) {
      return '${cooldownSecondsRemaining}s bekle...';
    }
    return 'Gonder';
  }
}
