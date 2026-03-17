package com.fitness.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * App Store ve Google Play abonelik satın almalarını doğrular.
 *
 * ──────────────────────────────────────────────────────────────
 * Konfigürasyon (application.properties / env):
 *
 *   iap.verify.mode            = dev | apple | google | strict
 *     dev    → token boş değilse kabul et (geliştirme/test)
 *     apple  → sadece App Store doğrula
 *     google → sadece Google Play doğrula
 *     strict → platforma göre zorunlu doğrulama
 *
 *   iap.apple.shared-secret    = App Store Connect → Subscriptions → Shared Secret
 *   iap.apple.bundle-id        = ör. com.fitnessapp
 *   iap.apple.sandbox          = true (TestFlight) | false (production)
 *
 *   iap.google.package-name    = ör. com.fitnessapp
 *   iap.google.service-account-json = Google Play service account JSON (tek satır)
 * ──────────────────────────────────────────────────────────────
 */
@ApplicationScoped
public class IapVerificationService {

    private static final Logger LOG = Logger.getLogger(IapVerificationService.class);

    // Apple endpoints
    private static final String APPLE_PROD_URL    = "https://buy.itunes.apple.com/verifyReceipt";
    private static final String APPLE_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

    // Google Play subscriptions endpoint
    private static final String GOOGLE_SUBS_URL =
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
            + "/%s/purchases/subscriptions/%s/tokens/%s";

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "iap.verify.mode", defaultValue = "dev")
    String verifyMode;

    @ConfigProperty(name = "iap.apple.shared-secret", defaultValue = "__MISSING__")
    String appleSharedSecret;

    @ConfigProperty(name = "iap.apple.bundle-id", defaultValue = "com.fitnessapp")
    String appleBundleId;

    @ConfigProperty(name = "iap.apple.sandbox", defaultValue = "false")
    boolean appleSandbox;

    @ConfigProperty(name = "iap.google.package-name", defaultValue = "com.fitnessapp")
    String googlePackageName;

    @ConfigProperty(name = "iap.google.service-account-json", defaultValue = "__MISSING__")
    String googleServiceAccountJson;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15))
            .build();

    // ─── Public API ───────────────────────────────────────────────────────────

    public record IapVerifyRequest(
            String platform,      // "ios" | "android"
            String planId,        // "premium_monthly" | "premium_yearly"
            String purchaseToken, // Android: Google Play purchase token
            String receiptData,   // iOS: base64 App Store receipt
            String transactionId  // opsiyonel, loglama için
    ) {}

    public record IapVerifyResult(
            boolean valid,
            String planId,      // doğrulanmış plan ID
            String errorMessage
    ) {
        static IapVerifyResult ok(String planId) {
            return new IapVerifyResult(true, planId, null);
        }
        static IapVerifyResult fail(String reason) {
            return new IapVerifyResult(false, null, reason);
        }
    }

    /**
     * Satın almayı doğrular. Sonuca göre premium aktifleştirme yapılır.
     */
    public IapVerifyResult verify(IapVerifyRequest req) {
        LOG.infof("IAP doğrulama — platform=%s plan=%s mode=%s txId=%s",
                req.platform(), req.planId(), verifyMode, req.transactionId());

        return switch (verifyMode.toLowerCase()) {
            case "dev"    -> verifyDev(req);
            case "apple"  -> verifyApple(req);
            case "google" -> verifyGoogle(req);
            case "strict" -> "ios".equalsIgnoreCase(req.platform())
                    ? verifyApple(req)
                    : verifyGoogle(req);
            default       -> verifyDev(req);
        };
    }

    // ─── Dev / Sandbox ────────────────────────────────────────────────────────

    /**
     * Geliştirme modu: token boş değilse geçerli say.
     * Production'da kullanma!
     */
    private IapVerifyResult verifyDev(IapVerifyRequest req) {
        final String token = "ios".equalsIgnoreCase(req.platform())
                ? req.receiptData()
                : req.purchaseToken();

        if (token == null || token.isBlank()) {
            return IapVerifyResult.fail("Satın alma token'ı boş.");
        }
        LOG.infof("[DEV] IAP kabul edildi — plan=%s txId=%s", req.planId(), req.transactionId());
        return IapVerifyResult.ok(normalizePlanId(req.planId()));
    }

    // ─── Apple App Store ──────────────────────────────────────────────────────

    private IapVerifyResult verifyApple(IapVerifyRequest req) {
        if (req.receiptData() == null || req.receiptData().isBlank()) {
            return IapVerifyResult.fail("iOS receipt verisi boş.");
        }
        if ("__MISSING__".equals(appleSharedSecret)) {
            LOG.warn("Apple shared secret yapılandırılmamış, dev moduna düşülüyor.");
            return verifyDev(req);
        }

        try {
            String body = objectMapper.writeValueAsString(
                    java.util.Map.of(
                            "receipt-data", req.receiptData(),
                            "password", appleSharedSecret,
                            "exclude-old-transactions", true
                    )
            );

            // Önce production, 21007 alırsak sandbox'a geç (TestFlight desteği)
            String url = appleSandbox ? APPLE_SANDBOX_URL : APPLE_PROD_URL;
            JsonNode root = callApple(url, body);

            int status = root.path("status").asInt(-1);

            // 21007: Receipt sandbox'a ait, production URL kullanıldı
            if (status == 21007 && !appleSandbox) {
                LOG.info("Apple: production receipt reddedildi (21007), sandbox deneniyor.");
                root = callApple(APPLE_SANDBOX_URL, body);
                status = root.path("status").asInt(-1);
            }

            if (status != 0) {
                String msg = appleStatusMessage(status);
                LOG.warnf("Apple receipt geçersiz — status=%d msg=%s", status, msg);
                return IapVerifyResult.fail(msg);
            }

            // En güncel aboneliği bul
            JsonNode latestInfo = root.path("latest_receipt_info");
            if (latestInfo.isArray() && latestInfo.size() > 0) {
                JsonNode latest = latestInfo.get(latestInfo.size() - 1);
                String productId = latest.path("product_id").asText("");
                long expiresMs = Long.parseLong(
                        latest.path("expires_date_ms").asText("0"));

                if (expiresMs > 0 && expiresMs < System.currentTimeMillis()) {
                    return IapVerifyResult.fail("Abonelik süresi dolmuş.");
                }

                String plan = normalizePlanId(productId);
                LOG.infof("Apple receipt geçerli — productId=%s plan=%s", productId, plan);
                return IapVerifyResult.ok(plan);
            }

            return IapVerifyResult.fail("Receipt içinde abonelik bulunamadı.");

        } catch (Exception e) {
            LOG.errorf(e, "Apple receipt doğrulama hatası");
            return IapVerifyResult.fail("App Store doğrulaması başarısız: " + e.getMessage());
        }
    }

    private JsonNode callApple(String url, String body) throws Exception {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofSeconds(20))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();
        HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
        return objectMapper.readTree(resp.body());
    }

    private String appleStatusMessage(int status) {
        return switch (status) {
            case 21000 -> "App Store isteği işlenemedi.";
            case 21002 -> "Receipt verisi geçersiz.";
            case 21003 -> "Receipt doğrulanamadı.";
            case 21004 -> "Shared secret hatalı.";
            case 21005 -> "App Store geçici olarak kullanılamıyor.";
            case 21006 -> "Abonelik aktif değil.";
            case 21007 -> "Sandbox receipt, production sunucusuna gönderildi.";
            case 21008 -> "Production receipt, sandbox sunucusuna gönderildi.";
            case 21010 -> "Bu hesap bulunamadı.";
            default    -> "Bilinmeyen App Store hatası (status=" + status + ").";
        };
    }

    // ─── Google Play ──────────────────────────────────────────────────────────

    private IapVerifyResult verifyGoogle(IapVerifyRequest req) {
        if (req.purchaseToken() == null || req.purchaseToken().isBlank()) {
            return IapVerifyResult.fail("Android purchase token boş.");
        }
        if ("__MISSING__".equals(googleServiceAccountJson)) {
            LOG.warn("Google service account yapılandırılmamış, dev moduna düşülüyor.");
            return verifyDev(req);
        }

        try {
            String accessToken = getGoogleAccessToken();
            String subscriptionId = toGoogleSubscriptionId(req.planId());
            String url = String.format(
                    GOOGLE_SUBS_URL,
                    googlePackageName,
                    subscriptionId,
                    req.purchaseToken()
            );

            HttpRequest httpReq = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(20))
                    .header("Authorization", "Bearer " + accessToken)
                    .GET()
                    .build();

            HttpResponse<String> resp = httpClient.send(
                    httpReq, HttpResponse.BodyHandlers.ofString());

            if (resp.statusCode() == 404) {
                return IapVerifyResult.fail("Purchase token geçersiz veya bulunamadı.");
            }
            if (resp.statusCode() != 200) {
                LOG.warnf("Google Play API hata — status=%d body=%s",
                        resp.statusCode(), resp.body());
                return IapVerifyResult.fail("Google Play doğrulaması başarısız (HTTP " + resp.statusCode() + ").");
            }

            JsonNode root = objectMapper.readTree(resp.body());

            // paymentState: 0=ödeme bekleniyor, 1=ödendi, 2=ücretsiz deneme
            int paymentState = root.path("paymentState").asInt(-1);
            if (paymentState != 1 && paymentState != 2) {
                return IapVerifyResult.fail("Ödeme tamamlanmamış (paymentState=" + paymentState + ").");
            }

            // expiryTimeMillis kontrolü
            long expiryMs = Long.parseLong(root.path("expiryTimeMillis").asText("0"));
            if (expiryMs > 0 && expiryMs < System.currentTimeMillis()) {
                return IapVerifyResult.fail("Google Play aboneliği süresi dolmuş.");
            }

            String plan = normalizePlanId(req.planId());
            LOG.infof("Google Play token geçerli — subscriptionId=%s plan=%s", subscriptionId, plan);
            return IapVerifyResult.ok(plan);

        } catch (Exception e) {
            LOG.errorf(e, "Google Play doğrulama hatası");
            return IapVerifyResult.fail("Google Play doğrulaması başarısız: " + e.getMessage());
        }
    }

    /**
     * Google service account JSON'dan OAuth2 access token alır.
     * JSON Web Token (JWT) ile Google OAuth2 token endpoint'ini çağırır.
     */
    private String getGoogleAccessToken() throws Exception {
        JsonNode sa = objectMapper.readTree(googleServiceAccountJson);
        String clientEmail = sa.path("client_email").asText();
        String privateKeyPem = sa.path("private_key").asText();

        // JWT oluştur
        long now = System.currentTimeMillis() / 1000;
        String header = base64Url(objectMapper.writeValueAsString(
                java.util.Map.of("alg", "RS256", "typ", "JWT")));
        String payload = base64Url(objectMapper.writeValueAsString(
                java.util.Map.of(
                        "iss", clientEmail,
                        "scope", "https://www.googleapis.com/auth/androidpublisher",
                        "aud", "https://oauth2.googleapis.com/token",
                        "iat", now,
                        "exp", now + 3600
                )));
        String signingInput = header + "." + payload;
        String signature = signRs256(signingInput, privateKeyPem);
        String jwt = signingInput + "." + signature;

        // Token endpoint çağrısı
        String form = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer"
                + "&assertion=" + jwt;
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create("https://oauth2.googleapis.com/token"))
                .timeout(Duration.ofSeconds(15))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(form))
                .build();
        HttpResponse<String> resp = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
        JsonNode tokenResp = objectMapper.readTree(resp.body());
        String token = tokenResp.path("access_token").asText("");
        if (token.isBlank()) {
            throw new RuntimeException(
                    "Google OAuth2 token alınamadı: " + tokenResp.path("error_description").asText());
        }
        return token;
    }

    private String base64Url(String json) {
        return java.util.Base64.getUrlEncoder().withoutPadding()
                .encodeToString(json.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    private String signRs256(String data, String pemKey) throws Exception {
        String keyContent = pemKey
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s+", "");
        byte[] keyBytes = java.util.Base64.getDecoder().decode(keyContent);
        java.security.spec.PKCS8EncodedKeySpec spec = new java.security.spec.PKCS8EncodedKeySpec(keyBytes);
        java.security.PrivateKey privateKey = java.security.KeyFactory.getInstance("RSA").generatePrivate(spec);
        java.security.Signature sig = java.security.Signature.getInstance("SHA256withRSA");
        sig.initSign(privateKey);
        sig.update(data.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(sig.sign());
    }

    // ─── Yardımcılar ──────────────────────────────────────────────────────────

    /**
     * Flutter ürün ID'sini backend plan ID'sine normalize eder.
     * "premium_monthly" → "monthly", "premium_yearly" → "yearly"
     */
    private String normalizePlanId(String productId) {
        if (productId == null) return "monthly";
        String lower = productId.toLowerCase();
        if (lower.contains("yearly") || lower.contains("annual") || lower.contains("year")) {
            return "yearly";
        }
        return "monthly";
    }

    /**
     * Plan ID'sini Google Play subscription ID formatına çevirir.
     * Google Play Console'daki ID'lerle eşleşmeli.
     */
    private String toGoogleSubscriptionId(String planId) {
        if (planId == null) return "premium_monthly";
        return planId.toLowerCase().contains("yearly") ? "premium_yearly" : "premium_monthly";
    }
}
