CREATE SEQUENCE IF NOT EXISTS ai_feedback_seq INCREMENT 50;

SELECT setval('ai_feedback_seq', GREATEST((SELECT COALESCE(MAX(id), 0) FROM ai_feedback) + 1, 1), false);
