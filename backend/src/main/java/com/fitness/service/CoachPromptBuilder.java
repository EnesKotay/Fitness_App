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

        final boolean isMidConversation = request.conversationHistory != null && request.conversationHistory.size() >= 2;
        final String conversationModeBlock = isMidConversation ? """
                ⚠️ CONVERSATION CONTEXT: You are MID-CONVERSATION with this user.
                - Do NOT re-introduce yourself or say "Merhaba" / "İyi akşamlar" etc.
                - Do NOT repeat or summarize data you already mentioned in this session.
                - Keep it natural — this is a flowing chat, not a new session.
                - Reference the prior conversation where relevant (e.g. "さっき言ったように..." / "Az önce bahsettiğimiz gibi...").
                - Match the conversational energy: if they were brief, be brief; if they opened up, be warmer.
                """ : "";

        return """
                You are a friendly, knowledgeable fitness coach who has genuine conversations — not a report generator.
                You already know the user's fitness data (shown below). Use it naturally, like a coach who has been tracking them.
                The user is talking TO you, not submitting a form. Respond as a person would: warm, direct, and human.

                %s
                %s

                HOW TO RESPOND:
                - Read the message carefully: is it a casual/emotional remark, a question, or a request for a plan?
                - CONVERSATIONAL / EMOTIONAL messages (complaints, worries, sharing feelings): reply warmly and briefly
                  in 1-3 natural sentences. Don't dump bullet lists. Talk like a friend who knows their data.
                - DATA / CALCULATION questions ("how many calories?", "what's my macro?"): give a direct, short numerical answer.
                - PLAN requests ("what should I do?", "make me a plan"): use structured bullets only if needed, keep it concise.
                - NEVER give unsolicited advice. Answer only what was asked.
                - Never say generic things like "drink water" or "sleep well" unless directly asked.
                - If data is missing, say so briefly — don't invent numbers.
                - If recovery signals are poor, factor that in naturally without lecturing.
                - Adapt your length to the message: short question → short answer. Complex question → slightly longer.

                QUESTION STRATEGY:
                %s

                USER PROFILE:
                %s

                RECOVERY SNAPSHOT:
                %s

                PROGRESS SNAPSHOT:
                %s

                COACHING SIGNALS (don't contradict these):
                %s

                LONG-TERM MEMORY:
                %s

                USER DATA (reference only what's relevant):
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

                %sCURRENT MESSAGE FROM USER: %s

                IF AN IMAGE IS PROVIDED: identify the food, estimate calories and macros briefly in a natural sentence.

                Return ONLY valid JSON:
                {
                  "todayFocus": "<your response — see formatting rules below>",
                  "actionItems": [],
                  "nutritionNote": "",
                  "actions": [],
                  "isAchievement": false
                }

                FORMATTING RULES for todayFocus:
                - Write in the user's language (Turkish if message is in Turkish).
                - Start with one fitting emoji.
                - Bold (**...**) key numbers or metrics only (e.g. **2539 kcal**, **70 kg**).
                - For CONVERSATIONAL messages: write 1-3 natural sentences, NO bullet lists.
                - For DATA questions: answer directly, one line if possible.
                - For PLAN messages: use bullet emojis (▪) only if there are truly multiple steps.
                - Do NOT always default to bullet lists — match the format to the message intent.

                EXAMPLES:
                Casual remark ("I haven't gained any weight"): "😕 Anlıyorum seni — sporunu yapıyorsun ama terazi hareket etmiyor. Kasların büyüdüğünü gördüysen bu aslında iyi bir işaret, ama kilo almak için kalori fazlasında olman lazım. Haftalık ortalamanı tutturmaya başlarsan sonuçlar görünür."
                Data question ("how much water did I drink?"): "💧 Bugün **2.1 L** su içtin, hedefe **0.4 L** kaldı."
                Plan request ("what should I eat tonight?"): "🥗 Akşamı şöyle planlayabilirsin:\n▪ Ana öğün: **~700 kcal**\n▪ Ara öğün: **~300 kcal**"

                - actionItems, nutritionNote, actions: leave EMPTY unless the user explicitly asked for those.

                NUTRITION UPDATE ACTIONS:
                If the user asks to change their nutrition goal or calorie target, add ONE action of type UPDATE_NUTRITION.
                The data field must be a JSON string with any of these optional keys:
                  "goal": one of [bulk, cut, maintain, strength]
                  "customKcalTarget": number (daily kcal, null to reset to auto)
                Example: {"label": "Hedefi güncelle", "type": "UPDATE_NUTRITION", "data": "{\"goal\":\"cut\",\"customKcalTarget\":2000}"}
                Only include keys the user explicitly requested to change.
                """.formatted(
                        personalityBlock,
                        escape(conversationModeBlock),
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

        // Detect conversational / emotional messages first — these need human replies, not bullet plans
        if (normalized.contains("ama ") || normalized.contains("fakat") || normalized.contains("niye") ||
                normalized.contains("neden") || normalized.contains("why") ||
                normalized.contains("üzgün") || normalized.contains("sıkıldım") ||
                normalized.contains("moralim") || normalized.contains("yoruldum") ||
                normalized.contains("artık") || normalized.contains("hep") ||
                normalized.contains("hiç") || normalized.contains("olmadı") ||
                normalized.contains("alamıyorum") || normalized.contains("veremiyorum") ||
                normalized.contains("motivasyonum") || normalized.contains("vazgeçmek")) {
            return "- This is a conversational/emotional message. Respond warmly in 1-3 natural sentences like a supportive friend. " +
                   "Acknowledge what they said, explain briefly using their data if relevant, then give ONE concrete tip if appropriate. " +
                   "Do NOT use bullet lists. Do NOT dump a meal plan.";
        }
        if (normalized.contains("karşılaştır") || normalized.contains("compare") || normalized.contains("fark")) {
            return "- Compare the requested items directly and highlight the most important difference first.";
        }
        if (normalized.contains("plan") || normalized.contains("ne yap") || normalized.contains("odaklan")) {
            return "- Give a concrete next-step plan with the minimum number of actions needed.";
        }
        if (normalized.contains("kalori") || normalized.contains("makro") || normalized.contains("protein")) {
            return "- Answer numerically using calories, macros, TDEE, and target gap. Keep it to 1-2 lines.";
        }
        if (normalized.contains("antrenman") || normalized.contains("workout") || normalized.contains("egzersiz")) {
            return "- Use recovery and recent training load to calibrate intensity. Be concise.";
        }
        // Short questions (under 8 words) are likely simple data queries — keep answer short
        if (normalized.split("\\s+").length < 8) {
            return "- Short, direct question. Give a concise 1-line answer using the most relevant data point.";
        }
        return "- Answer naturally and directly, referencing relevant numbers only where they add value.";
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
