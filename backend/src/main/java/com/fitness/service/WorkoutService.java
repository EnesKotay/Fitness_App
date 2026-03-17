package com.fitness.service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.fitness.dto.WorkoutRequest;
import com.fitness.dto.WorkoutResponse;
import com.fitness.dto.WorkoutSetDto;
import com.fitness.entity.User;
import com.fitness.entity.Workout;
import com.fitness.entity.WorkoutSet;
import com.fitness.repository.UserRepository;
import com.fitness.repository.WorkoutRepository;
import com.fitness.repository.WorkoutSetRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class WorkoutService {
    
    @Inject
    WorkoutRepository workoutRepository;

    @Inject
    WorkoutSetRepository workoutSetRepository;
    
    @Inject
    UserRepository userRepository;
    
    // ── Create ────────────────────────────────────────────────────────────────

    @Transactional
    public WorkoutResponse createWorkout(Long userId, WorkoutRequest request) {
        User user = userRepository.findById(userId);
        if (user == null) throw new RuntimeException("Kullanıcı bulunamadı!");
        if (request == null) throw new RuntimeException("Antrenman verisi gerekli!");

        String safeName = request.name == null ? "" : request.name.trim();
        if (safeName.isEmpty()) throw new RuntimeException("Antrenman adı zorunlu!");
        if (request.durationMinutes != null && request.durationMinutes < 0)
            throw new RuntimeException("Süre negatif olamaz!");
        if (request.caloriesBurned != null && request.caloriesBurned < 0)
            throw new RuntimeException("Kalori negatif olamaz!");
        validateOptionalMetrics(request);

        Workout workout = new Workout();
        workout.user = user;
        workout.name = safeName;
        workout.workoutType   = trimOrNull(request.workoutType);
        workout.durationMinutes = request.durationMinutes;
        workout.caloriesBurned  = request.caloriesBurned;
        workout.sets   = request.sets;
        workout.reps   = request.reps;
        workout.weight = request.weight;
        workout.workoutDate = request.workoutDate != null ? request.workoutDate : java.time.LocalDateTime.now();
        workout.notes  = trimOrNull(request.notes);

        // Yeni alanlar
        workout.muscleGroup     = trimOrNull(request.muscleGroup);
        workout.isSuperset      = request.isSuperset != null && request.isSuperset;
        workout.supersetPartner = trimOrNull(request.supersetPartner);
        workout.difficulty      = trimOrNull(request.difficulty);

        // 1RM: frontend'den gelirse kullan; yoksa set bazlı Epley hesapla
        workout.oneRepMax = resolveOneRepMax(request);

        workoutRepository.persist(workout);

        // Set detaylarını kaydet
        saveSetDetails(workout, request.setDetails);

        return toResponse(workout);
    }

    // ── Read ──────────────────────────────────────────────────────────────────

    public List<WorkoutResponse> getUserWorkouts(Long userId) {
        return workoutRepository.findByUserIdOrderByWorkoutDateDesc(userId)
                .stream().map(this::toResponse).collect(Collectors.toList());
    }

    public WorkoutResponse getWorkoutById(Long userId, Long workoutId) {
        Workout workout = workoutRepository.findById(workoutId);
        if (workout == null || !workout.user.id.equals(userId))
            throw new RuntimeException("Antrenman bulunamadı veya yetkiniz yok!");
        return toResponse(workout);
    }

    /**
     * Belirli bir egzersiz adına ait tüm kayıtları (en yeni önce) döndürür.
     * Egzersiz geçmişini ve ağırlık trendini göstermek için kullanılır.
     */
    public List<WorkoutResponse> getExerciseHistory(Long userId, String exerciseName) {
        if (exerciseName == null || exerciseName.isBlank())
            throw new RuntimeException("Egzersiz adı boş olamaz!");

        return workoutRepository.findByUserIdOrderByWorkoutDateDesc(userId)
                .stream()
                .filter(w -> w.name.equalsIgnoreCase(exerciseName.trim()))
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * Kullanıcının her egzersiz için en yüksek 1RM değerini döndürür.
     * Map<ExerciseName, MaxOneRepMax>
     */
    public Map<String, Double> getPersonalRecords(Long userId) {
        List<Workout> all = workoutRepository.findByUserIdOrderByWorkoutDateDesc(userId);
        Map<String, Double> prMap = new HashMap<>();
        for (Workout w : all) {
            if (w.oneRepMax != null && w.oneRepMax > 0) {
                prMap.merge(w.name, w.oneRepMax, Math::max);
            }
            // Fallback: özet ağırlık + reps'ten tahmin
            else if (w.weight != null && w.reps != null && w.reps > 0) {
                double est = w.weight * (1 + w.reps / 30.0);
                prMap.merge(w.name, est, Math::max);
            }
        }
        return prMap;
    }

    /**
     * Kullanıcının genel istatistikleri
     */
    public Map<String, Object> getWorkoutStats(Long userId) {
        List<Workout> all = workoutRepository.findByUserIdOrderByWorkoutDateDesc(userId);

        long totalWorkouts = all.size();
        long totalSets = all.stream().mapToLong(w -> w.sets != null ? w.sets : 0).sum();
        double totalVolume = all.stream()
                .mapToDouble(w -> {
                    double wt = w.weight != null ? w.weight : 0;
                    int    rp = w.reps   != null ? w.reps   : 0;
                    int    st = w.sets   != null ? w.sets   : 1;
                    return wt * rp * st;
                }).sum();
        int totalCalories = all.stream()
                .mapToInt(w -> w.caloriesBurned != null ? w.caloriesBurned : 0).sum();

        // En sık çalışılan kas grubu
        String topMuscleGroup = all.stream()
                .filter(w -> w.muscleGroup != null)
                .collect(Collectors.groupingBy(w -> w.muscleGroup, Collectors.counting()))
                .entrySet().stream()
                .max(Map.Entry.comparingByValue())
                .map(Map.Entry::getKey).orElse(null);

        Map<String, Object> stats = new HashMap<>();
        stats.put("totalWorkouts", totalWorkouts);
        stats.put("totalSets", totalSets);
        stats.put("totalVolumeKg", Math.round(totalVolume));
        stats.put("totalCaloriesBurned", totalCalories);
        stats.put("topMuscleGroup", topMuscleGroup);
        return stats;
    }

    // ── Update ────────────────────────────────────────────────────────────────

    @Transactional
    public WorkoutResponse updateWorkout(Long userId, Long workoutId, WorkoutRequest request) {
        Workout workout = workoutRepository.findById(workoutId);
        if (workout == null || !workout.user.id.equals(userId))
            throw new RuntimeException("Antrenman bulunamadı veya yetkiniz yok!");
        if (request == null) throw new RuntimeException("Guncelleme verisi gerekli!");

        if (request.name != null) {
            String safeName = request.name.trim();
            if (safeName.isEmpty()) throw new RuntimeException("Antrenman adı boş olamaz!");
            workout.name = safeName;
        }
        if (request.workoutType  != null) workout.workoutType  = request.workoutType.trim();
        if (request.durationMinutes != null) {
            if (request.durationMinutes < 0) throw new RuntimeException("Süre negatif olamaz!");
            workout.durationMinutes = request.durationMinutes;
        }
        if (request.caloriesBurned != null) {
            if (request.caloriesBurned < 0) throw new RuntimeException("Kalori negatif olamaz!");
            workout.caloriesBurned = request.caloriesBurned;
        }
        validateOptionalMetrics(request);
        if (request.sets       != null) workout.sets       = request.sets;
        if (request.reps       != null) workout.reps       = request.reps;
        if (request.weight     != null) workout.weight     = request.weight;
        if (request.workoutDate != null) workout.workoutDate = request.workoutDate;
        if (request.notes      != null) workout.notes      = request.notes.trim();

        // Yeni alanlar
        if (request.muscleGroup     != null) workout.muscleGroup     = request.muscleGroup.trim();
        if (request.isSuperset      != null) workout.isSuperset      = request.isSuperset;
        if (request.supersetPartner != null) workout.supersetPartner = request.supersetPartner.trim();
        if (request.difficulty      != null) workout.difficulty      = request.difficulty.trim();
        if (request.oneRepMax       != null) workout.oneRepMax       = request.oneRepMax;

        // Set detaylarını güncelle (varsa eskilerini sil)
        if (request.setDetails != null && !request.setDetails.isEmpty()) {
            workoutSetRepository.deleteByWorkoutId(workoutId);
            saveSetDetails(workout, request.setDetails);
        }

        workoutRepository.persist(workout);
        return toResponse(workout);
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    @Transactional
    public void deleteWorkout(Long userId, Long workoutId) {
        Workout workout = workoutRepository.findById(workoutId);
        if (workout == null || !workout.user.id.equals(userId))
            throw new RuntimeException("Antrenman bulunamadı veya yetkiniz yok!");
        // workout_sets ON DELETE CASCADE ile otomatik silinir
        workoutRepository.delete(workout);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Set detaylarını workout_sets tablosuna kaydeder.
     */
    private void saveSetDetails(Workout workout, List<WorkoutSetDto> details) {
        if (details == null || details.isEmpty()) return;
        int counter = 1;
        for (WorkoutSetDto dto : details) {
            WorkoutSet ws = new WorkoutSet();
            ws.workout   = workout;
            ws.setNumber = dto.setNumber != null ? dto.setNumber : counter;
            ws.setType   = dto.setType   != null ? dto.setType   : "NORMAL";
            ws.reps      = dto.reps;
            ws.weight    = dto.weight;
            workoutSetRepository.persist(ws);
            counter++;
        }
    }

    /**
     * 1RM: frontend'den geldiyse kullan, yoksa set listesinden Epley ile hesapla.
     */
    private Double resolveOneRepMax(WorkoutRequest request) {
        if (request.oneRepMax != null && request.oneRepMax > 0) return request.oneRepMax;
        if (request.setDetails != null) {
            return request.setDetails.stream()
                    .filter(s -> s.weight != null && s.reps != null && s.weight > 0 && s.reps > 0)
                    .mapToDouble(s -> s.weight * (1 + s.reps / 30.0))
                    .max()
                    .orElse(0);
        }
        // Özet alanlardan tahmin
        if (request.weight != null && request.reps != null && request.weight > 0 && request.reps > 0) {
            return request.weight * (1 + request.reps / 30.0);
        }
        return null;
    }

    private WorkoutResponse toResponse(Workout workout) {
        WorkoutResponse r = new WorkoutResponse();
        r.id             = workout.id;
        r.name           = workout.name;
        r.workoutType    = workout.workoutType;
        r.durationMinutes = workout.durationMinutes;
        r.caloriesBurned = workout.caloriesBurned;
        r.sets           = workout.sets;
        r.reps           = workout.reps;
        r.weight         = workout.weight;
        r.workoutDate    = workout.workoutDate;
        r.notes          = workout.notes;
        r.createdAt      = workout.createdAt;
        r.updatedAt      = workout.updatedAt;
        // Yeni alanlar
        r.muscleGroup     = workout.muscleGroup;
        r.isSuperset      = workout.isSuperset;
        r.supersetPartner = workout.supersetPartner;
        r.oneRepMax       = workout.oneRepMax;
        r.difficulty      = workout.difficulty;
        // Set detayları
        List<WorkoutSet> sets = workoutSetRepository.findByWorkoutId(workout.id);
        if (!sets.isEmpty()) {
            r.setDetails = sets.stream()
                    .sorted(Comparator.comparingInt(s -> s.setNumber))
                    .map(s -> new WorkoutSetDto(s.setNumber, s.setType, s.reps, s.weight))
                    .collect(Collectors.toList());
        }
        return r;
    }

    private void validateOptionalMetrics(WorkoutRequest request) {
        if (request.sets   != null && request.sets   < 0) throw new RuntimeException("Set sayisi negatif olamaz!");
        if (request.reps   != null && request.reps   < 0) throw new RuntimeException("Tekrar sayisi negatif olamaz!");
        if (request.weight != null && request.weight < 0) throw new RuntimeException("Agirlik negatif olamaz!");
    }

    private static String trimOrNull(String s) {
        return s == null ? null : (s.trim().isEmpty() ? null : s.trim());
    }
}
