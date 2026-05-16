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
}
