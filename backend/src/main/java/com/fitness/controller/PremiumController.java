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

    // ─── Upgrade (with payment) — DEVRE DIŞI ─────────────────────────────────
    //
    // Ham kart verisi backend'den geçirilmesi PCI-DSS'e aykırıdır.
    // Mobil uygulamalar için lütfen /upgrade-premium/iap (App Store / Google Play)
    // endpoint'ini kullanın. Web ödemeleri için Iyzico Checkout Form entegre edin:
    //   https://dev.iyzipay.com/tr/checkout-form
    //
    @POST
    @Path("/upgrade-premium")
    public Response upgradePremium(@Context HttpHeaders headers, Map<String, Object> body) {
        return Response.status(Response.Status.GONE)
                .entity(Map.of(
                    "error", "Bu endpoint artık kullanılmıyor.",
                    "message", "Mobil ödemeler için /api/user/upgrade-premium/iap endpoint'ini kullanın."
                ))
                .build();
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

    private String getString(Map<String, Object> body, String key) {
        Object val = body.get(key);
        return val != null ? val.toString().trim() : "";
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
