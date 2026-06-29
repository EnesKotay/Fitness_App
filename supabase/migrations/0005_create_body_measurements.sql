CREATE TABLE body_measurements (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    chest DOUBLE PRECISION,
    waist DOUBLE PRECISION,
    hips DOUBLE PRECISION,
    left_arm DOUBLE PRECISION,
    right_arm DOUBLE PRECISION,
    left_leg DOUBLE PRECISION,
    right_leg DOUBLE PRECISION,
    
    CONSTRAINT uq_body_measurements_user_date UNIQUE (user_id, date)
);

CREATE INDEX idx_body_measurements_user_id ON body_measurements(user_id);
