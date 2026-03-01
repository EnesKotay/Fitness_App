package com.fitness.controller;

import java.util.List;

import com.fitness.dto.ExerciseResponse;
import com.fitness.service.ExerciseService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
@Path("/api/exercises")
@Produces(MediaType.APPLICATION_JSON)
public class ExerciseController {

    @Inject
    ExerciseService exerciseService;

    /**
     * Tüm kas gruplarını getirir (bölge seçimi için).
     * GET /api/exercises/groups
     */
    @GET
    @Path("/groups")
    public Response getMuscleGroups() {
        List<String> groups = exerciseService.getMuscleGroups();
        return Response.ok(groups).build();
    }

    /**
     * Belirli bir kas grubuna ait egzersizleri getirir.
     * GET /api/exercises?muscleGroup=CHEST
     */
    @GET
    public Response getExercises(@QueryParam("muscleGroup") String muscleGroup) {
        if (muscleGroup == null || muscleGroup.isBlank()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"muscleGroup gerekli\"}")
                    .build();
        }
        List<ExerciseResponse> exercises = exerciseService.getExercisesByMuscleGroup(muscleGroup.trim());
        return Response.ok(exercises).build();
    }
}
