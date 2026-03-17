import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../domain/entities/food_item.dart';
import '../state/diet_provider.dart';
import 'package:provider/provider.dart';

/// Favori yemekleri yatay ribbon olarak gösteren widget.
class FavoritesSection extends StatelessWidget {
  final List<FoodItem> favorites;
  final Function(FoodItem) onTap;

  const FavoritesSection({
    super.key,
    required this.favorites,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.favorite_border_rounded, size: 16, color: Colors.white.withValues(alpha: 0.25)),
            const SizedBox(width: 8),
            Text(
              'Henüz favori yok — yemek kartındaki ♡ ile ekleyin',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 16,
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                'Favorilerim',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final food = favorites[index];
              final isFav = StorageHelper.isFavorite(food.id);
              return GestureDetector(
                onTap: () => onTap(food),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              food.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final provider = Provider.of<DietProvider>(
                                context,
                                listen: false,
                              );
                              provider.toggleFavorite(food.id);
                            },
                            child: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: const Color(0xFFFF6B6B),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${food.kcalPer100g.round()} kcal',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
