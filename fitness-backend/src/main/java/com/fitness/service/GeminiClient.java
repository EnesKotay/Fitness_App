package com.fitness.service;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Common Gemini API client with primary/fallback model support.
 * Handles API key validation, model selection, timeout, and structured telemetry logging.
 */
@ApplicationScoped
public class GeminiClient {

    private static final Logger LOG = Logger.getLogger(GeminiClient.class);
    private static final String MISSING_KEY_SENTINEL = "__MISSING__";

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "gemini.api.key", defaultValue = MISSING_KEY_SENTINEL)
    String geminiApiKey;

    @ConfigProperty(name = "gemini.timeout.ms", defaultValue = "15000")
    long timeoutMs;

    private final HttpClient httpClient = HttpClient.newHttpClient();

    /**
     * Generate text using Gemini API with automatic fallback.
     * 
     * @param endpointName  Identifier for the endpoint (e.g., "ai/coach", "ai/nutrition")
     * @param userId        User ID for logging
     * @param primaryModel  Primary model to try first
     * @param fallbackModel Model to use if primary fails
     * @param prompt        The prompt to send to Gemini
     * @param expectJson    Whether to expect JSON response
     * @return GeminiClientResult containing output text, model used, latency, and status
     */
    public GeminiClientResult generateText(
            String endpointName,
            Long userId,
            String primaryModel,
            String fallbackModel,
            String prompt,
            boolean expectJson) {

        int promptLength = prompt != null ? prompt.length() : 0;
        
        // Build model candidates list (primary + fallback)
        List<String> modelCandidates = buildModelCandidates(primaryModel, fallbackModel);
        
        GeminiClientResult lastResult = null;
        
        for (int i = 0; i < modelCandidates.size(); i++) {
            String model = modelCandidates.get(i);
            boolean isLastModel = i == modelCandidates.size() - 1;
            
            long startTime = System.currentTimeMillis();
            
            try {
                String responseBody = callGemini(prompt, model, expectJson);
                long latencyMs = System.currentTimeMillis() - startTime;
                
                String outputText = extractTextFromResponse(responseBody);
                
                lastResult = GeminiClientResult.builder()
                        .success(model, outputText, latencyMs)
                        .build();
                
                // Log successful call
                logStructured(endpointName, userId, "ok", promptLength, latencyMs, model, null);
                
                return lastResult;
                
            } catch (Exception e) {
                long latencyMs = System.currentTimeMillis() - startTime;
                int statusCode = extractStatusCode(e);
                Integer retryAfterSeconds = extractRetryAfterSeconds(e);
                String errorMsg = e.getMessage();
                
                // Check if we should try fallback
                if (!isLastModel && shouldRetry(statusCode)) {
                    LOG.warnf("Retrying with fallback model endpoint=%s userId=%d primaryModel=%s status=%d",
                            endpointName, userId, model, statusCode);
                    continue;
                }
                
                lastResult = GeminiClientResult.builder()
                        .failure(model, statusCode, errorMsg, latencyMs, retryAfterSeconds)
                        .build();
                
                // Log failure
                logStructured(endpointName, userId, "error", promptLength, latencyMs, model, errorMsg);
                
                return lastResult;
            }
        }
        
        // This should never happen, but return last result if we have one
        if (lastResult != null) {
            return lastResult;
        }
        
        // Fallback failure
        return GeminiClientResult.builder()
                .failure(fallbackModel, 503, "No model available", 0)
                .build();
    }

    /**
     * Validate that API key is configured. Throws ServiceUnavailableException if not.
     * This check is done lazily at call time rather than startup.
     */
    public void validateApiKey() {
        if (geminiApiKey == null || geminiApiKey.isBlank()
                || MISSING_KEY_SENTINEL.equals(geminiApiKey) || geminiApiKey.startsWith("__")) {
            throw new ServiceUnavailableException(503, "GEMINI_API_KEY is not configured");
        }
    }

    private List<String> buildModelCandidates(String primaryModel, String fallbackModel) {
        List<String> candidates = new ArrayList<>();
        
        if (primaryModel != null && !primaryModel.isBlank()) {
            candidates.add(normalizeModel(primaryModel));
        }
        
        if (fallbackModel != null && !fallbackModel.isBlank()) {
            String normalized = normalizeModel(fallbackModel);
            if (!candidates.contains(normalized)) {
                candidates.add(normalized);
            }
        }
        
        // Default fallback if nothing configured
        if (candidates.isEmpty()) {
            candidates.add("gemini-2.0-flash");
        }
        
        return candidates;
    }

    private String callGemini(String prompt, String model, boolean expectJson) throws IOException, InterruptedException {
        String endpoint = "https://generativelanguage.googleapis.com/v1beta/models/"
                + model
                + ":generateContent?key="
                + geminiApiKey;

        ObjectNode payload = objectMapper.createObjectNode();
        payload.set("contents", objectMapper.createArrayNode()
                .add(objectMapper.createObjectNode()
                        .set("parts", objectMapper.createArrayNode()
                                .add(objectMapper.createObjectNode().put("text", prompt)))));

        ObjectNode generationConfig = objectMapper.createObjectNode()
                .put("temperature", 0.4);
        
        if (expectJson) {
            generationConfig.put("responseMimeType", "application/json");
        }
        
        payload.set("generationConfig", generationConfig);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(endpoint))
                .timeout(Duration.ofMillis(timeoutMs))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(payload)))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            String retryAfterHeader = response.headers().firstValue("Retry-After").orElse(null);
            throw new GeminiApiException(response.statusCode(), response.body(), retryAfterHeader);
        }

        return response.body();
    }

    private String extractTextFromResponse(String responseBody) throws IOException {
        JsonNode root = objectMapper.readTree(responseBody);
        JsonNode candidates = root.path("candidates");
        
        if (candidates.isEmpty() || !candidates.get(0).has("content")) {
            throw new IOException("Gemini returned no candidates");
        }

        JsonNode textNode = candidates.path(0).path("content").path("parts").path(0).path("text");
        if (textNode.isMissingNode() || textNode.asText().isBlank()) {
            throw new IOException("Gemini returned empty content");
        }

        return textNode.asText();
    }

    private String extractJson(String raw) {
        String trimmed = raw.trim();
        int firstBrace = trimmed.indexOf('{');
        int lastBrace = trimmed.lastIndexOf('}');
        if (firstBrace >= 0 && lastBrace > firstBrace) {
            return trimmed.substring(firstBrace, lastBrace + 1);
        }
        return trimmed;
    }

    private boolean shouldRetry(int statusCode) {
        return statusCode == 404 || statusCode == 429 || statusCode >= 500;
    }

    private int extractStatusCode(Exception e) {
        if (e instanceof GeminiApiException apiEx) {
            return apiEx.getStatusCode();
        }
        if (e instanceof IOException) {
            return 502;
        }
        if (e instanceof InterruptedException) {
            return 503;
        }
        return 500;
    }

    private Integer extractRetryAfterSeconds(Exception e) {
        if (!(e instanceof GeminiApiException apiEx)) {
            return null;
        }

        Integer fromHeader = parseRetryAfterValue(apiEx.getRetryAfterHeader());
        if (fromHeader != null) {
            return fromHeader;
        }

        Integer fromBody = parseRetryAfterFromBody(apiEx.getBody());
        if (fromBody != null) {
            return fromBody;
        }

        return null;
    }

    private Integer parseRetryAfterFromBody(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }

        try {
            JsonNode root = objectMapper.readTree(body);
            Integer direct = parseRetryAfterNode(root.path("retryAfterSeconds"));
            if (direct != null) {
                return direct;
            }

            JsonNode error = root.path("error");
            Integer fromErrorNode = parseRetryAfterNode(error.path("retryAfterSeconds"));
            if (fromErrorNode != null) {
                return fromErrorNode;
            }

            JsonNode details = error.path("details");
            if (details.isArray()) {
                for (JsonNode detail : details) {
                    Integer fromDetail = parseRetryDelayNode(detail.path("retryDelay"));
                    if (fromDetail != null) {
                        return fromDetail;
                    }
                    Integer fromDetailSeconds = parseRetryAfterNode(detail.path("retryAfterSeconds"));
                    if (fromDetailSeconds != null) {
                        return fromDetailSeconds;
                    }
                }
            }

            String message = error.path("message").asText("");
            Integer fromMessage = parseRetryAfterValue(message);
            if (fromMessage != null) {
                return fromMessage;
            }
        } catch (IOException ignored) {
            // Body may be plain text; fall back to regex parsing below.
        }

        return parseRetryAfterValue(body);
    }

    private Integer parseRetryDelayNode(JsonNode retryDelayNode) {
        if (retryDelayNode == null || retryDelayNode.isMissingNode() || retryDelayNode.isNull()) {
            return null;
        }

        if (retryDelayNode.isObject()) {
            Integer seconds = parseRetryAfterNode(retryDelayNode.path("seconds"));
            if (seconds != null) {
                return seconds;
            }
        }

        return parseRetryAfterValue(retryDelayNode.asText(""));
    }

    private Integer parseRetryAfterNode(JsonNode node) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }
        if (node.isIntegralNumber()) {
            int value = node.asInt();
            return value > 0 ? value : null;
        }
        if (node.isTextual()) {
            return parseRetryAfterValue(node.asText());
        }
        return null;
    }

    private Integer parseRetryAfterValue(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }

        String value = raw.trim();

        if (value.matches("^\\d+$")) {
            int parsed = Integer.parseInt(value);
            return parsed > 0 ? parsed : null;
        }

        Matcher durationMatcher = Pattern.compile("(\\d+(?:\\.\\d+)?)\\s*s", Pattern.CASE_INSENSITIVE).matcher(value);
        if (durationMatcher.find()) {
            double seconds = Double.parseDouble(durationMatcher.group(1));
            int roundedUp = (int) Math.ceil(seconds);
            return Math.max(1, roundedUp);
        }

        Matcher genericNumberMatcher = Pattern.compile("(\\d+)").matcher(value);
        if (genericNumberMatcher.find()) {
            int parsed = Integer.parseInt(genericNumberMatcher.group(1));
            return parsed > 0 ? parsed : null;
        }

        return null;
    }

    private String normalizeModel(String model) {
        if (model == null) {
            return null;
        }
        String trimmed = model.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        if (trimmed.startsWith("models/")) {
            return trimmed.substring("models/".length());
        }
        return trimmed;
    }

    private void logStructured(
            String endpointName,
            Long userId,
            String status,
            int promptLength,
            long latencyMs,
            String modelUsed,
            String error) {
        
        if (error == null || error.isBlank()) {
            LOG.infof("endpoint=%s status=%s userId=%s promptLength=%d latencyMs=%d modelUsed=%s",
                    endpointName, status, userId, promptLength, latencyMs, modelUsed);
        } else {
            LOG.warnf("endpoint=%s status=%s userId=%s promptLength=%d latencyMs=%d modelUsed=%s error=%s",
                    endpointName, status, userId, promptLength, latencyMs, modelUsed, error);
        }
    }

    /**
     * Helper method to extract JSON from raw response text
     */
    public String extractJsonFromResponse(String rawResponse) {
        return extractJson(rawResponse);
    }

    /**
     * Exception for Gemini API errors
     */
    private static class GeminiApiException extends RuntimeException {
        private final int statusCode;
        private final String body;
        private final String retryAfterHeader;

        GeminiApiException(int statusCode, String body, String retryAfterHeader) {
            super("Gemini request failed with status " + statusCode);
            this.statusCode = statusCode;
            this.body = body;
            this.retryAfterHeader = retryAfterHeader;
        }

        int getStatusCode() {
            return statusCode;
        }

        String getBody() {
            return body;
        }

        String getRetryAfterHeader() {
            return retryAfterHeader;
        }
    }

    /**
     * Service unavailable exception for configuration errors
     */
    public static class ServiceUnavailableException extends RuntimeException {
        private final int statusCode;

        ServiceUnavailableException(int statusCode, String message) {
            super(message);
            this.statusCode = statusCode;
        }

        public int getStatusCode() {
            return statusCode;
        }
    }
}
