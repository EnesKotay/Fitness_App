CREATE SEQUENCE IF NOT EXISTS recipe_seq INCREMENT 50;

CREATE TABLE IF NOT EXISTS recipes (
    id            BIGINT PRIMARY KEY DEFAULT nextval('recipe_seq'),
    user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    external_id   VARCHAR(255) NOT NULL,
    name          VARCHAR(255) NOT NULL,
    description   TEXT,
    category      VARCHAR(100),
    servings      INTEGER NOT NULL DEFAULT 1,
    prep_time_minutes  INTEGER NOT NULL DEFAULT 0,
    cook_time_minutes  INTEGER NOT NULL DEFAULT 0,
    image_emoji   VARCHAR(20) DEFAULT '🍽️',
    kcal_per_serving    DOUBLE PRECISION NOT NULL DEFAULT 0,
    protein_per_serving DOUBLE PRECISION NOT NULL DEFAULT 0,
    carb_per_serving    DOUBLE PRECISION NOT NULL DEFAULT 0,
    fat_per_serving     DOUBLE PRECISION NOT NULL DEFAULT 0,
    fiber_per_serving   DOUBLE PRECISION NOT NULL DEFAULT 0,
    sugar_per_serving   DOUBLE PRECISION NOT NULL DEFAULT 0,
    tags        TEXT,
    ingredients TEXT,
    steps       TEXT,
    difficulty  VARCHAR(50) DEFAULT 'orta',
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_recipes_user_external UNIQUE (user_id, external_id)
);

CREATE INDEX IF NOT EXISTS idx_recipes_user_id ON recipes(user_id);
