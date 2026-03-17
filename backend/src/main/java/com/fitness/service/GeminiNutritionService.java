package com.fitness.service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fitness.dto.NutritionAiRequest;
import com.fitness.dto.NutritionAiResponse;
import com.fitness.dto.NutritionLabelResult;
import com.fitness.dto.FoodImageResult;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class GeminiNutritionService {

    private static final Logger LOG = Logger.getLogger(GeminiNutritionService.class);
    private static final int MAX_STEPS = 6;
    private static final int MAX_INGREDIENTS = 12;

    @Inject
    ObjectMapper objectMapper;

    @Inject
    GeminiClient geminiClient;

    @Inject
    AiProviderRouter aiProviderRouter;

    @Inject
    NutritionPromptBuilder promptBuilder;

    @Inject
    UserMealPreferenceService userPreferenceService;

    @ConfigProperty(name = "gemini.nutrition.model", defaultValue = "gemini-2.0-flash")
    String nutritionModel;

    @ConfigProperty(name = "gemini.nutrition.fallback", defaultValue = "gemini-1.5-flash")
    String nutritionFallbackModel;

    /**
     * Scan a nutrition label image using Gemini Vision API.
     * Returns structured nutrition data parsed from the label.
     */
    public NutritionLabelResult scanNutritionLabel(Long userId, byte[] imageBytes, String mimeType) {

        String prompt = """
                Sen bir besin değeri analiz uzmanısın. Bu besin etiketi fotoğrafından \
                aşağıdaki bilgileri JSON formatında çıkar:

                {
                  "productName": "Ürün adı (etikette varsa)",
                  "servingSize": 100,
                  "servingUnit": "g",
                  "kcal": 250.0,
                  "protein": 12.5,
                  "carb": 30.0,
                  "fat": 8.2,
                  "fiber": 3.0,
                  "sugar": 5.5,
                  "confidence": 0.95
                }

                Kurallar:
                - Değerler 100g başına olmalı. Etiket farklı porsiyon veriyorsa 100g'a çevir.
                - Bulunamayan değerler için null yaz.
                - Türkçe ve İngilizce etiketleri destekle.
                - confidence: Değerlerin doğruluğundan ne kadar eminsin (0.0-1.0).
                - Sadece JSON döndür, başka açıklama ekleme.
                """;

        GeminiClientResult result = aiProviderRouter.generateWithImage(
                "ai/nutrition/scan-label",
                userId,
                nutritionModel,
                nutritionFallbackModel,
                prompt,
                imageBytes,
                mimeType,
                true);

        if (!result.isSuccess()) {
            throw mapFailure(result);
        }

        try {
            String jsonText = extractJson(cleanResponse(result.getOutputText()));
            JsonNode parsed = objectMapper.readTree(jsonText);

            NutritionLabelResult labelResult = new NutritionLabelResult();
            labelResult.productName = parsed.path("productName").isNull() ? null
                    : parsed.path("productName").asText(null);
            labelResult.kcal = parseDouble(parsed, "kcal");
            labelResult.protein = parseDouble(parsed, "protein");
            labelResult.carb = parseDouble(parsed, "carb");
            labelResult.fat = parseDouble(parsed, "fat");
            labelResult.fiber = parseDouble(parsed, "fiber");
            labelResult.sugar = parseDouble(parsed, "sugar");
            labelResult.servingSize = parseDouble(parsed, "servingSize");
            labelResult.servingUnit = parsed.path("servingUnit").isNull() ? null
                    : parsed.path("servingUnit").asText(null);
            labelResult.confidence = parseDouble(parsed, "confidence");

            return labelResult;
        } catch (Exception e) {
            LOG.warnf("Failed to parse label scan response: %s", e.getMessage());
            // Return empty result rather than crashing
            NutritionLabelResult empty = new NutritionLabelResult();
            empty.confidence = 0.0;
            return empty;
        }
    }

    /**
     * Analyze a food/meal image using Gemini Vision API.
     * Returns structured nutrition estimation based on visual content.
     */
    public FoodImageResult analyzeFoodImage(Long userId, byte[] imageBytes, String mimeType) {
        String prompt = """
                Sen bir beslenme uzmanı ve yapay zeka görüntü analizörüsün. \
                Bu yemek/yiyecek fotoğrafını analiz et ve aşağıdakiJSON formatında sonuç döndür:

                {
                  "mealName": "Yemeğin/Besinin kısa adı",
                  "mealType": "SNACK", // BREAKFAST, LUNCH, DINNER veya SNACK olabilir
                  "estimatedKcal": 450.0,
                  "protein": 25.5,
                  "carb": 40.0,
                  "fat": 15.0,
                  "confidence": 0.90, // Tahminin ne kadar doğru olduğuna dair güven (0.0-1.0)
                  "detectedIngredients": ["Tavuk göğsü", "Pirinç pilavı", "Brokoli"] // Fotoğrafta görünen ana malzemeler
                }

                Kurallar:
                - Tüm değerleri fotoğrafta görülen porsiyona göre hesapla.
                - Porsiyonu göz kararı tahmin etmeye çalış.
                - Eğer birden fazla besin varsa hepsinin toplamını ver.
                - Sadece JSON döndür, başka hiçbir açıklama ekleme.
                """;

        GeminiClientResult result = aiProviderRouter.generateWithImage(
                "ai/nutrition/analyze-image",
                userId,
                nutritionModel,
                nutritionFallbackModel,
                prompt,
                imageBytes,
                mimeType,
                true);

        if (!result.isSuccess()) {
            throw mapFailure(result);
        }

        try {
            String jsonText = extractJson(cleanResponse(result.getOutputText()));
            JsonNode parsed = objectMapper.readTree(jsonText);

            FoodImageResult foodResult = new FoodImageResult();
            foodResult.mealName = parsed.path("mealName").isNull() ? "Bilinmeyen Yemek"
                    : parsed.path("mealName").asText("Bilinmeyen Yemek");
            foodResult.mealType = parsed.path("mealType").isNull() ? "SNACK"
                    : parsed.path("mealType").asText("SNACK");
            foodResult.estimatedKcal = parseDouble(parsed, "estimatedKcal");
            // Prevent null
            if (foodResult.estimatedKcal == null)
                foodResult.estimatedKcal = 0.0;

            foodResult.protein = parseDouble(parsed, "protein");
            foodResult.carb = parseDouble(parsed, "carb");
            foodResult.fat = parseDouble(parsed, "fat");
            foodResult.confidence = parseDouble(parsed, "confidence");
            foodResult.detectedIngredients = parseStringList(parsed.path("detectedIngredients"));

            return foodResult;
        } catch (Exception e) {
            LOG.warnf("Failed to parse food image analysis response: %s", e.getMessage());
            FoodImageResult empty = new FoodImageResult();
            empty.mealName = "Analiz Başarısız";
            empty.estimatedKcal = 0.0;
            empty.confidence = 0.0;
            empty.detectedIngredients = new ArrayList<>();
            empty.mealType = "SNACK";
            return empty;
        }
    }

    private Double parseDouble(JsonNode parent, String field) {
        JsonNode node = parent.path(field);
        if (node.isMissingNode() || node.isNull())
            return null;
        if (node.isNumber())
            return node.asDouble();
        if (node.isTextual()) {
            try {
                return Double.parseDouble(node.asText());
            } catch (NumberFormatException e) {
                return null;
            }
        }
        return null;
    }

    public NutritionGenerationResult generateNutritionResponse(Long userId, NutritionAiRequest request) {
        validateRequest(request);

        // Inject meal preferences into dietary restrictions if available
        if (userId != null && userPreferenceService != null) {
            String prefs = userPreferenceService.getPreferenceSummary(userId);
            if (!prefs.isEmpty()) {
                if (request.context == null) {
                    request.context = new NutritionAiRequest.NutritionContext();
                }
                if (request.context.dietaryRestrictions == null) {
                    request.context.dietaryRestrictions = new ArrayList<>();
                }
                request.context.dietaryRestrictions.add(prefs);
            }
        }

        String prompt = promptBuilder.buildPrompt(request);

        // Determine if we expect JSON based on task type
        boolean expectJson = !"EXTRACT_FOOD_ITEMS".equalsIgnoreCase(request.task);

        GeminiClientResult result = aiProviderRouter.generateText(
                "ai/nutrition",
                userId,
                nutritionModel,
                nutritionFallbackModel,
                prompt,
                expectJson);

        if (!result.isSuccess()) {
            throw mapFailure(result);
        }

        try {
            NutritionAiResponse response = parseResponse(result.getOutputText());
            // Get goal from request context for filtering
            String goal = (request.context != null) ? request.context.goal : null;
            validateAndNormalizeResponse(response, goal);
            return new NutritionGenerationResult(response, result.getModelUsed());
        } catch (Exception e) {
            // Parse fail olursa fallback response döndür
            LOG.warnf("Failed to parse nutrition response: %s", e.getMessage());
            NutritionAiResponse fallbackResponse = createFallbackResponse(result.getOutputText());
            return new NutritionGenerationResult(fallbackResponse, result.getModelUsed());
        }
    }

    private void validateRequest(NutritionAiRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Request body is required");
        }
        if (request.message == null || request.message.isBlank()) {
            throw new IllegalArgumentException("message is required");
        }
        if (request.message.trim().length() > 1000) {
            throw new IllegalArgumentException("message must be at most 1000 characters");
        }
    }

    private NutritionAiResponse parseResponse(String rawResponse) throws IOException {
        String raw = cleanResponse(rawResponse);

        try {
            String jsonText = extractJson(raw);
            JsonNode parsed = objectMapper.readTree(jsonText);

            if (!parsed.isObject()) {
                throw new IOException("Response is not a JSON object");
            }

            NutritionAiResponse response = new NutritionAiResponse();

            // Parse reply (optional field)
            response.reply = parsed.path("reply").asText("");

            // Parse meals array
            response.meals = parseMeals(parsed.path("meals"));

            // Parse shoppingList
            response.shoppingList = parseStringList(parsed.path("shoppingList"));

            // Parse followUpQuestions
            response.followUpQuestions = parseStringList(parsed.path("followUpQuestions"));

            return response;
        } catch (IOException e) {
            throw e;
        }
    }

    /**
     * Validate and normalize the response to ensure UI doesn't break
     */
    private void validateAndNormalizeResponse(NutritionAiResponse response, String goal) {
        // Ensure lists are not null
        if (response.meals == null) {
            response.meals = new ArrayList<>();
        }
        if (response.shoppingList == null) {
            response.shoppingList = new ArrayList<>();
        }
        if (response.followUpQuestions == null) {
            response.followUpQuestions = new ArrayList<>();
        }

        // Apply goal-based filtering
        if (goal != null && !goal.isBlank()) {
            applyGoalBasedFiltering(response, goal);
        }

        // Normalize meals
        for (NutritionAiResponse.SuggestedMeal meal : response.meals) {
            // Ensure macros is not null (UI will show ~)
            if (meal.macros == null) {
                meal.macros = new NutritionAiResponse.MealMacros();
            }

            // Truncate steps if > 6
            if (meal.steps != null && meal.steps.size() > MAX_STEPS) {
                meal.steps = meal.steps.subList(0, MAX_STEPS);
            }

            // Truncate ingredients if > 12
            if (meal.ingredients != null && meal.ingredients.size() > MAX_INGREDIENTS) {
                meal.ingredients = meal.ingredients.subList(0, MAX_INGREDIENTS);
            }
        }

        // If meals is empty, generate followUpQuestions
        if (response.meals.isEmpty() && response.followUpQuestions.isEmpty()) {
            response.followUpQuestions = generateSmartFollowUpQuestions();
        }

        // Fill reply if empty
        if (response.reply == null || response.reply.isBlank()) {
            if (!response.meals.isEmpty()) {
                response.reply = String.format(
                        "%d öneri hazırladım. Birini seç veya malzemelerini öğrenmek için sor.",
                        response.meals.size());
            } else if (!response.followUpQuestions.isEmpty()) {
                response.reply = "Size nasıl yardımcı olabilirim? Aşağıdaki sorulardan birini seçebilirsiniz.";
            } else {
                response.reply = "Su an net bir yanit olusturamadim. Lutfen tekrar dene.";
            }
        }
    }

    /**
     * Apply goal-based filtering to meals
     * - cut: max 750 kcal, max 30g fat
     * - bulk: min 450 kcal, min 30g protein
     * - conditioning: protein >= 25g, kcal 400-800
     */
    private void applyGoalBasedFiltering(NutritionAiResponse response, String goal) {
        String normalizedGoal = goal.toLowerCase().trim();

        List<NutritionAiResponse.SuggestedMeal> filteredMeals = new ArrayList<>();
        List<String> filteredWarnings = new ArrayList<>();

        for (NutritionAiResponse.SuggestedMeal meal : response.meals) {
            boolean passes = true;
            StringBuilder warning = new StringBuilder();

            int kcal = (meal.macros != null && meal.macros.kcal != null) ? meal.macros.kcal : 0;
            int protein = (meal.macros != null && meal.macros.proteinG != null) ? meal.macros.proteinG : 0;
            int fat = (meal.macros != null && meal.macros.fatG != null) ? meal.macros.fatG : 0;

            switch (normalizedGoal) {
                case "cut":
                    // Cut: max 750 kcal, max 30g fat
                    if (kcal > 750) {
                        passes = false;
                        warning.append("Kcal too high for cut");
                    }
                    if (fat > 30) {
                        if (!passes)
                            warning.append(", ");
                        warning.append("Yağ içeriği yüksek");
                        passes = false;
                    }
                    break;

                case "bulk":
                    // Bulk: min 450 kcal, min 30g protein
                    if (kcal > 0 && kcal < 450) {
                        passes = false;
                        warning.append("Kcal too low for bulk");
                    }
                    if (protein < 30) {
                        if (!passes)
                            warning.append(", ");
                        warning.append("Protein yetersiz");
                        passes = false;
                    }
                    break;

                case "strength":
                case "maintain":
                    // Conditioning: protein >= 25g, kcal 400-800
                    if (protein < 25) {
                        passes = false;
                        warning.append("Protein yetersiz");
                    }
                    if (kcal > 0 && (kcal < 400 || kcal > 800)) {
                        if (!passes)
                            warning.append(", ");
                        warning.append("Kcal hedefe uygun değil");
                        passes = false;
                    }
                    break;
            }

            if (!passes) {
                // Determine if we should keep it despite failing (e.g., if we are desperate for
                // meals)
                // but strictly speaking, filtering means discarding it. Let's discard if it
                // fails strict rules.
                LOG.warn("Filtering out meal: " + meal.name + " due to: " + warning.toString());
            } else {
                filteredMeals.add(meal);
            }
        }

        // If all filtered out, return original meals but add warnings so the user
        // understands why.
        if (filteredMeals.isEmpty() && !response.meals.isEmpty()) {
            LOG.warn(
                    "All meals filtered by goal " + normalizedGoal + ", keeping original list but appending warnings.");
            for (NutritionAiResponse.SuggestedMeal meal : response.meals) {
                if (meal.warnings == null)
                    meal.warnings = new ArrayList<>();
                meal.warnings.add("Yapay zeka hedefinize tam uyan bir menü bulamadı, alternatif listeleniyor.");
            }
        } else {
            response.meals = filteredMeals;
        }
    }

    private List<String> generateSmartFollowUpQuestions() {
        List<String> questions = new ArrayList<>();
        questions.add("Alerjiniz var mı? (fıstık, süt, gluten vb.)");
        questions.add("Bütceniz ne kadar? (düşük/orta/yüksek)");
        questions.add("Kaç kişilik yemek istiyorsunuz?");
        questions.add("Evde hangi malzemeler var?");
        return questions;
    }

    private NutritionAiResponse createFallbackResponse(String rawResponse) {
        NutritionAiResponse fallback = new NutritionAiResponse();
        fallback.meals = new ArrayList<>();
        fallback.shoppingList = new ArrayList<>();
        fallback.followUpQuestions = generateSmartFollowUpQuestions();

        // Try to use the raw text as reply
        String cleaned = cleanResponse(rawResponse);
        if (!cleaned.isEmpty()) {
            fallback.reply = cleaned;
        } else {
            fallback.reply = "Su an net bir yanit olusturamadim. Lutfen tekrar dene.";
        }

        return fallback;
    }

    private List<NutritionAiResponse.SuggestedMeal> parseMeals(JsonNode arrayNode) {
        List<NutritionAiResponse.SuggestedMeal> meals = new ArrayList<>();
        if (arrayNode == null || !arrayNode.isArray()) {
            return meals;
        }

        for (JsonNode node : arrayNode) {
            if (!node.isObject()) {
                continue;
            }
            String name = node.path("name").asText("").trim();
            if (name.isEmpty()) {
                continue;
            }

            NutritionAiResponse.SuggestedMeal meal = new NutritionAiResponse.SuggestedMeal();
            meal.name = name;
            meal.reason = node.path("reason").asText("").trim();
            meal.ingredients = parseStringList(node.path("ingredients"));
            meal.steps = parseStringList(node.path("steps"));
            meal.tags = parseStringList(node.path("tags"));
            meal.warnings = parseStringList(node.path("warnings"));

            // Parse prepMinutes
            JsonNode prepNode = node.path("prepMinutes");
            if (prepNode.isInt() || prepNode.isLong()) {
                meal.prepMinutes = prepNode.asInt();
            }

            // Parse macros
            JsonNode macrosNode = node.path("macros");
            if (macrosNode.isObject()) {
                NutritionAiResponse.MealMacros macros = new NutritionAiResponse.MealMacros();
                JsonNode kcalNode = macrosNode.path("kcal");
                JsonNode proteinNode = macrosNode.path("proteinG");
                JsonNode carbsNode = macrosNode.path("carbsG");
                JsonNode fatNode = macrosNode.path("fatG");

                if (kcalNode.isInt() || kcalNode.isLong()) {
                    macros.kcal = kcalNode.asInt();
                }
                if (proteinNode.isInt() || proteinNode.isLong()) {
                    macros.proteinG = proteinNode.asInt();
                }
                if (carbsNode.isInt() || carbsNode.isLong()) {
                    macros.carbsG = carbsNode.asInt();
                }
                if (fatNode.isInt() || fatNode.isLong()) {
                    macros.fatG = fatNode.asInt();
                }
                meal.macros = macros;
            }

            meals.add(meal);
        }
        return meals;
    }

    private List<String> parseStringList(JsonNode arrayNode) {
        List<String> result = new ArrayList<>();
        if (arrayNode == null || !arrayNode.isArray()) {
            return result;
        }

        for (JsonNode node : arrayNode) {
            if (node.isTextual()) {
                String value = node.asText("").trim();
                if (!value.isEmpty()) {
                    result.add(value);
                }
            }
        }
        return result;
    }

    private String cleanResponse(String raw) {
        String cleaned = raw.trim();
        // Strip markdown code blocks
        if (cleaned.startsWith("```")) {
            int firstNewline = cleaned.indexOf('\n');
            if (firstNewline > 0) {
                cleaned = cleaned.substring(firstNewline + 1);
            }
            int lastTripleBacktick = cleaned.lastIndexOf("```");
            if (lastTripleBacktick > 0) {
                cleaned = cleaned.substring(0, lastTripleBacktick);
            }
        }
        return cleaned.trim();
    }

    private String extractJson(String raw) {
        // More robust extraction
        String trimmed = raw.trim();

        // Strip known markdown blocks first if exist
        if (trimmed.startsWith("```json")) {
            trimmed = trimmed.substring(7);
        } else if (trimmed.startsWith("```")) {
            trimmed = trimmed.substring(3);
        }
        if (trimmed.endsWith("```")) {
            trimmed = trimmed.substring(0, trimmed.length() - 3);
        }

        trimmed = trimmed.trim();

        // Try to find JSON object
        int firstBrace = trimmed.indexOf('{');
        if (firstBrace < 0) {
            // No JSON found, return raw for fallback
            return trimmed;
        }

        int lastBrace = trimmed.lastIndexOf('}');
        if (lastBrace < 0 || lastBrace <= firstBrace) {
            return trimmed;
        }

        return trimmed.substring(firstBrace, lastBrace + 1);
    }

    private AiCoachServiceException mapFailure(GeminiClientResult result) {
        int status = result.getStatusCode();
        String modelInfo = result.getModelUsed() != null ? " (" + result.getModelUsed() + ")" : "";

        if (status == 401 || status == 403) {
            return new AiCoachServiceException(503, "Beslenme AI yetkilendirme hatasi. GEMINI_API_KEY kontrol et.");
        }
        if (status == 404) {
            return new AiCoachServiceException(503, "Beslenme AI modeli kullanilamiyor" + modelInfo + ".");
        }
        if (status == 429) {
            Integer retryAfterSeconds = result.getRetryAfterSeconds();
            if (retryAfterSeconds == null || retryAfterSeconds <= 0) {
                retryAfterSeconds = 20;
            }
            return new AiCoachServiceException(
                    429,
                    "Beslenme AI servisi yogun. Lutfen biraz sonra tekrar dene.",
                    retryAfterSeconds);
        }
        if (status >= 500) {
            return new AiCoachServiceException(503, "Beslenme AI servisi gecici olarak kullanilamiyor.");
        }
        if (result.getError() != null) {
            return new AiCoachServiceException(502, "Beslenme AI istegi basarisiz oldu: " + result.getError());
        }
        return new AiCoachServiceException(502, "Beslenme AI istegi basarisiz oldu.");
    }

    public static final class NutritionGenerationResult {
        private final NutritionAiResponse response;
        private final String modelUsed;

        public NutritionGenerationResult(NutritionAiResponse response, String modelUsed) {
            this.response = response;
            this.modelUsed = modelUsed;
        }

        public NutritionAiResponse response() {
            return response;
        }

        public String modelUsed() {
            return modelUsed;
        }
    }
}
