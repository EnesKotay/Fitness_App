package com.fitness.service;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.jboss.logging.Logger;

import com.fitness.entity.AiInsight;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

/**
 * Semantic Memory Service — provides a lightweight RAG (Retrieval-Augmented Generation)
 * system built on top of existing AiInsight records.
 *
 * <p>Since pgvector/embedding infrastructure is not yet available, this service uses
 * keyword-based relevance scoring to retrieve the most relevant long-term memories
 * for a given user query. When proper vector embeddings are added later, only
 * {@link #findRelevantMemories} needs to be swapped out.</p>
 *
 * <p>Memory types supported:
 * <ul>
 *   <li>SEMANTIC_MEMORY — facts the AI explicitly saved (injuries, preferences, goals)</li>
 *   <li>WEEKLY_PROGRESS — auto-generated weekly summaries</li>
 *   <li>USER_PREFERENCE — explicit likes/dislikes</li>
 * </ul>
 */
@ApplicationScoped
public class SemanticMemoryService {

    private static final Logger LOG = Logger.getLogger(SemanticMemoryService.class);
    private static final int MAX_MEMORIES_IN_CONTEXT = 4;

    @Inject
    AiProviderRouter aiRouter;

    // ─── RAG retrieval ──────────────────────────────────────────────────────

    /**
     * Finds the most relevant memories for a given user query using keyword
     * relevance scoring. Returns a formatted string ready to be injected
     * into the AI coach prompt.
     */
    public String buildRelevantMemoryBlock(Long userId, String query) {
        if (userId == null || query == null || query.isBlank()) return "";
        try {
            List<AiInsight> allMemories = findAllMemories(userId);
            if (allMemories.isEmpty()) return "";

            String queryLower = query.toLowerCase();
            List<ScoredMemory> scored = allMemories.stream()
                .map(m -> new ScoredMemory(m, score(m.summary, queryLower)))
                .filter(sm -> sm.score > 0)
                .sorted((a, b) -> Double.compare(b.score, a.score))
                .limit(MAX_MEMORIES_IN_CONTEXT)
                .collect(Collectors.toList());

            if (scored.isEmpty()) {
                // Fallback: return most recent memories even if not query-relevant
                return allMemories.stream()
                    .limit(2)
                    .map(m -> "- " + m.summary.trim())
                    .collect(Collectors.joining("\n"));
            }

            return scored.stream()
                .map(sm -> "- [" + labelFor(sm.memory.type) + "] " + sm.memory.summary.trim())
                .collect(Collectors.joining("\n"));

        } catch (Exception e) {
            LOG.warnf("SemanticMemoryService.buildRelevantMemoryBlock failed userId=%d: %s", userId, e.getMessage());
            return "";
        }
    }

    /**
     * Save a new semantic memory fact (called when AI uses the saveUserMemory function).
     * Deduplicates by checking if a nearly identical fact already exists.
     */
    @Transactional
    public void saveMemory(Long userId, String fact, String type) {
        if (userId == null || fact == null || fact.isBlank()) return;
        com.fitness.entity.User user = com.fitness.entity.User.findById(userId);
        if (user == null) return;

        // Deduplication: skip if same core fact already exists
        List<AiInsight> recent = findAllMemories(userId);
        String factLower = fact.toLowerCase();
        boolean duplicate = recent.stream().anyMatch(m ->
            m.summary != null && similarity(m.summary.toLowerCase(), factLower) > 0.7
        );
        if (duplicate) {
            LOG.infof("SemanticMemory: duplicate fact skipped userId=%d", userId);
            return;
        }

        AiInsight memory = new AiInsight();
        memory.user = user;
        memory.type = type != null ? type : "SEMANTIC_MEMORY";
        memory.summary = fact.trim();
        memory.persist();
        LOG.infof("SemanticMemory: saved userId=%d type=%s", userId, memory.type);
    }

    /**
     * Save a user preference (food like/dislike, training preference etc.).
     */
    @Transactional
    public void savePreference(Long userId, String preference) {
        saveMemory(userId, preference, "USER_PREFERENCE");
    }

    // ─── Retrieval internals ────────────────────────────────────────────────

    @Transactional
    public List<AiInsight> findAllMemories(Long userId) {
        return AiInsight
            .find("user.id = ?1 order by createdAt desc", userId)
            .range(0, 29)
            .list();
    }

    /**
     * Keyword relevance score between a memory summary and a user query.
     * Higher is more relevant. Returns 0 if no overlap.
     */
    private double score(String memorySummary, String queryLower) {
        if (memorySummary == null || memorySummary.isBlank()) return 0;
        String memLower = memorySummary.toLowerCase();

        // Domain keyword groups — each group is a semantic cluster
        String[][] clusters = {
            {"protein", "protein", "bcaa", "kreatin", "supplement", "ek", "takviye"},
            {"kilo", "ağırlık", "weight", "bmi", "obez", "zayıf"},
            {"antrenman", "egzersiz", "spor", "workout", "gym", "squat", "deadlift", "bench"},
            {"sakatlık", "yaralanma", "ağrı", "injury", "fıtık", "diz", "omuz", "sırt"},
            {"kalori", "diyet", "öğün", "beslenme", "yemek", "kahvaltı", "nutrition"},
            {"uyku", "toparlanma", "dinlenme", "recovery", "sleep"},
            {"kardio", "koşu", "yürüyüş", "bisiklet", "cardio", "step"},
            {"su", "hydration", "sıvı", "water"},
            {"hedef", "goal", "target", "ideal"},
        };

        double totalScore = 0;
        for (String[] cluster : clusters) {
            boolean inQuery = false;
            boolean inMemory = false;
            for (String kw : cluster) {
                if (queryLower.contains(kw)) inQuery = true;
                if (memLower.contains(kw)) inMemory = true;
            }
            if (inQuery && inMemory) totalScore += 1.0;
        }

        // Boost SEMANTIC_MEMORY (explicit facts) and USER_PREFERENCE
        return totalScore;
    }

    /**
     * Simple Jaccard-like similarity on word sets to detect near-duplicate facts.
     */
    private double similarity(String a, String b) {
        String[] wordsA = a.split("\\s+");
        String[] wordsB = b.split("\\s+");
        java.util.Set<String> setA = new java.util.HashSet<>(java.util.Arrays.asList(wordsA));
        java.util.Set<String> setB = new java.util.HashSet<>(java.util.Arrays.asList(wordsB));
        java.util.Set<String> intersection = new java.util.HashSet<>(setA);
        intersection.retainAll(setB);
        java.util.Set<String> union = new java.util.HashSet<>(setA);
        union.addAll(setB);
        return union.isEmpty() ? 0 : (double) intersection.size() / union.size();
    }

    private String labelFor(String type) {
        if (type == null) return "Hafıza";
        return switch (type) {
            case "SEMANTIC_MEMORY" -> "Kalıcı Hafıza";
            case "WEEKLY_PROGRESS" -> "Haftalık Özet";
            case "USER_PREFERENCE" -> "Tercih";
            default -> "Hafıza";
        };
    }

    // ─── Inner types ────────────────────────────────────────────────────────

    private static class ScoredMemory {
        final AiInsight memory;
        final double score;
        ScoredMemory(AiInsight m, double s) { this.memory = m; this.score = s; }
    }
}
