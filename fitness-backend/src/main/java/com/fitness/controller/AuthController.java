package com.fitness.controller;

import com.fitness.dto.AuthResponse;
import com.fitness.dto.LoginRequest;
import com.fitness.dto.RegisterRequest;
import com.fitness.dto.UserResponse;
import com.fitness.service.AuthService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
@Path("/api/auth")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AuthController {
    
    @Inject
    AuthService authService;
    
    /**
     * Kullanıcı kaydı
     * POST /api/auth/register
     */
    @POST
    @Path("/register")
    public Response register(RegisterRequest request) {
        try {
            AuthResponse response = authService.register(request);
            return Response.status(Response.Status.CREATED)
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Kullanıcı girişi
     * POST /api/auth/login
     */
    @POST
    @Path("/login")
    public Response login(LoginRequest request) {
        try {
            AuthResponse response = authService.login(request);
            return Response.ok()
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Mevcut kullanıcıyı token'dan döner (SecurityContext/principal yerine JWT parse).
     * İstemci bu endpoint'i kullanmalı; userId path'ten değil token'dan alınır.
     * GET /api/auth/me — Header: Authorization: Bearer &lt;token&gt;
     */
    @GET
    @Path("/me")
    public Response getMe(@Context HttpHeaders headers) {
        try {
            String auth = headers.getHeaderString(HttpHeaders.AUTHORIZATION);
            Long userId = authService.getUserIdFromToken(auth);
            UserResponse response = authService.getUserById(userId);
            return Response.ok()
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }

    /**
     * Kullanıcı bilgilerini getir — sadece token'daki userId ile path userId aynıysa döner (başka hesaba erişim engelli).
     * GET /api/auth/user/{userId}
     */
    @GET
    @Path("/user/{userId}")
    public Response getUser(@Context HttpHeaders headers, @PathParam("userId") Long userId) {
        try {
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
        } catch (RuntimeException e) {
            if (e.getMessage() != null && e.getMessage().startsWith("Kullanıcı bulunamadı")) {
                return Response.status(Response.Status.NOT_FOUND)
                        .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                        .build();
            }
            return Response.status(Response.Status.UNAUTHORIZED)
                    .entity("{\"error\": \"" + escapeJson(e.getMessage()) + "\"}")
                    .build();
        }
    }

    private static String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
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
}