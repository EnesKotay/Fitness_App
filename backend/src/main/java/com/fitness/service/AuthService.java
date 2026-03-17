package com.fitness.service;

import java.nio.charset.StandardCharsets;
import java.util.Date;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import com.fitness.dto.AuthResponse;
import com.fitness.dto.ChangePasswordRequest;
import com.fitness.dto.LoginRequest;
import com.fitness.dto.ProfileUpdateRequest;
import com.fitness.dto.RegisterRequest;
import com.fitness.dto.UserResponse;
import com.fitness.dto.WeightRecordRequest;
import com.fitness.entity.User;
import com.fitness.repository.UserRepository;
import com.fitness.entity.PasswordResetToken;
import com.fitness.dto.ForgotPasswordRequest;
import com.fitness.dto.VerifyResetCodeRequest;
import com.fitness.dto.ResetPasswordRequest;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.quarkus.mailer.Mail;
import io.quarkus.mailer.Mailer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.mindrot.jbcrypt.BCrypt;
import java.security.SecureRandom;

@ApplicationScoped
public class AuthService {

    private static final String HMAC_SHA256 = "HmacSHA256";
    private static final long JWT_LIFESPAN_MS = 86400L * 1000; // 24 saat

    @Inject
    UserRepository userRepository;

    @Inject
    TrackingService trackingService;

    @Inject
    Mailer mailer;

    @Inject
    @ConfigProperty(name = "smallrye.jwt.sign.key", defaultValue = "fitness-backend-jwt-secret-key-at-least-32-bytes-long")
    String jwtSignKey;

    /**
     * Kullanıcı kaydı - şifre BCrypt ile hash'lenir, cevap JWT döner.
     * Email küçük harfe normalize edilir; istemci tarafındaki hesap ayırımı
     * (suffix) ile uyumlu olur.
     */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String emailNorm = request.email == null ? null : request.email.trim().toLowerCase();
        if (emailNorm == null || emailNorm.isBlank()) {
            throw new RuntimeException("Email gerekli!");
        }
        User existingUser = userRepository.findByEmail(emailNorm);
        if (existingUser != null) {
            throw new RuntimeException("Bu email zaten kullanılıyor!");
        }

        User user = new User();
        user.email = emailNorm;
        user.password = BCrypt.hashpw(request.password, BCrypt.gensalt());
        user.name = request.name != null ? request.name.trim() : "";

        userRepository.persist(user);

        String token = buildJwt(user);
        UserResponse userResponse = toUserResponse(user);
        return new AuthResponse(token, userResponse);
    }

    /**
     * Kullanıcı girişi - şifre BCrypt veya eski düz metin (geçiş dönemi) ile
     * doğrulanır.
     * Eski düz metin şifre kabul edilirse bir sonraki giriş için BCrypt'e
     * yükseltilir.
     * Email büyük/küçük harf duyarsız aranır; dönen user her zaman giriş yapan
     * hesaba aittir (istemci hesap başına profil için buna güvenir).
     */
    @Transactional
    public AuthResponse login(LoginRequest request) {
        if (request.email == null || request.email.isBlank()) {
            throw new RuntimeException("Email gerekli!");
        }
        User user = userRepository.findByEmailIgnoreCase(request.email);
        if (user == null) {
            throw new RuntimeException("Email veya şifre hatalı!");
        }

        boolean passwordOk = false;
        if (isBcryptHash(user.password)) {
            passwordOk = BCrypt.checkpw(request.password, user.password);
        } else {
            // Eski kayıt: düz metin şifre (BCrypt eklenmeden önce)
            passwordOk = request.password.equals(user.password);
            if (passwordOk) {
                user.password = BCrypt.hashpw(request.password, BCrypt.gensalt());
                userRepository.persist(user);
            }
        }
        if (!passwordOk) {
            throw new RuntimeException("Email veya şifre hatalı!");
        }

        String token = buildJwt(user);
        UserResponse userResponse = toUserResponse(user);
        return new AuthResponse(token, userResponse);
    }

    /** BCrypt hash "$2a$", "$2b$", "$2y$" ile başlar. */
    private static boolean isBcryptHash(String stored) {
        return stored != null && stored.length() >= 4
                && stored.startsWith("$2")
                && (stored.charAt(2) == 'a' || stored.charAt(2) == 'b' || stored.charAt(2) == 'y')
                && stored.charAt(3) == '$';
    }

    private String buildJwt(User user) {
        String secret = (jwtSignKey != null && !jwtSignKey.isBlank())
                ? jwtSignKey
                : "fitness-backend-jwt-secret-key-at-least-32-bytes-long";
        SecretKey key = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), HMAC_SHA256);
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(user.id.toString())
                .issuer("fitness-backend")
                .claim("email", user.email)
                .claim("name", user.name)
                .issuedAt(new Date(now))
                .expiration(new Date(now + JWT_LIFESPAN_MS))
                .signWith(key)
                .compact();
    }

    /**
     * Yanıtta email her zaman küçük harf; istemci tarafındaki storage suffix ile
     * uyumlu.
     */
    private UserResponse toUserResponse(User user) {
        UserResponse r = new UserResponse();
        r.id = user.id;
        r.email = user.email == null ? null : user.email.trim().toLowerCase();
        r.name = user.name;
        r.height = user.height;
        r.weight = user.weight;
        r.targetWeight = user.targetWeight;
        r.birthDate = user.birthDate;
        r.gender = user.gender;
        r.premiumTier = user.premiumTier;
        r.premiumExpiresAt = user.premiumExpiresAt;
        r.premiumPlan = user.premiumPlan;
        r.premiumCancelAtPeriodEnd = user.premiumCancelAtPeriodEnd;
        r.premiumCanceledAt = user.premiumCanceledAt;
        r.createdAt = user.createdAt;
        r.updatedAt = user.updatedAt;
        return r;
    }

    /**
     * Kullanıcı bilgilerini getir (yanıtta email lowercase; toUserResponse kullan).
     */
    public UserResponse getUserById(Long userId) {
        User user = userRepository.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı!");
        }
        return toUserResponse(user);
    }

    /**
     * Authorization header'dan (Bearer &lt;token&gt;) JWT parse edip subject
     * (userId) döner.
     * Profil/me endpoint'leri bu userId ile token'dan gelen kullanıcıyı kullanmalı;
     * request parametresinden değil.
     */
    @Transactional
    public UserResponse updateProfile(Long userId, ProfileUpdateRequest request) {
        User user = userRepository.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanici bulunamadi!");
        }
        if (request == null) {
            throw new RuntimeException("Guncelleme verisi gerekli!");
        }
        if (request.name != null)
            user.name = request.name.trim();
        if (request.height != null)
            user.height = request.height;
        
        Double oldWeight = user.weight;
        if (request.weight != null) {
            user.weight = request.weight;
            // Eğer kilo değiştiyse veya yeni eklendiyse Takip/Kilo Geçmişi'ne de ekle
            if (oldWeight == null || !oldWeight.equals(request.weight)) {
                WeightRecordRequest recordRequest = new WeightRecordRequest();
                recordRequest.weight = request.weight;
                recordRequest.recordedAt = java.time.LocalDateTime.now();
                recordRequest.notes = "Profil güncellendi";
                try {
                    trackingService.createWeightRecord(userId, recordRequest);
                } catch (Exception e) {
                    // Kilo kaydı başarısız olsa bile profil güncellemesi devam etsin
                    System.err.println("Otomatik kilo kaydı hatası: " + e.getMessage());
                }
            }
        }

        if (request.targetWeight != null)
            user.targetWeight = request.targetWeight;
        if (request.birthDate != null)
            user.birthDate = request.birthDate;
        if (request.gender != null)
            user.gender = request.gender.trim();
        userRepository.persist(user);
        return toUserResponse(user);
    }

    @Transactional
    public void changePassword(Long userId, ChangePasswordRequest request) {
        User user = userRepository.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanici bulunamadi!");
        }
        if (request == null) {
            throw new RuntimeException("Sifre verisi gerekli!");
        }

        String current = request.currentPassword == null ? "" : request.currentPassword.trim();
        String next = request.newPassword == null ? "" : request.newPassword.trim();

        if (current.isEmpty() || next.isEmpty()) {
            throw new RuntimeException("Mevcut ve yeni sifre gerekli!");
        }
        if (next.length() < 6) {
            throw new RuntimeException("Yeni sifre en az 6 karakter olmali!");
        }

        boolean currentOk = isBcryptHash(user.password)
                ? BCrypt.checkpw(current, user.password)
                : current.equals(user.password);
        if (!currentOk) {
            throw new RuntimeException("Mevcut sifre hatali!");
        }
        if (current.equals(next)) {
            throw new RuntimeException("Yeni sifre mevcut sifre ile ayni olamaz!");
        }

        user.password = BCrypt.hashpw(next, BCrypt.gensalt());
        userRepository.persist(user);
    }

    public Long getUserIdFromToken(String authorizationHeader) {
        if (authorizationHeader == null) {
            throw new RuntimeException("Gecersiz veya eksik Authorization header");
        }
        String header = authorizationHeader.trim();
        if (!header.regionMatches(true, 0, "Bearer ", 0, 7)) {
            throw new RuntimeException("Gecersiz veya eksik Authorization header");
        }
        String token = header.substring(7).trim();
        if (token.isEmpty()) {
            throw new RuntimeException("Token boş");
        }
        String secret = (jwtSignKey != null && !jwtSignKey.isBlank())
                ? jwtSignKey
                : "fitness-backend-jwt-secret-key-at-least-32-bytes-long";
        SecretKey key = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), HMAC_SHA256);
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            String sub = claims.getSubject();
            if (sub == null || sub.isBlank()) {
                throw new RuntimeException("Token subject yok");
            }
            return Long.parseLong(sub);
        } catch (Exception e) {
            throw new RuntimeException("Geçersiz token: " + e.getMessage());
        }
    }

    /**
     * Şifre Sıfırlama İsteği: 6 haneli kod oluşturur, veritabanına yazar ve mail atar.
     */
    @Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        String emailNorm = request.email == null ? null : request.email.trim().toLowerCase();
        User user = userRepository.findByEmail(emailNorm);
        if (user == null) {
            // Güvenlik: Kullanıcı yoksa da "Email gönderildi" demek enumeration atağına karşı daha koruyucudur. 
            // Fakat mobil uygulama için kullanıcıya "Böyle bir hesap yok" demek daha makuldur.
            throw new RuntimeException("Bu email ile kayıtlı bir hesap bulunamadı.");
        }

        // Önceki tokenları sil
        PasswordResetToken.delete("user.id", user.id);

        // 6 Haneli yeni kod üret
        String code = generatePinCode();

        // 15 dakika geçerli olacak token'ı oluştur
        PasswordResetToken token = new PasswordResetToken(code, user, 15);
        token.persist();

        // Email Gönder
        String htmlBody = "<h2>Fitness Tracker</h2>"
                + "<p>Şifre sıfırlama talebinde bulundunuz.</p>"
                + "<p>Doğrulama kodunuz: <b style='font-size:24px; color:#CC7A4A;'>" + code + "</b></p>"
                + "<p>Kodunuz 15 dakika boyunca geçerlidir.</p>";

        try {
            mailer.send(Mail.withHtml(user.email, "Şifre Sıfırlama Kodu", htmlBody));
        } catch (Exception e) {
            System.err.println("=== MAIL GONDERIM HATASI ===");
            e.printStackTrace();
            System.err.println("============================");
            if (isSmtpFailure(e)) {
                throw new RuntimeException(
                        "Sifre sifirlama e-postasi gonderilemedi. Mail sunucusu ayarlarini kontrol edin (MAIL_USERNAME / MAIL_PASSWORD / MAIL_FROM).");
            }
            throw new RuntimeException("Sifre sifirlama e-postasi gonderilemedi. Lutfen daha sonra tekrar deneyin.");
        }
    }

    /**
     * Kod Doğrulama: Girilen email ve pin kodunun geçerliliğini test eder.
     */
    @Transactional
    public void verifyResetCode(VerifyResetCodeRequest request) {
        String emailNorm = request.email == null ? null : request.email.trim().toLowerCase();
        User user = userRepository.findByEmail(emailNorm);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı.");
        }

        PasswordResetToken token = PasswordResetToken.findById(request.code);
        if (token == null || !token.user.id.equals(user.id)) {
            throw new RuntimeException("Geçersiz veya hatalı doğrulama kodu.");
        }

        if (token.isExpired()) {
            throw new RuntimeException("Doğrulama kodunun süresi dolmuş. Lütfen tekrar kod isteyin.");
        }
    }

    /**
     * Şifreyi Sıfırla: Kodu tekrar doğrular ve yeni şifreyi BCrypt ile günceller.
     */
    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        String emailNorm = request.email == null ? null : request.email.trim().toLowerCase();
        User user = userRepository.findByEmail(emailNorm);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı.");
        }

        PasswordResetToken token = PasswordResetToken.findById(request.code);
        if (token == null || !token.user.id.equals(user.id)) {
            throw new RuntimeException("Geçersiz veya hatalı doğrulama kodu.");
        }

        if (token.isExpired()) {
            throw new RuntimeException("Doğrulama kodunun süresi dolmuş.");
        }

        if(request.newPassword.length() < 6){
             throw new RuntimeException("Şifre en az 6 karakter olmalıdır.");
        }

        // Yeni şifreyi kaydet
        user.password = BCrypt.hashpw(request.newPassword, BCrypt.gensalt());
        userRepository.persist(user);

        // Kodu sil (tek kullanımlık)
        token.delete();
    }

    private String generatePinCode() {
        SecureRandom random = new SecureRandom();
        int num = random.nextInt(1000000); // 0 ile 999999
        return String.format("%06d", num);
    }

    private boolean isSmtpFailure(Throwable error) {
        Throwable current = error;
        while (current != null) {
            String className = current.getClass().getName();
            String message = current.getMessage();
            String lowerMessage = message != null ? message.toLowerCase() : "";

            if (className.contains("SMTPException")
                    || lowerMessage.contains("smtp")
                    || lowerMessage.contains("auth plain failed")
                    || lowerMessage.contains("badcredentials")
                    || lowerMessage.contains("username and password not accepted")
                    || lowerMessage.contains("gsmtp")) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }
}
