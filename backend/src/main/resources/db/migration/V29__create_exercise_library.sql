-- Exercise Library table for storing 1,324+ curated exercises
CREATE TABLE exercise_library (
    id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    body_part VARCHAR(100) NOT NULL,
    equipment VARCHAR(100) NOT NULL,

    -- Instructions in multiple languages
    instructions_en TEXT,
    instructions_tr TEXT,
    instructions_es TEXT,
    instructions_it TEXT,
    instructions_ru TEXT,
    instructions_zh TEXT,

    -- Step-by-step instructions as JSON arrays
    instruction_steps_en TEXT,
    instruction_steps_tr TEXT,

    muscle_group VARCHAR(100),
    secondary_muscles TEXT, -- JSON array stored as text
    target VARCHAR(100),

    media_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common queries
CREATE INDEX idx_exercise_category ON exercise_library(category);
CREATE INDEX idx_exercise_equipment ON exercise_library(equipment);
CREATE INDEX idx_exercise_target ON exercise_library(target);
CREATE INDEX idx_exercise_body_part ON exercise_library(body_part);
