package com.fitness.service;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Base64;
import java.util.List;

import com.fitness.dto.NutritionAiRequest;

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

    @ConfigProperty(name = "claude.model", defaultValue = "claude-haiku-4-5")
    String defaultModel;

    @ConfigProperty(name = "claude.timeout.ms", defaultValue = "30000")
    long timeoutMs;

    private final HttpClient httpClient = HttpClient.newHttpClient();

    private static final String COACHING_SYSTEM_PROMPT = """
            You are PusulaFit — an elite personal fitness coach and nutritionist with deep reasoning ability.
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
     * System prompt for the Nutrition Assistant chat (separate from the main AI Coach).
     * Expects {reply, meals, shoppingList, followUpQuestions} JSON — NOT the coach format.
     */
    private static final String NUTRITION_SYSTEM_PROMPT = """
            You are PusulaFit Nutrition — a concise, data-driven nutrition assistant inside a fitness tracking app.
            You have the user's real food log, daily calorie intake, macro targets, dietary restrictions, and fitness goal.

            CORE RULES:
            1. Answer ONLY what the user asked. Never add unsolicited suggestions.
            2. Always respond in Turkish (tr).
            3. Short question → short answer (1-3 sentences for informational questions).
            4. Use the user's real data. Never invent numbers.
            5. No filler phrases: "tabii ki", "harika", "mükemmel", "elbette", "kesinlikle".
            6. If the user asks for a number, start the reply with that number immediately.
            7. If you have conversation history, continue naturally — do not restart tone or re-explain context.

            INTENT → OUTPUT MAPPING:
            A. Informational question (calories, macros, what I ate, water, general advice, comparisons):
               → Fill ONLY "reply" with a direct Turkish answer. "meals" = []. "shoppingList" = []. "followUpQuestions" = [].
            B. Meal suggestion, recipe, or food recommendation:
               → Provide 3-5 items in "meals". "reply" = 1 short intro sentence in Turkish.
               → Optionally add 1-2 relevant follow-up questions.
            C. Shopping list request:
               → Fill "shoppingList" only. "meals" = [].

            OUTPUT — return ONLY this exact JSON, no text before or after:
            {
              "reply": "string — direct Turkish answer to the user",
              "meals": [
                {
                  "name": "string",
                  "reason": "string",
                  "ingredients": ["string"],
                  "steps": ["string"],
                  "macros": {"kcal": 0, "proteinG": 0, "carbsG": 0, "fatG": 0},
                  "prepMinutes": 0,
                  "tags": ["string"],
                  "warnings": ["string"]
                }
              ],
              "shoppingList": ["string"],
              "followUpQuestions": ["string"]
            }
            No markdown code fences. No text outside the JSON object.
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
     * Generate text using Claude Messages API (single-turn, no history).
     */
    public GeminiClientResult generateText(
            String endpointName,
            Long userId,
            String prompt,
            boolean expectJson) {
        return generateText(endpointName, userId, prompt, null, expectJson);
    }

    /**
     * Generate text using Claude Messages API with optional conversation history
     * for multi-turn context awareness. Selects system prompt based on endpoint.
     */
    public GeminiClientResult generateText(
            String endpointName,
            Long userId,
            String prompt,
            List<NutritionAiRequest.ConversationTurn> history,
            boolean expectJson) {
        return generateText(endpointName, userId, prompt, history, expectJson, null);
    }

    /**
     * Generate text with optional Gemini-format tools. Tools are converted to Claude format internally.
     * Tool-use responses are converted to {"functionCall": {...}} for compatibility with GeminiCoachService.
     */
    public GeminiClientResult generateText(
            String endpointName,
            Long userId,
            String prompt,
            List<NutritionAiRequest.ConversationTurn> history,
            boolean expectJson,
            JsonNode geminiTools) {

        long startTime = System.currentTimeMillis();
        int promptLength = prompt != null ? prompt.length() : 0;

        try {
            JsonNode claudeTools = convertGeminiToolsToClaude(geminiTools);
            String responseText = callClaude(endpointName, prompt, history, null, null, expectJson, claudeTools);
            long latencyMs = System.currentTimeMillis() - startTime;

            LOG.infof("endpoint=%s status=ok userId=%s promptLength=%d historyTurns=%d latencyMs=%d modelUsed=%s provider=claude",
                    endpointName, userId, promptLength, history != null ? history.size() : 0, latencyMs, defaultModel);

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
     * Convert Gemini-format tool declarations to Claude format.
     * Gemini: [{function_declarations: [{name, description, parameters: {type, properties, required}}]}]
     * Claude: [{name, description, input_schema: {type, properties, required}}]
     */
    private JsonNode convertGeminiToolsToClaude(JsonNode geminiTools) {
        if (geminiTools == null || !geminiTools.isArray() || geminiTools.isEmpty()) return null;
        ArrayNode claudeTools = objectMapper.createArrayNode();
        for (JsonNode toolGroup : geminiTools) {
            JsonNode declarations = toolGroup.path("function_declarations");
            if (!declarations.isArray()) continue;
            for (JsonNode fn : declarations) {
                ObjectNode claudeTool = objectMapper.createObjectNode();
                claudeTool.put("name", fn.path("name").asText());
                claudeTool.put("description", fn.path("description").asText());
                JsonNode params = fn.path("parameters");
                ObjectNode inputSchema = objectMapper.createObjectNode();
                inputSchema.put("type", params.path("type").asText("object").toLowerCase());
                if (params.has("properties")) inputSchema.set("properties", convertProperties(params.path("properties")));
                if (params.has("required")) inputSchema.set("required", params.path("required"));
                claudeTool.set("input_schema", inputSchema);
                claudeTools.add(claudeTool);
            }
        }
        return claudeTools.isEmpty() ? null : claudeTools;
    }

    private JsonNode convertProperties(JsonNode geminiProps) {
        ObjectNode result = objectMapper.createObjectNode();
        geminiProps.fields().forEachRemaining(entry -> {
            ObjectNode prop = objectMapper.createObjectNode();
            String type = entry.getValue().path("type").asText("string").toLowerCase();
            prop.put("type", type);
            if (entry.getValue().has("description")) {
                prop.put("description", entry.getValue().path("description").asText());
            }
            result.set(entry.getKey(), prop);
        });
        return result;
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
            String responseText = callClaude(endpointName, prompt, null, imageBytes, mimeType, expectJson);
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

    private String callClaude(
            String endpointName,
            String prompt,
            List<NutritionAiRequest.ConversationTurn> history,
            byte[] imageBytes,
            String mimeType,
            boolean expectJson)
            throws IOException, InterruptedException {
        return callClaude(endpointName, prompt, history, imageBytes, mimeType, expectJson, null);
    }

    private String callClaude(
            String endpointName,
            String prompt,
            List<NutritionAiRequest.ConversationTurn> history,
            byte[] imageBytes,
            String mimeType,
            boolean expectJson,
            JsonNode claudeTools)
            throws IOException, InterruptedException {

        ObjectNode payload = objectMapper.createObjectNode();
        payload.put("model", defaultModel);
        payload.put("max_tokens", 4096);

        // Select system prompt based on endpoint
        boolean isNutritionEndpoint = endpointName != null && endpointName.contains("nutrition");
        String basePrompt = isNutritionEndpoint ? NUTRITION_SYSTEM_PROMPT : COACHING_SYSTEM_PROMPT;
        String systemPromptText = expectJson
                ? basePrompt + "\nCRITICAL: your entire response must be valid JSON only — no text outside the JSON object."
                : basePrompt;

        // Prompt caching: system prompt as array with cache_control for ~90% cost reduction
        // Cache TTL is 5 minutes — stable content (system prompt) is cached across requests
        ArrayNode systemArray = objectMapper.createArrayNode();
        ObjectNode systemBlock = objectMapper.createObjectNode();
        systemBlock.put("type", "text");
        systemBlock.put("text", systemPromptText);
        ObjectNode cacheControl = objectMapper.createObjectNode();
        cacheControl.put("type", "ephemeral");
        systemBlock.set("cache_control", cacheControl);
        systemArray.add(systemBlock);
        payload.set("system", systemArray);

        // Build messages array — prepend conversation history for multi-turn context.
        // Hard limits: max 6 turns, 800 chars/user-turn, 1500 chars/assistant-turn,
        // 6000 chars total history to stay well within Claude's context window.
        ArrayNode messages = objectMapper.createArrayNode();
        if (history != null && !history.isEmpty()) {
            int maxTurns = Math.min(history.size(), 6);
            int startIdx = history.size() - maxTurns;
            int totalHistoryChars = 0;
            final int maxTotalHistoryChars = 6000;
            for (int i = startIdx; i < history.size(); i++) {
                NutritionAiRequest.ConversationTurn turn = history.get(i);
                if (turn.userMessage == null || turn.assistantMessage == null) continue;
                String userMsg = truncate(turn.userMessage, 800);
                String assistantMsg = truncate(turn.assistantMessage, 1500);
                int turnChars = userMsg.length() + assistantMsg.length();
                if (totalHistoryChars + turnChars > maxTotalHistoryChars) break;
                totalHistoryChars += turnChars;
                ObjectNode prevUser = objectMapper.createObjectNode();
                prevUser.put("role", "user");
                prevUser.put("content", userMsg);
                messages.add(prevUser);
                ObjectNode prevAssistant = objectMapper.createObjectNode();
                prevAssistant.put("role", "assistant");
                prevAssistant.put("content", assistantMsg);
                messages.add(prevAssistant);
            }
        }

        // Current user message
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
            userMessage.put("content", prompt);
        }

        messages.add(userMessage);
        payload.set("messages", messages);

        // Native tool support: pass tools if provided (e.g. saveUserMemory)
        if (claudeTools != null && claudeTools.isArray() && !claudeTools.isEmpty()) {
            payload.set("tools", claudeTools);
        }

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(API_URL))
                .timeout(Duration.ofMillis(timeoutMs))
                .header("Content-Type", "application/json")
                .header("x-api-key", claudeApiKey)
                .header("anthropic-version", API_VERSION)
                .header("anthropic-beta", "prompt-caching-2024-07-31")
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
            // Check for tool_use blocks first — convert to Gemini-compatible functionCall format
            // so GeminiCoachService can handle both providers uniformly.
            for (JsonNode block : content) {
                if ("tool_use".equals(block.path("type").asText())) {
                    ObjectNode funcCallWrapper = objectMapper.createObjectNode();
                    ObjectNode funcCall = objectMapper.createObjectNode();
                    funcCall.put("name", block.path("name").asText());
                    funcCall.set("args", block.path("input"));
                    funcCallWrapper.set("functionCall", funcCall);
                    return funcCallWrapper.toString();
                }
            }

            // Regular text blocks
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

    private static String truncate(String s, int maxLen) {
        if (s == null) return "";
        return s.length() <= maxLen ? s : s.substring(0, maxLen);
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
