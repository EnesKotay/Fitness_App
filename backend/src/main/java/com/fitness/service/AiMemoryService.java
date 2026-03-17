package com.fitness.service;

import java.time.LocalDate;
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

    /**
     * Weekly summary every Sunday at midnight.
     */
    @Scheduled(cron = "0 0 0 ? * SUN")
    @Transactional
    public void generateWeeklyInsights() {
        LOG.info("Generating weekly AI insights for all users...");
        List<User> users = User.listAll();
        for (User user : users) {
             createWeeklySummary(user);
        }
    }

    @Transactional
    public void createWeeklySummary(User user) {
        LocalDate lastWeek = LocalDate.now().minusDays(7);
        
        // Gather week data
        List<Workout> workouts = Workout.find("user.id = ?1 and date >= ?2", user.id, lastWeek).list();
        List<Meal> meals = Meal.find("user.id = ?1 and date >= ?2", user.id, lastWeek).list();
        List<WeightRecord> weights = WeightRecord.find("user.id = ?1 and date >= ?2", user.id, lastWeek).list();

        String dataSnapshot = String.format(
            "Geçen Hafta Verileri:\n- Toplam Antrenman: %d\n- Ortalama Günlük Kalori: %.0f\n- Kilo Değişimi: %s",
            workouts.size(),
            meals.stream().mapToDouble(m -> m.calories).average().orElse(0),
            weights.isEmpty() ? "Veri yok" : weights.get(0).weight + " -> " + weights.get(weights.size()-1).weight
        );

        String prompt = "Sen uzman bir biyomekanik ve beslenme koçusun. Aşağıdaki haftalık verileri analiz et ve " +
                        "kullanıcının uzun süreli hafızasında saklanmak üzere teknik ve profesyonel bir gelişim özeti çıkar (maks 100 kelime).\n" +
                        dataSnapshot;

        try {
            GeminiClientResult result = aiRouter.generateText("weekly_insight", user.id, "gemini-2.0-flash", "gemini-1.5-flash", prompt, false);
            
            if (result.isSuccess()) {
                AiInsight insight = new AiInsight();
                insight.user = user;
                insight.type = "WEEKLY_PROGRESS";
                insight.summary = result.getOutputText();
                insight.persist();
                LOG.infof("Weekly insight saved for user %d", user.id);
            }
        } catch (Exception e) {
            LOG.error("Failed to generate weekly insight", e);
        }
    }
}
