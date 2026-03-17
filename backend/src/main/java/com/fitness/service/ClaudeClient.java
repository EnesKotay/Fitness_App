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

        // System prompt for JSON mode
        if (expectJson) {
            payload.put("system", "You MUST respond with valid JSON only. No markdown, no explanation, just JSON.");
        }

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
