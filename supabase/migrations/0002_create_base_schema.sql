-- V2: Temel şema oluşturma
-- Yeni (boş) veritabanlarında users ve bağımlı tablolar bu migration ile oluşturulur.
-- Dev ortamında Hibernate bu tabloları zaten oluşturuyordu; burada aynısını Flyway ile yapıyoruz.

-- ── USERS ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id              BIGSERIAL PRIMARY KEY,
    email           VARCHAR(255) NOT NULL UNIQUE,
    password        VARCHAR(255) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    height          DOUBLE PRECISION,
    weight          DOUBLE PRECISION,
    target_weight   DOUBLE PRECISION,
    birth_date      TIMESTAMP,
    gender          VARCHAR(20),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email));

-- ── WORKOUTS ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workouts (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name             VARCHAR(255) NOT NULL,
    workout_type     VARCHAR(50),
    duration_minutes INTEGER,
    calories_burned  INTEGER,
    sets             INTEGER,
    reps             INTEGER,
    weight           DOUBLE PRECISION,
    workout_date     TIMESTAMP NOT NULL,
    notes            VARCHAR(1000),
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_workouts_user_id ON workouts(user_id);

-- ── MEALS ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meals (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        VARCHAR(255) NOT NULL,
    meal_type   VARCHAR(50) NOT NULL,
    calories    INTEGER NOT NULL,
    protein     DOUBLE PRECISION,
    carbs       DOUBLE PRECISION,
    fat         DOUBLE PRECISION,
    meal_date   TIMESTAMP NOT NULL,
    notes       VARCHAR(1000),
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_meals_user_id ON meals(user_id);

-- ── WEIGHT RECORDS ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS weight_records (
    id                   BIGSERIAL PRIMARY KEY,
    user_id              BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weight               DOUBLE PRECISION NOT NULL,
    body_fat_percentage  DOUBLE PRECISION,
    muscle_mass          DOUBLE PRECISION,
    recorded_at          TIMESTAMP NOT NULL,
    notes                VARCHAR(1000),
    created_at           TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_weight_records_user_id ON weight_records(user_id);

-- ── EXERCISES ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS exercises (
    id           BIGSERIAL PRIMARY KEY,
    muscle_group VARCHAR(50) NOT NULL,
    name         VARCHAR(255) NOT NULL,
    description  TEXT,
    instructions TEXT,
    tips         TEXT
);

-- ── PASSWORD RESET TOKENS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS password_reset_token (
    token       VARCHAR(255) PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expiry_date TIMESTAMP NOT NULL
);

-- ── AI INSIGHTS ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_insights (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT REFERENCES users(id) ON DELETE CASCADE,
    created_at    TIMESTAMP NOT NULL,
    summary       TEXT,
    type          VARCHAR(50),
    metadata_json TEXT
);

CREATE INDEX IF NOT EXISTS idx_ai_insights_user_id ON ai_insights(user_id);

-- ── NOTIFICATIONS ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT REFERENCES users(id) ON DELETE CASCADE,
    title      VARCHAR(255) NOT NULL,
    message    TEXT NOT NULL,
    is_read    BOOLEAN DEFAULT FALSE,
    type       VARCHAR(50),
    created_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- ── MY_ENTITY (Quarkus örnek entity — gerekirse silinebilir) ─────────────────
CREATE TABLE IF NOT EXISTS myentity (
    id   BIGSERIAL PRIMARY KEY,
    field VARCHAR(255)
);
