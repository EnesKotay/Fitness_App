package com.fitness.repository;

import java.util.List;

import com.fitness.entity.WorkoutSession;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class WorkoutSessionRepository implements PanacheRepository<WorkoutSession> {

    public List<WorkoutSession> findByUserIdOrderByFinishedAtDesc(Long userId) {
        return find("user.id = ?1 ORDER BY finishedAt DESC", userId).list();
    }
}
