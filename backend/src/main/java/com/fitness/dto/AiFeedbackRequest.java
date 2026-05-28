package com.fitness.dto;

public class AiFeedbackRequest {
    /** The AI response text the user is reacting to. */
    public String aiResponse;

    /** POSITIVE or NEGATIVE */
    public String reaction;

    /** Optional: plan | nutrition | workout | recovery | analysis */
    public String taskMode;

    /** Optional: motivator | scientist | supportive */
    public String personality;

    /** Optional: the user question that produced this AI response. */
    public String userQuestion;

    /** Optional: short reason selected by the user, e.g. "too_generic". */
    public String reason;

    /** Optional: what the coach should do differently next time. */
    public String coachingPreference;
}
