package com.fitness.repository;

import com.fitness.entity.BodyMeasurement;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import io.quarkus.panache.common.Page;
import io.quarkus.panache.common.Parameters;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class BodyMeasurementRepository implements PanacheRepository<BodyMeasurement> {

    public List<BodyMeasurement> findByUserIdOrderByDateDesc(Long userId) {
        return find("userId = ?1 ORDER BY date DESC", userId).list();
    }

    public Optional<BodyMeasurement> findByUserIdAndDate(Long userId, LocalDate date) {
        return find("userId = ?1 AND date = ?2", userId, date).firstResultOptional();
    }

    public List<BodyMeasurement> findWithFilters(Long userId, LocalDate startDate, LocalDate endDate, int pageIndex, int pageSize) {
        StringBuilder query = new StringBuilder("userId = :userId");
        Parameters params = Parameters.with("userId", userId);

        if (startDate != null) {
            query.append(" AND date >= :startDate");
            params.and("startDate", startDate);
        }
        if (endDate != null) {
            query.append(" AND date <= :endDate");
            params.and("endDate", endDate);
        }

        query.append(" ORDER BY date DESC");

        return find(query.toString(), params)
                .page(Page.of(pageIndex, pageSize))
                .list();
    }
}
