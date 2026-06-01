package com.fitness.filter;

import java.io.IOException;
import java.time.Instant;

import org.eclipse.microprofile.jwt.JsonWebToken;
import org.jboss.logging.Logger;

import com.fitness.annotation.RequiresPremium;
import com.fitness.entity.User;

import jakarta.annotation.Priority;
import jakarta.inject.Inject;
import jakarta.ws.rs.Priorities;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.ContainerRequestFilter;
import jakarta.ws.rs.container.ResourceInfo;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.Provider;

/**
 * @RequiresPremium annotation'ını işleyen JAX-RS filter.
 *
 * Premium kontrolü yapar:
 * 1. Kullanıcı premium mi?
 * 2. Premium süresi dolmuş mu?
 * 3. Grace period içinde mi?
 *
 * Premium değilse HTTP 402 Payment Required döner.
 */
@Provider
@Priority(Priorities.AUTHORIZATION + 10) // Auth'dan sonra çalış
public class PremiumFeatureFilter implements ContainerRequestFilter {

    private static final Logger LOG = Logger.getLogger(PremiumFeatureFilter.class);

    @Context
    ResourceInfo resourceInfo;

    @Inject
    JsonWebToken jwt;

    @Override
    public void filter(ContainerRequestContext requestContext) throws IOException {
        // Method veya class'ta @RequiresPremium var mı?
        RequiresPremium methodAnnotation = resourceInfo.getResourceMethod()
                .getAnnotation(RequiresPremium.class);
        RequiresPremium classAnnotation = resourceInfo.getResourceClass()
                .getAnnotation(RequiresPremium.class);

        RequiresPremium annotation = methodAnnotation != null ? methodAnnotation : classAnnotation;

        if (annotation == null) {
            return; // Premium gerekmiyor, devam et
        }

        // JWT'den user ID al
        Long userId;
        try {
            userId = Long.parseLong(jwt.getClaim("userId").toString());
        } catch (Exception e) {
            LOG.warnf("PremiumFilter: userId JWT'den alınamadı: %s", e.getMessage());
            requestContext.abortWith(
                Response.status(401)
                    .entity("{\"error\": \"Geçersiz token\"}")
                    .build()
            );
            return;
        }

        // User'ı veritabanından çek
        User user = User.findById(userId);
        if (user == null) {
            requestContext.abortWith(
                Response.status(401)
                    .entity("{\"error\": \"Kullanıcı bulunamadı\"}")
                    .build()
            );
            return;
        }

        // Premium kontrolü
        boolean isPremium = checkPremiumStatus(user);

        if (!isPremium) {
            String feature = annotation.feature().isEmpty()
                ? resourceInfo.getResourceMethod().getName()
                : annotation.feature();

            LOG.infof("Premium gerekli: userId=%d, feature=%s", userId, feature);

            requestContext.abortWith(
                Response.status(402) // Payment Required
                    .entity(String.format(
                        "{\"error\": \"%s\", \"feature\": \"%s\", \"requiresPremium\": true}",
                        annotation.message(),
                        feature
                    ))
                    .build()
            );
        }
    }

    /**
     * Premium status kontrolü - grace period dahil
     */
    private boolean checkPremiumStatus(User user) {
        if (user.premiumTier == null || !user.premiumTier.equals("premium")) {
            return false;
        }

        if (user.premiumExpiresAt == null) {
            return false;
        }

        Instant now = Instant.now();
        // LocalDateTime'dan Instant'a çevir (UTC zone)
        Instant expiresAt = user.premiumExpiresAt
            .atZone(java.time.ZoneOffset.UTC)
            .toInstant();

        // Grace period: 3 gün (Apple/Google otomatik yenileme için)
        Instant gracePeriodEnd = expiresAt.plusSeconds(3 * 24 * 60 * 60);

        return now.isBefore(gracePeriodEnd);
    }
}
