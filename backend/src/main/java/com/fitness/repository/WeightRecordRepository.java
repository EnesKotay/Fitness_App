package com.fitness.repository;

import com.fitness.entity.WeightRecord;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import io.quarkus.panache.common.Page;
import io.quarkus.panache.common.Parameters;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.LocalDateTime;
import java.util.List;

@ApplicationScoped
public class WeightRecordRepository implements PanacheRepository<WeightRecord> {
    
    public List<WeightRecord> findByUserId(Long userId) {
        return find("user.id", userId).list();
    }
    
    public List<WeightRecord> findByUserIdOrderByRecordedAtDesc(Long userId) {
        return find("user.id = ?1 ORDER BY recordedAt DESC", userId).list();
    }

    public WeightRecord findLatestByUserId(Long userId) {
        return find("user.id = ?1 ORDER BY recordedAt DESC, id DESC", userId).firstResult();
    }

    public List<WeightRecord> findWithFilters(Long userId, LocalDateTime startDate, LocalDateTime endDate, int pageIndex, int pageSize) {
        StringBuilder query = new StringBuilder("user.id = :userId");
        Parameters params = Parameters.with("userId", userId);

        if (startDate != null) {
            query.append(" AND recordedAt >= :startDate");
            params.and("startDate", startDate);
        }
        if (endDate != null) {
            query.append(" AND recordedAt <= :endDate");
            params.and("endDate", endDate);
        }

        query.append(" ORDER BY recordedAt DESC");

        return find(query.toString(), params)
                .page(Page.of(pageIndex, pageSize))
                .list();
    }
}
