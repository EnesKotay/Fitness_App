-- Email'leri küçük harfe çek; aynı email'in farklı yazımları tek kayıt kalacak.
-- Child tablolar (weight_records, meals, workouts) varsa önce onlardaki user_id canonical'e çekilir, sonra duplicate user silinir.

-- 1) Tüm email'leri trim + lowercase yap
UPDATE users SET email = LOWER(TRIM(email)) WHERE email IS NOT NULL AND email != '';

-- 2) Duplicate email'li user silinmeden önce child tablolardaki user_id'yi canonical (min id) yap (FK hatası önlenir)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'weight_records') THEN
    UPDATE weight_records wr
    SET user_id = canon.keep_id
    FROM (
      SELECT a.id AS dup_id, (SELECT MIN(b.id) FROM users b WHERE b.email = a.email) AS keep_id
      FROM users a
      WHERE EXISTS (SELECT 1 FROM users b WHERE b.email = a.email AND b.id < a.id)
    ) canon
    WHERE wr.user_id = canon.dup_id;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'meals') THEN
    UPDATE meals m
    SET user_id = canon.keep_id
    FROM (
      SELECT a.id AS dup_id, (SELECT MIN(b.id) FROM users b WHERE b.email = a.email) AS keep_id
      FROM users a
      WHERE EXISTS (SELECT 1 FROM users b WHERE b.email = a.email AND b.id < a.id)
    ) canon
    WHERE m.user_id = canon.dup_id;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'workouts') THEN
    UPDATE workouts w
    SET user_id = canon.keep_id
    FROM (
      SELECT a.id AS dup_id, (SELECT MIN(b.id) FROM users b WHERE b.email = a.email) AS keep_id
      FROM users a
      WHERE EXISTS (SELECT 1 FROM users b WHERE b.email = a.email AND b.id < a.id)
    ) canon
    WHERE w.user_id = canon.dup_id;
  END IF;
END $$;

-- 3) Aynı email'e sahip çoklu kayıt varsa sadece en küçük id'liyi bırak (subquery ile; linter uyarısı önlenir)
DELETE FROM users
WHERE id IN (
  SELECT a.id FROM users a
  WHERE EXISTS (SELECT 1 FROM users b WHERE b.email = a.email AND b.id < a.id)
);


-- 4) LOWER(email) üzerinde unique index
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email));
