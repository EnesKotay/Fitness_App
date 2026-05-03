package com.fitness.service;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Base64;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Anthropic Claude API client for premium users.
 * Compatible interface with GeminiClientResult for seamless routing.
 */
@ApplicationScoped
public class ClaudeClient {

    private static final Logger LOG = Logger.getLogger(ClaudeClient.class);
    private static final String MISSING_KEY_SENTINEL = "__MISSING__";
    private static final String API_URL = "https://api.anthropic.com/v1/messages";
    private static final String API_VERSION = "2023-06-01";

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "claude.api.key", defaultValue = MISSING_KEY_SENTINEL)
    String claudeApiKey;

    @ConfigProperty(name = "claude.model", defaultValue = "claude-haiku-4-5-20251001")
    String defaultModel;

    @ConfigProperty(name = "claude.timeout.ms", defaultValue = "30000")
    long timeoutMs;

    private final HttpClient httpClient = HttpClient.newHttpClient();

    private static final String COACHING_SYSTEM_PROMPT = """
            You are FitMentor — an elite personal fitness coach and nutritionist with deep reasoning ability.
            You are having a real-time conversation with a user who has shared their daily fitness data with you.

            CORE RULES — follow these exactly:
            1. Answer ONLY what the user asked. Never volunteer unsolicited advice, plans, or suggestions.
            2. Match response length to the question complexity. Short question → 1-2 sentences maximum.
            3. Write in the user's language. If they write in Turkish, respond entirely in Turkish.
            4. Reference the user's actual data naturally — never invent or estimate numbers when real data exists.
            5. If data is missing for what they asked, say so briefly and honestly in one sentence.
            6. Never use filler phrases like "great question", "of course", "certainly", "tabii ki", "harika soru".
            7. If the user asks for one thing, do not answer neighboring topics.
            8. If the user asks for a number, lead with the number immediately.
            9. If the user is mid-conversation, continue naturally without restarting the tone or repeating context.

            QUESTION TYPE → RESPONSE STYLE:
            - Casual/emotional (feelings, frustration, motivation): 1-3 warm sentences like a supportive friend.
              Acknowledge their feeling first. Reference data only if it genuinely helps. No bullet lists.
            - Data lookup (calories, macros, weight, water): Exact number from their data in 1 direct line.
            - Plan request (what should I eat/do, make me a plan): 3-5 actionable bullets, stay in calorie budget.
            - Analysis/review: 1 key observation + 2-3 relevant numbers + 1 actionable tip.
            - Timeline: Calculate from current vs. target weight at realistic 0.3–0.7 kg/week rate.
            - Comparison: Start with the winner or key difference in the first sentence.

            OUTPUT — return ONLY this JSON, nothing else before or after:
            {
              "todayFocus": "<response — start with one emoji, bold (**) key numbers only, match style to question>",
              "actionItems": [],
              "nutritionNote": "",
              "actions": [],
              "isAchievement": false
            }
            Leave actionItems, nutritionNote, actions EMPTY unless the user explicitly requested them.
            No markdown code fences. No text before or after the JSON object.
            """;

    /**
     * Check if Claude API key is configured.
     */
    public boolean isAvailable() {
        return claudeApiKey != null && !claudeApiKey.isBlank()
                && !MISSING_KEY_SENTINEL.equals(claudeApiKey) && !claudeApiKey.startsWith("__");
    }

    /**
     * Validate that API key is set. Throws if not.
     */
    public void validateApiKey() {
        if (!isAvailable()) {
            throw new GeminiClient.ServiceUnavailableException(503, "CLAUDE_API_KEY is not configured");
        }
    }

    /**
     * Generate text using Claude Messages API.
     * Returns GeminiClientResult for compatibility with existing services.
     */
    public GeminiClientResult generateText(
            String endpointName,
            Long userId,
            String prompt,
            boolean expectJson) {

        long startTime = System.currentTimeMillis();
        int promptLength = prompt != null ? prompt.length() : 0;

        try {
            String responseText = callClaude(prompt, null, null, expectJson);
            long latencyMs = System.currentTimeMillis() - startTime;

            LOG.infof("endpoint=%s status=ok userId=%s promptLength=%d latencyMs=%d modelUsed=%s provider=claude",
                    endpointName, userId, promptLength, latencyMs, defaultModel);

            return GeminiClientResult.builder()
                    .success("claude:" + defaultModel, responseText, latencyMs)
                    .build();

        } catch (Exception e) {
            long latencyMs = System.currentTimeMillis() - startTime;
            String errorMsg = e.getMessage();
            int statusCode = extractStatusCode(e);

            LOG.warnf("endpoint=%s status=error userId=%s latencyMs=%d modelUsed=%s error=%s provider=claude",
                    endpointName, userId, latencyMs, defaultModel, errorMsg);

            return GeminiClientResult.builder()
                    .failure("claude:" + defaultModel, statusCode, errorMsg, latencyMs)
                    .build();
        }
    }

    /**
     * Generate content with image using Claude Vision.
     */
    public GeminiClientResult generateWithImage(
            String endpointName,
            Long userId,
            String prompt,
            byte[] imageBytes,
            String mimeType,
            boolean expectJson) {

        long startTime = System.currentTimeMillis();
        int promptLength = prompt != null ? prompt.length() : 0;

        try {
            String responseText = callClaude(prompt, imageBytes, mimeType, expectJson);
            long latencyMs = System.currentTimeMillis() - startTime;

            LOG.infof(
                    "endpoint=%s status=ok userId=%s promptLength=%d latencyMs=%d modelUsed=%s provider=claude_vision",
                    endpointName, userId, promptLength, latencyMs, defaultModel);

            return GeminiClientResult.builder()
                    .success("claude:" + defaultModel, responseText, latencyMs)
                    .build();

        } catch (Exception e) {
            long latencyMs = System.currentTimeMillis() - startTime;
            String errorMsg = e.getMessage();
            int statusCode = extractStatusCode(e);

            LOG.warnf("endpoint=%s status=error userId=%s latencyMs=%d error=%s provider=claude_vision",
                    endpointName, userId, latencyMs, errorMsg);

            return GeminiClientResult.builder()
                    .failure("claude:" + defaultModel, statusCode, errorMsg, latencyMs)
                    .build();
        }
    }

    /**
     * Extract JSON block from raw response text.
     */
    public String extractJsonFromResponse(String rawResponse) {
        if (rawResponse == null)
            return "{}";
        String trimmed = rawResponse.trim();
        int firstBrace = trimmed.indexOf('{');
        int lastBrace = trimmed.lastIndexOf('}');
        if (firstBrace >= 0 && lastBrace > firstBrace) {
            return trimmed.substring(firstBrace, lastBrace + 1);
        }
        return trimmed;
    }

    // ─── Private helpers ─────────────────────────────────────────

    private String callClaude(String prompt, byte[] imageBytes, String mimeType, boolean expectJson)
            throws IOException, InterruptedException {

        ObjectNode payload = objectMapper.createObjectNode();
        payload.put("model", defaultModel);
        payload.put("max_tokens", 4096);

        // Always use the coaching system prompt; reinforce JSON when expected
        String systemPrompt = expectJson
                ? COACHING_SYSTEM_PROMPT + "\nCRITICAL: your entire response must be valid JSON only — no text outside the JSON object."
                : COACHING_SYSTEM_PROMPT;
        payload.put("system", systemPrompt);

        // Build messages array
        ArrayNode messages = objectMapper.createArrayNode();
        ObjectNode userMessage = objectMapper.createObjectNode();
        userMessage.put("role", "user");

        if (imageBytes != null && imageBytes.length > 0) {
            // Vision: image + text content blocks
            ArrayNode contentBlocks = objectMapper.createArrayNode();

            ObjectNode imageBlock = objectMapper.createObjectNode();
            imageBlock.put("type", "image");
            ObjectNode source = objectMapper.createObjectNode();
            source.put("type", "base64");
            source.put("media_type", mimeType != null ? mimeType : "image/jpeg");
            source.put("data", Base64.getEncoder().encodeToString(imageBytes));
            imageBlock.set("source", source);
            contentBlocks.add(imageBlock);

            ObjectNode textBlock = objectMapper.createObjectNode();
            textBlock.put("type", "text");
            textBlock.put("text", prompt);
            contentBlocks.add(textBlock);

            userMessage.set("content", contentBlocks);
        } else {
            // Text only
            userMessage.put("content", prompt);
        }

        messages.add(userMessage);
        payload.set("messages", messages);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(API_URL))
                .timeout(Duration.ofMillis(timeoutMs))
                .header("Content-Type", "application/json")
                .header("x-api-key", claudeApiKey)
                .header("anthropic-version", API_VERSION)
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(payload)))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new ClaudeApiException(response.statusCode(), response.body());
        }

        return extractTextFromResponse(response.body());
    }

    private String extractTextFromResponse(String responseBody) throws IOException {
        JsonNode root = objectMapper.readTree(responseBody);
        JsonNode content = root.path("content");

        if (content.isArray() && !content.isEmpty()) {
            StringBuilder sb = new StringBuilder();
            for (JsonNode block : content) {
                if ("text".equals(block.path("type").asText())) {
                    sb.append(block.path("text").asText());
                }
            }
            String result = sb.toString().trim();
            if (!result.isEmpty()) {
                return result;
            }
        }

        throw new IOException("Claude returned empty content");
    }

    private int extractStatusCode(Exception e) {
        if (e instanceof ClaudeApiException apiEx) {
            return apiEx.getStatusCode();
        }
        if (e instanceof IOException)
            return 502;
        if (e instanceof InterruptedException)
            return 503;
        return 500;
    }

    private static class ClaudeApiException extends RuntimeException {
        private final int statusCode;

        ClaudeApiException(int statusCode, String body) {
            super("Claude request failed with status " + statusCode + ": " + body);
            this.statusCode = statusCode;
        }

        int getStatusCode() {
            return statusCode;
        }
    }
}
