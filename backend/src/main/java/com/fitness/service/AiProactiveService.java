package com.fitness.service;

import java.time.LocalDate;
import java.util.List;

import org.jboss.logging.Logger;

import com.fitness.entity.Meal;
import com.fitness.entity.Notification;
import com.fitness.entity.User;
import com.fitness.entity.Workout;

import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

/**
 * Scheduled service that periodically analyzes user data and generates proactive AI feedback.
 */
@ApplicationScoped
public class AiProactiveService {

    private static final Logger LOG = Logger.getLogger(AiProactiveService.class);

    @Inject
    AiProviderRouter aiRouter;

    @Inject
    CoachPromptBuilder promptBuilder;

    /**
     * Daily check at 21:00 to see if the user met their goals.
     * If not, the AI generates a supportive/corrective tip.
     */
    @Scheduled(cron = "0 0 21 * * ?") 
    @Transactional
    public void runDailyAnalysis() {
        LOG.info("Starting proactive daily AI analysis...");
        List<User> users = User.listAll();
        
        for (User user : users) {
            analyzeAndNotify(user);
        }
    }

    /**
     * Helper to analyze a single user's data for the current day.
     */
    @Transactional
    public void analyzeAndNotify(User user) {
        LocalDate today = LocalDate.now();
        java.time.LocalDateTime startOfDay = today.atStartOfDay();
        java.time.LocalDateTime endOfDay = today.plusDays(1).atStartOfDay();
        
        // Fetch data
        List<Meal> meals = Meal.find(
                "user.id = ?1 and mealDate >= ?2 and mealDate < ?3",
                user.id,
                startOfDay,
                endOfDay).list();
        List<Workout> workouts = Workout.find(
                "user.id = ?1 and workoutDate >= ?2 and workoutDate < ?3",
                user.id,
                startOfDay,
                endOfDay).list();
        
        // Simple logic for protein check (example)
        double totalProtein = meals.stream().mapToDouble(m -> m.protein).sum();
        double proteinGoal = 150.0; // Mock goal, should be dynamic
        
        if (totalProtein < proteinGoal * 0.7 && !meals.isEmpty()) {
            generateAiAlerter(user, "PROTEIN_DEFICIENCY", "Kullanıcı bugün protein hedefinin çok gerisinde kaldı. Nazikçe uyar ve akşam için protein içeriği yüksek bir atıştırmalık öner.");
        } else if (workouts.isEmpty() && today.getDayOfWeek().getValue() >= 5) {
            // If weekend and no workouts
            generateAiAlerter(user, "MISSED_WORKOUT", "Kullanıcı haftasonu henüz antrenman yapmadı. Onu motive et.");
        }
    }

    private void generateAiAlerter(User user, String type, String context) {
        String prompt = "Sen akıllı bir fitness koçusun. Senaryo: " + context + 
                        "\nKullanıcı adı: " + user.name + 
                        "\nYalnızca kısa, motive edici ve aksiyon odaklı bir mesaj üret (maks 2 cümle).";
        
        try {
            GeminiClientResult result = aiRouter.generateText("proactive_alert", user.id, "gemini-2.0-flash", "gemini-1.5-flash", prompt, false);
            
            if (result.isSuccess()) {
                Notification notification = new Notification();
                notification.user = user;
                notification.title = "AI Koç Tavsiyesi";
                notification.message = result.getOutputText();
                notification.type = "AI_COACH";
                notification.persist();
                LOG.infof("Proactive notification sent to user %d: %s", user.id, type);
            }
        } catch (Exception e) {
            LOG.error("Failed to generate proactive AI notification", e);
        }
    }
}
