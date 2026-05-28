package com.fitness.service;

import java.time.LocalDate;
import java.time.LocalDateTime;

import com.fitness.entity.Notification;
import com.fitness.entity.User;
import com.fitness.repository.UserRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class NotificationCreatorService {

    @Inject
    UserRepository userRepository;

    @Inject
    PushNotificationService pushNotificationService;

    @Transactional(Transactional.TxType.REQUIRES_NEW)
    public void create(Long userId, String title, String message, String type) {
        User user = userRepository.findById(userId);
        if (user == null) return;

        Notification n = new Notification();
        n.user = user;
        n.title = title;
        n.message = message;
        n.type = type;
        n.persist();
        pushNotificationService.sendToUser(userId, n.id, title, message, type);
    }

    /** Bugün bu kullanıcıya bu tip bildirim gönderildi mi? */
    @Transactional(Transactional.TxType.REQUIRES_NEW)
    public boolean existsToday(Long userId, String type) {
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        return Notification.count(
                "user.id = ?1 AND type = ?2 AND createdAt >= ?3",
                userId, type, startOfDay) > 0;
    }
}
