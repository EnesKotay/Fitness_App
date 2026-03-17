package com.fitness.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Base64;
import java.util.UUID;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Ödeme servisi — Iyzico entegrasyonu.
 *
 * Konfigürasyon (application.properties):
 *   payment.provider          = iyzico | sandbox
 *   iyzico.api.key            = sandbox-xxx veya live-xxx
 *   iyzico.secret.key         = sandbox-xxx veya live-xxx
 *   iyzico.base.url           = https://sandbox-api.iyzipay.com  (test)
 *                               https://api.iyzipay.com          (prod)
 *
 * "sandbox" provider seçilirse gerçek ödeme isteksiz, her başarılı kart
 * simüle edilir (geliştirme/test için).
 */
@ApplicationScoped
public class PaymentService {

    private static final Logger LOG = Logger.getLogger(PaymentService.class);

    // Test kartı: bu numaralarla sandbox'ta gerçek Iyzico isteği de başarılı olur
    private static final String TEST_CARD_SUCCESS = "5528790000000008";
    private static final String TEST_CARD_SUCCESS_2 = "4766620000000001";

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "payment.provider", defaultValue = "sandbox")
    String provider;

    @ConfigProperty(name = "iyzico.api.key", defaultValue = "__MISSING__")
    String iyzicoApiKey;

    @ConfigProperty(name = "iyzico.secret.key", defaultValue = "__MISSING__")
    String iyzicoSecretKey;

    @ConfigProperty(name = "iyzico.base.url", defaultValue = "https://sandbox-api.iyzipay.com")
    String iyzicoBaseUrl;

    private final HttpClient httpClient = HttpClient.newHttpClient();

    // ─── Public API ───────────────────────────────────────────────────────────

    /**
     * Karttan ödeme al.
     *
     * @param req ödeme isteği (kart bilgileri + tutar)
     * @return PaymentResult (başarı/hata + transactionId)
     */
    public PaymentResult charge(PaymentRequest req) {
        if ("sandbox".equalsIgnoreCase(provider)) {
            return sandboxCharge(req);
        }
        return iyzicoCharge(req);
    }

    // ─── Sandbox (test) ───────────────────────────────────────────────────────

    /**
     * Gerçek API çağrısı yapmadan simüle eder.
     * Sandbox modunda format geçerliyse tüm kartlar başarılı sayılır.
     * Sadece '0000...' ile başlayan test reddedilen kartlar hata döner.
     */
    private PaymentResult sandboxCharge(PaymentRequest req) {
        LOG.infof("[SANDBOX] Payment attempt userId=%d plan=%s amount=%d",
                req.userId(), req.planId(), req.amountKurus());

        // Sandbox: sadece açıkça geçersiz kartları reddet (tüm 0'lar veya 1'ler)
        String card = req.cardNumber();
        boolean isObviouslyFake = card.matches("0{16}") || card.matches("1{16}");

        if (isObviouslyFake) {
            LOG.warnf("[SANDBOX] Payment declined - obviously fake card");
            return PaymentResult.failure("Geçersiz kart numarası.");
        }

        // Sandbox modunda formatı geçerli olan tüm kartları kabul et
        String txId = "SANDBOX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        LOG.infof("[SANDBOX] Payment success txId=%s cardPrefix=%s",
                txId, card.substring(0, Math.min(6, card.length())));
        return PaymentResult.success(txId);
    }

    // ─── Iyzico ──────────────────────────────────────────────────────────────

    /**
     * Iyzico REST API üzerinden 3D-sız ödeme (non-3DS).
     * Üretim ortamında 3D-Secure kullanmak için iyzico/v2/payment/3dsecure
     * endpoint'ini kullanın.
     */
    private PaymentResult iyzicoCharge(PaymentRequest req) {
        try {
            if ("__MISSING__".equals(iyzicoApiKey) || "__MISSING__".equals(iyzicoSecretKey)) {
                LOG.error("Iyzico API key veya Secret key yapılandırılmamış!");
                return PaymentResult.failure(
                        "Ödeme sistemi yapılandırılmamış. Lütfen yöneticiyle iletişime geçin.");
            }

            String conversationId = UUID.randomUUID().toString();
            ObjectNode body = buildIyzicoPayload(req, conversationId);
            String bodyJson = objectMapper.writeValueAsString(body);

            String authHeader = buildIyzicoAuthHeader(bodyJson);

            HttpRequest httpRequest = HttpRequest.newBuilder()
                    .uri(URI.create(iyzicoBaseUrl + "/payment/auth"))
                    .timeout(Duration.ofSeconds(30))
                    .header("Content-Type", "application/json")
                    .header("Authorization", authHeader)
                    .header("x-iyzi-rnd", conversationId)
                    .POST(HttpRequest.BodyPublishers.ofString(bodyJson))
                    .build();

            HttpResponse<String> response = httpClient.send(
                    httpRequest, HttpResponse.BodyHandlers.ofString());

            return parseIyzicoResponse(response.body(), conversationId);

        } catch (Exception e) {
            LOG.errorf(e, "Iyzico payment error");
            return PaymentResult.failure("Ödeme sırasında teknik hata oluştu. Lütfen tekrar deneyin.");
        }
    }

    private ObjectNode buildIyzicoPayload(PaymentRequest req, String conversationId) {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("locale", "tr");
        root.put("conversationId", conversationId);
        root.put("price", formatAmount(req.amountKurus()));
        root.put("paidPrice", formatAmount(req.amountKurus()));
        root.put("currency", "TRY");
        root.put("installment", 1);
        root.put("paymentChannel", "MOBILE");
        root.put("paymentGroup", "SUBSCRIPTION");

        // Kart bilgileri
        ObjectNode card = objectMapper.createObjectNode();
        card.put("cardHolderName", req.cardHolder());
        card.put("cardNumber", req.cardNumber());
        card.put("expireMonth", req.expiryMonth());
        card.put("expireYear", "20" + req.expiryYear());
        card.put("cvc", req.cvv());
        card.put("registerCard", 0);
        root.set("paymentCard", card);

        // Alıcı bilgileri (Iyzico zorunlu alanlar)
        ObjectNode buyer = objectMapper.createObjectNode();
        buyer.put("id", String.valueOf(req.userId()));
        buyer.put("name", req.cardHolder().contains(" ")
                ? req.cardHolder().substring(0, req.cardHolder().lastIndexOf(' '))
                : req.cardHolder());
        buyer.put("surname", req.cardHolder().contains(" ")
                ? req.cardHolder().substring(req.cardHolder().lastIndexOf(' ') + 1)
                : "User");
        buyer.put("email", req.email());
        buyer.put("identityNumber", "11111111111"); // TC kimlik (sandbox)
        buyer.put("registrationAddress", "Türkiye");
        buyer.put("city", "Istanbul");
        buyer.put("country", "Turkey");
        root.set("buyer", buyer);

        // Fatura adresi
        ObjectNode address = objectMapper.createObjectNode();
        address.put("contactName", req.cardHolder());
        address.put("city", "Istanbul");
        address.put("country", "Turkey");
        address.put("address", "Türkiye");
        root.set("shippingAddress", address);
        root.set("billingAddress", address);

        // Ürün
        ObjectNode item = objectMapper.createObjectNode();
        item.put("id", req.planId());
        item.put("name", "Premium Üyelik - " + req.planId());
        item.put("category1", "Subscription");
        item.put("itemType", "VIRTUAL");
        item.put("price", formatAmount(req.amountKurus()));
        root.putArray("basketItems").add(item);

        return root;
    }

    private PaymentResult parseIyzicoResponse(String responseBody, String conversationId) throws Exception {
        JsonNode root = objectMapper.readTree(responseBody);
        String status = root.path("status").asText("");

        if ("success".equalsIgnoreCase(status)) {
            String paymentId = root.path("paymentId").asText(conversationId);
            LOG.infof("Iyzico payment success paymentId=%s", paymentId);
            return PaymentResult.success(paymentId);
        } else {
            String errorCode    = root.path("errorCode").asText("UNKNOWN");
            String errorMessage = root.path("errorMessage").asText("Ödeme reddedildi.");
            LOG.warnf("Iyzico payment failed errorCode=%s message=%s", errorCode, errorMessage);
            return PaymentResult.failure(translateIyzicoError(errorCode, errorMessage));
        }
    }

    /** Iyzico hata kodlarını Türkçe kullanıcı mesajına çevirir. */
    private String translateIyzicoError(String errorCode, String raw) {
        return switch (errorCode) {
            case "10005" -> "Kart bilgileri hatalı. Lütfen kontrol et.";
            case "10012" -> "Kart işlemi reddedildi. Lütfen bankanızla iletişime geçin.";
            case "10034" -> "Kart yetersiz bakiye.";
            case "10041" -> "Kayıp/çalıntı kart.";
            case "10043" -> "İşlem limite takıldı. Lütfen bankanızı arayın.";
            case "10051" -> "Kartınızda yeterli limit yok.";
            default      -> "Ödeme reddedildi: " + raw;
        };
    }

    /**
     * Iyzico HMAC-SHA256 Authorization başlığı oluşturur.
     * Format: IYZWSv2 apiKey:signature
     */
    private String buildIyzicoAuthHeader(String body) throws Exception {
        String rnd = UUID.randomUUID().toString();
        String toSign = iyzicoApiKey + rnd + iyzicoSecretKey + body;
        javax.crypto.Mac mac = javax.crypto.Mac.getInstance("HmacSHA256");
        mac.init(new javax.crypto.spec.SecretKeySpec(
                iyzicoSecretKey.getBytes(java.nio.charset.StandardCharsets.UTF_8), "HmacSHA256"));
        byte[] hash = mac.doFinal(toSign.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        String signature = Base64.getEncoder().encodeToString(hash);
        return "IYZWSv2 apiKey=" + iyzicoApiKey + "&randomKey=" + rnd + "&signature=" + signature;
    }

    private String formatAmount(int kuruş) {
        // Iyzico ondalık TRY bekler: 14900 kuruş → "149.00"
        return String.format("%.2f", kuruş / 100.0);
    }

    // ─── DTOs ─────────────────────────────────────────────────────────────────

    public record PaymentRequest(
            Long userId,
            String email,
            String cardNumber,
            String expiryMonth,
            String expiryYear,
            String cvv,
            String cardHolder,
            int amountKurus,
            String planId
    ) {}

    public record PaymentResult(boolean success, String transactionId, String errorMessage) {
        public static PaymentResult success(String txId) {
            return new PaymentResult(true, txId, null);
        }

        public static PaymentResult failure(String error) {
            return new PaymentResult(false, null, error);
        }
    }
}
