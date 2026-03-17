package com.fitness.repository;

import java.util.List;

import com.fitness.entity.Workout;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class WorkoutRepository implements PanacheRepository<Workout> {
    
    public List<Workout> findByUserId(Long userId) {
        return find("user.id", userId).list();
    }
    
    public List<Workout> findByUserIdOrderByWorkoutDateDesc(Long userId) {
        return find("user.id = ?1 ORDER BY workoutDate DESC", userId).list();
    }
}