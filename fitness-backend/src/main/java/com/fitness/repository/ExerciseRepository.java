package com.fitness.repository;

import java.util.List;

import com.fitness.entity.Exercise;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class ExerciseRepository implements PanacheRepository<Exercise> {

    public List<Exercise> findByMuscleGroup(String muscleGroup) {
        return list("muscleGroup", muscleGroup);
    }

    public List<String> findDistinctMuscleGroups() {
        return getEntityManager()
                .createQuery("SELECT DISTINCT e.muscleGroup FROM Exercise e ORDER BY e.muscleGroup", String.class)
                .getResultList();
    }
}
