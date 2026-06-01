package com.fitness.service;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.Signature;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fitness.entity.User;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

/**
 * Apple App Store Server Notifications V2 işleyicisi.
 *
 * Apple, abonelik yenileme / iptal / bitiş gibi olaylarda bu endpoint'e
 * imzalı JWS payload gönderir. Servis:
 *   1. JWS imzasını Apple sertifika zinciriyle doğrular.
 *   2. Bildirim tipini okur.
 *   3. originalTransactionId ile kullanıcıyı bulur.
 *   4. premiumExpiresAt / premiumCancelAtPeriodEnd'i günceller.
 *
 * Konfigürasyon (application.properties / env):
 *   iap.apple.bundle-id  → Info.plist Bundle ID
 */
@ApplicationScoped
public class AppleNotificationService {

    private static final Logger LOG = Logger.getLogger(AppleNotificationService.class);

    // Apple Root CA - G3 subject name parçası (sertifika zinciri doğrulaması için)
    private static final String APPLE_ROOT_CA_SUBJECT = "Apple Root CA";

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "iap.apple.bundle-id", defaultValue = "com.eneskotay.fitnessapp")
    String expectedBundleId;

    // ─── Ana giriş noktası ────────────────────────────────────────────────────

    /**
     * Apple'dan gelen raw signed payload'ı işler.
     * @return işlemin başarılı olup olmadığı (loglama için)
     */
    @Transactional
    public boolean process(String signedPayload) {
        try {
            JsonNode outerPayload = verifyAndDecodeJws(signedPayload);
            return handleNotification(outerPayload);
        } catch (Exception e) {
            LOG.errorf(e, "Apple bildirim işlenemedi");
            return false;
        }
    }

    // ─── JWS Doğrulama ────────────────────────────────────────────────────────

    /**
     * Apple'ın JWS compact serialization formatını doğrular ve payload'ı döner.
     * Format: base64url(header).base64url(payload).base64url(signature)
     */
    private JsonNode verifyAndDecodeJws(String jws) throws Exception {
        String[] parts = jws.split("\\.");
        if (parts.length != 3) {
            throw new IllegalArgumentException("Geçersiz JWS formatı: " + parts.length + " parça");
        }

        Base64.Decoder decoder = Base64.getUrlDecoder();
        String headerJson  = new String(decoder.decode(parts[0]), StandardCharsets.UTF_8);
        String payloadJson = new String(decoder.decode(parts[1]), StandardCharsets.UTF_8);
        byte[] signature   = decoder.decode(parts[2]);

        // Header'dan x5c sertifika zincirini al
        JsonNode header = objectMapper.readTree(headerJson);
        JsonNode x5c    = header.get("x5c");
        if (x5c == null || !x5c.isArray() || x5c.size() < 2) {
            throw new IllegalArgumentException("JWS header'da geçerli x5c zinciri yok");
        }

        List<X509Certificate> chain = buildCertChain(x5c);
        validateCertChain(chain);

        // ES256 imza doğrulama: imzalanan veri = "header.payload" (ASCII)
        byte[] signingInput = (parts[0] + "." + parts[1]).getBytes(StandardCharsets.US_ASCII);
        Signature ecSig = Signature.getInstance("SHA256withECDSA");
        ecSig.initVerify(chain.get(0).getPublicKey());
        ecSig.update(signingInput);
        if (!ecSig.verify(toDerSignature(signature))) {
            throw new SecurityException("Apple JWS imzası geçersiz");
        }

        return objectMapper.readTree(payloadJson);
    }

    private byte[] toDerSignature(byte[] joseSignature) {
        if (joseSignature.length != 64) {
            return joseSignature;
        }
        byte[] r = derInteger(Arrays.copyOfRange(joseSignature, 0, 32));
        byte[] s = derInteger(Arrays.copyOfRange(joseSignature, 32, 64));
        int sequenceLength = r.length + s.length;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(0x30);
        out.write(sequenceLength);
        out.writeBytes(r);
        out.writeBytes(s);
        return out.toByteArray();
    }

    private byte[] derInteger(byte[] value) {
        int offset = 0;
        while (offset < value.length - 1 && value[offset] == 0) {
            offset++;
        }
        byte[] normalized = Arrays.copyOfRange(value, offset, value.length);
        boolean needsPositivePadding = (normalized[0] & 0x80) != 0;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(0x02);
        out.write(normalized.length + (needsPositivePadding ? 1 : 0));
        if (needsPositivePadding) {
            out.write(0x00);
        }
        out.writeBytes(normalized);
        return out.toByteArray();
    }

    private List<X509Certificate> buildCertChain(JsonNode x5c) throws Exception {
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        List<X509Certificate> chain = new ArrayList<>();
        Base64.Decoder b64 = Base64.getDecoder();
        for (JsonNode certNode : x5c) {
            byte[] certBytes = b64.decode(certNode.asText());
            chain.add((X509Certificate) cf.generateCertificate(new ByteArrayInputStream(certBytes)));
        }
        return chain;
    }

    private void validateCertChain(List<X509Certificate> chain) throws Exception {
        // Her sertifikanın bir sonraki sertifika tarafından imzalandığını doğrula
        for (int i = 0; i < chain.size() - 1; i++) {
            try {
                chain.get(i).verify(chain.get(i + 1).getPublicKey());
            } catch (Exception e) {
                throw new SecurityException("Sertifika zinciri doğrulaması başarısız: index=" + i);
            }
        }
        // Kök sertifika Apple'a ait olmalı
        X509Certificate root = chain.get(chain.size() - 1);
        String subject = root.getSubjectX500Principal().getName();
        if (!subject.contains("Apple") || !subject.contains("Root")) {
            throw new SecurityException("Kök CA Apple değil: " + subject);
        }
    }

    // ─── Bildirim İşleyici ────────────────────────────────────────────────────

    private boolean handleNotification(JsonNode payload) throws Exception {
        String notificationType = payload.path("notificationType").asText("");
        String subtype          = payload.path("subtype").asText("");

        LOG.infof("Apple bildirim alındı — type=%s subtype=%s", notificationType, subtype);

        // Bundle ID kontrolü
        JsonNode data = payload.path("data");
        String bundleId = data.path("bundleId").asText("");
        if (!expectedBundleId.isBlank() && !expectedBundleId.equals(bundleId)) {
            LOG.warnf("Bundle ID uyuşmuyor: expected=%s actual=%s", expectedBundleId, bundleId);
            return false;
        }

        // signedTransactionInfo — asıl abonelik detayları
        String signedTxInfo = data.path("signedTransactionInfo").asText("");
        if (signedTxInfo.isBlank()) {
            LOG.warn("signedTransactionInfo eksik, bildirim işlenemiyor");
            return false;
        }

        JsonNode txInfo = verifyAndDecodeJws(signedTxInfo);
        String originalTxId = txInfo.path("originalTransactionId").asText("");
        long   expiresMs    = txInfo.path("expiresDate").asLong(0);

        if (originalTxId.isBlank()) {
            LOG.warn("originalTransactionId boş");
            return false;
        }

        User user = User.find("iapOriginalTransactionId", originalTxId).firstResult();
        if (user == null) {
            // İlk satın alma purchase flow'da kayıt edilmemiş olabilir; logla ve geç.
            LOG.warnf("originalTransactionId için kullanıcı bulunamadı: %s", originalTxId);
            return false;
        }

        return switch (notificationType) {
            case "SUBSCRIBED"                -> onSubscribed(user, txInfo, expiresMs);
            case "DID_RENEW"                 -> onRenew(user, txInfo, expiresMs);
            case "EXPIRED"                   -> onExpired(user, subtype);
            case "REVOKE", "REFUND"          -> onRevoke(user, notificationType);
            case "DID_CHANGE_RENEWAL_STATUS" -> onRenewalStatusChange(user, subtype);
            default -> {
                LOG.infof("Bilinmeyen/önemsiz bildirim tipi: %s", notificationType);
                yield true;
            }
        };
    }

    // ─── Olay İşleyicileri ────────────────────────────────────────────────────

    /** SUBSCRIBED: yeniden abone olma (resubscribe) ya da ilk abonelik */
    private boolean onSubscribed(User user, JsonNode txInfo, long expiresMs) {
        String productId = txInfo.path("productId").asText("");
        String plan = normalizePlan(productId);
        if (plan == null) {
            LOG.warnf("Tanınmayan productId: %s", productId);
            return false;
        }
        user.premiumTier = "premium";
        user.premiumPlan = plan;
        user.premiumExpiresAt = toLocalDateTime(expiresMs);
        user.premiumCancelAtPeriodEnd = false;
        user.premiumCanceledAt = null;
        user.persist();
        LOG.infof("SUBSCRIBED — userId=%d plan=%s expiresAt=%s", user.id, plan, user.premiumExpiresAt);
        return true;
    }

    /** DID_RENEW: otomatik yenileme başarılı — bitiş tarihini uzat */
    private boolean onRenew(User user, JsonNode txInfo, long expiresMs) {
        String productId = txInfo.path("productId").asText("");
        String plan = normalizePlan(productId);
        LocalDateTime newExpiry = toLocalDateTime(expiresMs);

        user.premiumTier = "premium";
        if (plan != null) user.premiumPlan = plan;
        user.premiumExpiresAt = newExpiry;
        user.premiumCancelAtPeriodEnd = false;
        user.premiumCanceledAt = null;
        user.persist();
        LOG.infof("DID_RENEW — userId=%d newExpiresAt=%s", user.id, newExpiry);
        return true;
    }

    /** EXPIRED: abonelik sona erdi */
    private boolean onExpired(User user, String subtype) {
        user.premiumTier = "free";
        user.premiumExpiresAt = LocalDateTime.now();
        user.premiumCancelAtPeriodEnd = false;
        user.persist();
        LOG.infof("EXPIRED (subtype=%s) — userId=%d premium sonlandırıldı", subtype, user.id);
        return true;
    }

    /** REVOKE / REFUND: iade veya iptal — premium hemen kaldır */
    private boolean onRevoke(User user, String type) {
        user.premiumTier = "free";
        user.premiumExpiresAt = LocalDateTime.now();
        user.premiumCancelAtPeriodEnd = false;
        user.premiumCanceledAt = LocalDateTime.now();
        user.persist();
        LOG.infof("%s — userId=%d premium hemen kaldırıldı", type, user.id);
        return true;
    }

    /** DID_CHANGE_RENEWAL_STATUS: kullanıcı otomatik yenilemeyi açtı/kapattı */
    private boolean onRenewalStatusChange(User user, String subtype) {
        boolean autoRenewDisabled = "AUTO_RENEW_DISABLED".equals(subtype);
        user.premiumCancelAtPeriodEnd = autoRenewDisabled;
        if (autoRenewDisabled && user.premiumCanceledAt == null) {
            user.premiumCanceledAt = LocalDateTime.now();
        } else if (!autoRenewDisabled) {
            user.premiumCanceledAt = null;
        }
        user.persist();
        LOG.infof("DID_CHANGE_RENEWAL_STATUS (subtype=%s) — userId=%d cancelAtPeriodEnd=%b",
                subtype, user.id, autoRenewDisabled);
        return true;
    }

    // ─── Yardımcılar ──────────────────────────────────────────────────────────

    private LocalDateTime toLocalDateTime(long epochMs) {
        if (epochMs <= 0) return LocalDateTime.now().plusMonths(1);
        return Instant.ofEpochMilli(epochMs).atZone(ZoneOffset.UTC).toLocalDateTime();
    }

    private String normalizePlan(String productId) {
        if (productId == null) return null;
        String lower = productId.toLowerCase();
        if (lower.contains("yearly") || lower.contains("annual") || lower.contains("year")) return "yearly";
        if (lower.contains("monthly") || lower.contains("month")) return "monthly";
        return null;
    }
}
