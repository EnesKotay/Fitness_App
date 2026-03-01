package com.fitness.service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fitness.dto.AiCoachRequest;
import com.fitness.dto.AiCoachResponse;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class GeminiCoachService {

    private static final Logger LOG = Logger.getLogger(GeminiCoachService.class);

    @Inject
    ObjectMapper objectMapper;

    @Inject
    GeminiClient geminiClient;

    @Inject
    CoachPromptBuilder promptBuilder;

    @ConfigProperty(name = "gemini.coach.model", defaultValue = "gemini-2.0-flash")
    String coachModel;

    @ConfigProperty(name = "gemini.coach.fallback", defaultValue = "gemini-1.5-flash")
    String coachFallbackModel;

    public AiCoachResponse generateCoachResponse(Long userId, AiCoachRequest request) {
        validateRequest(request);
        geminiClient.validateApiKey();

        String prompt = promptBuilder.buildPrompt(request);
        
        GeminiClientResult result = geminiClient.generateText(
                "ai/coach",
                userId,
                coachModel,
                coachFallbackModel,
                prompt,
                true // expect JSON
        );

        if (!result.isSuccess()) {
            throw mapFailure(result);
        }

        try {
            String jsonText = geminiClient.extractJsonFromResponse(result.getOutputText());
            JsonNode parsed = objectMapper.readTree(jsonText);
            AiCoachResponse response = parseResponse(parsed);
            validateResponse(response);
            return response;
        } catch (IOException e) {
            throw new AiCoachServiceException(502, "AI yaniti islenemedi.", e);
        }
    }

    private void validateRequest(AiCoachRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Request body is required");
        }
        if (request.goal == null || request.goal.isBlank()) {
            throw new IllegalArgumentException("goal is required");
        }
        if (request.question == null || request.question.isBlank()) {
            throw new IllegalArgumentException("question is required");
        }
        if (request.question.trim().length() > 500) {
            throw new IllegalArgumentException("question must be at most 500 characters");
        }
        if (request.dailySummary == null) {
            throw new IllegalArgumentException("dailySummary is required");
        }
    }

    private AiCoachResponse parseResponse(JsonNode parsed) {
        AiCoachResponse response = new AiCoachResponse();
        response.todayFocus = parsed.path("todayFocus").asText("").trim();
        response.nutritionNote = parsed.path("nutritionNote").asText("").trim();
        response.actionItems = parseActionItems(parsed.path("actionItems"));
        return response;
    }

    private List<String> parseActionItems(JsonNode items) {
        List<String> result = new ArrayList<>();
        if (items == null || !items.isArray()) {
            return result;
        }

        for (JsonNode node : items) {
            String value;
            if (node.isTextual()) {
                value = node.asText();
            } else if (node.isObject() && node.has("text")) {
                value = node.path("text").asText();
            } else if (node.isNumber() || node.isBoolean()) {
                value = node.asText();
            } else {
                continue;
            }

            if (value != null && !value.trim().isEmpty()) {
                result.add(value.trim());
            }
        }

        return result;
    }

    private void validateResponse(AiCoachResponse response) {
        if (response.todayFocus == null || response.todayFocus.isBlank()) {
            response.todayFocus = "Bugunku hedefe odaklan.";
        }
        if (response.nutritionNote == null || response.nutritionNote.isBlank()) {
            response.nutritionNote = "Dengeli beslenmeye devam et.";
        }
        if (response.actionItems == null || response.actionItems.isEmpty()) {
            response.actionItems = List.of(
                    "Planini uygula.",
                    "Yeterli su ic.",
                    "Uyku duzenini koru.");
        }
    }

    private AiCoachServiceException mapFailure(GeminiClientResult result) {
        int status = result.getStatusCode();
        String modelInfo = result.getModelUsed() != null ? " (" + result.getModelUsed() + ")" : "";
        
        if (status == 401 || status == 403) {
            return new AiCoachServiceException(503, "AI servisi yetkilendirme hatasi. GEMINI_API_KEY kontrol et.");
        }
        if (status == 404) {
            return new AiCoachServiceException(503, "AI modeli kullanilamiyor" + modelInfo + ".");
        }
        if (status == 429) {
            Integer retryAfterSeconds = result.getRetryAfterSeconds();
            if (retryAfterSeconds == null || retryAfterSeconds <= 0) {
                retryAfterSeconds = 20;
            }
            return new AiCoachServiceException(
                    429,
                    "AI servisi yogun. Lutfen biraz sonra tekrar dene.",
                    retryAfterSeconds);
        }
        if (status >= 500) {
            return new AiCoachServiceException(503, "AI servisi gecici olarak kullanilamiyor.");
        }
        if (result.getError() != null) {
            return new AiCoachServiceException(502, "AI istegi basarisiz oldu: " + result.getError());
        }
        return new AiCoachServiceException(502, "AI istegi basarisiz oldu.");
    }
}
