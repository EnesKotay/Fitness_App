package com.fitness.repository;

import com.fitness.entity.WeightRecord;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;

@ApplicationScoped
public class WeightRecordRepository implements PanacheRepository<WeightRecord> {
    
    public List<WeightRecord> findByUserId(Long userId) {
        return find("user.id", userId).list();
    }
    
    public List<WeightRecord> findByUserIdOrderByRecordedAtDesc(Long userId) {
        return find("user.id = ?1 ORDER BY recordedAt DESC", userId).list();
    }
}