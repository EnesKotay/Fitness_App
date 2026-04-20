import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';
import 'portion_utils.dart';

class AdvancedAdjustmentsCard extends StatefulWidget {
  final TextEditingController gramController;
  final double currentGrams;
  final double sliderValue;
  final double sliderMax;
  final ValueChanged<double> onGramsSelected;

  const AdvancedAdjustmentsCard({
    super.key,
    required this.gramController,
    required this.currentGrams,
    required this.sliderValue,
    required this.sliderMax,
    required this.onGramsSelected,
  });

  @override
  State<AdvancedAdjustmentsCard> createState() => _AdvancedAdjustmentsCardState();
}

class _AdvancedAdjustmentsCardState extends State<AdvancedAdjustmentsCard> {
  bool _showAdvancedAdjustments = false;

  @override
  Widget build(BuildContext context) {
    return PortionUtils.buildGlassCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _showAdvancedAdjustments = !_showAdvancedAdjustments;
              });
            },
            child: Row(
              children: [
                PortionUtils.buildHeader(Icons.tune_rounded, 'Gram ile Ayarla'),
                const Spacer(),
                // Show current grams inline when collapsed
                if (!_showAdvancedAdjustments && widget.currentGrams > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${widget.currentGrams.round()}g',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Icon(
                  _showAdvancedAdjustments
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                  size: 20,
                ),
              ],
            ),
          ),
          if (_showAdvancedAdjustments) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _stepBtn(Icons.remove_rounded, () {
                  final g = widget.currentGrams - 25;
                  widget.onGramsSelected(g < 0 ? 0 : g);
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: TextField(
                            controller: widget.gramController,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              height: 1,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            // Note: onChanged will propagate through gramController listener in parent
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 3),
                          child: Text(
                            'g',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.34),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _stepBtn(Icons.add_rounded, () {
                  widget.onGramsSelected(widget.currentGrams + 25);
                }),
              ],
            ),
            const SizedBox(height: 14),
            _buildSlider(),
            const SizedBox(height: 14),
            _buildGramChips(),
          ],
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.22),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: AppColors.primaryLight, size: 22),
    ),
  );

  Widget _buildSlider() {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.secondary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
            thumbColor: Colors.white,
            overlayColor: AppColors.secondary.withValues(alpha: 0.15),
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: widget.sliderValue,
            min: 0,
            max: widget.sliderMax,
            divisions: (widget.sliderMax / 5).round().clamp(20, 200),
            onChanged: (v) {
              final rounded = (v / 5).round() * 5.0;
              widget.onGramsSelected(rounded);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dimText('0g'),
              _dimText('${(widget.sliderMax / 2).round()}g'),
              _dimText('${widget.sliderMax.round()}g'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGramChips() {
    const values = [50.0, 100.0, 150.0, 200.0, 250.0, 300.0];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: values.map((v) {
          final isSelected = (widget.currentGrams - v).abs() < 1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => widget.onGramsSelected(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppColors.secondary.withValues(alpha: 0.30),
                            AppColors.secondary.withValues(alpha: 0.12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.secondary
                        : Colors.white.withValues(alpha: 0.10),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  '${v.toInt()}g',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.secondary : Colors.white60,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dimText(String t) => Text(
    t,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.35),
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    ),
  );
}
