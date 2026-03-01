import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class WeightRulerPicker extends StatefulWidget {
  final double initialValue;
  final double minValue;
  final double maxValue;
  final ValueChanged<double> onChanged;

  const WeightRulerPicker({
    super.key,
    required this.initialValue,
    this.minValue = 30.0,
    this.maxValue = 250.0,
    required this.onChanged,
  });

  @override
  State<WeightRulerPicker> createState() => _WeightRulerPickerState();
}

class _WeightRulerPickerState extends State<WeightRulerPicker> {
  late ScrollController _scrollController;
  final double _itemWidth = 10.0; // Width of each tick mark area
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    // Calculate initial offset
    final initialOffset = ((widget.initialValue - widget.minValue) * 10) * _itemWidth;
    
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    // Calculate value from offset
    // Offset 0 = minValue
    // Each item is 0.1kg
    final valueStep = offset / _itemWidth;
    final newValue = widget.minValue + (valueStep / 10);
    
    // Clamp
    final clampedValue = newValue.clamp(widget.minValue, widget.maxValue);
    
    // Only notify if meaningful change (e.g. 0.1 diff)
    // But for smooth UI we might want robust updates. 
    // We'll round to 1 decimal place.
    final rounded = (clampedValue * 10).round() / 10;
    
    if (rounded != widget.initialValue) { // This check is tricky since parent holds state, but we can verify against local if needed
       widget.onChanged(rounded);
       if (!_isScrolling) {
          HapticFeedback.selectionClick();
       }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Total steps (ticks) = (Max - Min) * 10
    final int totalSteps = ((widget.maxValue - widget.minValue) * 10).round();
    
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Scrollable Ruler with ShaderMask for smooth fade edges
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.15, 0.85, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  _isScrolling = true;
                } else if (notification is ScrollEndNotification) {
                  _isScrolling = false;
                  _snapToNearest();
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: totalSteps + 1,
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width / 2,
                ),
                itemBuilder: (context, index) {
                  final value = widget.minValue + (index / 10);
                  final isMajor = index % 10 == 0;
                  final isHalf = index % 5 == 0 && !isMajor;

                  return SizedBox(
                    width: _itemWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // The Tick
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isMajor ? 3 : (isHalf ? 2 : 1),
                          height: isMajor ? 40 : (isHalf ? 25 : 15),
                          decoration: BoxDecoration(
                            color: isMajor 
                                ? Colors.white 
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isMajor ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 4,
                                spreadRadius: 0,
                              )
                            ] : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Text label for major marks
                        if (isMajor)
                          Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14, // Slightly larger
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          )
                        else
                          const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Center Indicator (The Neon Line) - Placed ON TOP
          IgnorePointer(
            child: Container(
              width: 4,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snapToNearest() {
    final offset = _scrollController.offset;
    final snapOffset = (offset / _itemWidth).round() * _itemWidth;
    if (snapOffset != offset) {
      Future.microtask(() {
         _scrollController.animateTo(
          snapOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }
}
