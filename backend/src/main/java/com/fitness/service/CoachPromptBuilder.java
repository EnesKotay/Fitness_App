package com.fitness.service;

import com.fitness.dto.AiCoachRequest;

import jakarta.enterprise.context.ApplicationScoped;

/**
 * Builds prompts for the AI Coach service.
 * This class only generates prompt strings - it does not make network calls.
 */
@ApplicationScoped
public class CoachPromptBuilder {

    /**
     * Build a prompt for the AI coach based on the user's request and daily
     * summary.
     * 
     * @param request The AI coach request containing goal, question, and daily
     *                summary
     * @return The formatted prompt string to send to Gemini
     */
    public String buildPrompt(
            com.fitness.dto.AiCoachRequest request,
            java.util.List<com.fitness.entity.AiInsight> insights,
            CoachPromptContext context) {
        AiCoachRequest.DailySummaryDto s = request.dailySummary;

        String goal = normalizeGoal(request.goal);
        String personalityBlock = buildPersonalityBlock(request.personality, request.personalityInstruction);
        String questionStrategy = buildQuestionStrategy(request.question);
        String profileSnapshot = context != null ? context.profileSnapshot : CoachPromptContext.empty().profileSnapshot;
        String recoverySnapshot = context != null ? context.recoverySnapshot : CoachPromptContext.empty().recoverySnapshot;
        String progressSnapshot = context != null ? context.progressSnapshot : CoachPromptContext.empty().progressSnapshot;
        String coachingSignals = context != null ? context.coachingSignals : CoachPromptContext.empty().coachingSignals;
        String insightBlock = buildInsightBlock(insights);
        String mealBlock = buildMealBlock(s);
        String workoutHighlightBlock = buildWorkoutHighlightBlock(s);

        return """
                You are a high-quality fitness coach assistant. Give accurate, context-aware, practical answers.
                Answer ONLY what the user asks, but use the available user data to make the answer feel personalized and intelligent.

                %s
                RESPONSE STRATEGY:
                - First identify the user's real intent: direct answer, analysis, plan, comparison, or explanation.
                - Prefer answering with the user's own data instead of generic advice.
                - If data is missing, say that briefly instead of inventing details.
                - If recovery signals are poor, prioritize recovery over intensity.
                - If progress data exists, use it to explain trend or direction when relevant.
                - Never contradict the deterministic coaching signals.
                - Avoid repeating generic advice such as "drink water" unless it is directly relevant.

                QUESTION-SPECIFIC GUIDANCE:
                %s

                USER PROFILE:
                %s

                RECOVERY SNAPSHOT:
                %s

                PROGRESS SNAPSHOT:
                %s

                DETERMINISTIC COACHING SIGNALS:
                %s

                LONG-TERM MEMORY INSIGHTS:
                %s

                USER CONTEXT (use only what's relevant to the question):
                - Goal: %s | TDEE: %s kcal | Weight: %s kg → Target: %s kg
                - Today: %d kcal eaten / Target: %s kcal | Protein: %sg | Carbs: %sg | Fat: %sg
                - Water: %.1f L | Workouts: %d (%s min)
                - Age: %s | Height: %s cm | Gender: %s | Activity: %s
                - Steps: %d | Sleep: %s h | BMI: %s | 7d avg calories: %s | 7d avg steps: %s
                - Weekly weight change: %s kg | Weight logging streak: %s days
                - Current Weight: %s kg | Target Weight: %s kg | Workout Minutes: %s | Target: %s kcal

                TODAY'S MEALS:
                %s

                TODAY'S WORKOUT HIGHLIGHTS:
                %s

                %sCURRENT QUESTION: %s

                IF AN IMAGE IS PROVIDED: identify the food, estimate calories and macros briefly.

                Return only valid JSON:
                {
                  "todayFocus": "<formatted answer — see format rules below>",
                  "actionItems": [],
                  "nutritionNote": "",
                  "actions": [],
                  "isAchievement": false
                }

                FORMAT RULES for todayFocus:
                - Write in the user's language (Turkish if question is in Turkish).
                - Use a relevant emoji at the very start of the message.
                - Bold (**...**) every key number or metric (e.g. **2539 kcal**, **95g protein**, **70 kg**).
                - If the answer has 2+ distinct points, put each on its own line with a bullet emoji (▪ or relevant emoji per point).
                - Keep total length under 3 lines. No long paragraphs.
                - Do NOT give unsolicited advice. Answer only what was asked.

                EXAMPLE FORMATS:
                Simple: "💧 Bugün **2.1 L** su içtin, hedefe **0.4 L** kaldı."
                Multi-point: "💪 Hedefin **2539 kcal** — bugün hiç kayıt yok.\\n▪ Akşam öğünü için **~800 kcal** ayır.\\n▪ Protein hedefin: **95–130g**."
                Achievement: "🏆 Harika! Bu hafta **5 antrenman** tamamladın."

                - actionItems, nutritionNote, actions: leave empty unless the user explicitly asked for them.

                NUTRITION UPDATE ACTIONS:
                If the user asks to change their nutrition goal or calorie target, add ONE action of type UPDATE_NUTRITION.
                The data field must be a JSON string with any of these optional keys:
                  "goal": one of [bulk, cut, maintain, strength]
                  "customKcalTarget": number (daily kcal, null to reset to auto)
                Example: {"label": "Hedefi güncelle", "type": "UPDATE_NUTRITION", "data": "{\"goal\":\"cut\",\"customKcalTarget\":2000}"}
                Only include keys that the user explicitly requested to change.
                """.formatted(
                        personalityBlock,
                        questionStrategy,
                        escape(profileSnapshot),
                        escape(recoverySnapshot),
                        escape(progressSnapshot),
                        escape(coachingSignals),
                        escape(insightBlock),
                        goal,
                        nullableInt(s.tdee),
                        nullableDouble(s.currentWeightKg),
                        nullableDouble(s.targetWeightKg),
                        safeInt(s.calories),
                        nullableInt(s.targetCalories),
                        nullableInt(s.proteinGrams),
                        nullableInt(s.carbsGrams),
                        nullableInt(s.fatGrams),
                        safeDouble(s.waterLiters),
                        safeInt(s.workouts),
                        safeInt(s.workoutMinutes),
                        nullableInt(s.userAge),
                        nullableDouble(s.userHeightCm),
                        s.userGender != null ? s.userGender : "unknown",
                        s.activityLevel != null ? s.activityLevel : "unknown",
                        safeInt(s.steps),
                        nullableDouble(s.sleepHours),
                        nullableDouble(s.bmi),
                        nullableInt(s.avgCaloriesLast7Days),
                        nullableInt(s.avgStepsLast7Days),
                        nullableDouble(s.weeklyWeightChangeKg),
                        nullableInt(s.weightStreak),
                        nullableDouble(s.currentWeightKg),
                        nullableDouble(s.targetWeightKg),
                        nullableInt(s.workoutMinutes),
                        nullableInt(s.targetCalories),
                        escape(mealBlock),
                        escape(workoutHighlightBlock),
                        escape(buildConversationBlock(request.conversationHistory)),
                        escape(request.question.trim()));
    }

    /** Escapes '%' so user content doesn't break String.formatted() */
    private String escape(String s) {
        return s == null ? "" : s.replace("%", "%%");
    }

    private String buildConversationBlock(java.util.List<AiCoachRequest.ConversationTurn> history) {
        if (history == null || history.isEmpty()) return "";
        var sb = new StringBuilder("CONVERSATION SO FAR:\n");
        int start = Math.max(0, history.size() - 8);
        for (int i = start; i < history.size(); i++) {
            var turn = history.get(i);
            if (turn.role != null && turn.content != null && !turn.content.isBlank()) {
                sb.append(turn.role.equals("user") ? "User: " : "Coach: ")
                  .append(turn.content.trim())
                  .append("\n");
            }
        }
        sb.append("\n");
        return sb.toString();
    }

    private String buildQuestionStrategy(String question) {
        String normalized = question == null ? "" : question.trim().toLowerCase(java.util.Locale.ROOT);
        if (normalized.contains("neden") || normalized.contains("why")) {
            return "- Explain the cause briefly, then tie it to the user's current metrics.";
        }
        if (normalized.contains("karşılaştır") || normalized.contains("compare") || normalized.contains("fark")) {
            return "- Compare the requested items directly and highlight the most important difference first.";
        }
        if (normalized.contains("plan") || normalized.contains("ne yap") || normalized.contains("odaklan")) {
            return "- Give a concrete next-step plan with the minimum number of actions needed.";
        }
        if (normalized.contains("kalori") || normalized.contains("makro") || normalized.contains("protein")) {
            return "- Use calories, macros, TDEE, and target gap to answer numerically where possible.";
        }
        if (normalized.contains("antrenman") || normalized.contains("workout") || normalized.contains("egzersiz")) {
            return "- Use recovery and recent training load to calibrate intensity and exercise guidance.";
        }
        return "- Answer directly, using the most relevant numbers and trends from the provided context.";
    }

    private String buildPersonalityBlock(String personality, String personalityInstruction) {
        if (personalityInstruction != null && !personalityInstruction.isBlank()) {
            return "Tone: " + personalityInstruction.trim();
        }
        if (personality != null && !personality.isBlank()) {
            return switch (personality.trim().toLowerCase()) {
                case "motivator" -> "Tone: direct and motivating.";
                case "scientist" -> "Tone: analytical, use numbers.";
                case "supportive" -> "Tone: warm and encouraging.";
                default -> "Tone: clear and friendly.";
            };
        }
        return "Tone: clear and friendly.";
    }

    private String buildInsightBlock(java.util.List<com.fitness.entity.AiInsight> insights) {
        if (insights == null || insights.isEmpty()) {
            return "No saved insights.";
        }
        return insights.stream()
                .filter(insight -> insight != null && insight.summary != null && !insight.summary.isBlank())
                .limit(3)
                .map(insight -> {
                    String type = insight.type == null || insight.type.isBlank() ? "INSIGHT" : insight.type.trim();
                    return "- " + type + ": " + insight.summary.trim();
                })
                .collect(java.util.stream.Collectors.joining("\n"));
    }

    private String buildMealBlock(AiCoachRequest.DailySummaryDto summary) {
        if (summary == null || summary.mealNames == null || summary.mealNames.isEmpty()) {
            return "No meals logged today.";
        }
        return summary.mealNames.stream()
                .filter(name -> name != null && !name.isBlank())
                .map(String::trim)
                .limit(6)
                .collect(java.util.stream.Collectors.joining(", "));
    }

    private String buildWorkoutHighlightBlock(AiCoachRequest.DailySummaryDto summary) {
        if (summary == null) {
            return "No workout highlights available.";
        }
        return safeHighlights(summary.workoutHighlights);
    }

    private String normalizeGoal(String goal) {
        if (goal == null)
            return "CUSTOM";
        String normalized = goal.trim().toUpperCase();
        return switch (normalized) {
            case "BULK", "CUT", "MAINTAIN", "STRENGTH" -> normalized;
            default -> "CUSTOM";
        };
    }

    private int safeInt(Integer value) {
        return value == null ? 0 : value;
    }

    private double safeDouble(Double value) {
        return value == null ? 0.0 : value;
    }

    private String nullableInt(Integer value) {
        return value == null ? "no data" : Integer.toString(value);
    }

    private String nullableDouble(Double value) {
        return value == null ? "no data" : String.format(java.util.Locale.US, "%.1f", value);
    }

    private String safeHighlights(java.util.List<String> highlights) {
        if (highlights == null || highlights.isEmpty()) {
            return "none";
        }
        return highlights.stream()
                .filter(v -> v != null && !v.trim().isEmpty())
                .map(String::trim)
                .limit(6)
                .collect(java.util.stream.Collectors.joining(", "));
    }
}
