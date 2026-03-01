-- Normalize user emails for existing databases.
-- Safe on empty schema: if "users" table does not exist, this migration is a no-op.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'users'
  ) THEN
    -- 1) Normalize emails to lowercase + trimmed form.
    UPDATE users
    SET email = LOWER(TRIM(email))
    WHERE email IS NOT NULL AND email <> '';

    -- 2) Re-point child table foreign keys to canonical user (min id per email).
    IF EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'weight_records'
    ) THEN
      UPDATE weight_records wr
      SET user_id = canon.keep_id
      FROM (
        SELECT a.id AS dup_id, (SELECT MIN(b.id) FROM users b WHERE b.email = a.email) AS keep_id
        FROM users a
        WHERE EXISTS (SELECT 1 FROM users b WHERE b.email = a.email AND b.id < a.id)
      ) canon
      WHERE wr.user_id = canon.dup_id;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'meals'
    ) THEN
      UPDATE meals m
      SET user_id = canon.keep_id
      FROM (
        SELECT a.id AS dup_id, (SELECT MIN(b.id) FROM users b WHERE b.email = a.email) AS keep_id
        FROM users a
        WHERE EXISTS (SELECT 1 FROM users b WHERE b.email = a.email AND b.id < a.id)
      ) canon
      WHERE m.user_id = canon.dup_id;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'workouts'
    ) THEN
      UPDATE workouts w
      SET user_id = canon.keep_id
      FROM (
        SELECT a.id AS dup_id, (SELECT MIN(b.id) FROM users b WHERE b.email = a.email) AS keep_id
        FROM users a
        WHERE EXISTS (SELECT 1 FROM users b WHERE b.email = a.email AND b.id < a.id)
      ) canon
      WHERE w.user_id = canon.dup_id;
    END IF;

    -- 3) Remove duplicate users, keep smallest id.
    DELETE FROM users
    WHERE id IN (
      SELECT a.id
      FROM users a
      WHERE EXISTS (SELECT 1 FROM users b WHERE b.email = a.email AND b.id < a.id)
    );

    -- 4) Ensure case-insensitive uniqueness on email.
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email))';
  END IF;
END $$;
