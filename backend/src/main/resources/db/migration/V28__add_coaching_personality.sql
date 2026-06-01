-- V28: Add coaching_personality to users table

ALTER TABLE users ADD COLUMN coaching_personality VARCHAR(30) DEFAULT 'SUPPORTIVE';

-- Update description: Allows users to customize AI Coach personality (SUPPORTIVE, TOUGH_LOVE, ANALYTICAL)
