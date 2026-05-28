package com.fitness.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fitness.dto.AiFeedbackRequest;
import com.fitness.entity.AiFeedback;
import com.fitness.entity.User;
import com.fitness.repository.AiFeedbackRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class AiFeedbackService {

    @Inject
    AiFeedbackRepository feedbackRepository;

    @Inject
    ObjectMapper objectMapper;

    @Inject
    SemanticMemoryService semanticMemoryService;

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
        feedback.userQuestion = trim(request.userQuestion, 500);
        feedback.reason = trim(request.reason, 64);
        feedback.coachingPreference = trim(request.coachingPreference, 500);
        feedback.createdAt = LocalDateTime.now();
        feedbackRepository.persist(feedback);

        String memoryFact = buildMemoryFact(feedback);
        if (!memoryFact.isBlank()) {
            semanticMemoryService.savePreference(userId, memoryFact);
            appendAiMemorySummary(userId, memoryFact);
        }
    }

    /**
     * Returns a prompt-ready memory block describing the user's preferred
     * response style, derived from their recent positive feedback.
     * Returns empty string if no feedback exists.
     */
    public String buildFeedbackMemory(Long userId) {
        if (userId == null) return "";

        List<AiFeedback> positive = feedbackRepository.findRecentPositive(userId, 3);
        List<AiFeedback> negative = feedbackRepository.findRecentNegative(userId, 3);
        List<AiFeedback> recent = feedbackRepository.findRecentByUser(userId, 8);

        if (positive.isEmpty() && negative.isEmpty()) return "";

        StringBuilder sb = new StringBuilder("--- USER FEEDBACK MEMORY ---\n");
        sb.append("Use this to adapt like a real coach. Do not mention that feedback data exists.\n");

        List<String> preferences = recent.stream()
                .map(this::preferenceLine)
                .filter(line -> line != null && !line.isBlank())
                .distinct()
                .limit(5)
                .collect(Collectors.toList());
        if (!preferences.isEmpty()) {
            sb.append("Coaching preferences inferred from feedback:\n");
            preferences.forEach(line -> sb.append("- ").append(line).append("\n"));
        }

        if (!positive.isEmpty()) {
            sb.append("Responses the user previously LIKED (emulate this style/depth):\n");
            positive.stream()
                    .map(f -> trimSnippet(f.aiResponse, 140))
                    .forEach(snippet -> sb.append("+ ").append(snippet).append("\n"));
        }

        if (!negative.isEmpty()) {
            sb.append("Responses the user previously DISLIKED (avoid this style/content):\n");
            negative.stream()
                    .map(f -> trimSnippet(f.aiResponse, 140))
                    .forEach(snippet -> sb.append("- ").append(snippet).append("\n"));
        }

        return sb.toString().trim();
    }

    private String buildMemoryFact(AiFeedback feedback) {
        String preference = preferenceLine(feedback);
        if (preference == null || preference.isBlank()) return "";
        return "AI koç tercihi: " + preference;
    }

    private String preferenceLine(AiFeedback f) {
        if (f == null) return "";
        String reason = f.reason == null ? "" : f.reason.trim();
        String explicit = f.coachingPreference == null ? "" : f.coachingPreference.trim();
        if (!explicit.isBlank()) return explicit;

        if ("POSITIVE".equals(f.reaction)) {
            if ("practical".equals(reason)) return "Kullanıcı pratik ve uygulanabilir adımları seviyor.";
            if ("clear".equals(reason)) return "Kullanıcı net, kısa ve doğrudan cevapları seviyor.";
            if ("personal".equals(reason)) return "Kullanıcı kişisel verilerine bağlanan koçluğu seviyor.";
            return "Kullanıcı bu yanıt stilini faydalı buldu; benzer derinlik ve tonda cevap ver.";
        }

        if ("too_generic".equals(reason)) return "Ezbere/generic cevaplardan kaçın; kullanıcının verisine ve son mesajına özel konuş.";
        if ("too_long".equals(reason)) return "Cevapları daha kısa, taranabilir ve yoğun yaz.";
        if ("too_hard".equals(reason)) return "Önerileri daha kolay ve sürdürülebilir seviyeye indir.";
        if ("not_actionable".equals(reason)) return "Her yanıtta yapılabilir somut bir sonraki adım ver.";
        return "Kullanıcı bu yanıtı yeterince faydalı bulmadı; daha kişisel, net ve uygulanabilir cevap ver.";
    }

    private void appendAiMemorySummary(Long userId, String fact) {
        try {
            User user = User.findById(userId);
            if (user == null) return;

            ArrayNode facts;
            if (user.aiMemorySummary != null && !user.aiMemorySummary.isBlank()) {
                JsonNode decoded = objectMapper.readTree(user.aiMemorySummary);
                facts = decoded.isArray() ? (ArrayNode) decoded : objectMapper.createArrayNode();
            } else {
                facts = objectMapper.createArrayNode();
            }

            for (JsonNode item : facts) {
                if (fact.equals(item.path("fact").asText())) return;
            }

            ObjectNode entry = objectMapper.createObjectNode();
            entry.put("category", "feedback");
            entry.put("fact", fact);
            entry.put("savedAt", LocalDateTime.now().toString());
            facts.insert(0, entry);
            while (facts.size() > 30) {
                facts.remove(facts.size() - 1);
            }
            user.aiMemorySummary = objectMapper.writeValueAsString(facts);
            user.persist();
        } catch (Exception ignored) {
        }
    }

    private String trimSnippet(String text, int maxChars) {
        if (text == null) return "";
        String clean = text.replaceAll("\\s+", " ").trim();
        return clean.length() <= maxChars ? clean : clean.substring(0, maxChars) + "…";
    }

    private String trim(String text, int maxChars) {
        if (text == null) return null;
        String clean = text.replaceAll("\\s+", " ").trim();
        if (clean.isBlank()) return null;
        return clean.length() <= maxChars ? clean : clean.substring(0, maxChars);
    }
}
