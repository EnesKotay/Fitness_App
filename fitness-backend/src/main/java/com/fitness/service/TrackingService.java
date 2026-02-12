package com.fitness.service;

import java.util.List;
import java.util.stream.Collectors;

import com.fitness.dto.WeightRecordRequest;
import com.fitness.dto.WeightRecordResponse;
import com.fitness.entity.User;
import com.fitness.entity.WeightRecord;
import com.fitness.repository.UserRepository;
import com.fitness.repository.WeightRecordRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class TrackingService {
    
    @Inject
    WeightRecordRepository weightRecordRepository;
    
    @Inject
    UserRepository userRepository;
    
    /**
     * Yeni kilo kaydı oluştur
     */
    @Transactional
    public WeightRecordResponse createWeightRecord(Long userId, WeightRecordRequest request) {
        User user = userRepository.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı!");
        }
        
        WeightRecord record = new WeightRecord();
        record.user = user;
        record.weight = request.weight;
        record.bodyFatPercentage = request.bodyFatPercentage;
        record.muscleMass = request.muscleMass;
        record.recordedAt = request.recordedAt != null ? request.recordedAt : java.time.LocalDateTime.now();
        record.notes = request.notes;
        
        // @PrePersist otomatik çağrılacak, manuel çağırmaya gerek yok
        weightRecordRepository.persist(record);
        
        // Kullanıcının güncel kilosunu güncelle (Senkronizasyon)
        // Eğer bu kayıt en güncel ise veya yeni ekleniyorsa güncel kabul ediyoruz.
        // Daha karmaşık logic (tarih kontrolü) eklenebilir ama şimdilik doğrudan güncelliyoruz.
        user.weight = record.weight;
        userRepository.persist(user);
        
        return toResponse(record);
    }
    
    /**
     * Kullanıcının tüm kilo kayıtlarını getir
     */
    public List<WeightRecordResponse> getUserWeightRecords(Long userId) {
        List<WeightRecord> records = weightRecordRepository.findByUserIdOrderByRecordedAtDesc(userId);
        return records.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }
    
    /**
     * Kilo kaydını güncelle
     */
    @Transactional
    public WeightRecordResponse updateWeightRecord(Long userId, Long recordId, WeightRecordRequest request) {
        WeightRecord record = weightRecordRepository.findById(recordId);
        
        if (record == null) {
            throw new RuntimeException("Kayıt bulunamadı!");
        }
        
        // User kontrolü
        if (record.user == null || !record.user.id.equals(userId)) {
            throw new RuntimeException("Kayıt bulunamadı veya yetkiniz yok!");
        }
        
        if (request.weight != null) record.weight = request.weight;
        if (request.bodyFatPercentage != null) record.bodyFatPercentage = request.bodyFatPercentage;
        if (request.muscleMass != null) record.muscleMass = request.muscleMass;
        if (request.recordedAt != null) record.recordedAt = request.recordedAt;
        if (request.notes != null) record.notes = request.notes;
        
        weightRecordRepository.persist(record);
        
        return toResponse(record);
    }
    
    /**
     * Kilo kaydını sil
     */
    @Transactional
    public void deleteWeightRecord(Long userId, Long recordId) {
        WeightRecord record = weightRecordRepository.findById(recordId);
        
        if (record == null) {
            throw new RuntimeException("Kayıt bulunamadı!");
        }
        
        // User kontrolü
        if (record.user == null || !record.user.id.equals(userId)) {
            throw new RuntimeException("Kayıt bulunamadı veya yetkiniz yok!");
        }
        
        weightRecordRepository.delete(record);
    }
    
    /**
     * Entity'yi Response'a çevir
     */
    private WeightRecordResponse toResponse(WeightRecord record) {
        WeightRecordResponse response = new WeightRecordResponse();
        response.id = record.id;
        response.weight = record.weight;
        response.bodyFatPercentage = record.bodyFatPercentage;
        response.muscleMass = record.muscleMass;
        response.recordedAt = record.recordedAt;
        response.notes = record.notes;
        response.createdAt = record.createdAt;
        return response;
    }
}