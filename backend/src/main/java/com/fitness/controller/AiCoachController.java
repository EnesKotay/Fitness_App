package com.fitness.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.jboss.logging.Logger;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fitness.dto.AiCoachRequest;
import com.fitness.dto.AiCoachResponse;
import com.fitness.dto.AiFeedbackRequest;
import com.fitness.service.AiCoachRateLimiter;
import com.fitness.service.AiCoachServiceException;
import com.fitness.service.AiEntitlementService;
import com.fitness.service.AiFeedbackService;
import com.fitness.service.AuthService;
import com.fitness.service.GeminiClient;
import com.fitness.service.GeminiCoachService;
import com.fitness.service.GeminiClientResult;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.resteasy.reactive.RestForm;
import org.jboss.resteasy.reactive.multipart.FileUpload;

@ApplicationScoped
@Path("/api/ai")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AiCoachController {

    private static final Logger LOG = Logger.getLogger(AiCoachController.class);

    @Inject
    GeminiCoachService geminiCoachService;

    @Inject
    com.fitness.service.WorkoutAnalysisService workoutAnalysisService;

    @Inject
    com.fitness.service.SmartProgramGeneratorService programGeneratorService;

    @Inject
    com.fitness.service.FormCheckService formCheckService;

    @Inject
    com.fitness.service.CoachingPersonalityService coachingPersonalityService;

    @Inject
    com.fitness.service.HabitLearningService habitLearningService;

    @Inject
    com.fitness.service.SocialInsightsService socialInsightsService;

    @Inject
    GeminiClient geminiClient;

    @Inject
    AiCoachRateLimiter rateLimiter;

    @Inject
    AuthService authService;

    @Inject
    ObjectMapper objectMapper;

    @Inject
    AiEntitlementService entitlementService;

    @Inject
    AiFeedbackService feedbackService;

    @Inject
    com.fitness.service.ProgressPredictionService progressPredictionService;

    @Inject
    com.fitness.service.AdaptiveLearningService adaptiveLearningService;

    @Inject
    com.fitness.service.WeeklyDigestService weeklyDigestService;

    @POST
    @Path("/coach")
    public Response coach(@Context HttpHeaders headers, AiCoachRequest request) {
        long startNs = System.nanoTime();
        Long userId = null;
        boolean consumedFreeEntitlement = false;

        try {
            userId = resolveUserId(headers);
            int promptLength = promptLength(request);
            boolean isPremium = entitlementService.isPremium(userId);

            if (!isPremium) {
                if (!entitlementService.tryConsumeFreeCoachRequest(userId)) {
                    Map<String, Object> payload = new HashMap<>();
                    payload.put("error", "Gunluk 2 ucretsiz AI koç hakkin doldu. Premium ile sinirsiz devam edebilirsin.");
                    payload.put("upgradeRequired", true);
                    return Response.status(Response.Status.FORBIDDEN).entity(payload).build();
                }
                consumedFreeEntitlement = true;
            }

            if (!rateLimiter.tryAcquire(userId, isPremium)) {
                if (consumedFreeEntitlement) {
                    entitlementService.refundFreeCoachRequest(userId);
                    consumedFreeEntitlement = false;
                }
                int retryAfterSeconds = rateLimiter.retryAfterSeconds(userId, isPremium);
                LOG.warnf("AI coach rate limit exceeded userId=%d promptLength=%d retryAfterSeconds=%d",
                        userId, promptLength, retryAfterSeconds);
                Map<String, Object> payload = new HashMap<>();
                payload.put("error", "Rate limit exceeded for AI coach");
                payload.put("retryAfterSeconds", retryAfterSeconds);
                return Response.status(Response.Status.TOO_MANY_REQUESTS)
                        .header("Retry-After", retryAfterSeconds)
                        .entity(payload)
                        .build();
            }

            AiCoachResponse response = geminiCoachService.generateCoachResponse(userId, request);
            // Populate server-side quota so frontend stays in sync
            if (!isPremium) {
                response.remainingFreeRequests = entitlementService.remainingFreeCoachRequests(userId);
            }
            logResult("ok", userId, startNs);
            return Response.ok(response).build();
        } catch (ForbiddenException e) {
            if (consumedFreeEntitlement) {
                entitlementService.refundFreeCoachRequest(userId);
            }
            logResult("forbidden", userId, startNs);
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (SecurityException e) {
            if (consumedFreeEntitlement) {
                entitlementService.refundFreeCoachRequest(userId);
            }
            logResult("unauthorized", userId, startNs);
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (IllegalArgumentException e) {
            if (consumedFreeEntitlement) {
                entitlementService.refundFreeCoachRequest(userId);
            }
            logResult("bad_request", userId, startNs);
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (AiCoachServiceException e) {
            Response.Status status = Response.Status.fromStatusCode(e.getStatusCode());
            if (status == null) {
                status = Response.Status.BAD_GATEWAY;
            }
            if (consumedFreeEntitlement && status.getStatusCode() >= 400) {
                entitlementService.refundFreeCoachRequest(userId);
            }
            logResult("service_error", userId, startNs);
            Map<String, Object> payload = new HashMap<>();
            payload.put("error", e.getMessage());
            Response.ResponseBuilder builder = Response.status(status);
            if (status == Response.Status.TOO_MANY_REQUESTS
                    && e.getRetryAfterSeconds() != null
                    && e.getRetryAfterSeconds() > 0) {
                payload.put("retryAfterSeconds", e.getRetryAfterSeconds());
                builder.header("Retry-After", e.getRetryAfterSeconds());
            }
            return builder.entity(payload).build();
        } catch (IllegalStateException e) {
            if (consumedFreeEntitlement) {
                entitlementService.refundFreeCoachRequest(userId);
            }
            logResult("service_unavailable", userId, startNs);
            return Response.status(Response.Status.SERVICE_UNAVAILABLE)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (RuntimeException e) {
            if (consumedFreeEntitlement) {
                entitlementService.refundFreeCoachRequest(userId);
            }
            logResult("bad_gateway", userId, startNs);
            return Response.status(Response.Status.BAD_GATEWAY)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }

    @POST
    @Path("/vision")
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    public Response vision(@Context HttpHeaders headers,
                          @RestForm("media") FileUpload media,
                          @RestForm("image") FileUpload image,
                          @RestForm("question") String question,
                          @RestForm("goal") String goal,
                          @RestForm("taskMode") String taskMode,
                          @RestForm("taskModeInstruction") String taskModeInstruction,
                          @RestForm("personality") String personality,
                          @RestForm("personalityInstruction") String personalityInstruction,
                          @RestForm("conversationHistory") String conversationHistoryJson,
                          @RestForm("dailySummary") String dailySummaryJson) {
        long startNs = System.nanoTime();
        Long userId = null;

        try {
            userId = resolveUserId(headers);
            entitlementService.ensurePremium(userId, "Gorsel AI analiz");
            boolean isPremium = true;

            if (!rateLimiter.tryAcquire(userId, isPremium)) {
                int retryAfterSeconds = rateLimiter.retryAfterSeconds(userId, isPremium);
                LOG.warnf("AI coach vision rate limit exceeded userId=%d retryAfterSeconds=%d", userId, retryAfterSeconds);
                Map<String, Object> payload = new HashMap<>();
                payload.put("error", "Görüntü analizi limiti aşıldı. Lütfen biraz sonra tekrar deneyin.");
                payload.put("retryAfterSeconds", retryAfterSeconds);
                return Response.status(Response.Status.TOO_MANY_REQUESTS)
                        .header("Retry-After", retryAfterSeconds)
                        .entity(payload)
                        .build();
            }

            FileUpload file = media != null ? media : image;
            if (file == null || file.uploadedFile() == null) {
                return Response.status(Response.Status.BAD_REQUEST).entity("{\"error\": \"Media file is required\"}").build();
            }

            byte[] mediaBytes = java.nio.file.Files.readAllBytes(file.uploadedFile());
            String mimeType = file.contentType();

            AiCoachRequest request = new AiCoachRequest();
            request.question = question;
            request.goal = goal;
            request.taskMode = taskMode;
            request.taskModeInstruction = taskModeInstruction;
            request.personality = personality;
            request.personalityInstruction = personalityInstruction;

            if (conversationHistoryJson != null && !conversationHistoryJson.isBlank()) {
                try {
                    request.conversationHistory = objectMapper.readValue(
                        conversationHistoryJson,
                        objectMapper.getTypeFactory().constructCollectionType(
                            java.util.List.class, AiCoachRequest.ConversationTurn.class));
                } catch (JsonProcessingException e) {
                    LOG.warnf("Vision: invalid conversationHistory JSON userId=%s", userId);
                }
            }

            if (dailySummaryJson != null && !dailySummaryJson.isBlank()) {
                try {
                    request.dailySummary = objectMapper.readValue(dailySummaryJson, AiCoachRequest.DailySummaryDto.class);
                } catch (JsonProcessingException e) {
                    LOG.warnf("Vision: invalid dailySummary JSON userId=%s", userId);
                    return Response.status(Response.Status.BAD_REQUEST)
                            .entity("{\"error\": \"Geçersiz dailySummary formatı.\"}")
                            .build();
                }
            } else {
                request.dailySummary = new AiCoachRequest.DailySummaryDto();
            }

            AiCoachResponse response = geminiCoachService.generateVisionResponse(userId, request, mediaBytes, mimeType);

            logResult("vision_ok", userId, startNs);
            return Response.ok(response).build();
        } catch (ForbiddenException e) {
            logResult("vision_forbidden", userId, startNs);
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (SecurityException e) {
            logResult("vision_unauthorized", userId, startNs);
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (AiCoachServiceException e) {
            Response.Status status = Response.Status.fromStatusCode(e.getStatusCode());
            if (status == null) status = Response.Status.BAD_GATEWAY;
            Map<String, Object> payload = new HashMap<>();
            payload.put("error", e.getMessage());
            if (e.getStatusCode() == 429 && e.getRetryAfterSeconds() != null && e.getRetryAfterSeconds() > 0) {
                payload.put("retryAfterSeconds", e.getRetryAfterSeconds());
            }
            Response.ResponseBuilder builder = Response.status(status);
            if (e.getRetryAfterSeconds() != null && e.getRetryAfterSeconds() > 0) {
                builder.header("Retry-After", e.getRetryAfterSeconds());
            }
            return builder.entity(payload).build();
        } catch (Exception e) {
            LOG.error("Vision processing failed", e);
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Görüntü işlenemedi. Lütfen tekrar deneyin.\"}")
                    .build();
        }
    }

    @POST
    @Path("/summarize")
    public Response summarizeConversation(@Context HttpHeaders headers, java.util.Map<String, Object> body) {
        try {
            Long userId = resolveUserId(headers);
            @SuppressWarnings("unchecked")
            java.util.List<String> messages = (java.util.List<String>) body.get("messages");
            if (messages == null || messages.isEmpty()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\":\"messages required\"}").build();
            }
            String joined = String.join("\n", messages);
            String prompt = "Aşağıdaki fitness koçluk konuşmasını 3-5 cümleyle özetle. " +
                    "Sadece kullanıcının hedefleri, aldığı tavsiyeler ve önemli bilgileri tut. " +
                    "Türkçe yaz. Tekrar veya selamlama ekleme.\n\n---\n" + joined;
            GeminiClientResult result = geminiClient.generateText(
                    "summarize", userId, "gemini-2.5-flash", "gemini-2.0-flash", prompt, false);
            if (!result.isSuccess()) {
                return Response.status(Response.Status.BAD_GATEWAY)
                        .entity("{\"error\":\"Summarization failed\"}").build();
            }
            Map<String, Object> resp = new HashMap<>();
            resp.put("summary", result.getOutputText().trim());
            return Response.ok(resp).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    @GET
    @Path("/insights")
    public Response getInsights(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            List<com.fitness.entity.AiInsight> insights =
                    com.fitness.entity.AiInsight.findRecentByUser(userId, 20);
            List<Map<String, Object>> result = insights.stream().map(i -> {
                Map<String, Object> m = new HashMap<>();
                m.put("id", i.id);
                m.put("type", i.type);
                m.put("summary", i.summary);
                m.put("createdAt", i.createdAt != null ? i.createdAt.toString() : null);
                return m;
            }).toList();
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        } catch (Exception e) {
            LOG.warnf("Get insights failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Kullanıcının ilerleme tahminlerini (hedef kiloya ne zaman ulaşır, kalori dengesi) döner.
     */
    @GET
    @Path("/progress-prediction")
    public Response getProgressPrediction(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);

            Map<String, Object> result = new HashMap<>();

            // Kilo projeksiyonu
            com.fitness.service.ProgressPredictionService.WeightProjection projection =
                progressPredictionService.predictWeeksToTarget(userId);
            if (projection != null) {
                Map<String, Object> proj = new HashMap<>();
                proj.put("currentWeight", projection.currentWeight);
                proj.put("targetWeight", projection.targetWeight);
                proj.put("weeklyChangeKg", projection.weeklyChangeKg);
                proj.put("weeksToTarget", projection.weeksToTarget);
                proj.put("status", projection.status);
                proj.put("message", projection.message);
                result.put("weightProjection", proj);
            }

            // Kalori dengesi
            com.fitness.service.ProgressPredictionService.CalorieBalance balance =
                progressPredictionService.calculateCalorieBalance(userId);
            if (balance != null) {
                Map<String, Object> bal = new HashMap<>();
                bal.put("avgDailyCalories", balance.avgDailyCalories);
                bal.put("tdee", balance.tdee);
                bal.put("dailyBalance", balance.dailyBalance);
                bal.put("insight", balance.insight);
                result.put("calorieBalance", bal);
            }

            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        } catch (Exception e) {
            LOG.warnf("Progress prediction failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity("{\"error\": \"İlerleme tahmini hesaplanamadı.\"}")
                .build();
        }
    }

    /**
     * Kullanıcının öğrenme istatistiklerini döner (bilgi seviyesi, soru sayısı, memnuniyet oranı)
     */
    @GET
    @Path("/learning-stats")
    public Response getLearningStats(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            Map<String, Object> stats = adaptiveLearningService.getLearningStats(userId);
            return Response.ok(stats).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        } catch (Exception e) {
            LOG.warnf("Learning stats failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity("{\"error\": \"Öğrenme istatistikleri hesaplanamadı.\"}")
                .build();
        }
    }

    /**
     * Geçen haftanın (Pazartesi-Pazar) performans raporunu AI ile üretir.
     */
    @GET
    @Path("/weekly-digest")
    public Response getWeeklyDigest(@Context HttpHeaders headers) {
        Long userId = null;
        try {
            userId = resolveUserId(headers);
            Map<String, Object> digest = weeklyDigestService.generateWeeklyDigest(userId);
            return Response.ok(digest).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        } catch (IllegalArgumentException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                .build();
        } catch (Exception e) {
            LOG.errorf("Weekly digest failed for user %d: %s", userId, e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                .entity("{\"error\": \"Haftalık rapor oluşturulamadı.\"}")
                .build();
        }
    }

    @POST
    @Path("/feedback")
    @Transactional
    public Response feedback(@Context HttpHeaders headers, AiFeedbackRequest request) {
        try {
            Long userId = resolveUserId(headers);
            feedbackService.save(userId, request);
            return Response.noContent().build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.warnf("Feedback save failed: %s", e.getMessage());
            return Response.noContent().build(); // non-critical, never fail the client
        }
    }

    // ────────────────────────────────────────────────────────────────────────────
    // WORKOUT ANALYSIS ENDPOINTS
    // ────────────────────────────────────────────────────────────────────────────

    /**
     * Plato tespiti (belirli bir egzersiz için)
     * GET /api/ai/workout/plateau/{exerciseName}
     */
    @GET
    @Path("/workout/plateau/{exerciseName}")
    public Response getPlateauDetection(@Context HttpHeaders headers, @PathParam("exerciseName") String exerciseName) {
        try {
            Long userId = resolveUserId(headers);
            var result = workoutAnalysisService.detectPlateauForExercise(userId, exerciseName);
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Plateau detection failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Plato analizi başarısız\"}")
                    .build();
        }
    }

    /**
     * PR tahmini (belirli bir egzersiz için)
     * GET /api/ai/workout/pr-prediction/{exerciseName}
     */
    @GET
    @Path("/workout/pr-prediction/{exerciseName}")
    public Response getPRPrediction(@Context HttpHeaders headers, @PathParam("exerciseName") String exerciseName) {
        try {
            Long userId = resolveUserId(headers);
            var result = workoutAnalysisService.predictNextPR(userId, exerciseName);
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("PR prediction failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"PR tahmini başarısız\"}")
                    .build();
        }
    }

    /**
     * Deload ihtiyacı analizi
     * GET /api/ai/workout/deload-check
     */
    @GET
    @Path("/workout/deload-check")
    public Response getDeloadCheck(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            var result = workoutAnalysisService.calculateDeloadNeed(userId);
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Deload check failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Deload analizi başarısız\"}")
                    .build();
        }
    }

    /**
     * Volume analizi (son 8 hafta)
     * GET /api/ai/workout/volume-analysis
     */
    @GET
    @Path("/workout/volume-analysis")
    public Response getVolumeAnalysis(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            var result = workoutAnalysisService.getVolumeAnalysis(userId);
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Volume analysis failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Volume analizi başarısız\"}")
                    .build();
        }
    }

    /**
     * Kas grubu bazında plato analizi
     * GET /api/ai/workout/muscle-group-plateau/{muscleGroup}
     */
    @GET
    @Path("/workout/muscle-group-plateau/{muscleGroup}")
    public Response getMuscleGroupPlateau(@Context HttpHeaders headers, @PathParam("muscleGroup") String muscleGroup) {
        try {
            Long userId = resolveUserId(headers);
            var result = workoutAnalysisService.detectPlateauForMuscleGroup(userId, muscleGroup);
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Muscle group plateau detection failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Kas grubu plato analizi başarısız\"}")
                    .build();
        }
    }

    /**
     * AI bazlı akıllı program oluştur
     * POST /api/ai/generate-program
     */
    @POST
    @Path("/generate-program")
    public Response generateProgram(@Context HttpHeaders headers, com.fitness.service.SmartProgramGeneratorService.ProgramRequest request) {
        try {
            Long userId = resolveUserId(headers);
            var result = programGeneratorService.generateProgram(userId, request);
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Program generation failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Program oluşturulamadı: " + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }

    /**
     * Form analizi (görsel tabanlı)
     * POST /api/ai/form-check
     * Multipart form data: image (file), exerciseName (string)
     */
    @POST
    @Path("/form-check")
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    public Response formCheck(
        @Context HttpHeaders headers,
        @RestForm("image") FileUpload imageFile,
        @RestForm("exerciseName") String exerciseName
    ) {
        try {
            Long userId = resolveUserId(headers);

            if (imageFile == null || imageFile.filePath() == null) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"Görsel dosyası gerekli\"}")
                        .build();
            }

            if (exerciseName == null || exerciseName.isBlank()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"Egzersiz adı gerekli\"}")
                        .build();
            }

            var result = formCheckService.analyzeFormFromImage(
                userId,
                imageFile.filePath(),
                exerciseName.trim()
            );

            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Form check failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Form analizi başarısız: " + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }

    /**
     * Koçluk kişiliği al
     * GET /api/ai/coaching-personality
     */
    @GET
    @Path("/coaching-personality")
    public Response getCoachingPersonality(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            var personality = coachingPersonalityService.getUserPersonality(userId);
            Map<String, Object> response = new HashMap<>();
            response.put("personality", personality.name());
            response.put("displayName", personality.displayName);
            response.put("description", personality.promptGuidance);
            return Response.ok(response).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Get coaching personality failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Kişilik bilgisi alınamadı\"}")
                    .build();
        }
    }

    /**
     * Koçluk kişiliği güncelle
     * POST /api/ai/coaching-personality
     * Body: {"personality": "TOUGH_LOVE"}
     */
    @POST
    @Path("/coaching-personality")
    public Response updateCoachingPersonality(@Context HttpHeaders headers, Map<String, String> request) {
        try {
            Long userId = resolveUserId(headers);
            String personalityStr = request.get("personality");
            if (personalityStr == null || personalityStr.isBlank()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"personality parametresi gerekli\"}")
                        .build();
            }

            com.fitness.service.CoachingPersonalityService.CoachingPersonality personality;
            try {
                personality = com.fitness.service.CoachingPersonalityService.CoachingPersonality.valueOf(personalityStr);
            } catch (IllegalArgumentException e) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"Geçersiz kişilik tipi. SUPPORTIVE, TOUGH_LOVE veya ANALYTICAL olmalı\"}")
                        .build();
            }

            coachingPersonalityService.updatePersonality(userId, personality);
            return Response.ok("{\"success\": true}").build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Update coaching personality failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Kişilik güncellenemedi\"}")
                    .build();
        }
    }

    /**
     * Alışkanlık analizi
     * GET /api/ai/habit-analysis
     */
    @GET
    @Path("/habit-analysis")
    public Response getHabitAnalysis(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            var analysis = habitLearningService.analyzeWorkoutHabits(userId);
            return Response.ok(analysis).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Habit analysis failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Alışkanlık analizi başarısız\"}")
                    .build();
        }
    }

    /**
     * Sosyal içgörüler
     * GET /api/ai/social-insights
     */
    @GET
    @Path("/social-insights")
    public Response getSocialInsights(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            var trends = socialInsightsService.analyzeTrends(userId);
            return Response.ok(trends).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Social insights failed: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"Sosyal içgörüler alınamadı\"}")
                    .build();
        }
    }

    private Long resolveUserId(HttpHeaders headers) {
        String authorization = headers == null ? null : headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        if (authorization == null || authorization.isBlank()) {
            LOG.warn("AI coach: Authorization header missing or empty");
        }
        try {
            return authService.getUserIdFromToken(authorization);
        } catch (RuntimeException e) {
            LOG.warnf("AI coach: token validation failed: %s", e.getMessage());
            throw new SecurityException(e.getMessage());
        }
    }

    private void logResult(String status, Long userId, long startNs) {
        long elapsedMs = (System.nanoTime() - startNs) / 1_000_000;
        LOG.infof("AI coach endpoint status=%s userId=%s latencyMs=%d",
                status, userId, elapsedMs);
    }

    private int promptLength(AiCoachRequest request) {
        if (request == null || request.question == null) {
            return 0;
        }
        return request.question.trim().length();
    }

    private static String escapeJson(String s) {
        if (s == null)
            return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }
}
