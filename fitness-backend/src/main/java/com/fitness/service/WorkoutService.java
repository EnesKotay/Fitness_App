package com.fitness.service;

import java.util.List;
import java.util.stream.Collectors;

import com.fitness.dto.WorkoutRequest;
import com.fitness.dto.WorkoutResponse;
import com.fitness.entity.User;
import com.fitness.entity.Workout;
import com.fitness.repository.UserRepository;
import com.fitness.repository.WorkoutRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class WorkoutService {
    
    @Inject
    WorkoutRepository workoutRepository;
    
    @Inject
    UserRepository userRepository;
    
    /**
     * Yeni antrenman kaydı oluştur
     */
    @Transactional
    public WorkoutResponse createWorkout(Long userId, WorkoutRequest request) {
        User user = userRepository.findById(userId);
        if (user == null) {
            throw new RuntimeException("Kullanıcı bulunamadı!");
        }
        
        Workout workout = new Workout();
        workout.user = user;
        workout.name = request.name;
        workout.workoutType = request.workoutType;
        workout.durationMinutes = request.durationMinutes;
        workout.caloriesBurned = request.caloriesBurned;
        workout.workoutDate = request.workoutDate != null ? request.workoutDate : java.time.LocalDateTime.now();
        workout.notes = request.notes;
        // @PrePersist otomatik çağrılacak
        
        workoutRepository.persist(workout);
        
        return toResponse(workout);
    }
    
    /**
     * Kullanıcının tüm antrenmanlarını getir
     */
    public List<WorkoutResponse> getUserWorkouts(Long userId) {
        List<Workout> workouts = workoutRepository.findByUserIdOrderByWorkoutDateDesc(userId);
        return workouts.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }
    
    /**
     * Antrenman kaydını güncelle
     */
    @Transactional
    public WorkoutResponse updateWorkout(Long userId, Long workoutId, WorkoutRequest request) {
        Workout workout = workoutRepository.findById(workoutId);
        
        if (workout == null || !workout.user.id.equals(userId)) {
            throw new RuntimeException("Antrenman bulunamadı veya yetkiniz yok!");
        }
        
        if (request.name != null) workout.name = request.name;
        if (request.workoutType != null) workout.workoutType = request.workoutType;
        if (request.durationMinutes != null) workout.durationMinutes = request.durationMinutes;
        if (request.caloriesBurned != null) workout.caloriesBurned = request.caloriesBurned;
        if (request.workoutDate != null) workout.workoutDate = request.workoutDate;
        if (request.notes != null) workout.notes = request.notes;
        
        // @PreUpdate otomatik çağrılacak
        workoutRepository.persist(workout);
        
        return toResponse(workout);
    }
    
    /**
     * Antrenman kaydını sil
     */
    @Transactional
    public void deleteWorkout(Long userId, Long workoutId) {
        Workout workout = workoutRepository.findById(workoutId);
        
        if (workout == null || !workout.user.id.equals(userId)) {
            throw new RuntimeException("Antrenman bulunamadı veya yetkiniz yok!");
        }
        
        workoutRepository.delete(workout);
    }
    
    /**
     * Belirli bir antrenmanı getir
     */
    public WorkoutResponse getWorkoutById(Long userId, Long workoutId) {
        Workout workout = workoutRepository.findById(workoutId);
        
        if (workout == null || !workout.user.id.equals(userId)) {
            throw new RuntimeException("Antrenman bulunamadı veya yetkiniz yok!");
        }
        
        return toResponse(workout);
    }
    
    /**
     * Entity'yi Response'a çevir
     */
    private WorkoutResponse toResponse(Workout workout) {
        WorkoutResponse response = new WorkoutResponse();
        response.id = workout.id;
        response.name = workout.name;
        response.workoutType = workout.workoutType;
        response.durationMinutes = workout.durationMinutes;
        response.caloriesBurned = workout.caloriesBurned;
        response.workoutDate = workout.workoutDate;
        response.notes = workout.notes;
        response.createdAt = workout.createdAt;
        response.updatedAt = workout.updatedAt;
        return response;
    }
}