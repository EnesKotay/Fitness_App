-- V14: Kullanıcı profil alanları — activity_level, goal, workout_location ve AI/motivasyon kolonları
-- Bu kolonlar Hibernate update moduyla dev'de zaten oluşturulmuştu; Flyway ile kalıcı hale getiriyoruz.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS activity_level             VARCHAR(50),
  ADD COLUMN IF NOT EXISTS goal                       VARCHAR(50),
  ADD COLUMN IF NOT EXISTS goal_history_json           TEXT,
  ADD COLUMN IF NOT EXISTS workout_location            VARCHAR(50),
  ADD COLUMN IF NOT EXISTS equipment_type              VARCHAR(50),
  ADD COLUMN IF NOT EXISTS nutrition_preferences_json  TEXT,
  ADD COLUMN IF NOT EXISTS ai_memory_summary           TEXT,
  ADD COLUMN IF NOT EXISTS motivation_stats_json       TEXT;
