-- V27: Create weekly_training_load table for tracking weekly workout volume, intensity, and muscle group distribution

CREATE TABLE weekly_training_load (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    week_end DATE NOT NULL,
    total_sets INTEGER DEFAULT 0,
    total_volume_kg DOUBLE PRECISION DEFAULT 0.0,
    avg_rpe DOUBLE PRECISION,
    muscle_group VARCHAR(30),
    workout_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for efficient queries by user and week
CREATE INDEX idx_weekly_training_load_user_week ON weekly_training_load(user_id, week_start DESC);

-- Index for muscle group analysis
CREATE INDEX idx_weekly_training_load_muscle_group ON weekly_training_load(user_id, muscle_group, week_start DESC);

-- Unique constraint: one record per user per week per muscle group
CREATE UNIQUE INDEX idx_weekly_training_load_unique ON weekly_training_load(user_id, week_start, COALESCE(muscle_group, 'ALL'));
