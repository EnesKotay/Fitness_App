ALTER TABLE ai_rate_limits
    ADD COLUMN IF NOT EXISTS scope VARCHAR(32);

UPDATE ai_rate_limits
SET scope = 'nutrition'
WHERE scope IS NULL OR scope = '';

ALTER TABLE ai_rate_limits
    ALTER COLUMN scope SET NOT NULL;

ALTER TABLE ai_rate_limits
    DROP CONSTRAINT IF EXISTS ai_rate_limits_user_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS ux_ai_rate_limits_user_scope
    ON ai_rate_limits(user_id, scope);

CREATE INDEX IF NOT EXISTS idx_ai_rate_limits_scope
    ON ai_rate_limits(scope);
