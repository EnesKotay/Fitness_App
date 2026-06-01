package com.fitness.service;

import java.util.HashMap;
import java.util.Map;

import com.fitness.entity.User;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * AI destekli akıllı antrenman programı oluşturur.
 * Kullanıcının hedefi, tecrübe seviyesi, ekipmanları ve kısıtlamalarına göre
 * 4-12 haftalık periodize antrenman programı üretir.
 */
@ApplicationScoped
public class SmartProgramGeneratorService {

    @Inject
    AiProviderRouter aiProviderRouter;

    @Inject
    WorkoutAnalysisService analysisService;

    /**
     * Kullanıcı için akıllı antrenman programı oluşturur.
     *
     * @param userId Kullanıcı ID
     * @param request Program parametreleri
     * @return AI tarafından üretilen program (haftalık split, egzersiz listesi, set/rep şeması)
     */
    public SmartProgramResponse generateProgram(Long userId, ProgramRequest request) {
        User user = User.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı!");
        }

        // Kullanıcının mevcut durumunu analiz et
        String currentStatus = buildCurrentStatusSummary(userId, user);

        // AI'ya prompt oluştur
        String prompt = buildProgramPrompt(user, request, currentStatus);

        // AI'dan program al
        GeminiClientResult result = aiProviderRouter.generateText(
                "program-generator",
                userId,
                "gemini-1.5-flash",
                "gemini-1.5-flash",
                prompt,
                false
        );
        if (!result.isSuccess()) {
            throw new RuntimeException("Program oluşturulamadı: " + result.getError());
        }

        // Yanıtı parse et ve döndür
        return parseAIResponse(result.getOutputText(), request);
    }

    /**
     * Kullanıcının mevcut antrenman durumunu özetle.
     */
    private String buildCurrentStatusSummary(Long userId, User user) {
        StringBuilder summary = new StringBuilder();

        // Kişisel bilgiler
        summary.append(String.format("**Kullanıcı Bilgileri:**\n"));
        summary.append(String.format("- Hedef: %s\n", user.goal != null ? user.goal : "Belirsiz"));
        summary.append(String.format("- Kilo: %.1f kg\n", user.weight != null ? user.weight : 0));
        summary.append(String.format("- Boy: %.0f cm\n", user.height != null ? user.height : 0));
        if (user.gender != null) {
            summary.append(String.format("- Cinsiyet: %s\n", user.gender));
        }

        // Deload durumu
        var deload = analysisService.calculateDeloadNeed(userId);
        if (deload.needsDeload) {
            summary.append("\n⚠️ **Deload İhtiyacı Var:**\n");
            summary.append(deload.reason).append("\n");
        }

        // Volume analizi
        var volumeAnalysis = analysisService.getVolumeAnalysis(userId);
        if (volumeAnalysis != null && volumeAnalysis.containsKey("avgWeeklyVolume")) {
            summary.append(String.format("\n**Haftalık Ortalama Volume:** %.0f kg\n",
                volumeAnalysis.get("avgWeeklyVolume")));
        }

        return summary.toString();
    }

    /**
     * AI için program oluşturma promptu.
     */
    private String buildProgramPrompt(User user, ProgramRequest request, String currentStatus) {
        StringBuilder prompt = new StringBuilder();

        prompt.append("Sen bir profesyonel fitness koçusun. Kullanıcı için kişiselleştirilmiş, ");
        prompt.append("periodize antrenman programı oluştur.\n\n");

        // Kullanıcı durumu
        prompt.append("## KULLANICI DURUMU\n");
        prompt.append(currentStatus).append("\n\n");

        // Program gereksinimleri
        prompt.append("## PROGRAM GEREKSİNİMLERİ\n");
        prompt.append(String.format("- Hedef: %s\n", request.goal));
        prompt.append(String.format("- Tecrübe Seviyesi: %s\n", request.experienceLevel));
        prompt.append(String.format("- Haftalık Antrenman Günü: %d\n", request.daysPerWeek));
        prompt.append(String.format("- Program Süresi: %d hafta\n", request.weeks));

        if (request.equipment != null && !request.equipment.isEmpty()) {
            prompt.append(String.format("- Mevcut Ekipman: %s\n", String.join(", ", request.equipment)));
        }

        if (request.focusAreas != null && !request.focusAreas.isEmpty()) {
            prompt.append(String.format("- Odaklanılacak Bölgeler: %s\n", String.join(", ", request.focusAreas)));
        }

        if (request.injuries != null && !request.injuries.isEmpty()) {
            prompt.append(String.format("- ⚠️ Sakatlıklar/Kısıtlamalar: %s\n", String.join(", ", request.injuries)));
        }

        prompt.append("\n## GÖREVİN\n");
        prompt.append("Yukarıdaki bilgilere göre detaylı antrenman programı oluştur.\n\n");

        prompt.append("**Beklenen Format:**\n");
        prompt.append("```\n");
        prompt.append("# [Program Başlığı]\n\n");
        prompt.append("## Program Özeti\n");
        prompt.append("[1-2 paragraf: program felsefesi, periodizasyon yaklaşımı]\n\n");
        prompt.append("## Haftalık Split\n");
        prompt.append("[Haftalık antrenman dağılımı - örn: Push/Pull/Legs veya Upper/Lower]\n\n");
        prompt.append("## Faz 1: [İsim] (Hafta 1-4)\n");
        prompt.append("**Hedef:** [Bu fazın amacı]\n");
        prompt.append("**Gün 1: [Kas Grubu]**\n");
        prompt.append("- [Egzersiz Adı]: 3 set x 8-10 tekrar (RPE 7-8)\n");
        prompt.append("- [Egzersiz Adı]: 3 set x 10-12 tekrar (RPE 7)\n");
        prompt.append("...\n\n");
        prompt.append("## Progresyon Stratejisi\n");
        prompt.append("[Ağırlık/tekrar/set artırma kuralları]\n\n");
        prompt.append("## Deload Planı\n");
        prompt.append("[Ne zaman ve nasıl deload yapılacağı]\n");
        prompt.append("```\n\n");

        prompt.append("**ÖNEMLI KURALLAR:**\n");
        prompt.append("1. Egzersiz seçiminde kullanıcının ekipmanını göz önünde bulundur\n");
        prompt.append("2. Sakatlık varsa o bölgeye stres binmesin\n");
        prompt.append("3. Tecrübe seviyesine göre karmaşıklık ayarla (başlangıç → basit compound hareketler)\n");
        prompt.append("4. Set/rep şeması hedefe uygun olsun (kuvvet: 3-6, hipertrofi: 8-12, dayanıklılık: 15+)\n");
        prompt.append("5. RPE (Rate of Perceived Exertion) belirt (1-10 skala)\n");
        prompt.append("6. Her faz için volume kademeli artsın (%10-15 haftalık)\n");
        prompt.append("7. Türkçe egzersiz isimleri kullan, gerekirse İngilizce parantez içinde ekle\n\n");

        prompt.append("Şimdi yukarıdaki formatta detaylı programı oluştur:");

        return prompt.toString();
    }

    /**
     * AI yanıtını parse eder ve SmartProgramResponse döndürür.
     */
    private SmartProgramResponse parseAIResponse(String aiText, ProgramRequest request) {
        SmartProgramResponse response = new SmartProgramResponse();
        response.programMarkdown = aiText;
        response.daysPerWeek = request.daysPerWeek;
        response.weeks = request.weeks;
        response.goal = request.goal;
        response.experienceLevel = request.experienceLevel;

        // Basit metadata extraction (başlık varsa)
        String[] lines = aiText.split("\n");
        for (String line : lines) {
            if (line.startsWith("# ") && response.title == null) {
                response.title = line.substring(2).trim();
                break;
            }
        }

        if (response.title == null) {
            response.title = String.format("%d Haftalık %s Programı", request.weeks, request.goal);
        }

        return response;
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────────

    public static class ProgramRequest {
        /** STRENGTH, HYPERTROPHY, ENDURANCE, FAT_LOSS, GENERAL_FITNESS */
        public String goal;

        /** BEGINNER, INTERMEDIATE, ADVANCED */
        public String experienceLevel;

        /** Haftalık antrenman günü (3-6) */
        public int daysPerWeek;

        /** Program süresi (4-12 hafta) */
        public int weeks;

        /** Mevcut ekipmanlar ["BARBELL", "DUMBBELL", "BODYWEIGHT", "MACHINE"] */
        public java.util.List<String> equipment;

        /** Odaklanılacak kas grupları ["CHEST", "BACK", "LEGS", "SHOULDERS"] */
        public java.util.List<String> focusAreas;

        /** Sakatlıklar/kısıtlamalar (örn: "Sol dizde rahatsızlık") */
        public java.util.List<String> injuries;
    }

    public static class SmartProgramResponse {
        public String title;
        public String programMarkdown;
        public int daysPerWeek;
        public int weeks;
        public String goal;
        public String experienceLevel;
    }
}
