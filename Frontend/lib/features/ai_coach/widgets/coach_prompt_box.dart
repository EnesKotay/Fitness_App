import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CoachPromptBox extends StatefulWidget {
  const CoachPromptBox({
    super.key,
    required this.onSend,
    this.isLoading = false,
    this.cooldownSecondsRemaining,
    this.maxLength = 500,
    this.quickPrompts = const <String>[],
    this.isPremium = false,
    this.remainingFreePrompts,
    this.onUpgradeTap,
  });

  final Future<void> Function(String) onSend;
  final bool isLoading;
  final int? cooldownSecondsRemaining;
  final int maxLength;
  final List<String> quickPrompts;
  final bool isPremium;
  final int? remainingFreePrompts;
  final VoidCallback? onUpgradeTap;

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

  bool get _isCooldownActive =>
      widget.cooldownSecondsRemaining != null &&
      widget.cooldownSecondsRemaining! > 0;

  bool get _isFreeLimitReached =>
      !widget.isPremium && (widget.remainingFreePrompts ?? 0) <= 0;

  bool get _isInputBlocked =>
      widget.isLoading || _isCooldownActive || _isFreeLimitReached;

  bool get _canSubmit {
    final text = _controller.text.trim();
    return text.isNotEmpty &&
        text.length <= widget.maxLength &&
        !_isInputBlocked;
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (!_canSubmit) return;
    await widget.onSend(text);
    if (!mounted) return;
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.96),
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
                      'Koça sor',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isFreeLimitReached
                          ? 'Bugünkü 2 ücretsiz hak bitti.'
                          : 'Sorunu doğal cümleyle yaz, koç cevaplasın.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: widget.isPremium
                    ? 'Premium'
                    : '${widget.remainingFreePrompts ?? 0} hak',
              ),
            ],
          ),
          if (!widget.isPremium) ...[
            const SizedBox(height: 12),
            _FreeLimitNote(
              remainingFreePrompts: widget.remainingFreePrompts ?? 0,
              onUpgradeTap: widget.onUpgradeTap,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !_isInputBlocked,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: _isFreeLimitReached
                  ? 'Premium ile AI koçu sınırsız kullanabilirsin.'
                  : 'Örn: Bugün için 30 dakikalık yağ yakım antrenmanı planla.',
              hintStyle: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.34),
                fontSize: 14,
              ),
              filled: true,
              fillColor: const Color(0xFF0B1220),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          if (widget.quickPrompts.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.quickPrompts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = widget.quickPrompts[index];
                  return InkWell(
                    onTap: _isInputBlocked
                        ? null
                        : () {
                            _controller.text = prompt;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: _controller.text.length),
                            );
                            setState(() {});
                          },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        prompt,
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${_controller.text.trim().length}/${widget.maxLength}',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isCooldownActive)
                Text(
                  '${widget.cooldownSecondsRemaining}s',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFF0B54C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF73A7FF),
                  foregroundColor: const Color(0xFF08111E),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Gönder',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FreeLimitNote extends StatelessWidget {
  const _FreeLimitNote({
    required this.remainingFreePrompts,
    required this.onUpgradeTap,
  });

  final int remainingFreePrompts;
  final VoidCallback? onUpgradeTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFFF0B54C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              remainingFreePrompts > 0
                  ? 'Bugün $remainingFreePrompts ücretsiz AI koç hakkın kaldı.'
                  : '2 ücretsiz hakkın bitti. Premium ile sınırsız devam edebilirsin.',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (remainingFreePrompts <= 0 && onUpgradeTap != null)
            TextButton(
              onPressed: onUpgradeTap,
              child: Text(
                'Premium',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFF0B54C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
