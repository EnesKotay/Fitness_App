package com.fitness.controller;

import java.util.List;

import com.fitness.dto.WorkoutRequest;
import com.fitness.dto.WorkoutResponse;
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
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
@Path("/api/workouts")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class WorkoutController {
    
    @Inject
    WorkoutService workoutService;
    
    /**
     * Yeni antrenman kaydı oluştur
     * POST /api/workouts/users/{userId}
     */
    @POST
    @Path("/users/{userId}")
    public Response createWorkout(
            @PathParam("userId") Long userId,
            WorkoutRequest request) {
        try {
            WorkoutResponse response = workoutService.createWorkout(userId, request);
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
     * Kullanıcının tüm antrenmanlarını getir
     * GET /api/workouts/users/{userId}
     */
    @GET
    @Path("/users/{userId}")
    public Response getUserWorkouts(@PathParam("userId") Long userId) {
        try {
            List<WorkoutResponse> workouts = workoutService.getUserWorkouts(userId);
            return Response.ok()
                    .entity(workouts)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Belirli bir antrenmanı getir
     * GET /api/workouts/users/{userId}/{workoutId}
     */
    @GET
    @Path("/users/{userId}/{workoutId}")
    public Response getWorkoutById(
            @PathParam("userId") Long userId,
            @PathParam("workoutId") Long workoutId) {
        try {
            WorkoutResponse response = workoutService.getWorkoutById(userId, workoutId);
            return Response.ok()
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Antrenman kaydını güncelle
     * PUT /api/workouts/users/{userId}/{workoutId}
     */
    @PUT
    @Path("/users/{userId}/{workoutId}")
    public Response updateWorkout(
            @PathParam("userId") Long userId,
            @PathParam("workoutId") Long workoutId,
            WorkoutRequest request) {
        try {
            WorkoutResponse response = workoutService.updateWorkout(userId, workoutId, request);
            return Response.ok()
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Antrenman kaydını sil
     * DELETE /api/workouts/users/{userId}/{workoutId}
     */
    @DELETE
    @Path("/users/{userId}/{workoutId}")
    public Response deleteWorkout(
            @PathParam("userId") Long userId,
            @PathParam("workoutId") Long workoutId) {
        try {
            workoutService.deleteWorkout(userId, workoutId);
            return Response.noContent()
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
}