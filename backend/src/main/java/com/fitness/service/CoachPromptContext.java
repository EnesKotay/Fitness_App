package com.fitness.service;

/**
 * Deterministic user context added to the AI coach prompt.
 */
public class CoachPromptContext {

    public final String profileSnapshot;
    public final String recoverySnapshot;
    public final String progressSnapshot;
    public final String coachingSignals;

    public CoachPromptContext(
            String profileSnapshot,
            String recoverySnapshot,
            String progressSnapshot,
            String coachingSignals) {
        this.profileSnapshot = profileSnapshot;
        this.recoverySnapshot = recoverySnapshot;
        this.progressSnapshot = progressSnapshot;
        this.coachingSignals = coachingSignals;
    }

    public static CoachPromptContext empty() {
        return new CoachPromptContext(
                "Profile data unavailable.",
                "Recovery signals unavailable.",
                "Progress signals unavailable.",
                "No extra coaching signals.");
    }
}
