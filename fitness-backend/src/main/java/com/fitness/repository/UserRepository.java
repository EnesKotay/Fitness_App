package com.fitness.repository;

import com.fitness.entity.User;

import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class UserRepository implements PanacheRepository<User> {

    /** Tam eşleşme (register'da "bu email var mı" kontrolü). */
    public User findByEmail(String email) {
        return find("email", email == null ? null : email.trim().toLowerCase()).firstResult();
    }

    /** Büyük/küçük harf duyarsız; login'de kullanılır. Farklı hesaplar her zaman kendi user'ını alır. */
    public User findByEmailIgnoreCase(String email) {
        if (email == null || email.isBlank()) return null;
        String normalized = email.trim().toLowerCase();
        return find("LOWER(email) = ?1", normalized).firstResult();
    }
}