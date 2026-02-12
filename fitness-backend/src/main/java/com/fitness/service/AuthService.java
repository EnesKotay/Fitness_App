package com.fitness.service;

import java.nio.charset.StandardCharsets;
import java.util.Date;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import com.fitness.dto.AuthResponse;
import com.fitness.dto.LoginRequest;
import com.fitness.dto.RegisterRequest;
import com.fitness.dto.UserResponse;
import com.fitness.entity.User;
import com.fitness.repository.UserRepository;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.mindrot.jbcrypt.BCrypt;

@ApplicationScoped
public class AuthService {

    private static final String HMAC_SHA256 = "HmacSHA256";
    private static final long JWT_LIFESPAN_MS = 86400L * 1000; // 24 saat

    @Inject
    UserRepository userRepository;

    @Inject
    @ConfigProperty(name = "smallrye.jwt.sign.key", defaultValue = "fitness-backend-jwt-secret-key-at-least-32-bytes-long")
    String jwtSignKey;

    /**
     * Kullanıcı kaydı - şifre BCrypt ile hash'lenir, cevap JWT döner.
     * Email küçük harfe normalize edilir; istemci tarafındaki hesap ayırımı (suffix) ile uyumlu olur.
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
     * Kullanıcı girişi - şifre BCrypt veya eski düz metin (geçiş dönemi) ile doğrulanır.
     * Eski düz metin şifre kabul edilirse bir sonraki giriş için BCrypt'e yükseltilir.
     * Email büyük/küçük harf duyarsız aranır; dönen user her zaman giriş yapan hesaba aittir (istemci hesap başına profil için buna güvenir).
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

    /** Yanıtta email her zaman küçük harf; istemci tarafındaki storage suffix ile uyumlu. */
    private UserResponse toUserResponse(User user) {
        UserResponse r = new UserResponse();
        r.id = user.id;
        r.email = user.email == null ? null : user.email.trim().toLowerCase();
        r.name = user.name;
        r.createdAt = user.createdAt;
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
     * Authorization header'dan (Bearer &lt;token&gt;) JWT parse edip subject (userId) döner.
     * Profil/me endpoint'leri bu userId ile token'dan gelen kullanıcıyı kullanmalı; request parametresinden değil.
     */
    public Long getUserIdFromToken(String authorizationHeader) {
        if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
            throw new RuntimeException("Geçersiz veya eksik Authorization header");
        }
        String token = authorizationHeader.substring(7).trim();
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
}