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
     * Build a prompt for the AI coach based on the user's request and daily summary.
     * 
     * @param request The AI coach request containing goal, question, and daily summary
     * @return The formatted prompt string to send to Gemini
     */
    public String buildPrompt(AiCoachRequest request) {
        AiCoachRequest.DailySummaryDto s = request.dailySummary;

        String goal = normalizeGoal(request.goal);
        int steps = safeInt(s.steps);
        int calories = safeInt(s.calories);
        double waterLiters = safeDouble(s.waterLiters);
        double sleepHours = safeDouble(s.sleepHours);
        int workouts = safeInt(s.workouts);

        return """
                You are a fitness coach for a mobile app.
                User goal: %s
                Daily summary:
                - steps: %d
                - calories: %d
                - waterLiters: %.1f
                - sleepHours: %.1f
                - workouts: %d
                User question: %s

                Return only valid JSON with this exact shape:
                {
                  "todayFocus": "string",
                  "actionItems": ["string", "string", "string"],
                  "nutritionNote": "string"
                }

                Rules:
                - Keep answer practical and safe.
                - actionItems must contain 3 to 5 short items.
                - Avoid medical diagnosis.
                """.formatted(goal, steps, calories, waterLiters, sleepHours, workouts, request.question.trim());
    }

    private String normalizeGoal(String goal) {
        String normalized = goal.trim().toUpperCase();
        return switch (normalized) {
            case "BULK", "CUT", "STRENGTH" -> normalized;
            default -> "CUSTOM";
        };
    }

    private int safeInt(Integer value) {
        return value == null ? 0 : value;
    }

    private double safeDouble(Double value) {
        return value == null ? 0.0 : value;
    }
}
