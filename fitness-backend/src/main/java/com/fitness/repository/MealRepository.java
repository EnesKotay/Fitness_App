package com.fitness.repository;

import com.fitness.entity.Meal;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;

@ApplicationScoped
public class MealRepository implements PanacheRepository<Meal> {
    
    public List<Meal> findByUserId(Long userId) {
        return find("user.id", userId).list();
    }
    
    public List<Meal> findByUserIdOrderByMealDateDesc(Long userId) {
        return find("user.id = ?1 ORDER BY mealDate DESC", userId).list();
    }
}