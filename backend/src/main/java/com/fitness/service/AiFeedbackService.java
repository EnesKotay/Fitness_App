package com.fitness.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import com.fitness.dto.AiFeedbackRequest;
import com.fitness.entity.AiFeedback;
import com.fitness.repository.AiFeedbackRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class AiFeedbackService {

    @Inject
    AiFeedbackRepository feedbackRepository;

    @Transactional
    public void save(Long userId, AiFeedbackRequest request) {
        if (request == null || request.aiResponse == null || request.aiResponse.isBlank()) return;
        if (!"POSITIVE".equals(request.reaction) && !"NEGATIVE".equals(request.reaction)) return;

        AiFeedback feedback = new AiFeedback();
        feedback.userId = userId;
        feedback.aiResponse = request.aiResponse.length() > 1000
                ? request.aiResponse.substring(0, 1000)
                : request.aiResponse;
        feedback.reaction = request.reaction;
        feedback.taskMode = request.taskMode;
        feedback.personality = request.personality;
        feedback.createdAt = LocalDateTime.now();
        feedbackRepository.persist(feedback);
    }

    /**
     * Returns a prompt-ready memory block describing the user's preferred
     * response style, derived from their recent positive feedback.
     * Returns empty string if no feedback exists.
     */
    public String buildFeedbackMemory(Long userId) {
        if (userId == null) return "";

        List<AiFeedback> positive = feedbackRepository.findRecentPositive(userId, 3);
        List<AiFeedback> negative = feedbackRepository.findRecentNegative(userId, 2);

        if (positive.isEmpty() && negative.isEmpty()) return "";

        StringBuilder sb = new StringBuilder("--- USER FEEDBACK MEMORY ---\n");

        if (!positive.isEmpty()) {
            sb.append("Responses the user previously LIKED (emulate this style/depth):\n");
            positive.stream()
                    .map(f -> trimSnippet(f.aiResponse, 120))
                    .forEach(snippet -> sb.append("+ ").append(snippet).append("\n"));
        }

        if (!negative.isEmpty()) {
            sb.append("Responses the user previously DISLIKED (avoid this style/content):\n");
            negative.stream()
                    .map(f -> trimSnippet(f.aiResponse, 120))
                    .forEach(snippet -> sb.append("- ").append(snippet).append("\n"));
        }

        return sb.toString().trim();
    }

    private String trimSnippet(String text, int maxChars) {
        if (text == null) return "";
        String clean = text.replaceAll("\\s+", " ").trim();
        return clean.length() <= maxChars ? clean : clean.substring(0, maxChars) + "…";
    }
}
