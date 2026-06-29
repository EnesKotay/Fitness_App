ALTER TABLE ai_feedback
    ADD COLUMN IF NOT EXISTS user_question TEXT;
