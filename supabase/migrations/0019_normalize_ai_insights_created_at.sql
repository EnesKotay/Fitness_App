-- Normalize ai_insights timestamp naming after older Hibernate schemas created
-- a legacy camel-case-derived "createdat" column alongside "created_at".
ALTER TABLE ai_insights
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'ai_insights'
          AND column_name = 'createdat'
    ) THEN
        EXECUTE 'UPDATE ai_insights SET created_at = COALESCE(created_at, createdat) WHERE created_at IS NULL';
        EXECUTE 'ALTER TABLE ai_insights ALTER COLUMN createdat DROP NOT NULL';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'ai_insights'
          AND column_name = 'updatedat'
    ) THEN
        EXECUTE 'ALTER TABLE ai_insights ALTER COLUMN updatedat DROP NOT NULL';
    END IF;
END $$;

UPDATE ai_insights
SET created_at = NOW()
WHERE created_at IS NULL;

ALTER TABLE ai_insights
    ALTER COLUMN created_at SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ai_insights_created_at
    ON ai_insights(created_at);
