package com.fitness.repository;

import java.util.List;

import com.fitness.entity.AiFeedback;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class AiFeedbackRepository implements PanacheRepository<AiFeedback> {

    public List<AiFeedback> findRecentPositive(Long userId, int limit) {
        return find("userId = ?1 and reaction = 'POSITIVE' order by createdAt desc", userId)
                .page(0, limit)
                .list();
    }

    public List<AiFeedback> findRecentNegative(Long userId, int limit) {
        return find("userId = ?1 and reaction = 'NEGATIVE' order by createdAt desc", userId)
                .page(0, limit)
                .list();
    }
}
