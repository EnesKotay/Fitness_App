import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:ui' as ui;
import '../../../../core/theme/app_colors.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PremiumSummaryCard extends StatelessWidget {
  final WeightProvider provider;
  final ScreenshotController screenshotController;
  final VoidCallback onShare;
  final VoidCallback onSettingsTap; 

  const PremiumSummaryCard({
    super.key,
    required this.provider,
    required this.screenshotController,
    required this.onShare,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = provider.latestEntry;
    
    return Screenshot(
      controller: screenshotController,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              // Ultra-deep glass background
              color: const Color(0xFF141414).withValues(alpha: 0.80),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 1. Subtle Radial Glow (Green)
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 2. Share Button (Glass)
                Positioned(
                  top: 24,
                  right: 24,
                  child: GestureDetector(
                    onTap: onShare,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // 3. Main Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                  child: Consumer<DietProvider>(
                    builder: (context, diet, _) {
                      final target = diet.profile?.targetWeight ?? 70.0;
                      final currentKg = current?.weightKg ?? 0;
                      // İlk kilo: kayıtlardaki en eski, yoksa profil kilosu, yoksa güncel
                      final firstKg = provider.firstEntry?.weightKg;
                      final startKg = firstKg ?? diet.profile?.weightKg ?? currentKg;

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Big Modern Progress Ring
                              _buildModernProgressRing(startKg, currentKg, target),
                              
                              const SizedBox(width: 24),
                              
                              // Weight Text Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GÜNCEL AĞIRLIK',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          current?.weightKg.toStringAsFixed(1) ?? '--',
                                          style: const TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -2,
                                            height: 1.0,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'kg',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Hedef: ${target.toStringAsFixed(1)} kg',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (firstKg != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'İlk kilo: ${firstKg.toStringAsFixed(1)} kg',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.35),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Refined BMI Bar
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2), // Darker inner container
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: diet.profile == null || current == null
                                ? const Center(child: Text('Profil bekleniyor...', style: TextStyle(color: Colors.white30)))
                                : _buildModernBMIBar(current.weightKg, diet.profile!.heightCm),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernProgressRing(double start, double current, double target) {
    final progress = _calculateProgress(start, current, target);
    
    return SizedBox(
      height: 90,
      width: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Track
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: 1.0,
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 8,
            ),
          ),
          // Animated Value
          SizedBox(
            width: 90,
            height: 90,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: 1500.ms,
              curve: Curves.easeOutExpo,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  color: AppColors.primary,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          // Center Icon with Pulse
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: -2,
                )
              ],
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
        ],
      ),
    );
  }

  double _calculateProgress(double start, double current, double target) {
    if (start == target) return 1.0;
    final totalDiff = (start - target).abs();
    final currentDiff = (start - current).abs();
    
    bool isLosing = target < start;
    if (isLosing && current > start) return 0.0;
    if (!isLosing && current < start) return 0.0;
    
    final progress = currentDiff / totalDiff;
    return progress.clamp(0.0, 1.0);
  }

  Widget _buildModernBMIBar(double weight, double heightCm) {
    final heightM = heightCm / 100;
    final bmi = weight / (heightM * heightM);
    
    String status;
    Color color;
    double percent;

    if (bmi < 18.5) {
      status = 'Zayıf';
      color = Colors.blueAccent;
      percent = 0.2;
    } else if (bmi < 25) {
      status = 'Normal';
      color = const Color(0xFF00E676);
      percent = 0.5;
    } else if (bmi < 30) {
      status = 'Fazla Kilolu';
      color = const Color(0xFFFF9100);
      percent = 0.8;
    } else {
      status = 'Obez';
      color = const Color(0xFFFF1744);
      percent = 1.0;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Vücut Kitle İndeksi (BMI)',
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '$status (${bmi.toStringAsFixed(1)})',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                shadows: [
                  Shadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedFractionallySizedBox(
              duration: 1200.ms,
              curve: Curves.easeOutCubic,
              widthFactor: percent.clamp(0.05, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
