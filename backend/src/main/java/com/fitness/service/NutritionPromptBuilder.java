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

        String historyBlock = buildHistoryBlock(request.conversationHistory);

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

        if ("PLAN_CUSTOMIZATION".equals(task)) {
            return """
                    You are a practical nutrition assistant inside a fitness app.
                    Language: Turkish (tr)
                    %s

                    User request: %s

                    Context:
                    %s

                    Only output valid JSON. Do not wrap with markdown.
                    Response must follow this exact JSON schema:
                    {
                      "reply": "string - 1 to 3 short Turkish sentences explaining what changed",
                      "dailyPlan": [
                        {
                          "time": "HH:mm",
                          "label": "string - meal label in Turkish",
                          "mealType": "BREAKFAST | LUNCH | DINNER | SNACK",
                          "food": "string - the actual meal",
                          "reason": "string - why this change fits the request",
                          "ingredients": ["string"],
                          "macros": {
                            "kcal": 0,
                            "proteinG": 0,
                            "carbsG": 0,
                            "fatG": 0
                          }
                        }
                      ],
                      "shoppingList": ["string - only extra items needed beyond listed available ingredients"],
                      "followUpQuestions": ["string - short helpful next question"]
                    }

                        Rules:
                    - dailyPlan must contain 3 to 4 items
                    - Keep the plan aligned with the user's goal
                    - Respect dietary restrictions and the user's request strictly
                    - If the user mentions available ingredients, prioritize them heavily
                    - Preserve a realistic full-day flow with breakfast, lunch, dinner, and optionally one snack
                    - breakfast, lunch, and dinner are required; snack is optional
                    - At most one item is allowed for each mealType
                    - mealType must be one of BREAKFAST, LUNCH, DINNER, SNACK
                    - time must be realistic and sorted chronologically
                    - macros values must be integers
                    - ingredients should be concise and practical
                    - shoppingList should stay short and only mention truly missing extras
                    - Do not provide medical diagnosis
                    """.formatted(userContext, message, contextBlock);
        }

        // Structured JSON prompt — intent-aware: only populate meals when user asks for suggestions
        return """
                You are a practical nutrition assistant inside a fitness tracking app.
                Language: Turkish (tr)
                %s

                %sUser message: %s

                Context:
                %s

                Only output valid JSON. Do not wrap with ```json or ```.
                Response must follow this exact JSON schema:
                {
                  "reply": "string - your direct Turkish answer to the user's question",
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
                      "tags": ["string"],
                      "warnings": ["string - allergy warnings if any"]
                    }
                  ],
                  "shoppingList": ["string - shopping list item"],
                  "followUpQuestions": ["string - helpful follow-up question"]
                }

                CRITICAL — Decide output based on user INTENT:

                INTENT A — Informational / factual question (e.g. "Bugün kaç kalori aldım?",
                "Ne kadar protein yedim?", "Kalan kalori ne?", "Su içmeli miyim?",
                "Nasıl beslenmeliyim?", general health advice, "Ne yedim bugün?"):
                  → Answer ONLY in "reply" with a concise, direct Turkish response.
                  → "meals", "shoppingList", "followUpQuestions" must be [] (empty arrays).
                  → Do NOT add unsolicited meal suggestions.

                INTENT B — Meal suggestion / recipe request (e.g. "Ne yemek önerirsin?",
                "Akşam yemeği için ne yapayım?", "Yemek tarifi ver", "Kahvaltı önerisi"):
                  → Provide 3 to 5 meal suggestions in "meals".
                  → "reply" should be a short 1-sentence intro in Turkish.
                  → Optionally add 1-2 follow-up questions.

                INTENT C — Shopping list request:
                  → Fill "shoppingList" only. Leave "meals" as [].

                General rules:
                - Answer exactly what was asked. No extra suggestions unless requested.
                - macros values must be integers.
                - steps: 3 to 6 short items when included.
                - Do not provide medical diagnosis.
                - Respect dietary restrictions strictly.
                """.formatted(userContext, historyBlock, message, contextBlock);
    }

    private String buildHistoryBlock(List<NutritionAiRequest.ConversationTurn> history) {
        if (history == null || history.isEmpty()) return "";
        StringBuilder sb = new StringBuilder("Conversation history (oldest to most recent):\n");
        int maxTurns = Math.min(history.size(), 4);
        int startIdx = history.size() - maxTurns;
        for (int i = startIdx; i < history.size(); i++) {
            NutritionAiRequest.ConversationTurn turn = history.get(i);
            if (turn.userMessage != null && turn.assistantMessage != null) {
                sb.append("User: ").append(turn.userMessage).append("\n");
                sb.append("Assistant: ").append(turn.assistantMessage).append("\n");
            }
        }
        sb.append("\n");
        return sb.toString();
    }

    private String buildUserContext(NutritionAiRequest.NutritionContext context) {
        if (context == null) {
            return "Answer in concise Turkish.";
        }

        StringBuilder sb = new StringBuilder("Answer in concise Turkish. Language: Turkish (tr).");

        if (context.goal != null && !context.goal.isBlank()) {
            sb.append(" User goal: ").append(context.goal).append(".");
        }
        if (context.userAge != null) {
            sb.append(" Age: ").append(context.userAge).append(".");
        }
        if (context.userGender != null && !context.userGender.isBlank()) {
            sb.append(" Gender: ").append(context.userGender).append(".");
        }
        if (context.userWeightKg != null) {
            sb.append(String.format(java.util.Locale.US, " Weight: %.1f kg.", context.userWeightKg));
        }
        if (context.userHeightCm != null) {
            sb.append(String.format(java.util.Locale.US, " Height: %.0f cm.", context.userHeightCm));
        }
        if (context.activityLevel != null && !context.activityLevel.isBlank()) {
            sb.append(" Activity: ").append(context.activityLevel).append(".");
        }
        if (context.targetCalories != null) {
            sb.append(" Daily calorie target: ").append(context.targetCalories).append(" kcal.");
        }
        if (context.proteinTargetG != null) {
            sb.append(" Protein target: ").append(context.proteinTargetG).append(" g.");
        }
        if (context.mealType != null && !context.mealType.isBlank()) {
            sb.append(" Meal type: ").append(context.mealType).append(".");
        }
        if (context.dietaryRestrictions != null && !context.dietaryRestrictions.isEmpty()) {
            sb.append(" Dietary restrictions: ").append(String.join(", ", context.dietaryRestrictions)).append(".");
        }
        sb.append(" Difficulty: easy/medium (prefer easy if not specified).");
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
        if (context.currentPlan != null && !context.currentPlan.isEmpty()) {
            lines.add("- currentPlan:");
            for (NutritionAiRequest.CurrentPlanMeal meal : context.currentPlan) {
                if (meal == null) {
                    continue;
                }
                String time = meal.time == null ? "" : meal.time.trim();
                String label = meal.label == null ? "" : meal.label.trim();
                String mealType = meal.mealType == null ? "" : meal.mealType.trim();
                String food = meal.food == null ? "" : meal.food.trim();
                String macros = meal.macros == null ? "" : meal.macros.trim();
                lines.add("  - " + time + " | " + label + " | " + mealType + " | " + food + " | " + macros);
            }
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
