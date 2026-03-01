package com.fitness.dto;

public class AiCoachRequest {
    public String goal;
    public DailySummaryDto dailySummary;
    public String question;

    public static class DailySummaryDto {
        public Integer steps;
        public Integer calories;
        public Double waterLiters;
        public Double sleepHours;
        public Integer workouts;
    }
}
