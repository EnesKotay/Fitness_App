CREATE SEQUENCE IF NOT EXISTS workout_sessions_seq INCREMENT 50;

SELECT setval(
    'workout_sessions_seq',
    GREATEST((SELECT COALESCE(MAX(id), 0) FROM workout_sessions) + 1, 1),
    false
);
