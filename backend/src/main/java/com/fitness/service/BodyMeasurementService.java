package com.fitness.service;

import com.fitness.dto.BodyMeasurementRequest;
import com.fitness.dto.BodyMeasurementResponse;
import com.fitness.entity.BodyMeasurement;
import com.fitness.repository.BodyMeasurementRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.stream.Collectors;

@ApplicationScoped
public class BodyMeasurementService {

    @Inject
    BodyMeasurementRepository repository;

    @Transactional
    public BodyMeasurementResponse createMeasurement(Long userId, BodyMeasurementRequest request) {
        if (request == null || request.date == null) {
            throw new RuntimeException("Tarih zorunludur.");
        }
        validateHasAtLeastOneMeasurement(request);

        BodyMeasurement entity = repository.findByUserIdAndDate(userId, request.date)
                .orElseGet(() -> {
                    BodyMeasurement created = new BodyMeasurement();
                    created.setUserId(userId);
                    created.setDate(request.date);
                    return created;
                });

        entity.setChest(request.chest);
        entity.setWaist(request.waist);
        entity.setHips(request.hips);
        entity.setLeftArm(request.leftArm);
        entity.setRightArm(request.rightArm);
        entity.setLeftLeg(request.leftLeg);
        entity.setRightLeg(request.rightLeg);

        repository.persist(entity);
        return toResponse(entity);
    }

    public List<BodyMeasurementResponse> getUserMeasurements(Long userId, java.time.LocalDate startDate, java.time.LocalDate endDate, Integer page, Integer size) {
        int pIndex = (page != null) ? page : 0;
        int pSize = (size != null) ? size : 50;

        return repository.findWithFilters(userId, startDate, endDate, pIndex, pSize)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    public List<BodyMeasurementResponse> getUserMeasurements(Long userId) {
        return getUserMeasurements(userId, null, null, 0, 1000);
    }

    @Transactional
    public BodyMeasurementResponse updateMeasurement(Long userId, Long measurementId, BodyMeasurementRequest request) {
        if (request == null) {
            throw new RuntimeException("Guncellenecek veri bulunamadi.");
        }

        BodyMeasurement entity = repository.findById(measurementId);
        if (entity == null || !entity.getUserId().equals(userId)) {
            throw new RuntimeException("Olcum bulunamadi veya yetkiniz yok.");
        }

        if (request.date != null && !request.date.equals(entity.getDate())) {
            repository.findByUserIdAndDate(userId, request.date)
                    .filter(existing -> !existing.getId().equals(measurementId))
                    .ifPresent(existing -> {
                        throw new RuntimeException("Bu tarih icin zaten olcum kaydi var.");
                    });
            entity.setDate(request.date);
        }
        if (request.chest != null)
            entity.setChest(request.chest);
        if (request.waist != null)
            entity.setWaist(request.waist);
        if (request.hips != null)
            entity.setHips(request.hips);
        if (request.leftArm != null)
            entity.setLeftArm(request.leftArm);
        if (request.rightArm != null)
            entity.setRightArm(request.rightArm);
        if (request.leftLeg != null)
            entity.setLeftLeg(request.leftLeg);
        if (request.rightLeg != null)
            entity.setRightLeg(request.rightLeg);

        validateHasAtLeastOneMeasurement(entity);
        return toResponse(entity);
    }

    @Transactional
    public void deleteMeasurement(Long userId, Long measurementId) {
        BodyMeasurement entity = repository.findById(measurementId);
        if (entity == null || !entity.getUserId().equals(userId)) {
            throw new RuntimeException("Ölçüm bulunamadı veya yetkiniz yok.");
        }
        repository.delete(entity);
    }

    private BodyMeasurementResponse toResponse(BodyMeasurement entity) {
        BodyMeasurementResponse dto = new BodyMeasurementResponse();
        dto.id = entity.getId();
        dto.userId = entity.getUserId();
        dto.date = entity.getDate();
        dto.chest = entity.getChest();
        dto.waist = entity.getWaist();
        dto.hips = entity.getHips();
        dto.leftArm = entity.getLeftArm();
        dto.rightArm = entity.getRightArm();
        dto.leftLeg = entity.getLeftLeg();
        dto.rightLeg = entity.getRightLeg();
        return dto;
    }

    private void validateHasAtLeastOneMeasurement(BodyMeasurementRequest request) {
        if (request.chest == null &&
                request.waist == null &&
                request.hips == null &&
                request.leftArm == null &&
                request.rightArm == null &&
                request.leftLeg == null &&
                request.rightLeg == null) {
            throw new RuntimeException("En az bir olcu girmelisiniz.");
        }
    }

    private void validateHasAtLeastOneMeasurement(BodyMeasurement entity) {
        if (entity.getChest() == null &&
                entity.getWaist() == null &&
                entity.getHips() == null &&
                entity.getLeftArm() == null &&
                entity.getRightArm() == null &&
                entity.getLeftLeg() == null &&
                entity.getRightLeg() == null) {
            throw new RuntimeException("En az bir olcu girmelisiniz.");
        }
    }
}
