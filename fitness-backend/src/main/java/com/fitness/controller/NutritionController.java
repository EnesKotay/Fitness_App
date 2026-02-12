package com.fitness.controller;

import java.time.LocalDate;
import java.util.List;

import com.fitness.dto.MealRequest;
import com.fitness.dto.MealResponse;
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
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
@Path("/api/nutrition")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class NutritionController {
    
    @Inject
    NutritionService nutritionService;
    
    /**
     * Yeni yemek kaydı oluştur
     * POST /api/nutrition/users/{userId}/meals
     */
    @POST
    @Path("/users/{userId}/meals")
    public Response createMeal(
            @PathParam("userId") Long userId,
            MealRequest request) {
        try {
            MealResponse response = nutritionService.createMeal(userId, request);
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
     * Kullanıcının tüm yemek kayıtlarını getir
     * GET /api/nutrition/users/{userId}/meals
     */
    @GET
    @Path("/users/{userId}/meals")
    public Response getUserMeals(@PathParam("userId") Long userId) {
        try {
            List<MealResponse> meals = nutritionService.getUserMeals(userId);
            return Response.ok()
                    .entity(meals)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Belirli bir tarihteki yemekleri getir
     * GET /api/nutrition/users/{userId}/meals/date?date=2024-01-26
     */
    @GET
    @Path("/users/{userId}/meals/date")
    public Response getMealsByDate(
            @PathParam("userId") Long userId,
            @QueryParam("date") String dateString) {
        try {
            LocalDate date = LocalDate.parse(dateString);
            List<MealResponse> meals = nutritionService.getMealsByDate(userId, date);
            return Response.ok()
                    .entity(meals)
                    .build();
        } catch (Exception e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"Geçersiz tarih formatı. Örnek: 2024-01-26\"}")
                    .build();
        }
    }
    
    /**
     * Günlük kalori toplamını hesapla
     * GET /api/nutrition/users/{userId}/calories?date=2024-01-26
     */
    @GET
    @Path("/users/{userId}/calories")
    public Response getDailyCalories(
            @PathParam("userId") Long userId,
            @QueryParam("date") String dateString) {
        try {
            LocalDate date = LocalDate.parse(dateString);
            Integer totalCalories = nutritionService.getDailyCalories(userId, date);
            return Response.ok()
                    .entity("{\"date\": \"" + dateString + "\", \"totalCalories\": " + totalCalories + "}")
                    .build();
        } catch (Exception e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"Geçersiz tarih formatı. Örnek: 2024-01-26\"}")
                    .build();
        }
    }
    
    /**
     * Yemek kaydını güncelle
     * PUT /api/nutrition/users/{userId}/meals/{mealId}
     */
    @PUT
    @Path("/users/{userId}/meals/{mealId}")
    public Response updateMeal(
            @PathParam("userId") Long userId,
            @PathParam("mealId") Long mealId,
            MealRequest request) {
        try {
            MealResponse response = nutritionService.updateMeal(userId, mealId, request);
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
     * Yemek kaydını sil
     * DELETE /api/nutrition/users/{userId}/meals/{mealId}
     */
    @DELETE
    @Path("/users/{userId}/meals/{mealId}")
    public Response deleteMeal(
            @PathParam("userId") Long userId,
            @PathParam("mealId") Long mealId) {
        try {
            nutritionService.deleteMeal(userId, mealId);
            return Response.noContent()
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
}