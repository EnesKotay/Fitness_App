package com.fitness.resource;

import com.fitness.dto.ExerciseLibraryDTO;
import com.fitness.service.ExerciseLibraryService;
import jakarta.annotation.security.PermitAll;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;

import java.util.List;

@Path("/api/exercises")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ExerciseLibraryResource {

    @Inject
    ExerciseLibraryService exerciseService;

    @Inject
    JsonWebToken jwt;

    /**
     * Get all exercises
     * Query params:
     *   - language: tr, en, es, it, ru, zh (default: tr)
     *   - category: waist, chest, back, upper arms, etc.
     *   - equipment: body weight, dumbbell, barbell, etc.
     *   - target: abs, biceps, pectorals, etc.
     *   - search: search by name
     */
    @GET
    @PermitAll
    public Response getExercises(
            @QueryParam("language") @DefaultValue("tr") String language,
            @QueryParam("category") String category,
            @QueryParam("equipment") String equipment,
            @QueryParam("target") String target,
            @QueryParam("search") String search
    ) {
        List<ExerciseLibraryDTO> exercises;

        if (search != null && !search.trim().isEmpty()) {
            exercises = exerciseService.searchByName(search, language);
        } else if (category != null && !category.trim().isEmpty()) {
            exercises = exerciseService.getByCategory(category, language);
        } else if (equipment != null && !equipment.trim().isEmpty()) {
            exercises = exerciseService.getByEquipment(equipment, language);
        } else if (target != null && !target.trim().isEmpty()) {
            exercises = exerciseService.getByTarget(target, language);
        } else {
            exercises = exerciseService.getAllExercises(language);
        }

        return Response.ok(exercises).build();
    }

    /**
     * Get exercise by ID
     */
    @GET
    @Path("/{id}")
    @PermitAll
    public Response getExerciseById(
            @PathParam("id") String id,
            @QueryParam("language") @DefaultValue("tr") String language
    ) {
        ExerciseLibraryDTO exercise = exerciseService.getById(id, language);
        if (exercise == null) {
            return Response.status(Response.Status.NOT_FOUND).build();
        }
        return Response.ok(exercise).build();
    }

    /**
     * Get bodyweight exercises (no equipment)
     */
    @GET
    @Path("/bodyweight")
    @PermitAll
    public Response getBodyweightExercises(
            @QueryParam("language") @DefaultValue("tr") String language
    ) {
        List<ExerciseLibraryDTO> exercises = exerciseService.getBodyweightExercises(language);
        return Response.ok(exercises).build();
    }

    /**
     * Get unique categories
     */
    @GET
    @Path("/categories")
    @PermitAll
    public Response getCategories() {
        List<String> categories = List.of(
            "waist",
            "upper arms",
            "upper legs",
            "back",
            "chest",
            "shoulders",
            "lower legs",
            "lower arms",
            "cardio",
            "neck"
        );
        return Response.ok(categories).build();
    }

    /**
     * Get unique equipment types
     */
    @GET
    @Path("/equipment")
    @PermitAll
    public Response getEquipmentTypes() {
        List<String> equipment = List.of(
            "body weight",
            "dumbbell",
            "cable",
            "barbell",
            "leverage machine",
            "band",
            "smith machine",
            "kettlebell",
            "weighted",
            "stability ball",
            "ez barbell"
        );
        return Response.ok(equipment).build();
    }
}
