-- Premium tier support
ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_tier VARCHAR(20) DEFAULT 'free';
ALTER TABLE users ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMP;
