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
        CoachPromptContext safeContext = context == null ? CoachPromptContext.empty() : context;

        String knowledgeBase = """
            [SCIENTIFIC PROTOCOLS]:
            1. Basal Metabolic Rate (BMR): Calculated via Mifflin-St Jeor.
            2. Caloric Balance: Weight loss requires ~500kcal deficit/day (3500kcal/week for ~0.5kg loss).
            3. Protein Synthesis: Aim for 1.6g-2.2g of protein per kg of body weight for muscle growth.
            4. Water: 2.5L is baseline, add 500ml per hour of intense exercise.
            5. Sleep: 7-9 hours optimal for neural recovery and fat oxidation.
            
            [REASONING PROCESS]:
            - Step 1: Analyze today's data, recovery state, and progress signals vs the user's long-term goal.
            - Step 2: Compare today's metrics with the last 7-day averages to identify anomalies and trends.
            - Step 3: Cross-check calorie intake, current weight, target weight, and BMI before recommending deficits or surplus.
            - Step 4: If recovery is poor, lower training intensity and prioritize recovery behaviors.
            - Step 5: Validate advice against Scientific Protocols and user profile data.
            - Step 6: Formulate a direct, encouraging, or scientific response based on personality.
            """;

        return """
                %s

                ROLE: You are an elite Fitness Coach.
                %s
                USER GOAL: %s

                USER PROFILE:
                %s
                - Age: %s | Height: %s cm | Gender: %s
                - Activity Level: %s
                - TDEE (Total Daily Energy Expenditure): %s kcal

                TODAY'S METRICS:
                - Steps: %d
                - Calories: %d / Target: %s kcal
                - Macros: Protein %sg | Carbs %sg | Fat %sg
                - Meals today: %s
                - Water: %.1f L
                - Sleep: %.1f h
                - Workouts: %d (Highlights: %s)
                - Workout Minutes: %d
                - Current Weight: %s kg | Target: %s kg | BMI: %s

                WEIGHT TREND:
                - Weekly Change: %s kg
                - Logging Streak: %s days

                HISTORICAL TRENDS (Last 7 Days Avg):
                - Avg Steps: %s
                - Avg Calories: %s
                - Avg Water: %s

                RECOVERY SNAPSHOT:
                %s

                PROGRESS SNAPSHOT:
                %s

                LONG-TERM MEMORY (Past Insights):
                %s

                DETERMINISTIC COACHING SIGNALS:
                %s

                USER INPUT: %s

                IF AN IMAGE IS PROVIDED:
                Analyze food portions, estimate macronutrients (Protein/Carbs/Fat) AND calories.
                Suggest if this fits their current daily budget.

                RESPONSE REQUIREMENTS:
                Return only valid JSON with this exact shape:
                {
                  "todayFocus": "string (Start with a scientific insight or a personalized observation based on trends)",
                  "actionItems": ["string (3-5 specific, micro-tasks)"],
                  "nutritionNote": "string",
                  "actions": [{"label": "button label", "type": "START_WORKOUT|ADD_WATER|TRACK_WEIGHT", "data": "optional"}],
                  "isAchievement": boolean
                }

                Rules:
                - Be specific. Don't say "eat less", say "Your calorie avg is high, try to stay under 2000 today".
                - Always use TDEE and macro data when available to give precise targets, not generic advice.
                - Reference the user's actual meals when giving nutrition feedback.
                - If weight streak >= 3, acknowledge the consistency. If 0, encourage daily weigh-ins.
                - If weekly weight change is positive during a cut, reduce calories by ~200kcal. If negative during a bulk, increase by ~200kcal.
                - If today's water < 7-day avg, emphasize rehydration.
                - If sleep is below 6 hours, prioritize recovery, walking, mobility, and earlier sleep instead of hard training.
                - If target calories or body-weight goal are available, align recommendations to that budget and target direction.
                - If BMI is unusually high or low, keep advice conservative and sustainable rather than extreme.
                - Mention the user's progress trend when weight or measurements are available.
                - Keep action items feasible within the next 24 hours.
                - Use only these action types when relevant: START_WORKOUT, ADD_WATER, TRACK_WEIGHT.
                """.formatted(
                        knowledgeBase,
                        personalityBlock,
                        goal,
                        safeContext.profileSnapshot,
                        nullableInt(s.userAge),
                        nullableDouble(s.userHeightCm),
                        s.userGender != null ? s.userGender : "unknown",
                        s.activityLevel != null ? s.activityLevel : "unknown",
                        nullableInt(s.tdee),
                        safeInt(s.steps),
                        safeInt(s.calories),
                        nullableInt(s.targetCalories),
                        nullableInt(s.proteinGrams),
                        nullableInt(s.carbsGrams),
                        nullableInt(s.fatGrams),
                        safeHighlights(s.mealNames),
                        safeDouble(s.waterLiters),
                        safeDouble(s.sleepHours),
                        safeInt(s.workouts),
                        safeHighlights(s.workoutHighlights),
                        safeInt(s.workoutMinutes),
                        nullableDouble(s.currentWeightKg),
                        nullableDouble(s.targetWeightKg),
                        nullableDouble(s.bmi),
                        s.weeklyWeightChangeKg != null ? String.format(java.util.Locale.US, "%+.1f", s.weeklyWeightChangeKg) : "no data",
                        s.weightStreak != null ? s.weightStreak : "no data",
                        s.avgStepsLast7Days != null ? s.avgStepsLast7Days : "no data",
                        s.avgCaloriesLast7Days != null ? s.avgCaloriesLast7Days : "no data",
                        s.avgWaterLast7Days != null ? s.avgWaterLast7Days : "no data",
                        safeContext.recoverySnapshot,
                        safeContext.progressSnapshot,
                        formatInsights(insights),
                        safeContext.coachingSignals,
                        request.question.trim());
    }

    private String buildPersonalityBlock(String personality, String personalityInstruction) {
        if (personalityInstruction != null && !personalityInstruction.isBlank()) {
            return "COACH TONE (strictly follow this style): " + personalityInstruction.trim();
        }
        if (personality != null && !personality.isBlank()) {
            String normalized = personality.trim().toLowerCase();
            return switch (normalized) {
                case "motivator" -> "COACH TONE: Be direct, disciplined, and demanding. No excuses. Short, punchy answers.";
                case "scientist" -> "COACH TONE: Be analytical and evidence-based. Reference studies and physiology. Technical but clear.";
                case "supportive" -> "COACH TONE: Be warm, encouraging, and supportive. Celebrate small wins. Gentle language.";
                default -> "COACH TONE: Be encouraging and clear.";
            };
        }
        return "COACH TONE: Be encouraging and clear.";
    }

    private String formatInsights(java.util.List<com.fitness.entity.AiInsight> insights) {
        if (insights == null || insights.isEmpty()) {
            return "No prior insights recorded.";
        }
        return insights.stream()
                .map(i -> "[" + i.type + " at " + i.createdAt + "]: " + i.summary)
                .collect(java.util.stream.Collectors.joining("\n"));
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
