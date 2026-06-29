-- V10: Hibernate 6.x sequence desteği
-- PanacheEntity (@GeneratedValue) her tablo için {table}_seq adında bir sequence bekler.
-- BIGSERIAL'ın yarattığı {table}_id_seq ayrı kalır; Hibernate her INSERT'te
-- kendi sequence'ından aldığı ID'yi açıkça sağlar, DEFAULT'a güvenmez.
-- setval ile mevcut max ID'nin üzerinden başlatılır (veri varsa çakışmayı önler).

CREATE SEQUENCE IF NOT EXISTS users_seq               INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS workouts_seq            INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS meals_seq               INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS weight_records_seq      INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS exercises_seq           INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS ai_insights_seq         INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS notifications_seq       INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS ai_rate_limits_seq      INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS ai_user_preferences_seq INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS workout_sets_seq        INCREMENT 50;
CREATE SEQUENCE IF NOT EXISTS myentity_seq            INCREMENT 50;

SELECT setval('users_seq',               GREATEST((SELECT COALESCE(MAX(id),0) FROM users)               + 1, 1), false);
SELECT setval('workouts_seq',            GREATEST((SELECT COALESCE(MAX(id),0) FROM workouts)            + 1, 1), false);
SELECT setval('meals_seq',               GREATEST((SELECT COALESCE(MAX(id),0) FROM meals)               + 1, 1), false);
SELECT setval('weight_records_seq',      GREATEST((SELECT COALESCE(MAX(id),0) FROM weight_records)      + 1, 1), false);
SELECT setval('exercises_seq',           GREATEST((SELECT COALESCE(MAX(id),0) FROM exercises)           + 1, 1), false);
SELECT setval('ai_insights_seq',         GREATEST((SELECT COALESCE(MAX(id),0) FROM ai_insights)         + 1, 1), false);
SELECT setval('notifications_seq',       GREATEST((SELECT COALESCE(MAX(id),0) FROM notifications)       + 1, 1), false);
SELECT setval('ai_rate_limits_seq',      GREATEST((SELECT COALESCE(MAX(id),0) FROM ai_rate_limits)      + 1, 1), false);
SELECT setval('ai_user_preferences_seq', GREATEST((SELECT COALESCE(MAX(id),0) FROM ai_user_preferences) + 1, 1), false);
SELECT setval('workout_sets_seq',        GREATEST((SELECT COALESCE(MAX(id),0) FROM workout_sets)        + 1, 1), false);
