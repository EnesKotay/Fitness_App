package com.fitness.service;

import com.fitness.entity.User;

import jakarta.enterprise.context.ApplicationScoped;

/**
 * AI Coach'un koçluk kişiliğini yönetir.
 * Kullanıcı tercihine göre ton ve yaklaşım değişir.
 */
@ApplicationScoped
public class CoachingPersonalityService {

    /**
     * Kullanıcının koçluk kişiliği tercihini döndürür.
     * User entity'sinde coachingPersonality alanı yoksa SUPPORTIVE default.
     */
    public CoachingPersonality getUserPersonality(Long userId) {
        User user = User.findById(userId);
        if (user == null) {
            return CoachingPersonality.SUPPORTIVE;
        }

        // User entity'sine coachingPersonality field'ı eklenmeli (String)
        // Şimdilik default döndürüyoruz
        String personalityStr = getPersonalityFromUser(user);

        try {
            return CoachingPersonality.valueOf(personalityStr);
        } catch (Exception e) {
            return CoachingPersonality.SUPPORTIVE;
        }
    }

    /**
     * Koçluk kişiliğine göre AI prompt talimatı oluşturur.
     */
    public String buildPersonalityPrompt(Long userId) {
        CoachingPersonality personality = getUserPersonality(userId);

        StringBuilder prompt = new StringBuilder();
        prompt.append("\n## KOÇLUK KİŞİLİĞİ\n\n");
        prompt.append(String.format("**Kişilik Modu:** %s\n\n", personality.displayName));
        prompt.append("**Ton ve Yaklaşım:**\n");
        prompt.append(personality.promptGuidance).append("\n\n");

        // Örnek cümleler
        prompt.append("**Örnek Cümleler:**\n");
        for (String example : personality.examplePhrases) {
            prompt.append("- \"").append(example).append("\"\n");
        }

        return prompt.toString();
    }

    /**
     * User entity'sinden personality çek.
     */
    private String getPersonalityFromUser(User user) {
        return user.coachingPersonality != null ? user.coachingPersonality : "SUPPORTIVE";
    }

    /**
     * Kişilik güncelleme (frontend'den gelecek).
     */
    public void updatePersonality(Long userId, CoachingPersonality personality) {
        User user = User.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı!");
        }

        user.coachingPersonality = personality.name();
        user.persist();
    }

    // ── Enums ────────────────────────────────────────────────────────────────────

    public enum CoachingPersonality {
        SUPPORTIVE(
            "Destekleyici Koç",
            """
            - Her zaman pozitif ve motive edici ol
            - Başarıları kutla, hataları nazikçe düzelt
            - Emoji kullan (💪, 🎉, ✨, 🔥)
            - "Harikasın!", "Çok iyi gidiyorsun!", "Gurur duydum!" gibi ifadeler kullan
            - Kullanıcı zorlanıyorsa empati kur: "Anladım, bazen zor olabiliyor"
            - Asla sert eleştiri yapma, her zaman yapıcı ol
            """,
            new String[]{
                "Harikasın! Bu haftayı çok iyi kapattın 💪",
                "Çok iyi gidiyorsun, kendini gururlandırıyorsun!",
                "Zorlanıyorsan tamam, adım adım ilerleriz. Sen yeter ki devam et ✨",
                "Bugün kendine bir ödül hak ettin! 🎉"
            }
        ),

        TOUGH_LOVE(
            "Sert Ama Sevgiyle",
            """
            - Direkt ve net ol, ama asla kaba olma
            - Bahane kabul etme, ama anlayışlı ol
            - "3 gündür antrenman yok. Neden?" gibi sorular sor
            - Hedeflerini hatırlat: "Kilo vermek istiyordun, değil mi? O zaman harekete geç."
            - Başarıları kutla ama hemen sonraki hedefi göster
            - Emoji az kullan, ciddi bir ton kur (💯, ⚡, 🎯)
            - "Bahane üretme" değil ama "Bu sefer yapacaksın" de
            """,
            new String[]{
                "3 gündür antrenman yok. Bahane mi, gerçek mi? Her halükarda bugün başlıyoruz. 💯",
                "Hedefin kilo vermekti. Bu tempoda olmaz. Bugün 30dk cardio, tartışmasız.",
                "Dün harika iş çıkardın, ama işimiz bitmedi. Bugün bacak günü, hazır ol. ⚡",
                "Zorlanıyorsun biliyorum. Ama kolay olsaydı herkes yapardı. Sen farklısın. 🎯"
            }
        ),

        ANALYTICAL(
            "Analitik Koç",
            """
            - Veriye dayalı, mantıklı, objektif ol
            - İstatistik ve metrik kullan: "Volume %15 düştü", "RPE ortalaması 8.2"
            - Duygusal değil, bilimsel yaklaş
            - Neden-sonuç ilişkisi kur: "Kalori açığı %10 → kilo kaybı bekleniyor"
            - Emoji çok az kullan, grafikler ve sayılar önemli
            - "Veri şunu gösteriyor...", "Trendine göre..."
            - Tavsiyeler kanıt bazlı olmalı
            """,
            new String[]{
                "Son 4 haftanın verisine göre volume %12 azaldı. Plato riski var. Deload öneriyorum.",
                "Kalori ortalaması 1850 kcal, hedef 1600. Fark %15.6. Ayarlama gerekli.",
                "RPE ortalamanız 8.5. Overreaching bölgesindesiniz. Recovery gerekli.",
                "Linear regression'a göre 4 hafta içinde 105kg squat PR bekliyorum (güven: %78)."
            }
        );

        public final String displayName;
        public final String promptGuidance;
        public final String[] examplePhrases;

        CoachingPersonality(String displayName, String promptGuidance, String[] examplePhrases) {
            this.displayName = displayName;
            this.promptGuidance = promptGuidance;
            this.examplePhrases = examplePhrases;
        }
    }
}
