import re

file_path = 'Frontend/lib/features/ai_coach/widgets/chat_bubble.dart'
with open(file_path, 'r') as f:
    content = f.read()

# 1. Update _getActionColors
colors_new = """      case 'ADD_FOOD':
        return (const Color(0xFF81C784), const Color(0xFF388E3C));
      case 'START_WORKOUT':"""
content = content.replace("case 'START_WORKOUT':", colors_new, 1) # Only first occurrence

# 2. Update _getActionIcon
icon_new = """      case 'ADD_FOOD':
        return Icon(Icons.add_circle_outline_rounded, size: 15, color: color);
      case 'START_WORKOUT':"""
content = content.replace("case 'START_WORKOUT':", icon_new, 1)

# 3. Update _handleAction
action_new = """      case 'ADD_FOOD':
        _handleFoodAdd(context, action.data);
        break;
      case 'START_WORKOUT':"""
content = content.replace("case 'START_WORKOUT':", action_new, 1)

# 4. Add _handleFoodAdd method at the end of the class (before the last `}`)
# Need to find the end of the class _ChatBubbleState. 
# It ends right before `class _CyberpunkScanOverlay`

handle_food_method = """  Future<void> _handleFoodAdd(BuildContext context, String? data) async {
    if (data == null || data.isEmpty) return;
    try {
      final Map<String, dynamic> foodData = jsonDecode(data);
      final diet = context.read<DietProvider>();
      
      final mealTypeStr = foodData['mealType'] as String?;
      MealType mealType = MealType.snack;
      if (mealTypeStr != null) {
        if (mealTypeStr.toLowerCase() == 'breakfast') mealType = MealType.breakfast;
        else if (mealTypeStr.toLowerCase() == 'lunch') mealType = MealType.lunch;
        else if (mealTypeStr.toLowerCase() == 'dinner') mealType = MealType.dinner;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('ADD_FOOD parse hatası: $e');
    }
  }
}"""

content = content.replace("class _CyberpunkScanOverlay", handle_food_method + "\n\nclass _CyberpunkScanOverlay")
# The replacement above leaves an extra `}` at the end of _ChatBubbleState, wait.
# Oh, we need to replace the `}` before `class _CyberpunkScanOverlay`.
content = re.sub(r'\}\s+class _CyberpunkScanOverlay', handle_food_method + r'\n\nclass _CyberpunkScanOverlay', content)

with open(file_path, 'w') as f:
    f.write(content)
