package com.fitness.service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

import org.jboss.logging.Logger;

import com.fitness.entity.User;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Video tabanlı form analizi servisi.
 * Gemini Vision API kullanarak kullanıcının egzersiz formunu analiz eder.
 */
@ApplicationScoped
public class FormCheckService {

    private static final Logger LOG = Logger.getLogger(FormCheckService.class);

    @Inject
    AiProviderRouter aiProviderRouter;

    /**
     * Video dosyasından form analizi yapar.
     *
     * @param userId Kullanıcı ID
     * @param videoPath Video dosya yolu (geçici upload klasöründe)
     * @param exerciseName Egzersiz adı (örn: "Squat", "Bench Press")
     * @return Form analizi sonucu (güçlü yanlar, zayıf yanlar, öneriler)
     */
    public FormCheckResult analyzeForm(Long userId, Path videoPath, String exerciseName) throws IOException {
        User user = User.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı!");
        }

        if (!Files.exists(videoPath)) {
            throw new RuntimeException("Video dosyası bulunamadı!");
        }

        // Video'yu byte olarak al
        byte[] videoBytes = Files.readAllBytes(videoPath);

        // Form analizi promptu oluştur
        String prompt = buildFormAnalysisPrompt(exerciseName, user);

        // Gemini Vision API'ye gönder (Video da generateWithImage üzerinden işlenebilir)
        GeminiClientResult result = aiProviderRouter.generateWithImage(
            "form-check-video",
            userId,
            "gemini-1.5-pro",
            "gemini-1.5-flash",
            prompt,
            videoBytes,
            getMimeType(videoPath),
            false
        );

        if (!result.isSuccess()) {
            throw new RuntimeException("Form analizi başarısız: " + result.getError());
        }

        // Yanıtı parse et
        return parseFormAnalysisResponse(result.getOutputText(), exerciseName);
    }

    /**
     * Görsel (fotoğraf) tabanlı form analizi.
     */
    public FormCheckResult analyzeFormFromImage(Long userId, Path imagePath, String exerciseName) throws IOException {
        User user = User.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı!");
        }

        if (!Files.exists(imagePath)) {
            throw new RuntimeException("Görsel dosyası bulunamadı!");
        }

        // Görseli byte olarak al
        byte[] imageBytes = Files.readAllBytes(imagePath);

        // Form analizi promptu oluştur
        String prompt = buildFormAnalysisPrompt(exerciseName, user);

        // Gemini Vision API'ye gönder
        GeminiClientResult result = aiProviderRouter.generateWithImage(
            "form-check-image",
            userId,
            "gemini-1.5-pro",
            "gemini-1.5-flash",
            prompt,
            imageBytes,
            getMimeType(imagePath),
            false
        );

        if (!result.isSuccess()) {
            throw new RuntimeException("Form analizi başarısız: " + result.getError());
        }

        // Yanıtı parse et
        return parseFormAnalysisResponse(result.getOutputText(), exerciseName);
    }

    /**
     * Form analizi promptu oluşturur.
     */
    private String buildFormAnalysisPrompt(String exerciseName, User user) {
        StringBuilder prompt = new StringBuilder();

        prompt.append("Sen bir profesyonel kuvvet ve kondisyon koçusun. ");
        prompt.append("Video/görseldeki egzersiz formunu detaylı analiz et.\n\n");

        prompt.append(String.format("**Egzersiz:** %s\n\n", exerciseName));

        prompt.append("## ANALİZ KRİTERLERİ\n\n");
        prompt.append("Aşağıdaki kriterlere göre formu değerlendir:\n\n");

        // Egzersiz tipine göre özel kriterler
        prompt.append(getExerciseSpecificCriteria(exerciseName));

        prompt.append("\n## BEKLENEN ÇIKTI FORMATI\n\n");
        prompt.append("Türkçe olarak şu formatta yanıt ver:\n\n");
        prompt.append("```\n");
        prompt.append("## Form Değerlendirmesi\n");
        prompt.append("**Genel Puan:** [1-10 arası puan]\n\n");
        prompt.append("### ✅ Güçlü Yanlar\n");
        prompt.append("- [İyi yapılan nokta 1]\n");
        prompt.append("- [İyi yapılan nokta 2]\n\n");
        prompt.append("### ⚠️ Geliştirilmesi Gerekenler\n");
        prompt.append("- [Hatalı nokta 1 + nasıl düzeltilir]\n");
        prompt.append("- [Hatalı nokta 2 + nasıl düzeltilir]\n\n");
        prompt.append("### 💡 Öneriler\n");
        prompt.append("- [Öneri 1]\n");
        prompt.append("- [Öneri 2]\n\n");
        prompt.append("### 🎯 Sonraki Adımlar\n");
        prompt.append("- [Kısa vadeli hedef]\n");
        prompt.append("- [Uzun vadeli hedef]\n");
        prompt.append("```\n\n");

        prompt.append("**ÖNEMLI:**\n");
        prompt.append("- Sakatlık riski varsa açıkça belirt\n");
        prompt.append("- Teknik terimleri Türkçe + İngilizce parantez içinde yaz\n");
        prompt.append("- Somut, uygulanabilir öneriler ver (\"daha iyi yap\" değil, \"dirsekleri 45° açıda tut\" gibi)\n");
        prompt.append("- Pozitif ve motive edici ol, ama hataları net belirt\n\n");

        return prompt.toString();
    }

    /**
     * Egzersiz tipine özel analiz kriterlerini döndürür.
     */
    private String getExerciseSpecificCriteria(String exerciseName) {
        String lower = exerciseName.toLowerCase();

        if (lower.contains("squat") || lower.contains("çömelme")) {
            return """
                ### Squat Form Kriterleri:
                1. **Başlangıç Pozisyonu:**
                   - Ayak genişliği (omuz hizası veya biraz daha geniş)
                   - Ayak açısı (0-30° dışa açık)
                   - Bar yerleşimi (high bar vs low bar)
                   - Sırt duruşu (nötr omurga)

                2. **İniş Fazı (Eccentric):**
                   - Diz açısı ve diz ilerlemesi (ayak parmağı hizasını geçmemeli)
                   - Kalça katlanması (hip hinge)
                   - Sırt açısı (dik veya hafif öne eğik)
                   - Depth (paralel altı, ATG, veya yüksek)
                   - Topuk yere basıyor mu?

                3. **En Alt Nokta (Bottom Position):**
                   - Omurga nötr mi? (butt wink var mı?)
                   - Dizler içe kaçıyor mu? (valgus collapse)
                   - Denge merkezinde mi?

                4. **Çıkış Fazı (Concentric):**
                   - Kalça ve diz aynı anda mı açılıyor?
                   - Bar yolu dikey mi?
                   - Üst sırt gerilimi korunuyor mu?

                5. **Genel:**
                   - Tempo (kontrollü mü?)
                   - Nefes tekniği (Valsalva)
                   - Güvenlik (sakatlık riski)
                """;
        } else if (lower.contains("bench") || lower.contains("press") && lower.contains("göğüs")) {
            return """
                ### Bench Press Form Kriterleri:
                1. **Kurulum:**
                   - Göz pozisyonu (bar altında)
                   - Kürek kemikleri sıkıştırılmış mı? (scapular retraction)
                   - Sırt arkı (arch) var mı?
                   - Ayaklar yere sabitlenmiş mi?

                2. **Bar Yolu:**
                   - İniş açısı (göğüs orta hattına doğru)
                   - Touch point (sternum veya alt göğüs)
                   - Çıkış yolu (hafif arkaya doğru)

                3. **Dirsek Pozisyonu:**
                   - Dirsek açısı (45-75° arası, vücuda çok yakın veya çok açık olmamalı)
                   - Forearm dikey mi? (en verimli güç aktarımı)

                4. **Tempo ve Kontrol:**
                   - İniş kontrollü mü?
                   - Pause var mı? (powerlifting için gerekli)
                   - Çıkış explosive mı?

                5. **Güvenlik:**
                   - Omuz sağlığı (impingement riski)
                   - Bilek açısı (nötr)
                   - Spotter var mı? (gerekiyorsa)
                """;
        } else if (lower.contains("deadlift") || lower.contains("ölü kaldırış")) {
            return """
                ### Deadlift Form Kriterleri:
                1. **Başlangıç Pozisyonu:**
                   - Ayak genişliği (kalça hizası)
                   - Bar pozisyonu (ayak orta hattı üzerinde)
                   - Kalça yüksekliği (omuz-kalça-bar hizası)
                   - Sırt düzlüğü (nötr omurga, lumbar extension)

                2. **Kaldırış (Pull):**
                   - Bacaklar önce mi itiyor? (leg drive)
                   - Bar vücuda yakın mı?
                   - Sırt açısı sabit mi? (hips shooting up önlenmeli)
                   - Omuzlar bar önünde mi?

                3. **Lockout:**
                   - Kalça tam extension'a mı geliyor?
                   - Hiperextension var mı? (sakatlık riski)
                   - Omuzlar geriye çekilmiş mi?

                4. **İniş (Eccentric):**
                   - Kontrollü mü?
                   - Bar yolu aynı mı?
                   - Sırt nötr mi?

                5. **Güvenlik:**
                   - Lumbar flexion (rounded back) var mı? → SAKATLIKA RİSKİ
                   - Grip güvenli mi?
                   - Boyun pozisyonu nötr mi?
                """;
        } else {
            // Genel egzersiz kriterleri
            return """
                ### Genel Form Kriterleri:
                1. **Başlangıç Pozisyonu:**
                   - Duruş ve denge
                   - Vücut hizalaması
                   - Eklem açıları

                2. **Hareket Fazı:**
                   - Hareket yolu (range of motion)
                   - Tempo ve kontrol
                   - Stabilizasyon

                3. **Bitirme Pozisyonu:**
                   - Eksiksiz hareket tamamlanmış mı?
                   - Denge korunuyor mu?

                4. **Genel:**
                   - Nefes tekniği
                   - Kompansasyon hareketleri var mı?
                   - Sakatlık riski
                """;
        }
    }

    /**
     * AI yanıtını parse eder ve FormCheckResult döndürür.
     */
    private FormCheckResult parseFormAnalysisResponse(String aiText, String exerciseName) {
        FormCheckResult result = new FormCheckResult();
        result.exerciseName = exerciseName;
        result.fullAnalysis = aiText;

        // Basit puan çıkarma (regex ile "**Genel Puan:** 7" gibi satırı bul)
        try {
            String scorePattern = "\\*\\*Genel Puan:\\*\\*\\s*(\\d+)";
            java.util.regex.Pattern pattern = java.util.regex.Pattern.compile(scorePattern);
            java.util.regex.Matcher matcher = pattern.matcher(aiText);
            if (matcher.find()) {
                result.overallScore = Integer.parseInt(matcher.group(1));
            }
        } catch (Exception e) {
            LOG.warnf("Score parsing failed: %s", e.getMessage());
            result.overallScore = 0;
        }

        // Sakatlık riski kontrolü
        String lowerText = aiText.toLowerCase();
        result.injuryRisk = lowerText.contains("sakatlık riski") ||
                            lowerText.contains("injury risk") ||
                            lowerText.contains("tehlike");

        return result;
    }

    /**
     * Dosya uzantısından MIME type belirler.
     */
    private String getMimeType(Path filePath) {
        String fileName = filePath.getFileName().toString().toLowerCase();
        if (fileName.endsWith(".mp4")) return "video/mp4";
        if (fileName.endsWith(".mov")) return "video/quicktime";
        if (fileName.endsWith(".avi")) return "video/x-msvideo";
        if (fileName.endsWith(".webm")) return "video/webm";
        if (fileName.endsWith(".jpg") || fileName.endsWith(".jpeg")) return "image/jpeg";
        if (fileName.endsWith(".png")) return "image/png";
        if (fileName.endsWith(".webp")) return "image/webp";
        return "application/octet-stream"; // default
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────────

    public static class FormCheckResult {
        public String exerciseName;
        public String fullAnalysis;
        public int overallScore; // 1-10
        public boolean injuryRisk;
    }
}
