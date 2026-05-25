-- V17: ai_rate_limits tablosuna (user_id, scope) unique kısıt ekle
-- Race condition fix: concurrent requests aynı anda 2 kayıt oluşturamaz.
ALTER TABLE ai_rate_limits
    ADD CONSTRAINT uq_ai_rate_limits_user_scope UNIQUE (user_id, scope);
