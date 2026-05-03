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
        String taskModeBlock = buildTaskModeBlock(request.taskMode, request.taskModeInstruction);
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
                - Reference the prior conversation only when it directly helps answer the current message.
                - Match the conversational energy: if they were brief, be brief; if they opened up, be warmer.
                """ : "";

        return """
                You are a friendly, knowledgeable fitness coach who has genuine conversations — not a report generator.
                You already know the user's fitness data (shown below). Use it naturally, like a coach who has been tracking them.
                The user is talking TO you, not submitting a form. Respond as a person would: warm, direct, and human.

                %s
                %s
                %s

                HOW TO RESPOND:
                - Read the message carefully: is it a greeting, a casual/emotional remark, a data question, or a plan/program request?
                - GREETING / SMALLTALK (merhaba, selam, nasılsın, hey, iyi günler): reply briefly and naturally in 1-2 sentences.
                  You may give a quick status hook from their data, but keep it conversational — not a data dump.
                - CONVERSATIONAL / EMOTIONAL messages (complaints, worries, sharing feelings): reply warmly and briefly
                  in 1-3 natural sentences. Don't dump bullet lists. Talk like a friend who knows their data.
                - DATA / CALCULATION questions ("how many calories?", "what's my macro?"): give a direct, short numerical answer.
                - PLAN / PROGRAM requests ("make me a plan", "give me a workout", "antrenman ver", "program yap"): give a DETAILED,
                  STRUCTURED response with specific items. For workout requests, list exercises with sets, reps, and rest times.
                  For meal plans, list specific foods with portions and calories. This is what the user came here for — deliver value.
                - NEVER give unsolicited advice. Answer ONLY and EXACTLY what was asked — nothing more.
                - Never say generic things like "drink water" or "sleep well" unless directly asked.
                - If data is missing, say so briefly — don't invent numbers.
                - If recovery signals are poor, factor that in naturally without lecturing.
                - Adapt your length to the message: short question → short answer. Plan/program request → detailed and thorough.
                - If the message is vague, answer the most likely interpretation in 1-2 sentences rather than asking for clarification.
                - Do NOT answer adjacent questions the user did not ask.
                - Do NOT turn a simple lookup into a plan.
                - Do NOT add meal plans, workout plans, warnings, or motivation unless the user asked for them.
                - If the user asks for one number, lead with that number in the first sentence.
                - If the user says "ver", "yap", "hazırla", "öner", "oluştur" — they are requesting content. DELIVER IT, don't just describe what you could do.

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
                - Steps: %s | Sleep: %s | BMI: %s | 7d avg calories: %s | 7d avg steps: %s
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
                - For PLAN messages: use bullet emojis (▪) only if there are truly multiple steps, max 5 bullets.
                - Do NOT always default to bullet lists — match the format to the message intent.
                - If the user asks for comparison, start with the winner or the key difference in the first sentence.
                - If the user asks for a correction to a previous answer, update only that part and do not rewrite the whole session.

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
                        taskModeBlock,
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
                        nullableInt(s.steps),
                        s.sleepHours != null && s.sleepHours > 0
                                ? String.format(java.util.Locale.US, "%.1f h", s.sleepHours)
                                : "not tracked",
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

    private String buildTaskModeBlock(String taskMode, String taskModeInstruction) {
        String normalized = taskMode == null ? "" : taskMode.trim().toLowerCase(java.util.Locale.ROOT);
        String instruction = taskModeInstruction == null ? "" : taskModeInstruction.trim();

        if (normalized.isEmpty() && instruction.isEmpty()) {
            return "TASK MODE: none. Use the user's exact question to choose the response style.";
        }

        String modeMeaning = switch (normalized) {
            case "nutrition" -> "Nutrition lens: prioritize calories, macros, foods, portions, and meal structure when relevant.";
            case "workout" -> "Workout lens: prioritize exercise selection, training load, intensity, and recovery when relevant.";
            case "recovery" -> "Recovery lens: prioritize sleep, hydration, fatigue, soreness, and readiness when relevant.";
            case "analysis" -> "Analysis lens: prioritize diagnosis, trend interpretation, and the single most useful insight.";
            case "plan" -> "Planning lens: prioritize a concrete next-step plan if and only if the user asks for a plan.";
            default -> "Custom lens: use the supplied task mode only as a relevance hint.";
        };

        String extra = instruction.isEmpty() ? "" : " Requested lens: " + instruction + ".";
        return "TASK MODE: " + modeMeaning + extra
                + " This is a hint, not permission to change the subject. If the user's message is narrower than the mode, answer the narrower question only.";
    }

    private String buildQuestionStrategy(String question) {
        String normalized = question == null ? "" : question.trim().toLowerCase(java.util.Locale.ROOT);

        // ── 0. GREETING / SMALLTALK ──
        boolean isGreeting =
            normalized.matches("(merhaba|selam|hey|hi|hello|iyi günler|günaydın|iyi akşamlar|nasılsın|naber|ne haber|ne yapıyorsun)[.!?]?") ||
            (normalized.split("\\s+").length <= 3 &&
                (normalized.contains("merhaba") || normalized.contains("selam") || normalized.contains("hey") ||
                 normalized.contains("günaydın") || normalized.contains("iyi günler") || normalized.contains("nasılsın") ||
                 normalized.contains("naber") || normalized.contains("ne haber")));
        if (isGreeting) {
            return "- GREETING / SMALLTALK. Reply warmly in 1-2 sentences. You may include one quick hook from their data" +
                   " (e.g. today's calories or streak) but keep it brief and conversational. No bullet lists. No advice.";
        }

        // ── 1. EMOTIONAL / CONVERSATIONAL — needs a human reply, NOT bullet lists ──
        boolean isEmotional =
            normalized.contains("ama ") || normalized.contains("fakat") ||
            normalized.contains("niye") || normalized.contains("neden") || normalized.contains("why") ||
            normalized.contains("üzgün") || normalized.contains("sıkıldım") || normalized.contains("bunald") ||
            normalized.contains("moralim") || normalized.contains("yoruldum") || normalized.contains("bitik") ||
            normalized.contains("artık") || normalized.contains("hep ") || normalized.contains("hiç ") ||
            normalized.contains("olmadı") || normalized.contains("olmuyor") || normalized.contains("olmıyor") ||
            normalized.contains("gelmiyor") || normalized.contains("alamıyorum") || normalized.contains("veremiyorum") ||
            normalized.contains("motivasyon") || normalized.contains("vazgeçmek") || normalized.contains("bırakmak") ||
            normalized.contains("çok zor") || normalized.contains("sıkıntı") || normalized.contains("stres") ||
            normalized.contains("endişe") || normalized.contains("korku") || normalized.contains("korkuyorum") ||
            normalized.contains("nasıl hissed") || normalized.contains("berbat") || normalized.contains("kötü") ||
            normalized.contains("harika") || normalized.contains("muhteşem") || normalized.contains("sinirli") ||
            normalized.contains("üzülüyorum") || normalized.contains("sevinçli") || normalized.contains("mutlu") ||
            normalized.contains("mutsuz") || normalized.contains("panik") || normalized.contains("bunald") ||
            normalized.contains("dayanamıyorum") || normalized.contains("yapamıyorum");
        if (isEmotional) {
            return "- EMOTIONAL/CONVERSATIONAL message. Reply warmly in 1-3 short natural sentences — like a supportive friend." +
                   " Acknowledge their feeling first, then briefly reference their data only if it genuinely helps, then one concrete tip if relevant." +
                   " No bullet lists, no meal plans, no unsolicited advice.";
        }

        // ── 2. COMPARISON ──
        if (normalized.contains("karşılaştır") || normalized.contains("compare") ||
            normalized.contains("hangisi daha") || normalized.contains("mi daha") || normalized.contains("mı daha") ||
            normalized.contains("farkı ne") || normalized.contains("fark nedir") || normalized.contains("fark var mı")) {
            return "- COMPARISON question. State the key difference in 1 sentence, then add 1-2 relevant numbers. Be brief.";
        }

        // ── 3. NUTRITION DATA / CALCULATION ──
        boolean isNutritionCalc =
            normalized.contains("kaç kalori") || normalized.contains("kaç kcal") ||
            normalized.contains("kalori") || normalized.contains("kalori yedim") ||
            normalized.contains("makro") || normalized.contains("protein") ||
            normalized.contains("karbonhidrat") || normalized.contains("yağ gram") ||
            normalized.contains("tdee") || normalized.contains("ihtiyac") || normalized.contains("hedefim") ||
            normalized.contains("günlük hedef") || normalized.contains("kalorisi") ||
            normalized.contains("ne kadar yedim") || normalized.contains("kalan kalori");
        if (isNutritionCalc) {
            return "- NUTRITION CALCULATION question. Give a direct, specific numerical answer using the user's actual data" +
                   " (calories eaten, target, TDEE, macros, remaining). 1-2 lines max. No preamble, no filler.";
        }

        // ── 4. WORKOUT / TRAINING ──
        boolean isWorkout =
            normalized.contains("antrenman") || normalized.contains("egzersiz") ||
            normalized.contains("workout") || normalized.contains("spor yap") ||
            normalized.contains("hareket") || normalized.contains("kas") ||
            normalized.contains("ağırlık") || normalized.contains("set ") ||
            normalized.contains("tekrar") || normalized.contains("form") ||
            normalized.contains("kardiyo") || normalized.contains("koşu") ||
            normalized.contains("yüzme") || normalized.contains("bisiklet") ||
            normalized.contains("bench") || normalized.contains("squat") ||
            normalized.contains("deadlift") || normalized.contains("crunch") ||
            normalized.contains("plank") || normalized.contains("dumbbell") ||
            normalized.contains("barbell") || normalized.contains("hiit") ||
            normalized.contains("pilates") || normalized.contains("yoga") ||
            normalized.contains("ne kadar spor") || normalized.contains("kaç dakika");
        if (isWorkout) {
            // Detect explicit program/plan requests vs simple questions
            boolean wantsProgram = normalized.contains("ver") || normalized.contains("yap") ||
                normalized.contains("hazırla") || normalized.contains("öner") || normalized.contains("oluştur") ||
                normalized.contains("program") || normalized.contains("plan") || normalized.contains("rutin") ||
                normalized.contains("listele") || normalized.contains("full body") || normalized.contains("üst vücut") ||
                normalized.contains("alt vücut") || normalized.contains("push pull") || normalized.contains("split") ||
                normalized.contains("give me") || normalized.contains("create");
            if (wantsProgram) {
                return "- WORKOUT PROGRAM REQUEST. The user is explicitly asking for a workout plan/program." +
                       " You MUST provide a COMPLETE, DETAILED workout with:\n" +
                       "  1. Exercise names (use real exercise names like Barbell Squat, Bench Press, etc.)\n" +
                       "  2. Sets × Reps for each exercise (e.g. 4×10)\n" +
                       "  3. Rest periods between sets (e.g. 60-90 sn)\n" +
                       "  4. Brief form cues if helpful\n" +
                       " Organize by muscle group or circuit. Use 5-8 exercises minimum for full body." +
                       " Consider the user's goal (bulk/cut/maintain), experience level from their data, and recovery state." +
                       " Do NOT give a vague overview — give the ACTUAL program they can follow TODAY." +
                       " Format with bullet emojis (▪) for each exercise.";
            }
            return "- WORKOUT question. Consider recovery state and recent workout minutes from the user's data." +
                   " Give a focused recommendation. If asking for advice, 1-2 sentences.";
        }

        // ── 5. WEIGHT / BODY COMPOSITION ──
        boolean isWeight =
            normalized.contains("kilo") || normalized.contains("kilo verdim") || normalized.contains("kilo aldım") ||
            normalized.contains("kas kütlesi") || normalized.contains("bmi") ||
            normalized.contains("vücut yağı") || normalized.contains("vücut") ||
            normalized.contains("zayıflama") || normalized.contains("şişmanlama") ||
            normalized.contains("kilo kaybı") || normalized.contains("hedef kilo") ||
            normalized.contains("kaç kilo") || normalized.contains("tartı");
        if (isWeight) {
            return "- WEIGHT/BODY question. Reference current weight, target, weekly change, and BMI from the user's data." +
                   " If asking for a timeline estimate, calculate based on realistic 0.3-0.7 kg/week. Be direct with the numbers.";
        }

        // ── 6. MEAL / FOOD SUGGESTION ──
        boolean isMealRequest =
            normalized.contains("ne yeme") || normalized.contains("ne yiyeyim") ||
            normalized.contains("öğün") || normalized.contains("yemek öner") ||
            normalized.contains("kahvaltı") || normalized.contains("akşam yemeği") ||
            normalized.contains("öğle yemeği") || normalized.contains("menü") ||
            normalized.contains("tarif") || normalized.contains("ne pişir") ||
            normalized.contains("yemek listesi") || normalized.contains("nasıl besleneyim") ||
            normalized.contains("yemek") || normalized.contains("ne yesem") ||
            normalized.contains("ne atsam") || normalized.contains("snack") ||
            normalized.contains("ara öğün") || normalized.contains("beslenme planı") ||
            normalized.contains("diyet listesi") || normalized.contains("sağlıklı ye") ||
            normalized.contains("meyve") || normalized.contains("sebze") ||
            normalized.contains("et ") || normalized.contains("tavuk") || normalized.contains("balık");
        if (isMealRequest) {
            return "- MEAL SUGGESTION request. Suggest specific foods/portions using the remaining calorie and macro budget from user data." +
                   " Be practical and specific (name real foods with approximate portions). If asking for a full day plan," +
                   " use a short meal list (breakfast/lunch/dinner/snack). Always state remaining calories from their data.";
        }

        // ── 7. RECOVERY / SLEEP / HYDRATION ──
        boolean isRecovery =
            normalized.contains("uyku") || normalized.contains("toparlanma") ||
            normalized.contains("dinlenme") || normalized.contains("su içtim") ||
            normalized.contains("su hedef") || normalized.contains("hidrasyon") ||
            normalized.contains("yorgun") || normalized.contains("yorgunluk") ||
            normalized.contains("kas ağrısı") || normalized.contains("ağrı") ||
            normalized.contains("ne kadar su") || normalized.contains("dinleneyim mi") ||
            normalized.contains("rest day") || normalized.contains("dinlenme günü");
        if (isRecovery) {
            return "- RECOVERY question. Reference water intake, sleep, and workout minutes from user data." +
                   " Give practical, specific advice in 1-3 sentences.";
        }

        // ── 8. TIMELINE / PROGRESS ──
        if (normalized.contains("ne zaman") || normalized.contains("kaç hafta") ||
            normalized.contains("kaç ay") || normalized.contains("ne kadar sürede") ||
            normalized.contains("ilerleme") || normalized.contains("sonuç") ||
            normalized.contains("hedefe ulaş") || normalized.contains("kaç günde") ||
            normalized.contains("ne zaman ulaş")) {
            return "- TIMELINE question. Use user's current vs target weight and realistic weekly change rates (0.3-0.7 kg/week)" +
                   " to give a realistic estimate with a clear number. State if data is insufficient.";
        }

        // ── 9. PLAN / DAILY SCHEDULE ──
        if (normalized.contains("plan") || normalized.contains("ne yap") ||
            normalized.contains("program") || normalized.contains("bugünü planla") ||
            normalized.contains("nasıl geçireyim") || normalized.contains("öncelik") ||
            normalized.contains("günlük rutin") || normalized.contains("bugün ne")) {
            return "- PLAN request. Build a focused, actionable plan using the user's remaining calories, workouts, and goals." +
                   " Use bullets only if there are 3+ distinct steps. Keep total under 120 words.";
        }

        // ── 10. ANALYSIS / REVIEW ──
        if (normalized.contains("analiz") || normalized.contains("nasıl gidiyor") ||
            normalized.contains("değerlendir") || normalized.contains("özet") ||
            normalized.contains("yorumla") || normalized.contains("7 gün") ||
            normalized.contains("son hafta") || normalized.contains("bu hafta") ||
            normalized.contains("genel durum") || normalized.contains("raporla")) {
            return "- ANALYSIS request. Start with the single most notable observation, then list 2-3 key data points" +
                   " (calories, protein, workouts, weight trend). End with one actionable suggestion. Use numbers.";
        }

        // ── 11. WATER / HYDRATION LOOKUP ──
        if (normalized.contains("su") || normalized.contains("water") || normalized.contains("litre")) {
            return "- WATER/HYDRATION question. Reference the user's water intake vs target directly. 1 sentence.";
        }

        // ── 12. SHORT QUESTION (data lookup) ──
        if (normalized.split("\\s+").length < 6) {
            return "- SHORT question — likely a data lookup. Answer in 1 direct sentence using the single most relevant data point. No preamble, no extra context.";
        }

        // ── DEFAULT ──
        return "- Answer naturally and concisely, referencing the user's actual data where it directly adds value." +
               " Match your answer length to the question complexity. Do not add unrequested advice.";
    }

    private String buildPersonalityBlock(String personality, String personalityInstruction) {
        if (personalityInstruction != null && !personalityInstruction.isBlank()) {
            return "Tone: " + personalityInstruction.trim();
        }
        if (personality != null && !personality.isBlank()) {
            return switch (personality.trim().toLowerCase()) {
                case "motivator" -> "Tone: energetic and direct. Use action verbs, be decisive, push them forward. Keep it punchy.";
                case "scientist" -> "Tone: precise and analytical. Lead with numbers and data. Skip fluff. Reference studies or mechanisms briefly when relevant.";
                case "supportive" -> "Tone: warm, empathetic, and encouraging. Acknowledge feelings before data. Celebrate small wins.";
                default -> "Tone: clear, friendly, and direct. Balance warmth with practicality.";
            };
        }
        return "Tone: clear, friendly, and direct. Balance warmth with practicality.";
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
