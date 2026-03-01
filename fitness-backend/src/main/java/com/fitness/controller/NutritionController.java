package com.fitness.controller;

import java.time.LocalDate;
import java.util.List;

import com.fitness.dto.MealRequest;
import com.fitness.dto.MealResponse;
import com.fitness.service.AuthService;
import com.fitness.service.NutritionService;

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
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
@Path("/api/nutrition")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class NutritionController {
    
    @Inject
    NutritionService nutritionService;

    @Inject
    AuthService authService;
    
    /**
     * Yeni yemek kaydı oluştur
     * POST /api/nutrition/me/meals
     */
    @POST
    @Path("/me/meals")
    public Response createMeal(
            @Context HttpHeaders headers,
            MealRequest request) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            MealResponse response = nutritionService.createMeal(userId, request);
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
     * Kullanıcının tüm yemek kayıtlarını getir
     * GET /api/nutrition/me/meals
     */
    @GET
    @Path("/me/meals")
    public Response getUserMeals(@Context HttpHeaders headers) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            List<MealResponse> meals = nutritionService.getUserMeals(userId);
            return Response.ok()
                    .entity(meals)
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
     * Belirli bir tarihteki yemekleri getir
     * GET /api/nutrition/me/meals/date?date=2024-01-26
     */
    @GET
    @Path("/me/meals/date")
    public Response getMealsByDate(
            @Context HttpHeaders headers,
            @QueryParam("date") String dateString) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            LocalDate date = LocalDate.parse(dateString);
            List<MealResponse> meals = nutritionService.getMealsByDate(userId, date);
            return Response.ok()
                    .entity(meals)
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"Geçersiz tarih formatı. Örnek: 2024-01-26\"}")
                    .build();
        } catch (Exception e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"Geçersiz tarih formatı. Örnek: 2024-01-26\"}")
                    .build();
        }
    }
    
    /**
     * Günlük kalori toplamını hesapla
     * GET /api/nutrition/me/calories?date=2024-01-26
     */
    @GET
    @Path("/me/calories")
    public Response getDailyCalories(
            @Context HttpHeaders headers,
            @QueryParam("date") String dateString) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            LocalDate date = LocalDate.parse(dateString);
            Integer totalCalories = nutritionService.getDailyCalories(userId, date);
            return Response.ok()
                    .entity("{\"date\": \"" + dateString + "\", \"totalCalories\": " + totalCalories + "}")
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"Geçersiz tarih formatı. Örnek: 2024-01-26\"}")
                    .build();
        } catch (Exception e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"Geçersiz tarih formatı. Örnek: 2024-01-26\"}")
                    .build();
        }
    }
    
    /**
     * Yemek kaydını güncelle
     * PUT /api/nutrition/me/meals/{mealId}
     */
    @PUT
    @Path("/me/meals/{mealId}")
    public Response updateMeal(
            @Context HttpHeaders headers,
            @PathParam("mealId") Long mealId,
            MealRequest request) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            MealResponse response = nutritionService.updateMeal(userId, mealId, request);
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
     * Yemek kaydını sil
     * DELETE /api/nutrition/me/meals/{mealId}
     */
    @DELETE
    @Path("/me/meals/{mealId}")
    public Response deleteMeal(
            @Context HttpHeaders headers,
            @PathParam("mealId") Long mealId) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            nutritionService.deleteMeal(userId, mealId);
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
