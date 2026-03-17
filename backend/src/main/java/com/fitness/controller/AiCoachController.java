package com.fitness.controller;

import java.util.HashMap;
import java.util.Map;

import org.jboss.logging.Logger;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fitness.dto.AiCoachRequest;
import com.fitness.dto.AiCoachResponse;
import com.fitness.service.AiCoachRateLimiter;
import com.fitness.service.AiCoachServiceException;
import com.fitness.service.AiProviderRouter;
import com.fitness.service.AuthService;
import com.fitness.service.GeminiCoachService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
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
    AiCoachRateLimiter rateLimiter;

    @Inject
    AuthService authService;

    @Inject
    AiProviderRouter aiProviderRouter;

    @Inject
    ObjectMapper objectMapper;

    @POST
    @Path("/coach")
    public Response coach(@Context HttpHeaders headers, AiCoachRequest request) {
        long startNs = System.nanoTime();
        Long userId = null;

        try {
            userId = resolveUserId(headers);
            int promptLength = promptLength(request);
            boolean isPremium = aiProviderRouter.isPremium(userId);

            if (!rateLimiter.tryAcquire(userId, isPremium)) {
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
            logResult("ok", userId, startNs);
            return Response.ok(response).build();
        } catch (SecurityException e) {
            logResult("unauthorized", userId, startNs);
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (IllegalArgumentException e) {
            logResult("bad_request", userId, startNs);
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (AiCoachServiceException e) {
            Response.Status status = Response.Status.fromStatusCode(e.getStatusCode());
            if (status == null) {
                status = Response.Status.BAD_GATEWAY;
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
            logResult("service_unavailable", userId, startNs);
            return Response.status(Response.Status.SERVICE_UNAVAILABLE)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (RuntimeException e) {
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
                          @RestForm("image") FileUpload image,
                          @RestForm("question") String question,
                          @RestForm("goal") String goal,
                          @RestForm("personality") String personality,
                          @RestForm("personalityInstruction") String personalityInstruction,
                          @RestForm("dailySummary") String dailySummaryJson) {
        long startNs = System.nanoTime();
        Long userId = null;

        try {
            userId = resolveUserId(headers);
            boolean isPremium = aiProviderRouter.isPremium(userId);

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

            if (image == null || image.uploadedFile() == null) {
                return Response.status(Response.Status.BAD_REQUEST).entity("{\"error\": \"Image is required\"}").build();
            }

            byte[] imageBytes = java.nio.file.Files.readAllBytes(image.uploadedFile());
            String mimeType = image.contentType();

            AiCoachRequest request = new AiCoachRequest();
            request.question = question;
            request.goal = goal;
            request.personality = personality;
            request.personalityInstruction = personalityInstruction;

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

            AiCoachResponse response = geminiCoachService.generateVisionResponse(userId, request, imageBytes, mimeType);

            logResult("vision_ok", userId, startNs);
            return Response.ok(response).build();
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
