import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../widgets/macro_pie_chart.dart';

/// Yemek detay: Premium tasarım, Slider ile gramaj seçimi.
class FoodDetailPage extends StatefulWidget {
  final FoodItem food;
  final MealType? selectedMealType;

  const FoodDetailPage({super.key, required this.food, this.selectedMealType});

  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  double _grams = 100;

  @override
  Widget build(BuildContext context) {
    // 100g değerleri
    final baseKcal = widget.food.kcalPer100g ?? (4 * widget.food.proteinPer100g + 4 * widget.food.carbPer100g + 9 * widget.food.fatPer100g);
    
    // Seçili gramaja göre değerler
    final ratio = _grams / 100;
    final currentKcal = baseKcal * ratio;
    final currentP = widget.food.proteinPer100g * ratio;
    final currentC = widget.food.carbPer100g * ratio;
    final currentF = widget.food.fatPer100g * ratio;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppGradientBackground(
        child: CustomScrollView(
          slivers: [
             SliverAppBar(
               expandedHeight: 250,
               pinned: true,
               backgroundColor: AppColors.surface,
               leading: Container(
                 margin: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: Colors.black.withValues(alpha: 0.2),
                   shape: BoxShape.circle,
                 ),
                 child: IconButton(
                   icon: const Icon(Icons.arrow_back, color: Colors.white),
                   onPressed: () {
                     try {
                       Navigator.of(context, rootNavigator: false).pop();
                     } catch (e) {
                       Navigator.of(context).pop();
                     }
                   },
                 ),
               ),
               flexibleSpace: FlexibleSpaceBar(
                 title: Text(widget.food.name, style: AppTextStyles.headlineSmall.copyWith(color: Colors.white)),
                 centerTitle: true,
                 background: Container(
                   decoration: BoxDecoration(
                     gradient: LinearGradient(
                       colors: [
                         AppColors.primary.withValues(alpha: 0.6),
                         AppColors.background,
                       ],
                       begin: Alignment.topCenter,
                       end: Alignment.bottomCenter,
                     ),
                   ),
                   child: Center(
                     child: Icon(Icons.restaurant_menu, size: 100, color: Colors.white.withValues(alpha: 0.2))
                         .animate(onPlay: (c) => c.repeat(reverse: true))
                         .scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 2000.ms),
                   ),
                 ),
               ),
             ),
             SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.all(AppSpacing.m),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                     // 1. Özet Kartı
                     AppCard(
                       animateOnAppear: true,
                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                       child: Column(
                         children: [
                           Text('${_grams.round()}g için', style: AppTextStyles.bodyMedium),
                           const SizedBox(height: 8),
                           Text(
                             '${currentKcal.round()} kcal',
                             style: AppTextStyles.headlineLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 42),
                           ),
                           const SizedBox(height: 24),
                           
                           // Pasta Grafik
                           MacroPieChart(
                             proteinG: currentP,
                             carbG: currentC,
                             fatG: currentF,
                             size: 150,
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: AppSpacing.l),
                     
                     // 2. Makro Kartları
                     Text('Besin Değerleri', style: AppTextStyles.sectionSubtitle),
                     const SizedBox(height: AppSpacing.m),
                     
                     Row(
                       children: [
                         Expanded(child: _NutrientCard(label: 'Protein', value: '${currentP.toStringAsFixed(1)}g', color: const Color(0xFF4CAF50), icon: Icons.fitness_center)),
                         const SizedBox(width: 8),
                         Expanded(child: _NutrientCard(label: 'Karb', value: '${currentC.toStringAsFixed(1)}g', color: const Color(0xFF2196F3), icon: Icons.grain)),
                         const SizedBox(width: 8),
                         Expanded(child: _NutrientCard(label: 'Yağ', value: '${currentF.toStringAsFixed(1)}g', color: const Color(0xFFE91E63), icon: Icons.opacity)),
                       ],
                     ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                     const SizedBox(height: 32),
                     
                     // 3. Porsiyon Slider
                     Text('Porsiyon Ayarla', style: AppTextStyles.sectionSubtitle),
                     const SizedBox(height: 16),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       decoration: BoxDecoration(
                         color: AppColors.surface,
                         borderRadius: BorderRadius.circular(16),
                       ),
                       child: Column(
                         children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_grams.round()} g', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                                Text('Standart Porsiyon', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: AppColors.surfaceLight,
                                thumbColor: Colors.white,
                                overlayColor: AppColors.primary.withValues(alpha: 0.2),
                                trackHeight: 6,
                              ),
                              child: Slider(
                                value: _grams,
                                min: 10,
                                max: 500,
                                divisions: 49,
                                label: '${_grams.round()}g',
                                onChanged: (val) {
                                  setState(() => _grams = val);
                                },
                              ),
                            ),
                         ],
                       ),
                     ),

                     const SizedBox(height: 32),
                     
                     // Ekle Butonu
                     AppButton.primary(
                       onPressed: () {
                          // Gramajıyla birlikte porsiyon sayfasına veya doğrudan eklemeye gitmeli
                          // Şimdilik existing flow'u koruyoruz, portion sayfasına gidince slider değerini taşıyabiliriz
                          // Veya bu sayfa zaten slider içerdiği için direkt ekleyebiliriz? 
                          // User flow: Detail -> Add Portion -> Confirm. 
                          // Since we added slider HERE, we can skip Portion page if we want, OR pass the grams to portion page.
                          Navigator.of(context).pushNamed(
                           'portion',
                           arguments: {
                             'food': widget.food, 
                             'mealType': widget.selectedMealType,
                             'initialGrams': _grams // Bunu portion page desteklemeli, ama şimdilik standart flow
                           },
                         );
                       },
                       icon: Icons.check,
                       text: 'Devam Et',
                     ).animate().scale(delay: 200.ms),
                     const SizedBox(height: 40),
                   ],
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }
}

class _NutrientCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _NutrientCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface, // Daha flat görünüm
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
