import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../weight/presentation/providers/weight_provider.dart';

class StatsGrid extends StatelessWidget {
  final WeightProvider provider;

  const StatsGrid({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final weeklyChange = provider.weeklyChange;
    final totalChange = provider.totalChange;
    final avg7 = provider.average7Days;
    final count30 = provider.last30DaysCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate width for 2 columns with spacing
          final width = (constraints.maxWidth - 16) / 2;
          
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildModernCard(
                title: 'Haftalık Değişim',
                value: weeklyChange.abs() < 0.05
                    ? 'Stabil'
                    : '${weeklyChange > 0 ? '+' : ''}${weeklyChange.toStringAsFixed(1)}',
                unit: weeklyChange.abs() < 0.05 ? '' : 'kg',
                icon: weeklyChange < 0 ? Icons.trending_down_rounded : (weeklyChange > 0 ? Icons.trending_up_rounded : Icons.trending_flat_rounded),
                color: weeklyChange < 0 ? const Color(0xFF00E676) : (weeklyChange > 0 ? const Color(0xFFFF5252) : Colors.white70),
                width: width,
                delay: 0,
              ),
              _buildModernCard(
                title: 'Toplam Fark',
                value: totalChange.abs() < 0.05
                    ? 'Stabil'
                    : '${totalChange > 0 ? '+' : ''}${totalChange.toStringAsFixed(1)}',
                unit: totalChange.abs() < 0.05 ? '' : 'kg',
                icon: Icons.functions_rounded,
                color: totalChange < 0 ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                width: width,
                delay: 100,
              ),
              _buildModernCard(
                title: '7 Günlük Ort.',
                value: avg7.toStringAsFixed(1),
                unit: 'kg',
                icon: Icons.bar_chart_rounded,
                color: const Color(0xFF2979FF), // Bright Blue
                width: width,
                delay: 200,
              ),
              _buildModernCard(
                title: 'İstikrar (30G)',
                value: '$count30',
                unit: 'Kayıt',
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFFD500F9), // Vibrant Purple
                width: width,
                delay: 300,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required double width,
    required int delay,
  }) {
    return _PremiumStatCard(
      title: title,
      value: value,
      unit: unit,
      icon: icon,
      color: color,
      width: width,
    ).animate().fadeIn(delay: delay.ms, duration: 500.ms).slideY(begin: 0.1, end: 0);
  }
}

class _PremiumStatCard extends StatefulWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final double width;

  const _PremiumStatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  State<_PremiumStatCard> createState() => _PremiumStatCardState();
}

class _PremiumStatCardState extends State<_PremiumStatCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              width: widget.width,
              height: 160, // Fixed height for consistency
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: 22,
                    ),
                  ),
                  
                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                          if (widget.unit.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                widget.unit,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
