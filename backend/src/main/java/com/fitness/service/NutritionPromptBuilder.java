package com.fitness.service;

import java.util.ArrayList;
import java.util.List;

import com.fitness.dto.NutritionAiRequest;

import jakarta.enterprise.context.ApplicationScoped;

/**
 * Builds prompts for the AI Nutrition service.
 * This class only generates prompt strings - it does not make network calls.
 */
@ApplicationScoped
public class NutritionPromptBuilder {

    /**
     * Build a prompt for the AI nutrition service based on the user's request.
     * Returns structured JSON with meals, shoppingList, and followUpQuestions.
     * 
     * @param request The nutrition AI request containing message, task, and context
     * @return The formatted prompt string to send to Gemini
     */
    public String buildPrompt(NutritionAiRequest request) {
        String task = normalizeTask(request.task);
        String message = request.message.trim();
        String contextBlock = buildContextBlock(request.context);
        String userContext = buildUserContext(request.context);

        if ("EXTRACT_FOOD_ITEMS".equals(task)) {
            return """
                    Extract only food names from this Turkish text.
                    Text: %s

                    Rules:
                    - Return only comma-separated food names in Turkish.
                    - Do not include amounts, units, or explanations.
                    - If nothing found, return an empty string.
                    """.formatted(message);
        }

        if ("RECIPE_SUGGESTION".equals(task)) {
            message = "Şu anki makro değerlerime göre akşam veya öğle yemeği için tek bir akıllı, sağlıklı ve lezzetli yemek tarifi öner. Tarifin adını, yaklaşık kalorisi ve makrolarını, ve küçük bir neden seçtiğini ekle.";
        } else if ("GROCERY_LIST".equals(task)) {
            message = "Bana bu haftalık sağlıklı ve dengeli bir market alışveriş listesi (shoppingList) çıkar. Mevsimine uygun, yüksek proteinli ve temiz içerikli ürünler olsun. reply alanında listeyi neden bu şekilde oluşturduğunu 1-2 kısa cümlede Türkçe açıkla. shoppingList içinde yalnızca liste elemanlarını dön, başlık ekleme.";
        }

        if ("SUGGESTION_REASONING".equals(task)) {
            return """
                    You are a practical nutrition assistant in a fitness app.
                    Language: Turkish (tr)
                    %s

                    User message: Neden bu yemekleri önerdin? -> %s

                    Context:
                    %s

                    Only output valid JSON in this exact format:
                    {
                      "reply": "string - explain why these foods match the context"
                    }
                    """.formatted(userContext, message, contextBlock);
        }

        // Structured JSON prompt for meal suggestions with language/difficulty/budget
        return """
                You are a practical nutrition assistant in a fitness app.
                Language: Turkish (tr)
                %s

                User message: %s

                Context:
                %s

                Only output valid JSON. Do not wrap with ```json or ```.
                Response must follow this exact JSON schema:
                {
                  "reply": "string - your conversational response to the user's message",
                  "meals": [
                    {
                      "name": "string - meal name in Turkish",
                      "reason": "string - why this meal is suitable",
                      "ingredients": ["string - ingredient list"],
                      "steps": ["string - short cooking step"],
                      "macros": {
                        "kcal": 0,
                        "proteinG": 0,
                        "carbsG": 0,
                        "fatG": 0
                      },
                      "prepMinutes": 0,
                      "tags": ["string - meal tags like 'kahvalti', 'aksam', 'diyet', 'vegan', 'gluten-free'],
                      "warnings": ["string - allergy warnings or notes"]
                    }
                  ],
                  "shoppingList": ["string - shopping list item"],
                  "followUpQuestions": ["string - question user might ask next"]
                }

                Rules:
                - meals array must contain 3 to 5 items
                - macros values must be integers
                - steps must be 3 to 6 short items
                - ingredients list should be practical and easy to find
                - Keep suggestions realistic and safe
                - Do not provide medical diagnosis
                - If user asks about a specific meal, focus on that
                - Consider budget-friendly options when not specified
                - Prefer easy-to-prepare meals if user is busy
                """.formatted(userContext, message, contextBlock);
    }

    private String buildUserContext(NutritionAiRequest.NutritionContext context) {
        if (context == null) {
            return "Answer in concise Turkish.";
        }

        StringBuilder sb = new StringBuilder();
        sb.append("Answer in concise Turkish.");

        // Add language explicitly
        sb.append(" Language: Turkish (tr).");

        // Add goal if available
        if (context.goal != null && !context.goal.isBlank()) {
            sb.append(" User goal: ").append(context.goal);
        }

        // Add meal type if available
        if (context.mealType != null && !context.mealType.isBlank()) {
            sb.append(" Meal type: ").append(context.mealType);
        }

        // Add dietary restrictions if available
        if (context.dietaryRestrictions != null && !context.dietaryRestrictions.isEmpty()) {
            sb.append(" Dietary restrictions: ").append(String.join(", ", context.dietaryRestrictions));
        }

        // Add difficulty preference (default to easy if not specified)
        sb.append(" Difficulty: easy/medium (prefer easy if not specified).");

        // Add budget awareness
        sb.append(" Budget: consider cost-effective options when not specified.");

        return sb.toString();
    }

    private String buildContextBlock(NutritionAiRequest.NutritionContext context) {
        if (context == null) {
            return "- no extra context";
        }

        List<String> lines = new ArrayList<>();
        if (context.goal != null && !context.goal.isBlank()) {
            lines.add("- goal: " + context.goal.trim());
        }
        if (context.mealType != null && !context.mealType.isBlank()) {
            lines.add("- mealType: " + context.mealType.trim());
        }
        if (context.dietaryRestrictions != null && !context.dietaryRestrictions.isEmpty()) {
            lines.add("- dietaryRestrictions: " + String.join(", ", context.dietaryRestrictions));
        }
        if (context.availableIngredients != null && !context.availableIngredients.isEmpty()) {
            lines.add("- availableIngredients: " + String.join(", ", context.availableIngredients));
        }
        if (context.summaryText != null && !context.summaryText.isBlank()) {
            lines.add("- summaryText: " + context.summaryText.trim());
        }
        if (context.dailySummary != null) {
            NutritionAiRequest.DailySummary s = context.dailySummary;
            lines.add("- dailySummary.steps: " + safeInt(s.steps));
            lines.add("- dailySummary.calories: " + safeInt(s.calories));
            lines.add("- dailySummary.water: " + safeDouble(s.water));
            lines.add("- dailySummary.sleep: " + safeDouble(s.sleep));
        }
        if (lines.isEmpty()) {
            return "- no extra context";
        }
        return String.join("\n", lines);
    }

    private String normalizeTask(String task) {
        if (task == null || task.isBlank()) {
            return "CHAT";
        }
        return task.trim().toUpperCase();
    }

    private int safeInt(Integer value) {
        return value == null ? 0 : value;
    }

    private double safeDouble(Double value) {
        return value == null ? 0.0 : value;
    }
}
