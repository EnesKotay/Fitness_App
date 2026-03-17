package com.fitness.repository;

import java.util.List;

import com.fitness.entity.WorkoutSet;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class WorkoutSetRepository implements PanacheRepository<WorkoutSet> {

    public List<WorkoutSet> findByWorkoutId(Long workoutId) {
        return find("workout.id = ?1 ORDER BY setNumber ASC", workoutId).list();
    }

    public void deleteByWorkoutId(Long workoutId) {
        delete("workout.id", workoutId);
    }
}
