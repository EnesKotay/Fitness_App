package com.fitness.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fitness.entity.Recipe;
import com.fitness.entity.User;
import com.fitness.service.AuthService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
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
@Path("/api/recipes")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class RecipeController {

    @Inject
    AuthService authService;

    @Inject
    ObjectMapper objectMapper;

    @GET
    public Response getRecipes(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            List<Recipe> recipes = Recipe.find("user.id = ?1 order by createdAt desc", userId).list();
            List<Map<String, Object>> result = recipes.stream()
                    .map(this::toMap)
                    .collect(Collectors.toList());
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    @POST
    @Transactional
    public Response upsertRecipe(@Context HttpHeaders headers, Map<String, Object> body) {
        try {
            Long userId = resolveUserId(headers);
            User user = User.findById(userId);
            if (user == null) return Response.status(Response.Status.NOT_FOUND).build();

            String externalId = getString(body, "id", null);
            if (externalId == null || externalId.isBlank()) {
                return Response.status(400).entity(Map.of("error", "id is required")).build();
            }

            Recipe recipe = Recipe.find("user.id = ?1 and externalId = ?2", userId, externalId).firstResult();
            boolean isNew = recipe == null;
            if (isNew) {
                recipe = new Recipe();
                recipe.user = user;
                recipe.externalId = externalId;
            }
            populateFromBody(recipe, body);
            recipe.persist();

            return isNew
                    ? Response.status(Response.Status.CREATED).entity(toMap(recipe)).build()
                    : Response.ok(toMap(recipe)).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    @DELETE
    @Path("/{externalId}")
    @Transactional
    public Response deleteRecipe(@Context HttpHeaders headers, @PathParam("externalId") String externalId) {
        try {
            Long userId = resolveUserId(headers);
            long deleted = Recipe.delete("user.id = ?1 and externalId = ?2", userId, externalId);
            if (deleted == 0) return Response.status(Response.Status.NOT_FOUND).build();
            return Response.noContent().build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    private void populateFromBody(Recipe r, Map<String, Object> body) {
        r.name = getString(body, "name", "");
        r.description = getString(body, "description", "");
        r.category = getString(body, "category", "ana_yemek");
        r.servings = getInt(body, "servings", 1);
        r.prepTimeMinutes = getInt(body, "prepTimeMinutes", 0);
        r.cookTimeMinutes = getInt(body, "cookTimeMinutes", 0);
        r.imageEmoji = getString(body, "imageEmoji", "🍽️");
        r.kcalPerServing = getDouble(body, "kcalPerServing", 0);
        r.proteinPerServing = getDouble(body, "proteinPerServing", 0);
        r.carbPerServing = getDouble(body, "carbPerServing", 0);
        r.fatPerServing = getDouble(body, "fatPerServing", 0);
        r.fiberPerServing = getDouble(body, "fiberPerServing", 0);
        r.sugarPerServing = getDouble(body, "sugarPerServing", 0);
        r.difficulty = getString(body, "difficulty", "orta");

        try {
            r.tags = objectMapper.writeValueAsString(body.getOrDefault("tags", List.of()));
            r.ingredients = objectMapper.writeValueAsString(body.getOrDefault("ingredients", List.of()));
            r.steps = objectMapper.writeValueAsString(body.getOrDefault("steps", List.of()));
        } catch (Exception e) {
            r.tags = "[]";
            r.ingredients = "[]";
            r.steps = "[]";
        }
    }

    private Map<String, Object> toMap(Recipe r) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", r.externalId);
        m.put("name", r.name != null ? r.name : "");
        m.put("description", r.description != null ? r.description : "");
        m.put("category", r.category != null ? r.category : "ana_yemek");
        m.put("servings", r.servings);
        m.put("prepTimeMinutes", r.prepTimeMinutes);
        m.put("cookTimeMinutes", r.cookTimeMinutes);
        m.put("imageEmoji", r.imageEmoji != null ? r.imageEmoji : "🍽️");
        m.put("kcalPerServing", r.kcalPerServing);
        m.put("proteinPerServing", r.proteinPerServing);
        m.put("carbPerServing", r.carbPerServing);
        m.put("fatPerServing", r.fatPerServing);
        m.put("fiberPerServing", r.fiberPerServing);
        m.put("sugarPerServing", r.sugarPerServing);
        m.put("difficulty", r.difficulty != null ? r.difficulty : "orta");
        try {
            m.put("tags", r.tags != null ? objectMapper.readValue(r.tags, List.class) : List.of());
            m.put("ingredients", r.ingredients != null ? objectMapper.readValue(r.ingredients, List.class) : List.of());
            m.put("steps", r.steps != null ? objectMapper.readValue(r.steps, List.class) : List.of());
        } catch (Exception e) {
            m.put("tags", List.of());
            m.put("ingredients", List.of());
            m.put("steps", List.of());
        }
        return m;
    }

    private String getString(Map<String, Object> body, String key, String def) {
        Object v = body.get(key);
        return v != null ? v.toString() : def;
    }

    private int getInt(Map<String, Object> body, String key, int def) {
        Object v = body.get(key);
        return v instanceof Number ? ((Number) v).intValue() : def;
    }

    private double getDouble(Map<String, Object> body, String key, double def) {
        Object v = body.get(key);
        return v instanceof Number ? ((Number) v).doubleValue() : def;
    }

    private Long resolveUserId(HttpHeaders headers) {
        String auth = headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        return authService.getUserIdFromToken(auth);
    }
}
