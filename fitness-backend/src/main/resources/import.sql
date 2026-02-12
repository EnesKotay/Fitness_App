-- Örnek egzersizler (geliştirme için). Tablo yoksa Hibernate oluşturur; sonra bu script çalışır.
-- PostgreSQL'de id genelde SERIAL/BIGSERIAL ile otomatik. Panache ile tablo adı: exercises.

INSERT INTO exercises (muscle_group, name, description, instructions) VALUES
('CHEST', 'Bench Press', 'Göğüs, ön omuz ve triceps çalıştırır.', '3 set x 8-12 tekrar. Bar göğüs hizasında indirip kaldır.'),
('CHEST', 'Incline Dumbbell Press', 'Üst göğüs ve ön omuz.', '3 set x 10-12 tekrar. Bank 30-45° eğim.'),
('CHEST', 'Cable Fly', 'Göğüs içi ve yan bölge.', '3 set x 12-15 tekrar. Kolları yanlara açıp birleştir.'),
('CHEST', 'Push-Up', 'Tüm göğüs ve core.', '3 set x 15-20 tekrar. Gövde düz, dirsekler 45° dışa.'),
('BACK', 'Barbell Row', 'Sırt kalınlığı ve genişliği.', '3 set x 8-12 tekrar. Barı bele doğru çek.'),
('BACK', 'Pull-Up', 'Üst sırt ve kol çekme gücü.', '3 set x max tekrar. Avuç dışa, çeneyi barın üstüne.'),
('BACK', 'Lat Pulldown', 'Geniş sırt.', '3 set x 10-12 tekrar. Barı göğüse doğru çek.'),
('BACK', 'Deadlift', 'Tüm sırt ve bacak arka zincir.', '3 set x 6-10 tekrar. Dizleri bükmeden barı kaldır.'),
('LEGS', 'Squat', 'Ön bacak ve kalça.', '3 set x 8-12 tekrar. Dizler ayak ucu yönünde.'),
('LEGS', 'Leg Press', 'Quadriceps ve kalça.', '3 set x 10-15 tekrar. Platformu it, diz 90°yi geçmesin.'),
('LEGS', 'Romanian Deadlift', 'Arka bacak ve kalça.', '3 set x 10-12 tekrar. Hafif diz bükük, kalçayı geri it.'),
('LEGS', 'Leg Curl', 'Arka bacak (hamstring).', '3 set x 12-15 tekrar. Topukları kalçaya doğru çek.'),
('SHOULDERS', 'Overhead Press', 'Tüm omuz başı.', '3 set x 8-10 tekrar. Barı baş üstüne it.'),
('SHOULDERS', 'Lateral Raise', 'Yan omuz.', '3 set x 12-15 tekrar. Kolları yanlara kaldır.'),
('SHOULDERS', 'Face Pull', 'Arka omuz ve sırt.', '3 set x 15 tekrar. Halatı yüze doğru çek.'),
('BICEPS', 'Barbell Curl', 'Biseps ana hareket.', '3 set x 10-12 tekrar. Dirsekler sabit, barı kıvır.'),
('BICEPS', 'Hammer Curl', 'Biseps ve ön kol.', '3 set x 12 tekrar. Avuçlar içe bakacak şekilde kıvır.'),
('BICEPS', 'Preacher Curl', 'Biseps izolasyon.', '3 set x 12 tekrar. Kol destekli, kontrollü kıvır.'),
('TRICEPS', 'Tricep Pushdown', 'Triceps izolasyon.', '3 set x 12-15 tekrar. Kabloyu aşağı it.'),
('TRICEPS', 'Skull Crusher', 'Triceps uzun baş.', '3 set x 10-12 tekrar. Barı alna doğru indir.'),
('TRICEPS', 'Close-Grip Bench Press', 'Triceps ve göğüs içi.', '3 set x 8-12 tekrar. Eller omuz genişliğinde.'),
('CORE', 'Plank', 'Core stabilitesi.', '3 set x 30-60 sn. Gövde düz, kalça yukarıda değil.'),
('CORE', 'Cable Crunch', 'Üst karın.', '3 set x 15-20 tekrar. Halatla göğüsten aşağı kıvrıl.'),
('CORE', 'Leg Raise', 'Alt karın.', '3 set x 12-15 tekrar. Bacakları düz kaldır, kalçayı kaldırma.'),
('GLUTES', 'Hip Thrust', 'Kalça kasları.', '3 set x 12-15 tekrar. Sırt bankta, kalçayı yukarı it.'),
('GLUTES', 'Glute Bridge', 'Kalça ve hamstring.', '3 set x 15 tekrar. Sırt üstü, kalçayı kaldır.')
;
