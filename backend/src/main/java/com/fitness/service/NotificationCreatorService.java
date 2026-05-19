package com.fitness.service;

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

    @Transactional
    public void create(Long userId, String title, String message, String type) {
        User user = userRepository.findById(userId);
        if (user == null) return;

        Notification n = new Notification();
        n.user = user;
        n.title = title;
        n.message = message;
        n.type = type;
        n.persist();
    }
}
