package com.fitness.service;

import com.fitness.dto.AiCoachRequest;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

/**
 * Builds optimized, robust prompts for the AI Coach service.
 * Refactored to reduce fragility, improve JSON compliance, and leverage LLM intent inference
 * rather than hardcoded string matching.
 */
@ApplicationScoped
public class CoachPromptBuilder {

    // Katman 1: System Prompt (Değişmez Temel Kurallar)
    private static final String SYSTEM_PROMPT = """
        You are FitMentor's AI Coach: a knowledgeable, empathetic, and direct fitness expert.
        Your goal is to converse naturally with the user, referencing their provided context only when directly relevant.
        
        CRITICAL RULES:
        1. JSON STRICTNESS: You MUST respond with ONLY a valid JSON object. No markdown code blocks (`\\`\\`\\`json`), no greeting text before JSON, no trailing text. If you output anything outside the JSON brackets, the system will crash.
        2. INTENT-BASED LENGTH:
           - Casual/Emotional message -> 1-2 warm sentences.
           - Simple question (e.g., "is plank good?", "how many calories?") -> 1 direct sentence.
           - Explicit plan request (e.g., "give me a workout program", "make a meal plan") -> Detailed list with bullet points.
        3. DATA RELEVANCE (IMPORTANT): Answer ONLY what is asked. Do NOT mention target weight, daily calories, or personal data unless the user's question is explicitly about weight change or their diet.
        4. TONE & FORMATTING: Be warm but professional. Start the `todayFocus` field with a relevant emoji. Use Markdown (**bold**) for key metrics.
        5. NO REPETITION: If conversation history exists, do not say "Merhaba" again. Continue the flow seamlessly.
        """;

    // Katman 2: Output Format (JSON Şablonu ve Özel Aksiyon Kuralları)
    private static final String JSON_FORMAT_INSTRUCTION = """
        EXPECTED OUTPUT FORMAT (Raw, Valid JSON only):
        {
          "todayFocus": "<your response string in Turkish. Use \\n for line breaks>",
          "actionItems": [],
          "nutritionNote": "",
          "actions": [],
          "isAchievement": false
        }
        
        NUTRITION UPDATE RULE:
        If the user explicitly asks to change their fitness goal (bulk/cut/maintain) or custom calorie target, add ONE action object to the "actions" array:
        {"label": "Hedefi Güncelle", "type": "UPDATE_NUTRITION", "data": "{\\"goal\\":\\"cut\\",\\"customKcalTarget\\":2000}"}
        Otherwise, leave "actions" empty.
        """;

    /**
     * Build a prompt for the AI coach based on the user's request.
     */
    public String buildPrompt(
            AiCoachRequest request,
            List<com.fitness.entity.AiInsight> insights,
            CoachPromptContext context) {
        
        AiCoachRequest.DailySummaryDto s = request.dailySummary;
        CoachPromptContext ctx = context != null ? context : CoachPromptContext.empty();

        StringBuilder prompt = new StringBuilder();

        // 1. TEMEL KURALLAR VE ŞABLON
        prompt.append(SYSTEM_PROMPT).append("\n");
        
        if (request.personalityInstruction != null && !request.personalityInstruction.isBlank()) {
            prompt.append("ADDITIONAL TONE INSTRUCTION: ").append(request.personalityInstruction.trim()).append("\n");
        }
        if (request.taskMode != null && !request.taskMode.isBlank()) {
            prompt.append("CURRENT LENS: ").append(request.taskMode.trim()).append(" (Focus on this aspect if the question is vague)\n");
        }
        prompt.append("\n").append(JSON_FORMAT_INSTRUCTION).append("\n");

        // 2. DİNAMİK BAĞLAM (Kullanıcı Verileri - Token Optimize)
        prompt.append("--- USER CONTEXT ---\n");
        prompt.append(buildUserDataBlock(request, s)).append("\n");
        
        String healthSnapshots = buildHealthSnapshots(ctx, insights);
        if (!healthSnapshots.isEmpty()) {
            prompt.append(healthSnapshots).append("\n");
        }

        // 3. KONUŞMA GEÇMİŞİ (Son 6 Mesaj - Token Tasarrufu)
        String history = buildConversationBlock(request.conversationHistory);
        if (!history.isEmpty()) {
            prompt.append("--- CONVERSATION HISTORY ---\n").append(history).append("\n");
        }

        // 4. GÜNCEL KULLANICI MESAJI
        prompt.append("--- CURRENT MESSAGE ---\n");
        prompt.append("User: ").append(request.question != null ? request.question.trim() : "").append("\n\n");
        prompt.append("Remember: Output ONLY raw, valid JSON without any markdown formatting.");

        return prompt.toString();
    }

    /**
     * Kullanıcının sayısal verilerini tokenize optimize edilmiş, kısa ve okunabilir şekilde hazırlar.
     */
    private String buildUserDataBlock(AiCoachRequest request, AiCoachRequest.DailySummaryDto s) {
        if (s == null) return "No daily summary provided.";
        
        return String.format(Locale.US, """
            Goal: %s | TDEE: %s kcal
            Weight: %s kg -> Target: %s kg (Change: %s kg/wk)
            Nutrition Today: %d kcal eaten / %s kcal target (P: %sg, C: %sg, F: %sg)
            Activity Today: %d workouts (%s min), %s steps
            Profile: %s age, %s cm height, %s
            """,
            normalizeGoal(request.goal),
            nullableInt(s.tdee),
            nullableDouble(s.currentWeightKg), nullableDouble(s.targetWeightKg), nullableDouble(s.weeklyWeightChangeKg),
            safeInt(s.calories), nullableInt(s.targetCalories),
            nullableInt(s.proteinGrams), nullableInt(s.carbsGrams), nullableInt(s.fatGrams),
            safeInt(s.workouts), nullableInt(s.workoutMinutes), nullableInt(s.steps),
            nullableInt(s.userAge), nullableDouble(s.userHeightCm), s.userGender != null ? s.userGender : "unknown"
        );
    }

    /**
     * Toparlanma, gelişim sinyalleri ve geçmiş AI çıkarımlarını birleştirir.
     */
    private String buildHealthSnapshots(CoachPromptContext ctx, List<com.fitness.entity.AiInsight> insights) {
        StringBuilder sb = new StringBuilder();
        if (ctx.recoverySnapshot != null && !ctx.recoverySnapshot.isBlank()) {
            sb.append("Recovery: ").append(ctx.recoverySnapshot.trim()).append("\n");
        }
        if (ctx.coachingSignals != null && !ctx.coachingSignals.isBlank()) {
            sb.append("Signals: ").append(ctx.coachingSignals.trim()).append("\n");
        }
        if (insights != null && !insights.isEmpty()) {
            String insightList = insights.stream()
                .filter(i -> i != null && i.summary != null && !i.summary.isBlank())
                .limit(3)
                .map(i -> "- " + i.summary.trim())
                .collect(Collectors.joining("\n"));
            if (!insightList.isEmpty()) {
                sb.append("Long-term Insights:\n").append(insightList).append("\n");
            }
        }
        return sb.toString().trim();
    }

    /**
     * Geçmiş konuşmaları token limitini aşmamak için son 6 mesajla sınırlandırarak ekler.
     */
    private String buildConversationBlock(List<AiCoachRequest.ConversationTurn> history) {
        if (history == null || history.isEmpty()) return "";
        int start = Math.max(0, history.size() - 6);
        return history.subList(start, history.size()).stream()
            .filter(t -> t.role != null && t.content != null && !t.content.isBlank())
            .map(t -> (t.role.equals("user") ? "User: " : "Coach: ") + t.content.trim())
            .collect(Collectors.joining("\n"));
    }

    private String normalizeGoal(String goal) {
        if (goal == null) return "CUSTOM";
        String normalized = goal.trim().toUpperCase();
        return switch (normalized) {
            case "BULK", "CUT", "MAINTAIN", "STRENGTH" -> normalized;
            default -> "CUSTOM";
        };
    }

    private int safeInt(Integer value) { return value == null ? 0 : value; }
    private String nullableInt(Integer value) { return value == null ? "-" : value.toString(); }
    private String nullableDouble(Double value) { return value == null ? "-" : String.format(Locale.US, "%.1f", value); }
}
