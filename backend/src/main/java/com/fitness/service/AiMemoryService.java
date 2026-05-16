package com.fitness.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.jboss.logging.Logger;

import com.fitness.entity.AiInsight;
import com.fitness.entity.Meal;
import com.fitness.entity.User;
import com.fitness.entity.WeightRecord;
import com.fitness.entity.Workout;

import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

/**
 * Manages long-term user memory by summarizing performance into insights.
 */
@ApplicationScoped
public class AiMemoryService {

    private static final Logger LOG = Logger.getLogger(AiMemoryService.class);

    @Inject
    AiProviderRouter aiRouter;

    // @Transactional anotasyonlarının sınıf içi çağrılarda çalışması için self-injection
    @Inject
    AiMemoryService self;

    /**
     * Weekly summary every Sunday at midnight.
     */
    @Scheduled(cron = "0 0 0 ? * SUN")
    public void generateWeeklyInsights() {
        LOG.info("Generating weekly AI insights for all users...");
        
        // Sadece ID'leri çekiyoruz
        List<Long> userIds = self.getAllUserIds();
        
        for (Long userId : userIds) {
             try {
                 // Ağ (AI) çağrısı içeren metodu transaction dışında çağırıyoruz
                 // Böylece veritabanı bağlantı havuzu (connection pool) kilitlenmez.
                 self.processWeeklySummaryForUser(userId);
             } catch (Exception e) {
                 LOG.warnf("Failed to generate weekly insight for user %d: %s", userId, e.getMessage());
             }
        }
    }

    @Transactional
    public List<Long> getAllUserIds() {
        return User.<User>streamAll().map(u -> u.id).collect(Collectors.toList());
    }

    public void processWeeklySummaryForUser(Long userId) {
        String dataSnapshot = self.buildDataSnapshot(userId);
        if (dataSnapshot == null) return;

        String prompt = "Sen uzman bir biyomekanik ve beslenme koçusun. Aşağıdaki haftalık verileri analiz et ve " +
                        "kullanıcının kalıcı hafızasında saklanmak üzere teknik ve profesyonel bir gelişim özeti çıkar (maks 3 cümle).\n" +
                        "Bu özet gelecekteki antrenman ve diyet planlamaları için sana referans olarak sunulacaktır.\n\n" +
                        dataSnapshot;

        try {
            GeminiClientResult result = aiRouter.generateText("weekly_insight", userId, "gemini-2.5-flash", "gemini-2.0-flash", prompt, false);
            
            if (result.isSuccess() && result.getOutputText() != null && !result.getOutputText().isBlank()) {
                self.saveWeeklyInsight(userId, result.getOutputText().trim());
            }
        } catch (Exception e) {
            LOG.error("Failed to generate weekly insight for user " + userId, e);
        }
    }

    @Transactional
    public String buildDataSnapshot(Long userId) {
        User user = User.findById(userId);
        if (user == null) return null;

        LocalDateTime lastWeek = LocalDate.now().minusDays(7).atStartOfDay();
        
        // "date" isimli alanlar entitylerde bulunmadığı için doğru alan isimleri (workoutDate, mealDate, recordedAt) eklendi
        List<Workout> workouts = Workout.find("user.id = ?1 and workoutDate >= ?2", userId, lastWeek).list();
        List<Meal> meals = Meal.find("user.id = ?1 and mealDate >= ?2", userId, lastWeek).list();
        // Ağırlıkların doğru trendi göstermesi için tarihe göre sıralama eklendi
        List<WeightRecord> weights = WeightRecord.find("user.id = ?1 and recordedAt >= ?2 order by recordedAt asc", userId, lastWeek).list();

        double avgCal = meals.stream()
            .mapToDouble(m -> m.calories != null ? m.calories : 0)
            .average()
            .orElse(0);

        String weightTrend = "Veri yok";
        if (!weights.isEmpty()) {
            Double firstWeight = weights.get(0).weight;
            Double lastWeight = weights.get(weights.size() - 1).weight;
            if (firstWeight != null && lastWeight != null) {
                weightTrend = String.format("%.1f kg -> %.1f kg", firstWeight, lastWeight);
            }
        }

        return String.format(
            "Geçen Hafta Verileri:\n- Toplam Antrenman: %d\n- Ortalama Günlük Kalori: %.0f kcal\n- Kilo Değişimi: %s",
            workouts.size(),
            avgCal,
            weightTrend
        );
    }

    @Transactional
    public void saveWeeklyInsight(Long userId, String summary) {
        User user = User.findById(userId);
        if (user != null) {
            AiInsight insight = new AiInsight();
            insight.user = user;
            insight.type = "WEEKLY_PROGRESS";
            insight.summary = summary;
            insight.persist();
            LOG.infof("Weekly insight saved for user %d", userId);
        }
    }
}
