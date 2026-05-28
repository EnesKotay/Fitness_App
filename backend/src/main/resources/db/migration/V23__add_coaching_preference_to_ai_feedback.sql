ALTER TABLE ai_feedback
    ADD COLUMN IF NOT EXISTS coaching_preference TEXT;
