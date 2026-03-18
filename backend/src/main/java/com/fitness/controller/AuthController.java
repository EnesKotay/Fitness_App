package com.fitness.controller;

import com.fitness.dto.AuthResponse;
import com.fitness.dto.ChangePasswordRequest;
import com.fitness.dto.LoginRequest;
import com.fitness.dto.ProfileUpdateRequest;
import com.fitness.dto.RegisterRequest;
import com.fitness.dto.UserResponse;
import com.fitness.dto.ForgotPasswordRequest;
import com.fitness.dto.VerifyResetCodeRequest;
import com.fitness.dto.ResetPasswordRequest;
import com.fitness.service.AuthRateLimiter;
import com.fitness.service.AuthService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;

@ApplicationScoped
@Path("/api/auth")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AuthController {

    @Inject
    AuthService authService;

    @Inject
    AuthRateLimiter rateLimiter;

    @Context
    UriInfo uriInfo;
    
    /**
     * Kullanıcı kaydı
     * POST /api/auth/register
     */
    @POST
    @Path("/register")
    public Response register(@Valid RegisterRequest request, @Context HttpHeaders headers) {
        String ip = resolveIp(headers);
        if (!rateLimiter.allowRegister(ip)) {
            return Response.status(429)
                    .header("Retry-After", rateLimiter.registerRetryAfter(ip))
                    .entity("{\"error\": \"Çok fazla kayıt denemesi. Lütfen bir saat sonra tekrar deneyin.\"}")
                    .build();
        }
        AuthResponse response = authService.register(request);
        return Response.status(Response.Status.CREATED)
                .entity(response)
                .build();
    }
    
    /**
     * Kullanıcı girişi
     * POST /api/auth/login
     */
    @POST
    @Path("/login")
    public Response login(@Valid LoginRequest request, @Context HttpHeaders headers) {
        String ip = resolveIp(headers);
        if (!rateLimiter.allowLogin(ip)) {
            return Response.status(429)
                    .header("Retry-After", rateLimiter.loginRetryAfter(ip))
                    .entity("{\"error\": \"Çok fazla giriş denemesi. Lütfen 15 dakika sonra tekrar deneyin.\"}")
                    .build();
        }
        AuthResponse response = authService.login(request);
        return Response.ok()
                .entity(response)
                .build();
    }
    
    /**
     * Mevcut kullanıcıyı token'dan döner (SecurityContext/principal yerine JWT parse).
     * İstemci bu endpoint'i kullanmalı; userId path'ten değil token'dan alınır.
     * GET /api/auth/me — Header: Authorization: Bearer &lt;token&gt;
     */
    @GET
    @Path("/me")
    public Response getMe(@Context HttpHeaders headers) {
        String auth = headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        Long userId = authService.getUserIdFromToken(auth);
        UserResponse response = authService.getUserById(userId);
        return Response.ok()
                .entity(response)
                .build();
    }

    /**
     * Profil güncelleme (sadece token'daki kullanıcı).
     * PUT /api/auth/me/profile
     */
    @PUT
    @Path("/me/profile")
    public Response updateMeProfile(@Context HttpHeaders headers, @Valid ProfileUpdateRequest request) {
        String auth = headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        Long userId = authService.getUserIdFromToken(auth);
        UserResponse response = authService.updateProfile(userId, request);
        return Response.ok()
                .entity(response)
                .build();
    }

    /**
     * Şifre güncelleme (sadece token'daki kullanıcı).
     * PUT /api/auth/me/password
     */
    @PUT
    @Path("/me/password")
    public Response updateMePassword(@Context HttpHeaders headers, @Valid ChangePasswordRequest request) {
        String auth = headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        Long userId = authService.getUserIdFromToken(auth);
        authService.changePassword(userId, request);
        return Response.noContent().build();
    }

    /**
     * Hesabı ve ilişkili tüm kullanıcı verilerini siler.
     * DELETE /api/auth/me
     */
    @DELETE
    @Path("/me")
    public Response deleteMe(@Context HttpHeaders headers) {
        String auth = headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        Long userId = authService.getUserIdFromToken(auth);
        authService.deleteAccount(userId);
        return Response.noContent().build();
    }

    /**
     * Kullanıcı bilgilerini getir — sadece token'daki userId ile path userId aynıysa döner (başka hesaba erişim engelli).
     * GET /api/auth/user/{userId}
     */
    @GET
    @Path("/user/{userId}")
    public Response getUser(@Context HttpHeaders headers, @PathParam("userId") Long userId) {
        String auth = headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        Long tokenUserId = authService.getUserIdFromToken(auth);
        if (!tokenUserId.equals(userId)) {
            return Response.status(Response.Status.FORBIDDEN)
                    .entity("{\"error\": \"Sadece kendi kullanıcı bilginize erişebilirsiniz.\"}")
                    .build();
        }
        UserResponse response = authService.getUserById(userId);
        return Response.ok()
                .entity(response)
                .build();
    }
    
    private String resolveIp(HttpHeaders headers) {
        String xff = headers.getHeaderString("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        String realIp = headers.getHeaderString("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return realIp.trim();
        }
        return "unknown";
    }

    /**
     * Test endpoint
     * GET /api/auth/test
     */
    @GET
    @Path("/test")
    public Response test() {
        return Response.ok()
                .entity("{\"message\": \"Auth endpoint çalışıyor!\"}")
                .build();
    }
    /**
     * Şifremi Unuttum (Kod Gönderme)
     * POST /api/auth/forgot-password
     */
    @POST
    @Path("/forgot-password")
    public Response forgotPassword(@Valid ForgotPasswordRequest request, @Context HttpHeaders headers) {
        String ip = resolveIp(headers);
        if (!rateLimiter.allowForgotPassword(ip)) {
            return Response.status(429)
                    .header("Retry-After", rateLimiter.forgotPasswordRetryAfter(ip))
                    .entity("{\"message\": \"Doğrulama kodu e-posta adresinize gönderildi.\"}")
                    .build();
        }
        authService.forgotPassword(request);
        return Response.ok()
                .entity("{\"message\": \"Doğrulama kodu e-posta adresinize gönderildi.\"}")
                .build();
    }

    /**
     * Kod Doğrulama
     * POST /api/auth/verify-reset-code
     */
    @POST
    @Path("/verify-reset-code")
    public Response verifyResetCode(@Valid VerifyResetCodeRequest request) {
        authService.verifyResetCode(request);
        return Response.ok()
                .entity("{\"message\": \"Doğrulama kodu geçerli.\"}")
                .build();
    }

    /**
     * Şifreyi Yenileme (Reset)
     * POST /api/auth/reset-password
     */
    @POST
    @Path("/reset-password")
    public Response resetPassword(@Valid ResetPasswordRequest request) {
        authService.resetPassword(request);
        return Response.ok()
                .entity("{\"message\": \"Şifreniz başarıyla sıfırlandı. Yeni şifrenizle giriş yapabilirsiniz.\"}")
                .build();
    }
}
