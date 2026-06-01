package com.fitness.service;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.Map;

import com.fitness.entity.User;

import jakarta.enterprise.context.ApplicationScoped;

/**
 * Bağlamsal farkındalık servisi.
 * Günün saati, gün tipi (hafta içi/sonu), saat dilimi gibi bağlamsal bilgileri sağlar.
 * AI Coach'un daha akıllı öneriler yapmasını sağlar.
 */
@ApplicationScoped
public class ContextualAwarenessService {

    /**
     * AI Coach için bağlamsal bilgi prompt'u oluşturur.
     */
    public String buildContextPrompt(Long userId) {
        User user = User.findById(userId);
        if (user == null) {
            return "";
        }

        LocalDateTime now = LocalDateTime.now();
        TimeContext timeContext = analyzeTimeContext(now);

        StringBuilder context = new StringBuilder();
        context.append("\n## BAGLAMSAL FARKINDALIK\n\n");

        // Zaman bağlamı
        context.append(String.format("**Şu Anki Zaman:** %s, %s\n",
            timeContext.dayType, timeContext.timeOfDay));
        context.append(String.format("**Saat:** %02d:%02d\n", now.getHour(), now.getMinute()));

        // Öneriler
        context.append("\n**AI Koç Talimatları (Zaman Bazlı):**\n");
        context.append(timeContext.coachingGuidance).append("\n");

        return context.toString();
    }

    /**
     * Zaman bağlamını analiz eder.
     */
    private TimeContext analyzeTimeContext(LocalDateTime now) {
        TimeContext ctx = new TimeContext();

        // Gün tipi
        int dayOfWeek = now.getDayOfWeek().getValue();
        ctx.dayType = (dayOfWeek >= 6) ? "Hafta Sonu" : "Hafta İçi";

        // Günün saati
        LocalTime time = now.toLocalTime();
        int hour = time.getHour();

        if (hour >= 5 && hour < 12) {
            ctx.timeOfDay = "Sabah";
            ctx.energyLevel = "YÜKSEK";
            ctx.coachingGuidance = """
                - Sabah enerjisi yüksek olduğu için ağır compound egzersizler önerilebilir (squat, deadlift)
                - Kahvaltı sonrası 1-2 saat beklenmeli antrenman için
                - Motivasyon mesajları enerjik ve pozitif olmalı
                - "Güne mükemmel başlıyorsun!" tarzı
                """;
        } else if (hour >= 12 && hour < 17) {
            ctx.timeOfDay = "Öğleden Sonra";
            ctx.energyLevel = "ORTA";
            ctx.coachingGuidance = """
                - Öğle arası yorgunluğu olabilir, orta yoğunluk egzersizler öner
                - Hafif bir öğle yemeği sonrası kısa antrenman uygun
                - Motivasyon: "Günün en verimli saatleri"
                """;
        } else if (hour >= 17 && hour < 21) {
            ctx.timeOfDay = "Akşam";
            ctx.energyLevel = "YÜKSEK";
            ctx.coachingGuidance = """
                - Akşam 17:00-19:00 arası ideal antrenman saati (vücut sıcaklığı zirve)
                - Yüksek yoğunluk antrenmanlar için en iyi zaman
                - Motivasyon: "İş gününü harika bitir!"
                - Antrenman sonrası protein öğünü hatırlat
                """;
        } else if (hour >= 21 && hour < 24) {
            ctx.timeOfDay = "Gece";
            ctx.energyLevel = "DÜŞÜK";
            ctx.coachingGuidance = """
                - Gece antrenmanı önerilmez (uyku kalitesi bozulabilir)
                - Eğer mutlaka yapacaksa hafif cardio veya yoga öner
                - Ağır ağırlık kaldırma öneri yapma
                - Motivasyon: "Yarın için dinlen, bugün iyi geçti"
                """;
        } else { // 00:00 - 05:00
            ctx.timeOfDay = "Gece Yarısı";
            ctx.energyLevel = "ÇOK DÜŞÜK";
            ctx.coachingGuidance = """
                - Antrenman önerme, uyku zamanı
                - "Şu an dinlenme zamanı, yarın güçlü başlayacaksın" mesajı ver
                - Beslenme değil, uyku kalitesi hakkında konuş
                """;
        }

        // Hafta sonu ekstra bağlam
        if (ctx.dayType.equals("Hafta Sonu")) {
            ctx.coachingGuidance += "\n- Hafta sonu olduğu için daha uzun antrenman seansları önerilebilir\n";
            ctx.coachingGuidance += "- Kullanıcı daha esnek olabilir, farklı egzersizler dene\n";
        } else {
            ctx.coachingGuidance += "\n- Hafta içi yoğunluğu göz önünde bulundur, kısa ve etkili öneriler yap\n";
        }

        return ctx;
    }

    /**
     * Kullanıcının mevcut durumuna göre öneri tipi belirler.
     */
    public SuggestionType getSuggestionType(Long userId) {
        LocalDateTime now = LocalDateTime.now();
        int hour = now.getHour();

        if (hour >= 6 && hour < 10) {
            return SuggestionType.MORNING_ROUTINE;
        } else if (hour >= 10 && hour < 12) {
            return SuggestionType.PRE_LUNCH;
        } else if (hour >= 12 && hour < 14) {
            return SuggestionType.LUNCH_TIME;
        } else if (hour >= 14 && hour < 17) {
            return SuggestionType.AFTERNOON_SLUMP;
        } else if (hour >= 17 && hour < 20) {
            return SuggestionType.EVENING_WORKOUT;
        } else if (hour >= 20 && hour < 23) {
            return SuggestionType.EVENING_WRAP_UP;
        } else {
            return SuggestionType.NIGHT_REST;
        }
    }

    /**
     * Bağlamsal bilgileri map olarak döndürür (frontend için).
     */
    public Map<String, Object> getContextMap(Long userId) {
        LocalDateTime now = LocalDateTime.now();
        TimeContext ctx = analyzeTimeContext(now);

        Map<String, Object> map = new HashMap<>();
        map.put("dayType", ctx.dayType);
        map.put("timeOfDay", ctx.timeOfDay);
        map.put("energyLevel", ctx.energyLevel);
        map.put("hour", now.getHour());
        map.put("suggestionType", getSuggestionType(userId).name());

        return map;
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────────

    private static class TimeContext {
        String dayType; // "Hafta İçi" | "Hafta Sonu"
        String timeOfDay; // "Sabah" | "Öğleden Sonra" | "Akşam" | "Gece"
        String energyLevel; // "YÜKSEK" | "ORTA" | "DÜŞÜK" | "ÇOK DÜŞÜK"
        String coachingGuidance;
    }

    public enum SuggestionType {
        MORNING_ROUTINE,    // Sabah rutini
        PRE_LUNCH,          // Öğle öncesi
        LUNCH_TIME,         // Öğle zamanı
        AFTERNOON_SLUMP,    // Öğleden sonra yorgunluğu
        EVENING_WORKOUT,    // Akşam antrenmanı
        EVENING_WRAP_UP,    // Akşam kapanış
        NIGHT_REST          // Gece dinlenme
    }
}
