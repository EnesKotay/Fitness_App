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
import jakarta.transaction.Transactional;

@ApplicationScoped
public class GeminiCoachService {

    private static final Logger LOG = Logger.getLogger(GeminiCoachService.class);

    @Inject
    ObjectMapper objectMapper;

    @Inject
    GeminiClient geminiClient;

    @Inject
    AiProviderRouter aiProviderRouter;

    @Inject
    CoachPromptBuilder promptBuilder;

    @Inject
    AiCoachContextBuilder contextBuilder;

    @Inject
    SemanticMemoryService semanticMemoryService;

    @ConfigProperty(name = "gemini.coach.model", defaultValue = "gemini-2.0-flash")
    String coachModel;

    @ConfigProperty(name = "gemini.coach.fallback", defaultValue = "gemini-2.0-flash-lite")
    String coachFallbackModel;

    public AiCoachResponse generateCoachResponse(Long userId, AiCoachRequest request) {
        validateRequest(request);

        // Fetch long-term memory insights
        List<com.fitness.entity.AiInsight> insights = com.fitness.entity.AiInsight.findRecentByUser(userId, 3);
        
        CoachPromptContext context = contextBuilder.build(userId, request.dailySummary);
        String prompt = promptBuilder.buildPrompt(request, insights, context);

        GeminiClientResult result = aiProviderRouter.generateText(
            "ai/coach",
            userId,
            coachModel,
            coachFallbackModel,
            prompt,
            null,
            true,
            null // Removed Native Function Calling for memory
        );

        if (!result.isSuccess()) throw mapFailure(result);

        try {
            String jsonText = aiProviderRouter.extractJsonFromResponse(userId, result.getOutputText());
            JsonNode parsed = objectMapper.readTree(jsonText);
            
            AiCoachResponse response = parseResponse(parsed);
            
            // Handle SAVE_MEMORY internally from JSON instead of Native Function Calling
            if (response.actions != null) {
                java.util.Iterator<AiCoachResponse.AiCoachAction> iterator = response.actions.iterator();
                while (iterator.hasNext()) {
                    AiCoachResponse.AiCoachAction action = iterator.next();
                    if ("SAVE_MEMORY".equals(action.type) && action.data != null && !action.data.isBlank()) {
                        saveSemanticMemory(userId, action.data);
                        response.memorySaved = action.data;
                        iterator.remove(); // Do not send this action to the frontend UI buttons
                    }
                }
            }
            sanitizeResponse(response, request);
            validateResponse(response);
            return response;
        } catch (IOException e) {
            LOG.error("Failed to parse AI response for user " + userId, e);
            throw new AiCoachServiceException(502, "Koç yanıtı işlenemedi.");
        }
    }

    public AiCoachResponse generateVisionResponse(Long userId, AiCoachRequest request, byte[] mediaBytes, String mimeType) {
        validateRequest(request);

        CoachPromptContext context = contextBuilder.build(userId, request.dailySummary);
        String basePrompt = promptBuilder.buildPrompt(
                request,
                com.fitness.entity.AiInsight.findRecentByUser(userId, 2),
                context);
                
        String mediaContext = mimeType.startsWith("video/") 
            ? "VISUAL CONTEXT (VIDEO ANALYSIS):\n- Analyze the video for form correction, movement mechanics, and posture.\n- Provide frame-by-frame guidance on what to improve."
            : "VISUAL CONTEXT (IMAGE ANALYSIS):\n- Analyze the image in service of the user's question.\n- If a meal, estimate calories/macros. If exercise form, comment on technique.";

        String visionPrompt = mediaContext + "\n\n" + basePrompt;

        GeminiClientResult result = aiProviderRouter.generateWithImage(
                "ai/vision",
                userId,
                coachModel,
                coachFallbackModel,
                visionPrompt,
                mediaBytes,
                mimeType,
                true
        );

        if (!result.isSuccess()) throw mapFailure(result);

        try {
            String jsonText = aiProviderRouter.extractJsonFromResponse(userId, result.getOutputText());
            AiCoachResponse response = parseResponse(objectMapper.readTree(jsonText));
            sanitizeResponse(response, request);
            validateResponse(response);  // was missing — empty todayFocus silently returned before
            return response;
        } catch (IOException e) {
            throw new AiCoachServiceException(502, "Görüntü analizi işlenemedi.", e);
        }
    }

    // Removed buildCoachTools() as we now use JSON actions for memory.

    @Transactional
    public void saveSemanticMemory(Long userId, String fact) {
        semanticMemoryService.saveMemory(userId, fact, "SEMANTIC_MEMORY");
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

        // V5: Rich Data Parsing
        response.isAchievement = parsed.path("isAchievement").asBoolean(false);
        response.actions = parseActions(parsed.path("actions"));
        response.media = parseMedia(parsed.path("media"));

        return response;
    }

    private List<AiCoachResponse.AiCoachAction> parseActions(JsonNode actionsNode) {
        List<AiCoachResponse.AiCoachAction> actions = new ArrayList<>();
        if (actionsNode != null && actionsNode.isArray()) {
            for (JsonNode node : actionsNode) {
                AiCoachResponse.AiCoachAction action = new AiCoachResponse.AiCoachAction();
                action.label = node.path("label").asText("");
                action.type = node.path("type").asText("");
                action.data = node.path("data").asText("");
                if (!action.type.isEmpty())
                    actions.add(action);
            }
        }
        return actions;
    }

    private List<AiCoachResponse.AiCoachMedia> parseMedia(JsonNode mediaNode) {
        List<AiCoachResponse.AiCoachMedia> mediaList = new ArrayList<>();
        if (mediaNode != null && mediaNode.isArray()) {
            for (JsonNode node : mediaNode) {
                AiCoachResponse.AiCoachMedia media = new AiCoachResponse.AiCoachMedia();
                media.type = node.path("type").asText("");
                media.url = node.path("url").asText("");
                media.title = node.path("title").asText("");
                if (!media.type.isEmpty())
                    mediaList.add(media);
            }
        }
        return mediaList;
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
            throw new AiCoachServiceException(502, "Yapay zeka net bir yanıt üretemedi. Lütfen tekrar deneyin.");
        }
        if (response.nutritionNote == null || response.nutritionNote.isBlank()) {
            response.nutritionNote = "";
        }
        if (response.actionItems == null || response.actionItems.isEmpty()) {
            response.actionItems = List.of();
        }
    }

    private void sanitizeResponse(AiCoachResponse response, AiCoachRequest request) {
        if (response == null) return;

        if (response.todayFocus != null) {
            response.todayFocus = response.todayFocus.trim();
        }

        if (response.actionItems != null && !response.actionItems.isEmpty()) {
            response.actionItems = response.actionItems.stream()
                    .filter(item -> item != null && !item.isBlank())
                    .map(String::trim)
                    .limit(10)
                    .toList();
        }

        if (response.nutritionNote != null) {
            response.nutritionNote = response.nutritionNote.trim();
        }

        if (response.actions != null && !response.actions.isEmpty()) {
            response.actions = response.actions.stream()
                    .filter(action -> action != null && action.type != null && !action.type.isBlank())
                    .limit(3)
                    .toList();
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
