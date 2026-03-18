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
    @ConfigProperty(name = "iap.verify.mode", defaultValue = "dev")
    String iapMode;

    @Inject
    @ConfigProperty(name = "iap.apple.shared-secret", defaultValue = "__MISSING__")
    String appleSharedSecret;

    @Inject
    @ConfigProperty(name = "iap.google.service-account-json", defaultValue = "__MISSING__")
    String googleServiceAccount;

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

        // Production'da IAP strict zorunlu
        if (isProd && "strict".equalsIgnoreCase(iapMode)) {
            if ("__MISSING__".equals(appleSharedSecret) || appleSharedSecret.isBlank()) {
                errors.add("Production IAP strict modunda IAP_APPLE_SHARED_SECRET tanımlı değil.");
            }
            if ("__MISSING__".equals(googleServiceAccount) || googleServiceAccount.isBlank()) {
                errors.add("Production IAP strict modunda IAP_GOOGLE_SERVICE_ACCOUNT_JSON tanımlı değil.");
            }
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
