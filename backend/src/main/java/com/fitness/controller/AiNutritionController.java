package com.fitness.controller;

import java.util.HashMap;
import java.util.Map;

import org.jboss.logging.Logger;

import com.fitness.dto.NutritionAiRequest;
import com.fitness.dto.NutritionAiResponse;
import com.fitness.dto.NutritionFeedbackRequest;
import com.fitness.dto.NutritionLabelResult;
import com.fitness.dto.FoodImageResult;
import com.fitness.service.AiCoachServiceException;
import com.fitness.service.AiEntitlementService;
import com.fitness.service.AiNutritionRateLimiter;
import com.fitness.service.AiProviderRouter;
import com.fitness.service.AuthService;
import com.fitness.service.GeminiNutritionService;
import com.fitness.service.UserMealPreferenceService;

import io.quarkus.security.Authenticated;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.ForbiddenException;
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
public class AiNutritionController {

    private static final Logger LOG = Logger.getLogger(AiNutritionController.class);

    @Inject
    GeminiNutritionService geminiNutritionService;

    @Inject
    AiNutritionRateLimiter rateLimiter;

    @Inject
    AuthService authService;

    @Inject
    UserMealPreferenceService userPreferenceService;

    @Inject
    AiProviderRouter aiProviderRouter;

    @Inject
    AiEntitlementService entitlementService;

    @POST
    @Path("/nutrition")
    public Response nutrition(@Context HttpHeaders headers, NutritionAiRequest request) {
        long startNs = System.nanoTime();
        Long userId = null;

        try {
            userId = resolveUserId(headers);
            boolean isPremium = aiProviderRouter.isPremium(userId);
            if (isPremiumTask(request)) {
                entitlementService.ensurePremium(userId, "AI destekli premium planlama");
                isPremium = true;
            }

            if (!rateLimiter.tryAcquire(userId, isPremium)) {
                int retryAfterSeconds = rateLimiter.retryAfterSeconds(userId, isPremium);
                logResult("rate_limited", userId, startNs);
                Map<String, Object> payload = new HashMap<>();
                payload.put("error", "Too Many Requests");
                payload.put("retryAfterSeconds", retryAfterSeconds);
                return Response.status(Response.Status.TOO_MANY_REQUESTS)
                        .header("Retry-After", retryAfterSeconds)
                        .entity(payload)
                        .build();
            }

            GeminiNutritionService.NutritionGenerationResult result = geminiNutritionService
                    .generateNutritionResponse(userId, request);
            NutritionAiResponse response = result.response();

            logResult("ok", userId, startNs);
            return Response.ok(response).build();
        } catch (ForbiddenException e) {
            logResult("forbidden", userId, startNs);
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
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
        } catch (RuntimeException e) {
            logResult("bad_gateway", userId, startNs);
            return Response.status(Response.Status.BAD_GATEWAY)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }

    private Long resolveUserId(HttpHeaders headers) {
        String authorization = headers == null ? null : headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        try {
            return authService.getUserIdFromToken(authorization);
        } catch (RuntimeException e) {
            throw new SecurityException(e.getMessage());
        }
    }

    private void logResult(String status, Long userId, long startNs) {
        long latencyMs = (System.nanoTime() - startNs) / 1_000_000;
        LOG.infof("endpoint=ai/nutrition status=%s userId=%s latencyMs=%d",
                status, userId, latencyMs);
    }

    private static String escapeJson(String s) {
        if (s == null) {
            return "";
        }
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }

    private boolean isPremiumTask(NutritionAiRequest request) {
        if (request == null || request.task == null || request.task.isBlank()) {
            return false;
        }
        String task = request.task.trim().toUpperCase();
        return "GROCERY_LIST".equals(task);
    }

    /**
     * Feedback endpoint to record user meal preferences
     * Called when user adds a meal to diary from AI suggestions
     */
    @POST
    @Path("/nutrition/feedback")
    @Authenticated
    public Response nutritionFeedback(@Context HttpHeaders headers, NutritionFeedbackRequest request) {
        Long userId = null;
        try {
            userId = resolveUserId(headers);

            if (request == null || request.mealName == null || request.mealName.isBlank()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"mealName is required\"}")
                        .build();
            }

            // Record the preference
            userPreferenceService.recordPreference(
                    userId,
                    request.mealName,
                    request.tags,
                    request.mealType);

            LOG.infof("Recorded feedback for user %d: %s", userId, request.mealName);

            return Response.ok("{\"status\": \"ok\"}").build();

        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (Exception e) {
            LOG.errorf("Feedback error: %s", e.getMessage());
            return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }

    /**
     * Scan nutrition label image using Gemini Vision AI.
     * Accepts multipart form with "image" file field.
     */
    @POST
    @Path("/nutrition/scan-label")
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    @Authenticated
    public Response scanLabel(@Context HttpHeaders headers,
            @RestForm("image") FileUpload imageFile) {
        long startNs = System.nanoTime();
        Long userId = null;

        try {
            userId = resolveUserId(headers);
            entitlementService.ensurePremium(userId, "Besin etiketi tarama");

            if (!rateLimiter.tryAcquire(userId, aiProviderRouter.isPremium(userId))) {
                int retryAfterSeconds = rateLimiter.retryAfterSeconds(userId, aiProviderRouter.isPremium(userId));
                logResult("scan_rate_limited", userId, startNs);
                Map<String, Object> payload = new HashMap<>();
                payload.put("error", "Too Many Requests");
                payload.put("retryAfterSeconds", retryAfterSeconds);
                return Response.status(Response.Status.TOO_MANY_REQUESTS)
                        .header("Retry-After", retryAfterSeconds)
                        .entity(payload).build();
            }

            if (imageFile == null || imageFile.filePath() == null) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"image field is required\"}")
                        .build();
            }

            // Read file bytes
            byte[] imageBytes = java.nio.file.Files.readAllBytes(imageFile.filePath());

            // Validate size (max 10 MB)
            if (imageBytes.length > 10 * 1024 * 1024) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"Image too large. Max 10 MB.\"}")
                        .build();
            }

            // Determine MIME type
            String mimeType = imageFile.contentType();
            if (mimeType == null || !mimeType.startsWith("image/")) {
                mimeType = "image/jpeg"; // fallback
            }

            NutritionLabelResult result = geminiNutritionService.scanNutritionLabel(
                    userId, imageBytes, mimeType);

            logResult("scan_ok", userId, startNs);
            return Response.ok(result).build();

        } catch (ForbiddenException e) {
            logResult("scan_forbidden", userId, startNs);
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (SecurityException e) {
            logResult("scan_unauthorized", userId, startNs);
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (AiCoachServiceException e) {
            Response.Status status = Response.Status.fromStatusCode(e.getStatusCode());
            if (status == null)
                status = Response.Status.BAD_GATEWAY;
            logResult("scan_service_error", userId, startNs);
            Map<String, Object> payload = new HashMap<>();
            payload.put("error", e.getMessage());
            return Response.status(status).entity(payload).build();
        } catch (Exception e) {
            logResult("scan_error", userId, startNs);
            LOG.errorf("Label scan error: %s", e.getMessage());
            return Response.status(Response.Status.BAD_GATEWAY)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }

    /**
     * Analyze a food/meal image using Gemini Vision AI.
     * Accepts multipart form with "image" file field.
     */
    @POST
    @Path("/nutrition/analyze-image")
    @Consumes(MediaType.MULTIPART_FORM_DATA)
    @Authenticated
    public Response analyzeFoodImage(@Context HttpHeaders headers,
            @RestForm("image") FileUpload imageFile) {
        long startNs = System.nanoTime();
        Long userId = null;

        try {
            userId = resolveUserId(headers);
            entitlementService.ensurePremium(userId, "Yemek fotografi analizi");

            if (!rateLimiter.tryAcquire(userId, aiProviderRouter.isPremium(userId))) {
                int retryAfterSeconds = rateLimiter.retryAfterSeconds(userId, aiProviderRouter.isPremium(userId));
                logResult("analyze_image_rate_limited", userId, startNs);
                Map<String, Object> payload = new HashMap<>();
                payload.put("error", "Too Many Requests");
                payload.put("retryAfterSeconds", retryAfterSeconds);
                return Response.status(Response.Status.TOO_MANY_REQUESTS)
                        .header("Retry-After", retryAfterSeconds)
                        .entity(payload).build();
            }

            if (imageFile == null || imageFile.filePath() == null) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"image field is required\"}")
                        .build();
            }

            // Read file bytes
            byte[] imageBytes = java.nio.file.Files.readAllBytes(imageFile.filePath());

            // Validate size (max 10 MB)
            if (imageBytes.length > 10 * 1024 * 1024) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity("{\"error\": \"Image too large. Max 10 MB.\"}")
                        .build();
            }

            // Determine MIME type
            String mimeType = imageFile.contentType();
            if (mimeType == null || !mimeType.startsWith("image/")) {
                mimeType = "image/jpeg"; // fallback
            }

            FoodImageResult result = geminiNutritionService.analyzeFoodImage(
                    userId, imageBytes, mimeType);

            logResult("analyze_image_ok", userId, startNs);
            return Response.ok(result).build();

        } catch (ForbiddenException e) {
            logResult("analyze_image_forbidden", userId, startNs);
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (SecurityException e) {
            logResult("analyze_image_unauthorized", userId, startNs);
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        } catch (AiCoachServiceException e) {
            Response.Status status = Response.Status.fromStatusCode(e.getStatusCode());
            if (status == null)
                status = Response.Status.BAD_GATEWAY;
            logResult("analyze_image_service_error", userId, startNs);
            Map<String, Object> payload = new HashMap<>();
            payload.put("error", e.getMessage());
            return Response.status(status).entity(payload).build();
        } catch (Exception e) {
            logResult("analyze_image_error", userId, startNs);
            LOG.errorf("Food image analysis error: %s", e.getMessage());
            return Response.status(Response.Status.BAD_GATEWAY)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }
}
