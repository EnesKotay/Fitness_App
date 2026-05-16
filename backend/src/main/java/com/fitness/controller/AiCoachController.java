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
