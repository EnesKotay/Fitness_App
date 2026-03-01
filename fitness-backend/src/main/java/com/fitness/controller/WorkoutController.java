package com.fitness.controller;

import java.util.List;

import com.fitness.dto.WorkoutRequest;
import com.fitness.dto.WorkoutResponse;
import com.fitness.service.AuthService;
import com.fitness.service.WorkoutService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
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

@ApplicationScoped
@Path("/api/workouts")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class WorkoutController {
    
    @Inject
    WorkoutService workoutService;

    @Inject
    AuthService authService;
    
    /**
     * Yeni antrenman kaydı oluştur
     * POST /api/workouts/me
     */
    @POST
    @Path("/me")
    public Response createWorkout(
            @Context HttpHeaders headers,
            WorkoutRequest request) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            WorkoutResponse response = workoutService.createWorkout(userId, request);
            return Response.status(Response.Status.CREATED)
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }
    
    /**
     * Kullanıcının tüm antrenmanlarını getir
     * GET /api/workouts/me
     */
    @GET
    @Path("/me")
    public Response getUserWorkouts(@Context HttpHeaders headers) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            List<WorkoutResponse> workouts = workoutService.getUserWorkouts(userId);
            return Response.ok()
                    .entity(workouts)
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }
    
    /**
     * Belirli bir antrenmanı getir
     * GET /api/workouts/me/{workoutId}
     */
    @GET
    @Path("/me/{workoutId}")
    public Response getWorkoutById(
            @Context HttpHeaders headers,
            @PathParam("workoutId") Long workoutId) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            WorkoutResponse response = workoutService.getWorkoutById(userId, workoutId);
            return Response.ok()
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }
    
    /**
     * Antrenman kaydını güncelle
     * PUT /api/workouts/me/{workoutId}
     */
    @PUT
    @Path("/me/{workoutId}")
    public Response updateWorkout(
            @Context HttpHeaders headers,
            @PathParam("workoutId") Long workoutId,
            WorkoutRequest request) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            WorkoutResponse response = workoutService.updateWorkout(userId, workoutId, request);
            return Response.ok()
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }
    
    /**
     * Antrenman kaydını sil
     * DELETE /api/workouts/me/{workoutId}
     */
    @DELETE
    @Path("/me/{workoutId}")
    public Response deleteWorkout(
            @Context HttpHeaders headers,
            @PathParam("workoutId") Long workoutId) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            workoutService.deleteWorkout(userId, workoutId);
            return Response.noContent()
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }

    private static boolean isAuthFailure(RuntimeException e) {
        String m = e.getMessage();
        return m != null && (m.contains("Authorization") || m.contains("Token") || m.contains("Geçersiz token"));
    }

    private static String escape(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }
}
