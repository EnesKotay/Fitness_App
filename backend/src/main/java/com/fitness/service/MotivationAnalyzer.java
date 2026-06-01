package com.fitness.service;

import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;
import java.util.Locale;

/**
 * Kullanıcının mesajlarını analiz ederek duygusal durumunu (motivasyon düşüklüğü,
 * yorgunluk, stres) tespit eder ve koça özel talimat ekler.
 */
@ApplicationScoped
public class MotivationAnalyzer {

    // Düşük motivasyon sinyalleri
    private static final List<String> LOW_MOTIVATION_SIGNALS = List.of(
        "yapmak istemiyorum", "üşeniyorum", "motivasyonum yok", "pes etmek",
        "bırakmak istiyorum", "yapamıyorum", "zor geliyor", "yorgunum",
        "baş edemiyorum", "sıkıldım", "dayanamıyorum", "yine başaramadım"
    );

    // Stres/endişe sinyalleri
    private static final List<String> STRESS_SIGNALS = List.of(
        "stres", "endişe", "kaygı", "başım dönüyor", "aşırı yüklenme",
        "çok fazla", "kaldıramıyorum", "bunaldım", "ağrıyor", "sancı"
    );

    // Hayal kırıklığı/platoda kalma sinyalleri
    private static final List<String> PLATEAU_SIGNALS = List.of(
        "değişim yok", "ilerleme göremiyorum", "kilo vermiyor", "aynı",
        "sonuç yok", "fayda etmiyor", "boşa mı", "platoda", "duruyor"
    );

    // Aşırı hırs/burnout riski
    private static final List<String> BURNOUT_SIGNALS = List.of(
        "her gün", "aralıksız", "dinlenme yok", "tüketiyorum", "acı çekiyorum",
        "çok ağrısı", "dayanmam lazım", "extreme", "maksimum", "sert program"
    );

    /**
     * Kullanıcının sorusunu ve son mesaj geçmişini analiz eder.
     * Düşük motivasyon, stres, platoda kalma veya burnout riski varsa
     * koça ekstra talimat döner.
     */
    public String analyzeAndProvideGuidance(String userQuestion, List<String> recentMessages) {
        if (userQuestion == null || userQuestion.isBlank()) {
            return "";
        }

        String lowerQuestion = userQuestion.toLowerCase(Locale.forLanguageTag("tr"));
        StringBuilder guidance = new StringBuilder();

        // 1. Düşük Motivasyon
        if (containsAny(lowerQuestion, LOW_MOTIVATION_SIGNALS)) {
            guidance.append("""
                --- MOTIVATION CRISIS DETECTED ---
                The user is expressing low motivation or fatigue. Your response strategy:
                - DO NOT pile on guilt or "you should do better" language
                - Acknowledge their feeling: "Tamam, bugün kendin gibi hissetmiyorsun — bu normal."
                - Offer the SMALLEST possible action (e.g., "Sadece 5 dakika yürüyüş yap ve bana haber ver")
                - Frame it as a reset, not a test
                - End with: "Bugün sadece bu kadar yeterli. Yarın daha güçlü olacaksın."
                """);
        }

        // 2. Stres/Endişe
        if (containsAny(lowerQuestion, STRESS_SIGNALS)) {
            guidance.append("""
                --- STRESS/ANXIETY DETECTED ---
                The user is showing signs of stress or physical discomfort.
                - Check if they mention pain (ağrı, sancı) — if yes, advise rest + seeing a professional if it persists
                - Suggest stress-relief tactics: 10 min walk, breathing exercise, light stretching
                - Lower intensity recommendations today
                - Prioritize sleep and hydration in your answer
                """);
        }

        // 3. Platoda Kalma (Hayal Kırıklığı)
        if (containsAny(lowerQuestion, PLATEAU_SIGNALS)) {
            guidance.append("""
                --- PLATEAU FRUSTRATION DETECTED ---
                The user feels stuck or isn't seeing progress.
                - Validate: "Platoda kalmak en sinir bozucu şey, ama bu geçici."
                - Explain 2-3 physiological reasons (water retention, muscle gain masking fat loss, adaptive thermogenesis)
                - Suggest ONE small change (e.g., increase steps by 1000/day, or add 10g protein)
                - Emphasize non-scale victories (uyku kalitesi, enerji seviyesi, kıyafet fit)
                - DO NOT suggest drastic calorie cuts — that's a red flag for metabolic slowdown
                """);
        }

        // 4. Burnout Riski (Aşırı Hırs)
        if (containsAny(lowerQuestion, BURNOUT_SIGNALS)) {
            guidance.append("""
                --- BURNOUT RISK DETECTED ---
                The user may be overtraining or pushing too hard without recovery.
                - RED FLAG: If they're training 7 days/week with no rest, strongly recommend at least 1 full rest day
                - Explain the concept of "supercompensation" — gains happen during rest, not during the workout
                - If they mention pain, advise deload week (50% volume/intensity)
                - Tone: firm but caring — "Daha fazla yapmak her zaman daha iyi değildir. Şimdi dinlenirsen, önümüzdeki hafta daha güçlü olacaksın."
                """);
        }

        // 5. Geçmiş Mesaj Analizi (Trend Tespiti)
        if (recentMessages != null && recentMessages.size() >= 3) {
            int negativeCount = 0;
            for (String msg : recentMessages) {
                String lower = msg.toLowerCase(Locale.forLanguageTag("tr"));
                if (containsAny(lower, LOW_MOTIVATION_SIGNALS) ||
                    containsAny(lower, STRESS_SIGNALS) ||
                    containsAny(lower, PLATEAU_SIGNALS)) {
                    negativeCount++;
                }
            }

            if (negativeCount >= 2) {
                guidance.append("""
                    --- RECURRING NEGATIVE PATTERN ---
                    The user has expressed frustration/low motivation in multiple recent messages.
                    - This is a sign of burnout or unrealistic expectations
                    - Suggest a conversation about adjusting their goal (e.g., from aggressive cut to maintenance for 2 weeks)
                    - Offer: "Belki biraz hızımızı düşürüp sürdürülebilir bir tempo tutabiliriz. Bu maraton, sprint değil."
                    - DO NOT just give another workout plan — address the root cause
                    """);
            }
        }

        return guidance.toString().trim();
    }

    /**
     * Pozitif sinyaller (başarı, motivasyon yüksek) tespit eder.
     * Koç tebrik edip momentum kazandırmak için kullanabilir.
     */
    public boolean detectPositiveMomentum(String userQuestion) {
        if (userQuestion == null || userQuestion.isBlank()) {
            return false;
        }

        String lower = userQuestion.toLowerCase(Locale.forLanguageTag("tr"));
        List<String> positiveSignals = List.of(
            "başardım", "rekor kırdım", "kilo verdim", "form gelişti",
            "bugün harikayım", "enerjim çok iyi", "mutluyum", "hedefe ulaştım",
            "ilk defa", "en iyi", "artık daha kolay"
        );

        return containsAny(lower, positiveSignals);
    }

    private boolean containsAny(String text, List<String> keywords) {
        for (String keyword : keywords) {
            if (text.contains(keyword)) {
                return true;
            }
        }
        return false;
    }
}
