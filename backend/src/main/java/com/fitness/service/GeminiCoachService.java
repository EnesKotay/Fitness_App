package com.fitness.service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

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

    private enum ResponseIntent {
        DIRECT_QUESTION,
        WORKOUT_PLAN,
        NUTRITION,
        FOOD_LOGGING,
        HYDRATION,
        RECIPE_OR_SHOPPING,
        SUPPLEMENT,
        PROGRESS_ANALYSIS,
        SAFETY_OR_INJURY,
        EMOTIONAL_SUPPORT
    }

    private static final String[] SAFETY_KEYWORDS = {
            "ağrı", "agri", "ağrıyor", "agriyor", "acı", "aci", "sakat", "incin",
            "dizim", "belim", "omzum", "bileğim", "bilegim", "baş dön", "bas don",
            "göğüs ağr", "gogus agr", "nefes darl", "bayıl", "bayil", "tansiyon",
            "diyabet", "hamile", "hastayım", "hastayim"
    };

    private static final String[] NUTRITION_KEYWORDS = {
            "ne yesem", "ne yemeliyim", "ne yiy", "ne iç", "ne ic", "öğün", "ogun",
            "yemek", "menü", "menu", "tarif", "beslen", "kalori", "kcal", "makro",
            "protein", "karbonhidrat", "karb", "yağ", "yag", "diyet", "porsiyon",
            "gram", "kahvalt", "öğle", "ogle", "öğlene", "oglene", "akşam yeme",
            "aksam yeme", "akşama", "aksama", "ara öğün", "ara ogun", "atıştır",
            "atistir", "tabak", "yulaf", "yumurta", "tavuk", "salata", "pilav",
            "yoğurt", "yogurt"
    };

    private static final String[] FOOD_LOG_KEYWORDS = {
            "yedim", "içtim", "ictim", "tükettim", "tukettim", "günlüğe ekle",
            "gunluge ekle", "yediğim", "yedigim", "yemeği ekle", "yemegi ekle",
            "öğünü ekle", "ogunu ekle", "kaç kalori", "kac kalori", "kalorisi ne"
    };

    private static final String[] HYDRATION_KEYWORDS = {
            "su içtim", "su ictim", "su ekle", "su kaydet", "su hedef",
            "su tüket", "su tuket", "hidrasyon", "susuz", "kaç litre", "kac litre"
    };

    private static final String[] RECIPE_SHOPPING_KEYWORDS = {
            "tarif", "nasıl piş", "nasil pis", "malzeme", "alışveriş", "alisveris",
            "market", "alışveriş list", "alisveris list", "market list", "menü hazırla",
            "menu hazirla", "meal prep"
    };

    private static final String[] SUPPLEMENT_KEYWORDS = {
            "kreatin", "creatine", "whey", "protein tozu", "preworkout", "pre-workout",
            "bcaa", "omega", "magnezyum", "vitamin", "kafein", "supplement"
    };

    private static final String[] WORKOUT_KEYWORDS = {
            "antrenman program", "antreman program", "antrenman plan", "antreman plan",
            "antrenman ver", "antrenman", "antreman", "hareket", "egzersiz",
            "workout", "set", "tekrar", "gym", "spor", "salon", "evde çalış",
            "evde calis", "ne çalış", "ne calis", "çalışmalıyım", "calismaliyim",
            "full body", "split", "push pull", "bacak", "göğüs", "gogus", "sırt",
            "sirt", "omuz", "kol", "kardiyo", "koşu", "kosu", "ısınma", "isinma",
            "esneme", "formum", "teknik"
    };

    private static final String[] ANALYSIS_KEYWORDS = {
            "nasılım", "nasilim", "analiz", "değerlendir", "degerlendir",
            "ilerleme", "trend", "kilo veriyor muyum", "kilo alıyor muyum",
            "kilo aliyor muyum", "yağ yakıyor muyum", "yag yakiyor muyum",
            "durumum", "gidişat", "gidisat", "hedefe yakın", "hedefe yakin", "rapor"
    };

    private static final String[] RECOVERY_KEYWORDS = {
            "zorlan", "motivasyon", "bıktım", "biktim", "olmuyor", "moral", "üşen",
            "usen", "yapamıyorum", "yapamiyorum", "stres", "toparlan", "dinlen",
            "uyku", "yorgun", "enerjim yok", "çok yoruldum", "cok yoruldum"
    };

    public AiCoachResponse generateCoachResponse(Long userId, AiCoachRequest request) {
        validateRequest(request);

        // Fetch long-term memory insights
        List<com.fitness.entity.AiInsight> insights = com.fitness.entity.AiInsight.findRecentByUser(userId, 3);
        
        CoachPromptContext context = contextBuilder.build(userId, request.dailySummary, request.question);
        String prompt = promptBuilder.buildPrompt(request, insights, context);
        ResponseIntent intent = inferIntent(request);

        AiCoachResponse response = generateOnce(userId, prompt);
        sanitizeResponse(response, request);
        String qualityIssue = responseQualityIssue(response, request, intent);
        if (qualityIssue != null) {
            LOG.infof("AI coach response repair userId=%d intent=%s issue=%s", userId, intent, qualityIssue);
            response = generateOnce(userId, buildRepairPrompt(prompt, response, qualityIssue, intent));
            sanitizeResponse(response, request);
        }

        handleMemoryActions(userId, response);
        saveDetectedMemory(userId, request, response);
        validateResponse(response);
        fillSuggestedPrompts(response, intent);
        return response;
    }

    private AiCoachResponse generateOnce(Long userId, String prompt) {
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
            return parseResponse(parsed);
        } catch (IOException e) {
            LOG.error("Failed to parse AI response for user " + userId, e);
            throw new AiCoachServiceException(502, "Koç yanıtı işlenemedi.");
        }
    }

    public AiCoachResponse generateVisionResponse(Long userId, AiCoachRequest request, byte[] mediaBytes, String mimeType) {
        validateRequest(request);

        CoachPromptContext context = contextBuilder.build(userId, request.dailySummary, request.question);
        String basePrompt = promptBuilder.buildPrompt(
                request,
                com.fitness.entity.AiInsight.findRecentByUser(userId, 2),
                context);
                
        String mediaContext = mimeType.startsWith("video/")
            ? buildVideoAnalysisPrompt()
            : buildImageAnalysisPrompt(request);

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
            handleMemoryActions(userId, response);
            saveDetectedMemory(userId, request, response);
            validateResponse(response);  // was missing — empty todayFocus silently returned before
            fillSuggestedPrompts(response, inferIntent(request));
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
        if (request.question.trim().length() > 2000) {
            throw new IllegalArgumentException("question must be at most 2000 characters");
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
        response.suggestedPrompts = parseSuggestedPrompts(parsed.path("suggestedPrompts"));

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

    private List<String> parseSuggestedPrompts(JsonNode node) {
        List<String> result = new ArrayList<>();
        if (node != null && node.isArray()) {
            for (JsonNode n : node) {
                if (n.isTextual() && !n.asText().trim().isEmpty()) {
                    result.add(n.asText().trim());
                }
            }
        }
        return result;
    }

    private void handleMemoryActions(Long userId, AiCoachResponse response) {
        if (response == null || response.actions == null) return;

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

    private String responseQualityIssue(AiCoachResponse response, AiCoachRequest request, ResponseIntent intent) {
        if (response == null) return "Yanıt nesnesi boş.";
        String focus = response.todayFocus == null ? "" : response.todayFocus.trim();
        String combined = (focus + " " + String.join(" ", safeList(response.actionItems)) + " " + nullToEmpty(response.nutritionNote))
                .toLowerCase(Locale.ROOT);

        if (focus.isBlank()) {
            return "todayFocus boş; kullanıcının sorusuna doğrudan cevap yok.";
        }
        if (looksLikePlaceholder(focus) && safeList(response.actionItems).isEmpty()) {
            return "Cevap plan hazırladığını söylüyor ama gerçek içerik vermiyor.";
        }
        if (requiresSpecificity(intent) && looksTooGeneric(combined)) {
            return "Cevap fazla genel; kullanıcıya özel ölçü, örnek veya uygulanabilir ayrıntı yok.";
        }

        switch (intent) {
            case WORKOUT_PLAN:
                if (safeList(response.actionItems).size() < 3) {
                    return "Antrenman/program sorusunda en az 3 somut hareket veya adım gerekli.";
                }
                if (!containsAny(combined, "set", "tekrar", "dk", "dakika", "saniye", "rpe", "rir", "tur")) {
                    return "Antrenman cevabında set/tekrar/süre/dinlenme gibi ölçülebilir detay yok.";
                }
                break;
            case NUTRITION:
                if (!mentionsFoodOrMeal(combined)) {
                    return "Beslenme cevabı somut yiyecek veya öğün önermiyor.";
                }
                if (safeList(response.actionItems).isEmpty()
                        && nullToEmpty(response.nutritionNote).isBlank()
                        && !hasNutritionQuantity(focus)) {
                    return "Beslenme sorusunda öğün, porsiyon veya beslenme notu yok.";
                }
                if (!hasNutritionQuantity(combined)) {
                    return "Beslenme cevabında porsiyon, gram, kcal veya ölçü yok.";
                }
                break;
            case FOOD_LOGGING:
                if (!containsAny(combined, "kcal", "kalori", "protein", "karbonhidrat", "yağ", "yag")) {
                    return "Yemek kaydı/kalori tahmininde kcal veya makro tahmini yok.";
                }
                if (!hasNutritionQuantity(combined)) {
                    return "Yemek kaydı cevabında porsiyon veya miktar belirsiz.";
                }
                break;
            case HYDRATION:
                if (!containsAny(combined, "su", "litre", "ml", "hidrasyon", "bardak")) {
                    return "Su/hidrasyon cevabı litre, bardak veya su hedefine bağlanmıyor.";
                }
                break;
            case RECIPE_OR_SHOPPING:
                if (safeList(response.actionItems).size() < 3) {
                    return "Tarif/alışveriş isteğinde en az 3 malzeme, adım veya liste öğesi gerekli.";
                }
                if (!containsAny(combined, "malzeme", "tarif", "piş", "pis", "karıştır", "karistir", "liste", "market", "alışveriş", "alisveris")) {
                    return "Tarif/alışveriş cevabı tarif adımı, malzeme veya alışveriş listesi gibi beklenen içerik taşımıyor.";
                }
                if (!hasNutritionQuantity(combined)) {
                    return "Tarif/alışveriş cevabında miktar, gram, porsiyon veya kcal yok.";
                }
                break;
            case SUPPLEMENT:
                if (!containsAny(combined, "doz", "gram", "gün", "gun", "kullan", "uygun", "dikkat", "doktor", "böbrek", "bobrek")) {
                    return "Supplement cevabı kullanım/dikkat bilgisi içermiyor.";
                }
                break;
            case PROGRESS_ANALYSIS:
                if (!containsAny(combined, "kalori", "protein", "su", "antrenman", "kilo", "hedef", "trend", "%")) {
                    return "Analiz cevabı kullanıcının verilerine veya ölçülebilir sinyale bağlanmıyor.";
                }
                if (!containsAny(combined, "çünkü", "cunku", "bu yüzden", "bu yuzden", "risk", "iyi", "eksik", "artır", "artir", "azalt")) {
                    return "Analiz cevabı ölçüleri yorumlamıyor; neden-sonuç ve sonraki adım eksik.";
                }
                break;
            case SAFETY_OR_INJURY:
                if (!containsAny(combined, "durdur", "azalt", "hafif", "dinlen", "doktor", "fizyoterap", "uzman", "ağrı", "agri")) {
                    return "Ağrı/sakatlık cevabı güvenlik, azaltma veya profesyonel destek yönlendirmesi içermiyor.";
                }
                break;
            case EMOTIONAL_SUPPORT:
                if (safeList(response.actionItems).size() > 4) {
                    return "Duygusal destek sorusunda aksiyon listesi fazla uzun; küçük adımlar gerekli.";
                }
                break;
            case DIRECT_QUESTION:
                if (focus.length() < 20 && safeList(response.actionItems).isEmpty()) {
                    return "Kısa bilgi sorusunda cevap fazla eksik.";
                }
                break;
        }

        return null;
    }

    private String buildRepairPrompt(String originalPrompt, AiCoachResponse response, String issue, ResponseIntent intent) {
        String previous;
        try {
            previous = objectMapper.writeValueAsString(response);
        } catch (Exception e) {
            previous = response != null ? nullToEmpty(response.todayFocus) : "";
        }

        return originalPrompt + """

            --- RESPONSE QUALITY REPAIR ---
            Your previous JSON was insufficient.
            Issue: %s
            Detected intent: %s
            Previous response: %s

            Rewrite the answer as valid raw JSON only.
            Fix the issue directly:
            - Answer the user's actual request, not a generic intro.
            - If workout/program: include exercises with sets/reps/rest or duration.
            - If nutrition/food log/recipe/shopping: include foods, quantities, kcal/macros or ingredients when relevant.
            - If hydration: mention water amount/target/timing and never treat water as calories.
            - If supplement: include practical use, evidence-level caution, and who should avoid/ask a professional.
            - If pain/injury: be safety-first, reduce intensity, and recommend professional help for severe or persistent symptoms.
            - If analysis: cite the most relevant user metrics and next step.
            - Keep Turkish, concise, and actionable.
            """.formatted(issue, intent, previous);
    }

    private ResponseIntent inferIntent(AiCoachRequest request) {
        String q = request.question == null ? "" : request.question.toLowerCase(Locale.ROOT);
        String mode = request.taskMode == null ? "" : request.taskMode.toLowerCase(Locale.ROOT);
        String routeText = isShortFollowUp(q) ? (q + " " + recentConversationText(request, 4)) : q;

        if (containsAny(routeText, SAFETY_KEYWORDS)) {
            return ResponseIntent.SAFETY_OR_INJURY;
        }
        if (containsAny(routeText, HYDRATION_KEYWORDS)) {
            return ResponseIntent.HYDRATION;
        }
        if (containsAny(routeText, RECIPE_SHOPPING_KEYWORDS)) {
            return ResponseIntent.RECIPE_OR_SHOPPING;
        }
        if (containsAny(routeText, FOOD_LOG_KEYWORDS)) {
            return ResponseIntent.FOOD_LOGGING;
        }
        if (containsAny(routeText, SUPPLEMENT_KEYWORDS)) {
            return ResponseIntent.SUPPLEMENT;
        }
        if ("nutrition".equals(mode) || containsAny(routeText, NUTRITION_KEYWORDS)) {
            return ResponseIntent.NUTRITION;
        }
        if ("workout".equals(mode) || "weekly_plan".equals(mode) || containsAny(routeText, WORKOUT_KEYWORDS)) {
            return ResponseIntent.WORKOUT_PLAN;
        }
        if ("analysis".equals(mode) || containsAny(routeText, ANALYSIS_KEYWORDS)) {
            return ResponseIntent.PROGRESS_ANALYSIS;
        }
        if ("recovery".equals(mode) || containsAny(routeText, RECOVERY_KEYWORDS)) {
            return ResponseIntent.EMOTIONAL_SUPPORT;
        }
        return ResponseIntent.DIRECT_QUESTION;
    }

    private void saveDetectedMemory(Long userId, AiCoachRequest request, AiCoachResponse response) {
        String fact = detectMemoryFact(request);
        if (fact == null || fact.isBlank()) return;
        saveSemanticMemory(userId, fact);
        if (response != null && (response.memorySaved == null || response.memorySaved.isBlank())) {
            response.memorySaved = fact;
        }
    }

    private String detectMemoryFact(AiCoachRequest request) {
        if (request == null || request.question == null) return null;
        String raw = request.question.trim();
        String q = raw.toLowerCase(Locale.ROOT);
        if (raw.length() < 8 || raw.length() > 240) return null;

        if (containsAny(q, "sevmiyorum", "severim", "seviyorum", "alerjim", "alerji", "vejetaryen", "vegan",
                "laktoz", "gluten", "diyetim", "helal", "domuz", "balık yemem", "balik yemem")) {
            return "Beslenme tercihi/kısıtı: " + raw;
        }
        if (containsAny(q, SAFETY_KEYWORDS)) {
            return "Fiziksel durum/sakatlık notu: " + raw;
        }
        if (containsAny(q, "evde çalış", "evde calis", "salona gidem", "dumbbell", "halter", "ekipman",
                "koşu bandı", "kosu bandi", "barfiks", "direnç bandı", "direnc bandi")) {
            return "Antrenman ortamı/ekipman notu: " + raw;
        }
        if (containsAny(q, "sabah spor", "akşam spor", "gece çalış", "haftada", "vaktim", "zamanım")) {
            return "Program/zaman tercihi: " + raw;
        }
        if (containsAny(q, SUPPLEMENT_KEYWORDS) && containsAny(q, "kullanıyorum", "kullaniyorum", "kullanmıyorum", "kullanmiyorum", "başladım", "basladim")) {
            return "Supplement kullanım notu: " + raw;
        }
        return null;
    }

    private void fillSuggestedPrompts(AiCoachResponse response, ResponseIntent intent) {
        if (response == null) return;
        if (response.suggestedPrompts != null && response.suggestedPrompts.size() >= 3) {
            return;
        }

        List<String> fallback = switch (intent) {
            case WORKOUT_PLAN -> List.of("Isınma ekle", "Planı hafiflet", "Kaydetmeye hazırla");
            case NUTRITION -> List.of("Alternatif öğün ver", "Makroları hesapla", "Alışveriş listesi yap");
            case FOOD_LOGGING -> List.of("Günlüğe ekle", "Porsiyonu düzelt", "Makroları göster");
            case HYDRATION -> List.of("Suyu ekle", "Hedefim kaç litre", "Saatlere böl");
            case RECIPE_OR_SHOPPING -> List.of("Tarifi kaydet", "Listeyi sadeleştir", "Protein artır");
            case SUPPLEMENT -> List.of("Dozu açıkla", "Yan etkiler ne", "Bana uygun mu");
            case PROGRESS_ANALYSIS -> List.of("En kritik adım ne", "Yarın ne yapayım", "Eksikleri göster");
            case SAFETY_OR_INJURY -> List.of("Nasıl hafifletirim", "Ne zaman doktora", "Alternatif hareket ver");
            case EMOTIONAL_SUPPORT -> List.of("Daha kolay yap", "Bana mini hedef ver", "Yarın planla");
            case DIRECT_QUESTION -> List.of("Daha detaylı açıkla", "Bana göre yorumla", "Sonraki adım ne");
        };

        List<String> merged = new ArrayList<>();
        if (response.suggestedPrompts != null) {
            merged.addAll(response.suggestedPrompts);
        }
        for (String prompt : fallback) {
            if (merged.size() >= 3) break;
            if (!merged.contains(prompt)) merged.add(prompt);
        }
        response.suggestedPrompts = merged.stream().limit(3).toList();
    }

    private boolean looksLikePlaceholder(String focus) {
        String f = focus == null ? "" : focus.toLowerCase(Locale.ROOT);
        return containsAny(f, "hazırladım", "oluşturdum", "aşağıda", "şöyle bir plan")
                && !containsAny(f, "set", "tekrar", "kcal", "gram", "dakika");
    }

    private boolean requiresSpecificity(ResponseIntent intent) {
        return intent == ResponseIntent.WORKOUT_PLAN
                || intent == ResponseIntent.NUTRITION
                || intent == ResponseIntent.FOOD_LOGGING
                || intent == ResponseIntent.RECIPE_OR_SHOPPING
                || intent == ResponseIntent.PROGRESS_ANALYSIS;
    }

    private boolean looksTooGeneric(String text) {
        if (text == null || text.isBlank()) return true;
        boolean hasGenericPhrase = containsAny(text,
                "dengeli beslen", "sağlıklı beslen", "saglikli beslen", "bol su iç", "bol su ic",
                "düzenli egzersiz", "duzenli egzersiz", "kendini dinle", "genel olarak",
                "hedefine uygun", "planına sadık", "planina sadik");
        boolean hasConcreteDetail = text.matches(".*\\d+.*")
                || containsAny(text, "set", "tekrar", "kcal", "gram", "porsiyon", "dakika", "ml", "litre", "malzeme");
        return hasGenericPhrase && !hasConcreteDetail;
    }

    private boolean mentionsFoodOrMeal(String text) {
        return containsAny(text,
                "kahvalt", "öğle", "ogle", "akşam", "aksam", "ara öğün", "ara ogun",
                "yumurta", "yulaf", "yoğurt", "yogurt", "tavuk", "et", "balık", "balik",
                "peynir", "salata", "pilav", "bulgur", "mercimek", "nohut", "sebze",
                "meyve", "sandviç", "sandvic", "smoothie", "protein", "öğün", "ogun");
    }

    private boolean isShortFollowUp(String q) {
        if (q == null) return false;
        String clean = q.trim();
        if (clean.length() <= 28) return true;
        return containsAny(clean,
                "bunu", "aynısını", "aynisini", "daha basit", "hafiflet", "zorlaştır", "zorlastir",
                "alternatif", "kaydet", "devam", "bir de", "peki", "detaylandır", "detaylandir");
    }

    private String recentConversationText(AiCoachRequest request, int maxTurns) {
        if (request == null || request.conversationHistory == null || request.conversationHistory.isEmpty()) {
            return "";
        }
        int start = Math.max(0, request.conversationHistory.size() - maxTurns);
        StringBuilder sb = new StringBuilder();
        for (int i = start; i < request.conversationHistory.size(); i++) {
            AiCoachRequest.ConversationTurn turn = request.conversationHistory.get(i);
            if (turn == null || turn.content == null || turn.content.isBlank()) continue;
            sb.append(' ').append(turn.content.toLowerCase(Locale.ROOT));
        }
        return sb.toString();
    }

    private boolean hasNutritionQuantity(String text) {
        if (text == null || text.isBlank()) return false;
        String lower = text.toLowerCase(Locale.ROOT);
        return lower.matches(".*\\d+\\s*(g|gr|gram|kg|kcal|kalori|ml|l|litre|adet|porsiyon|kase|bardak|dilim|kaşık|kasik|ölçek|olcek|avuç|avuc).*")
                || containsAny(lower,
                        "bir porsiyon", "yarım porsiyon", "yarim porsiyon",
                        "bir ölçek", "bir olcek", "bir kase", "bir bardak",
                        "bir dilim", "bir avuç", "bir avuc", "bir kaşık", "bir kasik");
    }

    private List<String> safeList(List<String> values) {
        return values == null ? List.of() : values;
    }

    private String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private boolean containsAny(String text, String... needles) {
        if (text == null || text.isBlank()) return false;
        for (String needle : needles) {
            if (needle != null && !needle.isBlank() && text.contains(needle)) {
                return true;
            }
        }
        return false;
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
                    .distinct()
                    .limit(10)
                    .toList();
        }

        if (response.nutritionNote != null) {
            response.nutritionNote = response.nutritionNote.trim();
        }

        if (response.actions != null && !response.actions.isEmpty()) {
            response.actions = response.actions.stream()
                    .filter(action -> action != null && action.type != null && !action.type.isBlank())
                    .filter(this::hasUsefulActionLabel)
                    .filter(distinctAction())
                    .limit(3)
                    .toList();
        }

        if (response.suggestedPrompts != null && !response.suggestedPrompts.isEmpty()) {
            response.suggestedPrompts = response.suggestedPrompts.stream()
                    .filter(prompt -> prompt != null && !prompt.isBlank())
                    .map(String::trim)
                    .distinct()
                    .limit(3)
                    .toList();
        } else {
            response.suggestedPrompts = List.of();
        }
    }

    private boolean hasUsefulActionLabel(AiCoachResponse.AiCoachAction action) {
        if (action.label == null || action.label.isBlank()) {
            action.label = switch (action.type) {
                case "ADD_FOOD" -> "Günlüğe Ekle";
                case "ADD_WATER" -> "Suyu Ekle";
                case "SAVE_WORKOUT", "SAVE_WORKOUT_SESSION" -> "Antrenmanı Kaydet";
                case "CREATE_RECIPE" -> "Tarifi Kaydet";
                case "GENERATE_SHOPPING_LIST" -> "Alışveriş Listesi";
                default -> "Aç";
            };
        }
        action.label = action.label.trim();
        if (action.data != null) {
            action.data = action.data.trim();
        }
        return true;
    }

    private java.util.function.Predicate<AiCoachResponse.AiCoachAction> distinctAction() {
        java.util.Set<String> seen = new java.util.HashSet<>();
        return action -> seen.add(action.type + "|" + nullToEmpty(action.data));
    }

    private String buildVideoAnalysisPrompt() {
        return """
            VISUAL CONTEXT (VIDEO ANALYSIS):
            You are analyzing a workout form video. Your task:
            1. Identify the exercise being performed (squat, deadlift, bench press, etc.)
            2. Analyze movement mechanics, joint angles, and posture
            3. Point out form errors (e.g., knees caving in, lower back rounding, bar path issues)
            4. Provide 3-5 actionable corrections with cues (e.g., "Drive through heels", "Keep chest up")
            5. If the form is correct, praise and suggest progressions

            Use clear, coaching language in Turkish. Be specific and constructive.
            """;
    }

    private String buildImageAnalysisPrompt(AiCoachRequest request) {
        String userQuestion = request.question != null ? request.question.toLowerCase(Locale.ROOT) : "";
        boolean isMealAnalysis = containsAny(userQuestion, NUTRITION_KEYWORDS)
                || containsAny(userQuestion, FOOD_LOG_KEYWORDS)
                || containsAny(userQuestion, RECIPE_SHOPPING_KEYWORDS);

        if (isMealAnalysis) {
            return """
                VISUAL CONTEXT (MEAL ANALYSIS - ENHANCED):
                You are analyzing a food photo. Your task:
                1. **Identify all food items** on the plate/table with high accuracy
                2. **Estimate portion sizes** using visual cues (plate size, hand comparison, packaging)
                   - Small plate (~20cm): standard reference
                   - Medium plate (~25cm): +30% volume
                   - Large plate (~30cm): +60% volume
                3. **Calculate macros** for each item:
                   - Protein (g), Carbs (g), Fat (g), Total Calories (kcal)
                   - Use Turkish nutrition database values
                4. **Provide alternatives** if the user's goal is cut/bulk:
                   - Suggest swaps to increase protein or reduce calories
                   - Keep cultural context (Turkish cuisine preferred)
                5. **Add to daily log suggestion**: If accurate, offer an "ADD_FOOD" action with all items

                IMPORTANT RULES:
                - Be conservative with portions if unsure — better to underestimate than overestimate
                - For mixed dishes (e.g., pilav, içli köfte), break down components
                - Always mention confidence level (e.g., "Yaklaşık 250g tavuk göğsü (~80% emin)")
                - If multiple items, list each separately with individual macros

                Output in Turkish, warm but precise tone.
                """;
        } else {
            // Form check, selfie, or general image
            return """
                VISUAL CONTEXT (IMAGE ANALYSIS - GENERAL):
                You are analyzing a fitness-related image. Determine the content:
                1. **Exercise Form Check**: If showing a workout pose, analyze technique and posture
                2. **Progress Photo**: If a body/mirror selfie, give constructive feedback on visible progress
                3. **Equipment/Supplement**: If showing a product, comment on its relevance to the user's goal
                4. **Other**: Answer the user's question based on what you see

                Use Turkish, be empathetic and evidence-based.
                """;
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
