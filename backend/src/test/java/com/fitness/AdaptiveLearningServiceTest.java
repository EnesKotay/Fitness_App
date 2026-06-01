package com.fitness;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDateTime;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.fitness.entity.AiFeedback;
import com.fitness.entity.User;
import com.fitness.service.AdaptiveLearningService;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@QuarkusTest
public class AdaptiveLearningServiceTest {

    @Inject
    AdaptiveLearningService adaptiveLearningService;

    @BeforeEach
    @Transactional
    public void setup() {
        AiFeedback.deleteAll();
        User.delete("email", "adaptive-learning-test@example.com");
    }

    @Test
    @Transactional
    public void testUsesScalarUserIdQueries() {
        User user = new User();
        user.email = "adaptive-learning-test@example.com";
        user.password = "test-password-hash";
        user.name = "Adaptive Test";
        user.persist();
        assertNotNull(user.id);

        AiFeedback feedback = new AiFeedback();
        feedback.userId = user.id;
        feedback.aiResponse = "Net ve uygulanabilir bir cevap.";
        feedback.reaction = "POSITIVE";
        feedback.userQuestion = "BMR nedir?";
        feedback.createdAt = LocalDateTime.now();
        feedback.persist();

        assertDoesNotThrow(() -> adaptiveLearningService.assessKnowledgeLevel(user.id));
        Map<String, Object> stats = assertDoesNotThrow(() -> adaptiveLearningService.getLearningStats(user.id));

        assertEquals("BEGINNER", stats.get("knowledgeLevel"));
        assertEquals(1L, stats.get("questionsAsked30d"));
    }
}
