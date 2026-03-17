package com.fitness.controller;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

import org.jboss.logging.Logger;

import com.fitness.entity.User;
import com.fitness.service.AuthService;
import com.fitness.service.IapVerificationService;
import com.fitness.service.IapVerificationService.IapVerifyRequest;
import com.fitness.service.IapVerificationService.IapVerifyResult;
import com.fitness.service.PaymentService;
import com.fitness.service.PaymentService.PaymentRequest;
import com.fitness.service.PaymentService.PaymentResult;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

/**
 * Premium subscription management endpoints.
 */
@ApplicationScoped
@Path("/api/user")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class PremiumController {

    private static final Logger LOG = Logger.getLogger(PremiumController.class);

    @Inject
    AuthService authService;

    @Inject
    PaymentService paymentService;

    @Inject
    IapVerificationService iapVerificationService;

    // ─── Premium Status ───────────────────────────────────────────────────────

    @GET
    @Path("/premium-status")
    public Response getPremiumStatus(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            User user = User.findById(userId);
            if (user == null) {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("{\"error\": \"User not found\"}")
                        .build();
            }

            String tier = user.premiumTier != null ? user.premiumTier : "free";
            boolean isActive = "premium".equalsIgnoreCase(tier);
            if (isActive && user.premiumExpiresAt != null
                    && user.premiumExpiresAt.isBefore(LocalDateTime.now())) {
                isActive = false;
                tier = "expired";
            }

            Map<String, Object> result = new HashMap<>();
            result.put("tier", tier);
            result.put("isActive", isActive);
            result.put("expiresAt",
                    user.premiumExpiresAt != null ? user.premiumExpiresAt.toString() : null);
            result.put("planId", user.premiumPlan);
            result.put("cancelAtPeriodEnd", Boolean.TRUE.equals(user.premiumCancelAtPeriodEnd));
            result.put("canceledAt",
                    user.premiumCanceledAt != null ? user.premiumCanceledAt.toString() : null);
            result.put("canCancel", isActive
                    && "monthly".equalsIgnoreCase(user.premiumPlan)
                    && !Boolean.TRUE.equals(user.premiumCancelAtPeriodEnd));

            return Response.ok(result).build();

        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }

    // ─── Upgrade (with payment) ───────────────────────────────────────────────

    /**
     * Upgrade user to premium after payment processing.
     *
     * Body fields (from Flutter payment form):
     *   planId      — "monthly" | "yearly"
     *   cardNumber  — 16-digit string (no spaces)
     *   expiryMonth — MM
     *   expiryYear  — YY
     *   cvv         — 3-4 digits
     *   cardHolder  — cardholder name
     */
    @POST
    @Path("/upgrade-premium")
    @Transactional
    public Response upgradePremium(@Context HttpHeaders headers, Map<String, Object> body) {
        try {
            Long userId = resolveUserId(headers);
            User user = User.findById(userId);
            if (user == null) {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("{\"error\": \"User not found\"}")
                        .build();
            }

            // Zaten premium ise tekrar ödeme almayalım
            if ("premium".equalsIgnoreCase(user.premiumTier)
                    && user.premiumExpiresAt != null
                    && user.premiumExpiresAt.isAfter(LocalDateTime.now())) {
                Map<String, Object> result = new HashMap<>();
                result.put("tier", "premium");
                result.put("isActive", true);
                result.put("expiresAt", user.premiumExpiresAt.toString());
                result.put("planId", user.premiumPlan);
                result.put("cancelAtPeriodEnd", Boolean.TRUE.equals(user.premiumCancelAtPeriodEnd));
                result.put("canceledAt",
                        user.premiumCanceledAt != null ? user.premiumCanceledAt.toString() : null);
                result.put("canCancel", "monthly".equalsIgnoreCase(user.premiumPlan)
                        && !Boolean.TRUE.equals(user.premiumCancelAtPeriodEnd));
                result.put("message", "Premium zaten aktif.");
                return Response.ok(result).build();
            }

            // Kart bilgilerini parse et
            String cardNumber  = getString(body, "cardNumber");
            String expiryMonth = getString(body, "expiryMonth");
            String expiryYear  = getString(body, "expiryYear");
            String cvv         = getString(body, "cvv");
            String cardHolder  = getString(body, "cardHolder");
            String planId      = getString(body, "planId");
            int months         = resolvePlanMonths(planId);
            int amountKurus    = resolvePlanAmount(planId);

            if (months <= 0 || amountKurus <= 0) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "Geçersiz premium planı."))
                        .build();
            }

            // Temel validasyon
            String validationError = validateCardFields(cardNumber, expiryMonth, expiryYear, cvv, cardHolder);
            if (validationError != null) {
                return Response.status(422)
                        .entity(Map.of("error", validationError))
                        .build();
            }

            // Ödeme işlemini gerçekleştir
            PaymentRequest paymentRequest = new PaymentRequest(
                    userId,
                    user.email,
                    cardNumber,
                    expiryMonth,
                    expiryYear,
                    cvv,
                    cardHolder,
                    amountKurus,
                    planId
            );

            PaymentResult paymentResult = paymentService.charge(paymentRequest);

            if (!paymentResult.success()) {
                LOG.warnf("Payment failed for userId=%d plan=%s reason=%s",
                        userId, planId, paymentResult.errorMessage());
                return Response.status(402)
                        .entity(Map.of("error", paymentResult.errorMessage()))
                        .build();
            }

            // Ödeme başarılı → premium aktifleştir
            user.premiumTier = "premium";
            user.premiumPlan = planId;
            user.premiumExpiresAt = LocalDateTime.now().plusMonths(months);
            user.premiumCancelAtPeriodEnd = false;
            user.premiumCanceledAt = null;
            user.persist();

            LOG.infof("User %d upgraded to premium (plan=%s) until %s txId=%s",
                    userId, planId, user.premiumExpiresAt, paymentResult.transactionId());

            Map<String, Object> result = new HashMap<>();
            result.put("tier", "premium");
            result.put("isActive", true);
            result.put("expiresAt", user.premiumExpiresAt.toString());
            result.put("planId", user.premiumPlan);
            result.put("cancelAtPeriodEnd", false);
            result.put("canceledAt", null);
            result.put("canCancel", "monthly".equalsIgnoreCase(user.premiumPlan));
            result.put("transactionId", paymentResult.transactionId());
            result.put("message", "Premium aktivasyonu başarılı!");

            return Response.ok(result).build();

        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(Map.of("error", e.getMessage()))
                    .build();
        } catch (Exception e) {
            LOG.errorf(e, "Unexpected error during premium upgrade");
            return Response.serverError()
                    .entity(Map.of("error", "Ödeme işlemi sırasında bir hata oluştu."))
                    .build();
        }
    }

    // ─── Upgrade via IAP (App Store / Google Play) ────────────────────────────

    /**
     * Flutter'dan gelen App Store / Google Play satın alma tokenini doğrular
     * ve premium aktifleştirir.
     *
     * Body alanları:
     *   platform      — "ios" | "android"
     *   planId        — "premium_monthly" | "premium_yearly"
     *   purchaseToken — Android: Google Play purchase token
     *   receiptData   — iOS: base64 App Store receipt
     *   transactionId — opsiyonel, loglama için
     */
    @POST
    @Path("/upgrade-premium/iap")
    @Transactional
    public Response upgradeViaIap(@Context HttpHeaders headers, Map<String, Object> body) {
        try {
            Long userId = resolveUserId(headers);
            User user = User.findById(userId);
            if (user == null) {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity(Map.of("error", "Kullanıcı bulunamadı."))
                        .build();
            }

            // Zaten aktif premium varsa tekrar işlem yapma
            if ("premium".equalsIgnoreCase(user.premiumTier)
                    && user.premiumExpiresAt != null
                    && user.premiumExpiresAt.isAfter(LocalDateTime.now())) {
                return Response.ok(buildStatusMap(user, "Premium zaten aktif.")).build();
            }

            String platform      = getString(body, "platform");
            String planId        = getString(body, "planId");
            String purchaseToken = getString(body, "purchaseToken");
            String receiptData   = getString(body, "receiptData");
            String transactionId = getString(body, "transactionId");

            if (platform.isBlank() || planId.isBlank()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "platform ve planId zorunludur."))
                        .build();
            }

            // Apple / Google doğrulama
            IapVerifyRequest verifyReq = new IapVerifyRequest(
                    platform, planId, purchaseToken, receiptData, transactionId);
            IapVerifyResult result = iapVerificationService.verify(verifyReq);

            if (!result.valid()) {
                LOG.warnf("IAP doğrulama başarısız — userId=%d reason=%s", userId, result.errorMessage());
                return Response.status(402)
                        .entity(Map.of("error", result.errorMessage()))
                        .build();
            }

            // Doğrulama başarılı → premium aktifleştir
            int months = "yearly".equalsIgnoreCase(result.planId()) ? 12 : 1;
            user.premiumTier = "premium";
            user.premiumPlan = result.planId();
            user.premiumExpiresAt = LocalDateTime.now().plusMonths(months);
            user.premiumCancelAtPeriodEnd = false;
            user.premiumCanceledAt = null;
            user.persist();

            LOG.infof("IAP premium aktif — userId=%d plan=%s until=%s platform=%s txId=%s",
                    userId, result.planId(), user.premiumExpiresAt, platform, transactionId);

            Map<String, Object> resp = buildStatusMap(user, "Premium aktivasyonu başarılı!");
            resp.put("transactionId", transactionId);
            return Response.ok(resp).build();

        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity(Map.of("error", e.getMessage()))
                    .build();
        } catch (Exception e) {
            LOG.errorf(e, "IAP upgrade beklenmeyen hata");
            return Response.serverError()
                    .entity(Map.of("error", "İşlem sırasında hata oluştu."))
                    .build();
        }
    }

    // ─── Downgrade ────────────────────────────────────────────────────────────

    @POST
    @Path("/downgrade-premium")
    @Transactional
    public Response downgradePremium(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            User user = User.findById(userId);
            if (user == null) {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("{\"error\": \"User not found\"}")
                        .build();
            }

            if (!"premium".equalsIgnoreCase(user.premiumTier)
                    || user.premiumExpiresAt == null
                    || user.premiumExpiresAt.isBefore(LocalDateTime.now())) {
                return Response.status(Response.Status.CONFLICT)
                        .entity(Map.of("error", "Aktif premium üyelik bulunamadı."))
                        .build();
            }

            if (!"monthly".equalsIgnoreCase(user.premiumPlan)) {
                return Response.status(Response.Status.CONFLICT)
                        .entity(Map.of("error", "Yıllık plan satın alındıktan sonra iptal edilemez."))
                        .build();
            }

            if (Boolean.TRUE.equals(user.premiumCancelAtPeriodEnd)) {
                return Response.status(Response.Status.CONFLICT)
                        .entity(Map.of("error", "Aylık plan için dönem sonu iptali zaten planlandı."))
                        .build();
            }

            user.premiumCancelAtPeriodEnd = true;
            user.premiumCanceledAt = LocalDateTime.now();
            user.persist();

            LOG.infof("User %d scheduled premium cancellation at period end=%s",
                    userId, user.premiumExpiresAt);

            Map<String, Object> result = new HashMap<>();
            result.put("tier", "premium");
            result.put("isActive", true);
            result.put("expiresAt", user.premiumExpiresAt.toString());
            result.put("planId", user.premiumPlan);
            result.put("cancelAtPeriodEnd", true);
            result.put("canceledAt", user.premiumCanceledAt.toString());
            result.put("canCancel", false);
            result.put("message", "İptal planlandı. Premium erişimin dönem sonuna kadar devam edecek.");

            return Response.ok(result).build();

        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private String validateCardFields(String cardNumber, String expiryMonth,
            String expiryYear, String cvv, String cardHolder) {
        if (cardNumber == null || !cardNumber.matches("\\d{16}")) {
            return "Geçersiz kart numarası. 16 hane olmalıdır.";
        }
        if (expiryMonth == null || !expiryMonth.matches("0[1-9]|1[0-2]")) {
            return "Geçersiz son kullanma ayı (MM).";
        }
        if (expiryYear == null || !expiryYear.matches("\\d{2}")) {
            return "Geçersiz son kullanma yılı (YY).";
        }
        if (cvv == null || !cvv.matches("\\d{3,4}")) {
            return "Geçersiz CVV.";
        }
        if (cardHolder == null || cardHolder.isBlank()) {
            return "Kart üzerindeki isim boş bırakılamaz.";
        }
        // Son kullanma tarihi geçmiş mi?
        int month = Integer.parseInt(expiryMonth);
        int year  = 2000 + Integer.parseInt(expiryYear);
        LocalDateTime now = LocalDateTime.now();
        if (year < now.getYear() || (year == now.getYear() && month < now.getMonthValue())) {
            return "Kartın son kullanma tarihi geçmiş.";
        }
        return null;
    }

    private String getString(Map<String, Object> body, String key) {
        Object val = body.get(key);
        return val != null ? val.toString().trim() : "";
    }

    private int resolvePlanMonths(String planId) {
        return switch (planId == null ? "" : planId.trim().toLowerCase()) {
            case "monthly" -> 1;
            case "yearly" -> 12;
            default -> -1;
        };
    }

    private int resolvePlanAmount(String planId) {
        return switch (planId == null ? "" : planId.trim().toLowerCase()) {
            case "monthly" -> 14900;
            case "yearly" -> 119900;
            default -> -1;
        };
    }

    private Map<String, Object> buildStatusMap(User user, String message) {
        Map<String, Object> m = new HashMap<>();
        m.put("tier", user.premiumTier);
        m.put("isActive", true);
        m.put("expiresAt", user.premiumExpiresAt != null ? user.premiumExpiresAt.toString() : null);
        m.put("planId", user.premiumPlan);
        m.put("cancelAtPeriodEnd", Boolean.TRUE.equals(user.premiumCancelAtPeriodEnd));
        m.put("canceledAt", user.premiumCanceledAt != null ? user.premiumCanceledAt.toString() : null);
        m.put("canCancel", "monthly".equalsIgnoreCase(user.premiumPlan)
                && !Boolean.TRUE.equals(user.premiumCancelAtPeriodEnd));
        m.put("message", message);
        return m;
    }

    private Long resolveUserId(HttpHeaders headers) {
        String authorization = headers == null ? null
                : headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        try {
            return authService.getUserIdFromToken(authorization);
        } catch (RuntimeException e) {
            throw new SecurityException(e.getMessage());
        }
    }
}
