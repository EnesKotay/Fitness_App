-- V6: workout_sets tablosu ekle ve workouts tablosuna yeni sütunlar ekle

-- Her setin detayını ayrı satırda tutan yeni tablo
CREATE TABLE IF NOT EXISTS workout_sets (
    id          BIGSERIAL PRIMARY KEY,
    workout_id  BIGINT    NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
    set_number  INTEGER   NOT NULL,
    set_type    VARCHAR(20) NOT NULL DEFAULT 'NORMAL', -- WARMUP | NORMAL | DROP | FAILURE
    reps        INTEGER,
    weight      DOUBLE PRECISION,
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workout_sets_workout_id ON workout_sets(workout_id);

-- workouts tablosuna ek sütunlar (geriye dönük uyumlu, nullable)
ALTER TABLE workouts
    ADD COLUMN IF NOT EXISTS muscle_group     VARCHAR(30),
    ADD COLUMN IF NOT EXISTS is_superset      BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS superset_partner VARCHAR(255),
    ADD COLUMN IF NOT EXISTS one_rep_max      DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS difficulty       VARCHAR(10); -- EASY | MEDIUM | HARD | MAX
