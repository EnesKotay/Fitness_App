CREATE TABLE ai_feedback (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT        NOT NULL,
    ai_response TEXT          NOT NULL,
    reaction    VARCHAR(16)   NOT NULL,
    task_mode   VARCHAR(32),
    personality VARCHAR(32),
    created_at  TIMESTAMP     NOT NULL
);
