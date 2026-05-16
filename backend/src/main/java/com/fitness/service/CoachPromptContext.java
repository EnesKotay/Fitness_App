package com.fitness.service;

/**
 * Deterministic user context added to the AI coach prompt.
 */
public class CoachPromptContext {

    public final String profileSnapshot;
    public final String recoverySnapshot;
    public final String progressSnapshot;
    public final String coachingSignals;
    /** Derived from the user's past thumbs-up/down reactions. Empty string means no data yet. */
    public final String feedbackMemory;
    /** Last 7 days of workout history. Empty string means no data. */
    public final String workoutHistory;
    /** User ID — needed by SemanticMemoryService for RAG retrieval. */
    public final Long userId;

    public CoachPromptContext(
            String profileSnapshot,
            String recoverySnapshot,
            String progressSnapshot,
            String coachingSignals) {
        this(profileSnapshot, recoverySnapshot, progressSnapshot, coachingSignals, "", "", null);
    }

    public CoachPromptContext(
            String profileSnapshot,
            String recoverySnapshot,
            String progressSnapshot,
            String coachingSignals,
            String feedbackMemory) {
        this(profileSnapshot, recoverySnapshot, progressSnapshot, coachingSignals, feedbackMemory, "", null);
    }

    public CoachPromptContext(
            String profileSnapshot,
            String recoverySnapshot,
            String progressSnapshot,
            String coachingSignals,
            String feedbackMemory,
            String workoutHistory) {
        this(profileSnapshot, recoverySnapshot, progressSnapshot, coachingSignals, feedbackMemory, workoutHistory, null);
    }

    public CoachPromptContext(
            String profileSnapshot,
            String recoverySnapshot,
            String progressSnapshot,
            String coachingSignals,
            String feedbackMemory,
            String workoutHistory,
            Long userId) {
        this.profileSnapshot = profileSnapshot;
        this.recoverySnapshot = recoverySnapshot;
        this.progressSnapshot = progressSnapshot;
        this.coachingSignals = coachingSignals;
        this.feedbackMemory = feedbackMemory != null ? feedbackMemory : "";
        this.workoutHistory = workoutHistory != null ? workoutHistory : "";
        this.userId = userId;
    }

    public static CoachPromptContext empty() {
        return new CoachPromptContext(
                "Profile data unavailable.",
                "Recovery signals unavailable.",
                "Progress signals unavailable.",
                "No extra coaching signals.",
                "",
                "",
                null);
    }
}
