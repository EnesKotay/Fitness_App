package com.fitness.service;

import com.fitness.dto.AiCoachRequest;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
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

    @Inject
    TurkishFitnessKnowledge fitnessKnowledge;

    @Inject
    SemanticMemoryService semanticMemoryService;

    // Katman 1: System Prompt (Değişmez Temel Kurallar)
    private static final String SYSTEM_PROMPT = """
        You are PusulaFit's AI Coach: a knowledgeable, empathetic, and direct fitness expert.
        Your goal is to converse naturally with the user, referencing their provided context only when directly relevant.
        
        CRITICAL RULES:
        1. JSON STRICTNESS: You MUST respond with ONLY a valid JSON object. No markdown code blocks (`\\`\\`\\`json`), no greeting text before JSON, no trailing text. If you output anything outside the JSON brackets, the system will crash.
        2. ANSWER THE QUESTION DIRECTLY — this is the most important rule:
           - Casual/Emotional message -> 1-2 warm sentences in todayFocus.
           - Simple question (e.g., "is plank good?", "how many calories?") -> 1 direct answer in todayFocus.
           - List request (e.g., "tell me exercises", "give me a workout", "what foods?") -> Short intro in todayFocus + full list in actionItems. NEVER just say "I prepared a plan" — always include the actual content.
           - Plan/Program request -> Brief context in todayFocus + detailed steps in actionItems.
        3. DATA RELEVANCE (IMPORTANT): Answer ONLY what is asked. Do NOT mention target weight, daily calories, or personal data unless the user's question is explicitly about weight change or their diet.
        4. TONE & FORMATTING: Be warm but professional. Start the `todayFocus` field with a relevant emoji. Use Markdown (**bold**) for key metrics in actionItems.
        5. NO REPETITION: If conversation history exists, do not say "Merhaba" again. Continue the flow seamlessly.
        6. TEMPORAL FLEXIBILITY: Answer for the exact time frame the user specifies. If they mention 'yarın' (tomorrow), 'hafta sonu' (weekend), 'akşam' (evening), 'sabah' (morning), or any future period — respond for THAT time. The user's daily data shows today's context, but never force a time-based frame unless the user explicitly asks about right now.
        7. COACH-LIKE CONVERSATION: Do not sound like a canned FAQ. React to the user's exact words, recent history, and available trends. If the request is vague, give one useful next step and ask at most one short clarifying question.
        8. PERSONALIZATION: Use memory, feedback, and trends quietly. Never say "according to your data" unless it helps. Make the answer feel remembered, not robotic.
        """;

    // Haftalık plan modu için özel talimat
    private static final String WEEKLY_PLAN_INSTRUCTION = """
        TASK: WEEKLY TRAINING PLAN
        Generate a structured 7-day workout plan based on the user's goal, fitness level, and available equipment.
        Use the user's context (workoutsPerWeek, focusAreas, injuries, bodyWeight) from the question.
        RULES:
        - todayFocus: 1-2 sentence summary of the week's approach (emoji + goal + key principle).
        - actionItems: Exactly 7 entries, one per day (Pazartesi–Pazar). Format each as:
          "📅 [DayName]: [Focus] — [Exercise1], [Exercise2], [Exercise3 with sets×reps]"
          Rest days: "😴 [DayName]: Dinlenme — Hafif yürüyüş veya esneme önerilir"
        - nutritionNote: One short protein/calorie tip aligned with the goal.
        - Do NOT add SAVE_WORKOUT actions for weekly plans.
        """;

    // Katman 2: Output Format (JSON Şablonu ve Özel Aksiyon Kuralları)
    private static final String JSON_FORMAT_INSTRUCTION = """
        EXPECTED OUTPUT FORMAT (Raw, Valid JSON only):
        {
          "todayFocus": "<Direct answer to the user's question in Turkish. Use \\n for line breaks. For exercise/plan requests, briefly introduce here then list details in actionItems. For simple questions answer completely here.>",
          "actionItems": ["<Item 1>", "<Item 2>", "..."],
          "nutritionNote": "<Only if nutrition-relevant, otherwise empty string>",
          "actions": [],
          "isAchievement": false
        }

        FIELD USAGE RULES:
        - todayFocus: ALWAYS answer the question directly. Never write only a generic intro like "I prepared a plan for you" — that alone is useless. Write the actual answer.
        - actionItems: Use for lists of exercises, meal items, steps, tips. Each item is a string. Example for exercise request: ["💪 Şınav: 3 set x 15 tekrar", "🔥 Mekik: 3 set x 20 tekrar", "🦵 Squat: 3 set x 15 tekrar", "⚡ Plank: 3 set x 45 saniye"]. Leave empty [] only for single-sentence answers.
        - nutritionNote: Only for nutrition tips. Leave "" for workout/recovery/general questions.

        NUTRITION UPDATE RULE:
        1. If the user explicitly asks to change their fitness goal (bulk/cut/maintain) or custom calorie target, add ONE action object to the "actions" array:
        {"label": "Hedefi Güncelle", "type": "UPDATE_NUTRITION", "data": "{\\"goal\\":\\"cut\\",\\"customKcalTarget\\":2000}"}

        ADD FOOD RULE:
        2. If the user tells you they ate a specific food and you estimate its calories, offer to log it:
        {"label": "Günlüğe Ekle (850 kcal)", "type": "ADD_FOOD", "data": "{\\"name\\":\\"İskender\\",\\"kcal\\":850,\\"protein\\":40,\\"carbs\\":60,\\"fat\\":35,\\"mealType\\":\\"lunch\\"}"}

        SAVE_WORKOUT RULE:
        3. If you provide a workout plan in actionItems (exercises with sets/reps), also add ONE action:
        {"label": "💪 Antrenmanı Kaydet", "type": "SAVE_WORKOUT", "data": "{\"name\":\"Ev Antrenmanı\",\"workoutType\":\"STRENGTH\",\"muscleGroup\":\"FULL_BODY\",\"durationMinutes\":45}"}
        Adjust name/muscleGroup/durationMinutes to match the actual plan you gave.

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
        if ("weekly_plan".equals(request.taskMode)) {
            prompt.append(WEEKLY_PLAN_INSTRUCTION).append("\n");
        } else if (request.taskMode != null && !request.taskMode.isBlank()) {
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

        // 2b. WORKOUT HISTORY (Son 7 günün antrenman geçmişi)
        if (ctx.workoutHistory != null && !ctx.workoutHistory.isBlank()) {
            prompt.append(ctx.workoutHistory).append("\n");
        }

        // 2c. FEEDBACK MEMORY (Kullanıcının beğenip beğenmediği yanıt stilleri)
        if (ctx.feedbackMemory != null && !ctx.feedbackMemory.isBlank()) {
            prompt.append(ctx.feedbackMemory).append("\n");
        }

        if (request.userMemory != null && !request.userMemory.isBlank()) {
            prompt.append("--- CLIENT USER MEMORY SUMMARY ---\n")
                    .append(sanitizeUserInput(request.userMemory, 1200))
                    .append("\n");
        }

        // 3. KONUŞMA GEÇMİŞİ (Son 6 Mesaj - Token Tasarrufu)
        String history = buildConversationBlock(request.conversationHistory);
        if (!history.isEmpty()) {
            prompt.append("--- CONVERSATION HISTORY ---\n").append(history).append("\n");
        }

        // 4a. DEEP MEMORY RAG — Semantic long-term user memories
        if (context != null && context.userId != null) {
            String deepMemory = semanticMemoryService.buildRelevantMemoryBlock(
                context.userId, request.question);
            if (!deepMemory.isEmpty()) {
                prompt.append("--- USER LONG-TERM MEMORY (critical: use these facts, never contradict them) ---\n");
                prompt.append(deepMemory).append("\n\n");
            }
        }

        // 4b. RAG — Konuya özel bilimsel bilgi enjeksiyonu
        String knowledgeSnippet = fitnessKnowledge.retrieve(request.question);
        if (!knowledgeSnippet.isEmpty()) {
            prompt.append("--- EVIDENCE-BASED FACT (use this in your answer, do not contradict it) ---\n");
            prompt.append(knowledgeSnippet).append("\n\n");
        }

        // 5. FEW-SHOT EXAMPLES
        prompt.append("""
            --- EXAMPLES OF IDEAL RESPONSES ---
            Example 1:
            User: "bana evde yapılacak hareketler söyle"
            {"todayFocus":"💪 İşte ekipman gerektirmeyen evde tam vücut antrenmanı:","actionItems":["🔥 Şınav: 3 set x 15 tekrar","🦵 Çömelme (Squat): 3 set x 20 tekrar","⚡ Plank: 3 set x 45 saniye","🤸 Lunge: 3 set x 12 tekrar (her bacak)","🔄 Superman: 3 set x 15 tekrar"],"nutritionNote":"","actions":[],"isAchievement":false}

            Example 2:
            User: "kreatin ne zaman kullanılmalı?"
            {"todayFocus":"🧪 Kreatin kullanımı için en etkili yöntem: antrenmandan **30-60 dakika önce** veya hemen **sonrasında** 3-5g almak. Yükleme fazı şart değil ama ilk 1 haftada günde 20g (4x5g) alınırsa depolar daha hızlı dolar.","actionItems":[],"nutritionNote":"Kreatin, su tutulumunu artırır — günlük su tüketimine dikkat et.","actions":[],"isAchievement":false}

            Example 3:
            User: "bugün nasılım?"
            {"todayFocus":"📊 Bugünkü verilerine göre: **%85** yolunda gidiyorsun! Kalori hedefin tutturulmuş, antrenman yapılmış. Eksik tek şey su — hedefe biraz daha var.","actionItems":["💧 250ml su iç","🌙 Yatmadan önce hafif protein al (yoğurt/süt)"],"nutritionNote":"","actions":[],"isAchievement":false}

            Example 4:
            User: "çok zorlanıyorum"
            {"todayFocus":"🧭 Tamam, bugün hedefi büyütmeyelim. Senden istediğim tek şey: **10 dakikalık çok hafif bir başlangıç**. Bu, motivasyon beklemekten daha güvenilir.","actionItems":["🚶 5 dk rahat yürüyüş","💧 1 bardak su","✅ Sonra bana sadece 'bitti' yaz"],"nutritionNote":"","actions":[],"isAchievement":false}
            --- END EXAMPLES ---
            """);

        // 5. GÜNCEL KULLANICI MESAJI
        prompt.append("--- CURRENT MESSAGE ---\n");
        String safeQuestion = sanitizeUserInput(request.question, 2000);
        prompt.append("User: ").append(safeQuestion).append("\n\n");
        prompt.append("Remember: Output ONLY raw, valid JSON without any markdown formatting.");

        return prompt.toString();
    }

    /**
     * Kullanıcının sayısal verilerini tokenize optimize edilmiş, kısa ve okunabilir şekilde hazırlar.
     */
    private String buildUserDataBlock(AiCoachRequest request, AiCoachRequest.DailySummaryDto s) {
        if (s == null) return "No daily summary provided.";
        
        String locationLabel = resolveWorkoutLocation(s.workoutLocation);
        String equipmentLabel = resolveEquipmentType(s.equipmentType);

        return String.format(Locale.US, """
            Goal: %s | TDEE: %s kcal
            Weight: %s kg -> Target: %s kg (Change: %s kg/wk)
            Nutrition Today: %d kcal eaten / %s kcal target (P: %sg, C: %sg, F: %sg)
            Activity Today: %d workouts (%s min), %s steps
            7-Day Trends: avg calories %s kcal, recent calories %s, avg water %s L, weekly weight change %s kg
            Meals Today: %s
            Workout Highlights: %s
            Training Setup: %s | Equipment: %s
            Profile: %s age, %s cm height, %s
            """,
            normalizeGoal(request.goal),
            nullableInt(s.tdee),
            nullableDouble(s.currentWeightKg), nullableDouble(s.targetWeightKg), nullableDouble(s.weeklyWeightChangeKg),
            safeInt(s.calories), nullableInt(s.targetCalories),
            nullableInt(s.proteinGrams), nullableInt(s.carbsGrams), nullableInt(s.fatGrams),
            safeInt(s.workouts), nullableInt(s.workoutMinutes), nullableInt(s.steps),
            nullableInt(s.avgCaloriesLast7Days), formatIntList(s.recentDaysCalories), nullableDouble(s.avgWaterLast7Days), nullableDouble(s.weeklyWeightChangeKg),
            formatStringList(s.mealNames), formatStringList(s.workoutHighlights),
            locationLabel, equipmentLabel,
            nullableInt(s.userAge), nullableDouble(s.userHeightCm), s.userGender != null ? s.userGender : "unknown"
        );
    }

    private String resolveWorkoutLocation(String location) {
        if (location == null) return "home";
        return switch (location) {
            case "gym"     -> "gym";
            case "outdoor" -> "outdoor";
            default        -> "home";
        };
    }

    private String resolveEquipmentType(String equipment) {
        if (equipment == null) return "bodyweight only";
        return switch (equipment) {
            case "dumbbells" -> "dumbbells/kettlebells";
            case "full_gym"  -> "full gym equipment (barbells, machines)";
            default          -> "bodyweight only";
        };
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
            .map(t -> {
                String label = t.role.equals("user") ? "User: " : "Coach: ";
                int limit = t.role.equals("user") ? 1000 : 2000;
                return label + sanitizeUserInput(t.content, limit);
            })
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

    private String formatIntList(List<Integer> values) {
        if (values == null || values.isEmpty()) return "-";
        return values.stream()
                .limit(5)
                .map(v -> v == null ? "-" : Integer.toString(v))
                .collect(Collectors.joining(", "));
    }

    private String formatStringList(List<String> values) {
        if (values == null || values.isEmpty()) return "-";
        return values.stream()
                .filter(v -> v != null && !v.isBlank())
                .limit(6)
                .map(v -> sanitizeUserInput(v, 80))
                .collect(Collectors.joining(", "));
    }

    /**
     * Kullanıcı girdisini prompt'a eklemeden önce temizler:
     * - Null byte ve Unicode control karakterleri kaldırır
     * - Newline injection engeli (satır sonu → boşluk)
     * - Prompt delimiter injection engeli (--- blokları kırpar)
     * - Uzunluk sınırı
     */
    private String sanitizeUserInput(String input, int maxLen) {
        if (input == null || input.isBlank()) return "";
        String cleaned = input.trim()
                // Newline injection — tüm satır sonu varyantları
                .replace("\r\n", " ")
                .replace("\r", " ")
                .replace("\n", " ")
                // Null byte ve control karakterleri (U+0000–U+001F, U+007F)
                .replaceAll("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]", "")
                // Prompt delimiter injection: "---" bloklarını boz
                .replace("---", "- - -")
                // System prompt override girişimi: köşeli parantez kalıpları
                .replaceAll("(?i)\\[SYSTEM\\]|\\[INST\\]|\\[/INST\\]|<\\|system\\|>|<\\|user\\|>", "");
        if (cleaned.length() > maxLen) {
            cleaned = cleaned.substring(0, maxLen);
        }
        return cleaned;
    }
}
