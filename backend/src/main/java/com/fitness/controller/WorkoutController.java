package com.fitness.controller;

import java.util.List;
import java.util.Map;

import com.fitness.dto.WorkoutRequest;
import com.fitness.dto.WorkoutResponse;
import com.fitness.service.AuthService;
import com.fitness.service.WorkoutService;

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

@ApplicationScoped
@Path("/api/workouts")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class WorkoutController {
    
    @Inject WorkoutService workoutService;
    @Inject AuthService   authService;

    // ── CRUD ──────────────────────────────────────────────────────────────────

    /** POST /api/workouts/me — yeni antrenman oluştur */
    @POST
    @Path("/me")
    public Response createWorkout(@Context HttpHeaders headers, @Valid WorkoutRequest request) {
        Long userId = getUserId(headers);
        WorkoutResponse res = workoutService.createWorkout(userId, request);
        return Response.status(Response.Status.CREATED).entity(res).build();
    }

    /** GET /api/workouts/me — kullanıcının tüm antrenmanları */
    @GET
    @Path("/me")
    public Response getUserWorkouts(@Context HttpHeaders headers) {
        Long userId = getUserId(headers);
        List<WorkoutResponse> list = workoutService.getUserWorkouts(userId);
        return Response.ok(list).build();
    }

    /** GET /api/workouts/me/{workoutId} — tek antrenman */
    @GET
    @Path("/me/{workoutId}")
    public Response getWorkoutById(@Context HttpHeaders headers, @PathParam("workoutId") Long workoutId) {
        Long userId = getUserId(headers);
        WorkoutResponse res = workoutService.getWorkoutById(userId, workoutId);
        return Response.ok(res).build();
    }

    /** PUT /api/workouts/me/{workoutId} — antrenmanı güncelle */
    @PUT
    @Path("/me/{workoutId}")
    public Response updateWorkout(@Context HttpHeaders headers,
                                  @PathParam("workoutId") Long workoutId,
                                  @Valid WorkoutRequest request) {
        Long userId = getUserId(headers);
        WorkoutResponse res = workoutService.updateWorkout(userId, workoutId, request);
        return Response.ok(res).build();
    }

    /** DELETE /api/workouts/me/{workoutId} — antrenmanı sil */
    @DELETE
    @Path("/me/{workoutId}")
    public Response deleteWorkout(@Context HttpHeaders headers, @PathParam("workoutId") Long workoutId) {
        Long userId = getUserId(headers);
        workoutService.deleteWorkout(userId, workoutId);
        return Response.noContent().build();
    }

    // ── Yeni endpoint'ler ─────────────────────────────────────────────────────

    /**
     * GET /api/workouts/me/exercise/{name}/history
     * Belirli bir egzersizin tüm geçmişini döndürür (ağırlık trendi için).
     */
    @GET
    @Path("/me/exercise/{name}/history")
    public Response getExerciseHistory(@Context HttpHeaders headers, @PathParam("name") String name) {
        Long userId = getUserId(headers);
        List<WorkoutResponse> history = workoutService.getExerciseHistory(userId, name);
        return Response.ok(history).build();
    }

    /**
     * GET /api/workouts/me/personal-records
     * Her egzersiz için kişisel rekorları (en yüksek 1RM) döndürür.
     * Yanıt: { "Lat Pulldown": 95.0, "Bench Press": 110.0, ... }
     */
    @GET
    @Path("/me/personal-records")
    public Response getPersonalRecords(@Context HttpHeaders headers) {
        Long userId = getUserId(headers);
        Map<String, Double> prs = workoutService.getPersonalRecords(userId);
        return Response.ok(prs).build();
    }

    /**
     * GET /api/workouts/me/stats
     * Özet istatistikler: toplam antrenman, set, hacim (kg), kalori, en sık kas grubu.
     */
    @GET
    @Path("/me/stats")
    public Response getWorkoutStats(@Context HttpHeaders headers) {
        Long userId = getUserId(headers);
        Map<String, Object> stats = workoutService.getWorkoutStats(userId);
        return Response.ok(stats).build();
    }

    // ── Utilities ─────────────────────────────────────────────────────────────

    private Long getUserId(HttpHeaders headers) {
        return authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
    }
}
