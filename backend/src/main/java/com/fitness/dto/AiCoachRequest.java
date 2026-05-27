package com.fitness.dto;

import jakarta.validation.constraints.Size;
import java.util.List;

public class AiCoachRequest {
    public String goal;
    public DailySummaryDto dailySummary;

    @Size(max = 2000, message = "Soru en fazla 2000 karakter olabilir.")
    public String question;
    /** Optional: motivator | scientist | supportive – affects coach tone in prompt */
    public String personality;
    /** Optional: instruction for the chosen personality */
    public String personalityInstruction;
    /** Optional: plan | nutrition | workout | recovery | analysis */
    public String taskMode;
    /** Optional: human-readable prompt lead for the task mode */
    public String taskModeInstruction;
    /** Optional: last N turns of the conversation for context */
    public List<ConversationTurn> conversationHistory;
    /** Optional: local long-term memory summary sent by the client. */
    public String userMemory;

    public static class ConversationTurn {
        public String role;    // "user" | "assistant"
        @Size(max = 4000)
        public String content;
    }

    public static class DailySummaryDto {
        public Integer steps;
        public Integer calories;
        public Double waterLiters;
        public Double sleepHours;
        public Integer workouts;
        public Integer workoutMinutes;
        public List<String> workoutHighlights;

        // Phase 8: Historical Context
        public Integer avgStepsLast7Days;
        public Integer avgCaloriesLast7Days;
        public Double avgWaterLast7Days;
        public Integer targetCalories;
        public Double currentWeightKg;
        public Double targetWeightKg;
        public Double bmi;

        // Phase 9: Richer context for smarter AI
        public Integer proteinGrams;
        public Integer carbsGrams;
        public Integer fatGrams;
        public List<String> mealNames;
        public Double weeklyWeightChangeKg;
        public Integer weightStreak;
        public Integer userAge;
        public Double userHeightCm;
        public String userGender;
        public String activityLevel;
        public Integer tdee;
        public String workoutLocation;
        public String equipmentType;
        public List<Integer> recentDaysCalories;
    }
}
