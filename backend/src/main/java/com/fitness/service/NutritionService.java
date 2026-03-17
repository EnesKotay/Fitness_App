package com.fitness.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import com.fitness.dto.MealRequest;
import com.fitness.dto.MealResponse;
import com.fitness.entity.Meal;
import com.fitness.entity.User;
import com.fitness.repository.MealRepository;
import com.fitness.repository.UserRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class NutritionService {
    
    @Inject
    MealRepository mealRepository;
    
    @Inject
    UserRepository userRepository;
    
    /**
     * Yeni yemek kaydı oluştur
     */
    @Transactional
    public MealResponse createMeal(Long userId, MealRequest request) {
        validateCreateRequest(request);

        User user = userRepository.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı!");
        }
        
        Meal meal = new Meal();
        meal.user = user;
        meal.name = request.name;
        meal.mealType = request.mealType;
        meal.calories = request.calories;
        meal.protein = request.protein;
        meal.carbs = request.carbs;
        meal.fat = request.fat;
        meal.mealDate = request.mealDate != null ? request.mealDate : LocalDateTime.now();
        meal.notes = request.notes;
        // @PrePersist otomatik çağrılacak
        
        mealRepository.persist(meal);
        
        return toResponse(meal);
    }
    
    /**
     * Kullanıcının tüm yemek kayıtlarını getir
     */
    public List<MealResponse> getUserMeals(Long userId) {
        List<Meal> meals = mealRepository.findByUserIdOrderByMealDateDesc(userId);
        return meals.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }
    
    /**
     * Belirli bir tarihteki yemekleri getir
     */
    public List<MealResponse> getMealsByDate(Long userId, LocalDate date) {
        LocalDateTime startOfDay = date.atStartOfDay();
        LocalDateTime nextDayStart = date.plusDays(1).atStartOfDay();
        
        List<Meal> meals = mealRepository.find(
            "user.id = ?1 AND mealDate >= ?2 AND mealDate < ?3 ORDER BY mealDate DESC",
            userId, startOfDay, nextDayStart
        ).list();
        
        return meals.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }
    
    /**
     * Günlük kalori toplamını hesapla
     */
    public Integer getDailyCalories(Long userId, LocalDate date) {
        List<MealResponse> meals = getMealsByDate(userId, date);
        return meals.stream()
                .mapToInt(m -> m.calories != null ? m.calories : 0)
                .sum();
    }
    
    /**
     * Yemek kaydını güncelle
     */
    @Transactional
    public MealResponse updateMeal(Long userId, Long mealId, MealRequest request) {
        Meal meal = mealRepository.findById(mealId);
        
        if (meal == null || !meal.user.id.equals(userId)) {
            throw new RuntimeException("Yemek kaydı bulunamadı veya yetkiniz yok!");
        }
        
        if (request.calories != null && request.calories < 0) {
            throw new RuntimeException("Kalori değeri 0'dan küçük olamaz.");
        }
        if (request.name != null && request.name.trim().isEmpty()) {
            throw new RuntimeException("Yemek adı boş olamaz.");
        }
        if (request.mealType != null && request.mealType.trim().isEmpty()) {
            throw new RuntimeException("Öğün tipi boş olamaz.");
        }

        if (request.name != null) meal.name = request.name;
        if (request.mealType != null) meal.mealType = request.mealType;
        if (request.calories != null) meal.calories = request.calories;
        if (request.protein != null) meal.protein = request.protein;
        if (request.carbs != null) meal.carbs = request.carbs;
        if (request.fat != null) meal.fat = request.fat;
        if (request.mealDate != null) meal.mealDate = request.mealDate;
        if (request.notes != null) meal.notes = request.notes;
        
        // @PreUpdate otomatik çağrılacak
        mealRepository.persist(meal);
        
        return toResponse(meal);
    }
    
    /**
     * Yemek kaydını sil
     */
    @Transactional
    public void deleteMeal(Long userId, Long mealId) {
        Meal meal = mealRepository.findById(mealId);
        
        if (meal == null || !meal.user.id.equals(userId)) {
            throw new RuntimeException("Yemek kaydı bulunamadı veya yetkiniz yok!");
        }
        
        mealRepository.delete(meal);
    }
    
    /**
     * Entity'yi Response'a çevir
     */
    private MealResponse toResponse(Meal meal) {
        MealResponse response = new MealResponse();
        response.id = meal.id;
        response.name = meal.name;
        response.mealType = meal.mealType;
        response.calories = meal.calories;
        response.protein = meal.protein;
        response.carbs = meal.carbs;
        response.fat = meal.fat;
        response.mealDate = meal.mealDate;
        response.notes = meal.notes;
        response.createdAt = meal.createdAt;
        response.updatedAt = meal.updatedAt;
        return response;
    }

    private void validateCreateRequest(MealRequest request) {
        if (request == null) {
            throw new RuntimeException("Yemek isteği boş olamaz.");
        }
        if (request.name == null || request.name.trim().isEmpty()) {
            throw new RuntimeException("Yemek adı zorunludur.");
        }
        if (request.mealType == null || request.mealType.trim().isEmpty()) {
            throw new RuntimeException("Öğün tipi zorunludur.");
        }
        if (request.calories == null || request.calories < 0) {
            throw new RuntimeException("Geçerli bir kalori değeri girilmelidir.");
        }
    }
}
