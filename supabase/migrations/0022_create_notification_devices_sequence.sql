CREATE SEQUENCE IF NOT EXISTS notification_devices_seq INCREMENT 50;

SELECT setval(
    'notification_devices_seq',
    GREATEST((SELECT COALESCE(MAX(id), 0) FROM notification_devices) + 1, 1),
    false
);
