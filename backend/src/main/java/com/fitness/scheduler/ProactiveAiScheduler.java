package com.fitness.scheduler;

import com.fitness.entity.User;
import com.fitness.entity.Notification;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.List;

@ApplicationScoped
public class ProactiveAiScheduler {

    @Inject
    EntityManager em;

    // Her akşam saat 20:00'de çalışır (Kullanıcı kalori takibi proaktif uyarısı)
    @Scheduled(cron = "0 0 20 * * ?")
    @Transactional
    public void generateProactiveCoaching() {
        System.out.println("Starting Proactive AI Coaching Job...");
        List<User> users = em.createQuery("SELECT u FROM User u", User.class).getResultList();
        
        for (User user : users) {
            try {
                // Burada her kullanıcının güncel kalori durumu çekilip eksik varsa Gemini üzerinden 
                // kişiselleştirilmiş bir mesaj üretilebilir. Şimdilik statik bir koç mesajı simüle ediyoruz.
                String aiMessage = "Günü kapatmadan önce kalori hedefine ulaşman için protein ağırlıklı küçük bir ara öğün yapmaya ne dersin?";
                
                Notification notification = new Notification();
                notification.user = user;
                notification.title = "AI Koçundan Mesaj ⚡";
                notification.message = aiMessage;
                notification.isRead = false;
                notification.type = "AI_PROACTIVE";
                notification.createdAt = LocalDateTime.now();
                
                em.persist(notification);
                System.out.println("Proactive AI notification generated for user " + user.id);
            } catch (Exception e) {
                System.err.println("Failed to send proactive notification to user " + user.id + ": " + e.getMessage());
            }
        }
        System.out.println("Proactive AI Coaching Job Completed.");
    }
}
