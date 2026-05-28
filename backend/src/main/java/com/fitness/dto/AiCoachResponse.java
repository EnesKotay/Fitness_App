package com.fitness.dto;

import java.util.List;

public class AiCoachResponse {
    public String todayFocus;
    public List<String> actionItems;
    public String nutritionNote;

    // Quota info — backend is the single source of truth
    /** Remaining free requests for today. null for premium users. */
    public Integer remainingFreeRequests;
    
    public String memorySaved;

    // V5: Rich Data
    public List<AiCoachAction> actions;
    public List<AiCoachMedia> media;
    public Boolean isAchievement;

    public static class AiCoachAction {
        public String label;
        public String type; // START_WORKOUT, ADD_WATER, TRACK_WEIGHT
        public String data;
    }

    public static class AiCoachMedia {
        public String type; // IMAGE, TABLE, VIDEO_LINK
        public String url;
        public String title;
    }
}
