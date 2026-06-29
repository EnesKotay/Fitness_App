CREATE TABLE IF NOT EXISTS workout_sessions (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title               VARCHAR(255) NOT NULL,
    started_at          TIMESTAMP,
    finished_at         TIMESTAMP NOT NULL,
    duration_minutes    INTEGER,
    planned_set_count   INTEGER,
    completed_set_count INTEGER,
    difficulty          VARCHAR(20),
    notes               VARCHAR(1000),
    created_at          TIMESTAMP,
    updated_at          TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_id
    ON workout_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_workout_sessions_finished_at
    ON workout_sessions(user_id, finished_at DESC);

ALTER TABLE workouts
    ADD COLUMN IF NOT EXISTS workout_session_id BIGINT REFERENCES workout_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_workouts_session_id
    ON workouts(workout_session_id);

ALTER TABLE workout_sets
    ADD COLUMN IF NOT EXISTS rpe DOUBLE PRECISION;
