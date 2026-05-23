package com.fitness;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Uygulama başlarken kritik ortam değişkenlerinin tanımlı olduğunu doğrular.
 * Eksik bir değer varsa uygulama hata fırlatarak durur (fail-fast).
 */
@ApplicationScoped
public class StartupValidator {

    private static final Logger LOG = Logger.getLogger(StartupValidator.class);

    @Inject
    @ConfigProperty(name = "smallrye.jwt.sign.key")
    Optional<String> jwtSecret;

    @Inject
    @ConfigProperty(name = "quarkus.datasource.password")
    Optional<String> dbPassword;

    @Inject
    @ConfigProperty(name = "quarkus.datasource.jdbc.url", defaultValue = "")
    String dbUrl;

    @Inject
    @ConfigProperty(name = "iap.verify.mode", defaultValue = "dev")
    String iapMode;

    @Inject
    @ConfigProperty(name = "iap.apple.shared-secret", defaultValue = "__MISSING__")
    String appleSharedSecret;

    @Inject
    @ConfigProperty(name = "iap.google.service-account-json", defaultValue = "__MISSING__")
    String googleServiceAccount;

    @Inject
    @ConfigProperty(name = "app.auth.google.allowed-client-ids", defaultValue = "")
    String googleAuthClientIds;

    @Inject
    @ConfigProperty(name = "app.auth.apple.allowed-audiences", defaultValue = "")
    String appleAuthAudiences;

    void onStart(@Observes StartupEvent event) {
        boolean isProd = "prod".equals(System.getProperty("quarkus.profile"))
                || "prod".equals(System.getenv("QUARKUS_PROFILE"));

        List<String> errors = new ArrayList<>();
        List<String> warnings = new ArrayList<>();

        // JWT secret — her ortamda zorunlu
        if (jwtSecret.isEmpty() || jwtSecret.get().isBlank()) {
            errors.add("JWT_SECRET_KEY tanımlı değil. En az 64 karakterlik güçlü bir secret ayarlayın.");
        } else if (jwtSecret.get().length() < 32) {
            (isProd ? errors : warnings).add("JWT_SECRET_KEY çok kısa (en az 32 karakter gerekli, 64 önerilen).");
        }

        // DB password — production'da güçlü olması zorunlu, dev'de uyarı
        if (dbPassword.isEmpty() || dbPassword.get().isBlank()) {
            errors.add("DB_PASSWORD tanımlı değil.");
        } else if (isWeakPassword(dbPassword.get())) {
            (isProd ? errors : warnings).add("DB_PASSWORD güvensiz ('admin123', 'password' vb.). Production'da güçlü şifre kullanın.");
        }

        // DB URL — production'da localhost olmamalı
        if (isProd && (dbUrl.isBlank() || dbUrl.contains("localhost") || dbUrl.contains("127.0.0.1"))) {
            errors.add("DB_URL production ortamında localhost içeriyor veya tanımlı değil. Gerçek veritabanı URL'si gerekli.");
        }

        // Production'da IAP dev modu yasak; strict/apple/google kabul edilir
        if (isProd && "dev".equalsIgnoreCase(iapMode)) {
            errors.add("IAP_VERIFY_MODE production ortamında 'dev' olamaz. 'strict', 'apple' veya 'google' kullanın.");
        }
        if (isProd && (List.of("strict", "apple").contains(iapMode.toLowerCase()))) {
            if ("__MISSING__".equals(appleSharedSecret) || appleSharedSecret.isBlank()) {
                errors.add("Production IAP doğrulaması için IAP_APPLE_SHARED_SECRET tanımlı değil.");
            }
        }
        if (isProd && (List.of("strict", "google").contains(iapMode.toLowerCase()))) {
            if ("__MISSING__".equals(googleServiceAccount) || googleServiceAccount.isBlank()) {
                warnings.add("IAP_GOOGLE_SERVICE_ACCOUNT_JSON tanımlı değil. Android satın almaları doğrulanamaz.");
            }
        }

        if (googleAuthClientIds.isBlank()) {
            warnings.add("AUTH_GOOGLE_ALLOWED_CLIENT_IDS tanımlı değil. Google ile giriş reddedilir.");
        }
        if (appleAuthAudiences.isBlank()) {
            warnings.add("AUTH_APPLE_ALLOWED_AUDIENCES tanımlı değil. Apple ile giriş reddedilir.");
        }

        if (!warnings.isEmpty()) {
            LOG.warn("=== GELİŞTİRME UYARILARI (production'da hata verir) ===");
            warnings.forEach(w -> LOG.warnf("  ⚠ %s", w));
            LOG.warn("=======================================================");
        }

        if (!errors.isEmpty()) {
            LOG.error("=== YAPILANDIRMA HATASI — Uygulama başlatılamıyor ===");
            errors.forEach(e -> LOG.errorf("  ✗ %s", e));
            LOG.error("=====================================================");
            throw new IllegalStateException(
                "Kritik ortam değişkenleri eksik: " + String.join("; ", errors)
            );
        }

        LOG.infof("✓ Startup validation başarılı. [profile=%s]", isProd ? "prod" : "dev");
    }

    private boolean isWeakPassword(String pw) {
        return pw.equals("admin123") || pw.equals("password") || pw.equals("postgres")
                || pw.equals("123456") || pw.equals("admin") || pw.equals("secret");
    }
}
