# Diyet / Kalori Takibi – Test Checklist

## 1. Profil kaydediliyor mu?
- [ ] Profil ekranından cinsiyet, yaş, kilo, boy, aktivite, hedef girip "Kaydet"e bas.
- [ ] Uygulamayı kapatıp aç; profil hâlâ dolu mu? (Hive persistence)
- [ ] Profil düzenle, kaydet; değişiklik kalıcı mı?

## 2. Hedef kalori doğru hesaplanıyor mu?
- [ ] Erkek, 30 yaş, 80 kg, 175 cm, Orta aktif, Kilo koru → BMR ≈ 1825, TDEE ≈ 2829, hedef ≈ 2829.
- [ ] Aynı profil, Kilo ver → hedef ≈ TDEE * 0.85 (≈ 2405).
- [ ] Aynı profil, Kilo al → hedef ≈ TDEE * 1.10 (≈ 3112).
- [ ] Kadın, 25 yaş, 60 kg, 165 cm → BMR formülü (−161) uygulanıyor mu?

## 3. 100g → 250 kcal olan yiyecekte 180g girince 450 kcal oluyor mu?
- [ ] Mock listede 100g = 250 kcal olan bir yiyecek seç (veya ekle).
- [ ] Porsiyon ekranında 180 g gir.
- [ ] Hesaplanan kalori 450 kcal olmalı (250 * 180/100).

## 4. Gün değişince ayrı günlük liste oluşuyor mu?
- [ ] Bugün bir yemek ekle.
- [ ] Takvimden dünü seç; dünün listesi boş olmalı.
- [ ] Düne bir yemek ekle.
- [ ] Bugüne dön; sadece bugünkü kayıt görünmeli.
- [ ] Düne dön; sadece dünkü kayıt görünmeli.

## 5. Öğünlere göre toplamlar doğru mu?
- [ ] Kahvaltıya A yiyeceği (100 kcal), öğleye B (200 kcal), akşama C (150 kcal) ekle.
- [ ] Günlük özet: Alınan = 450 kcal, Kalan = hedef − 450.
- [ ] Her öğün kartında sadece o öğüne eklenen item’lar listelenmeli.

## 6. Validasyon
- [ ] Profil: yaş 9 veya 101 → hata mesajı.
- [ ] Profil: kilo 29 veya 251 → hata mesajı.
- [ ] Profil: boy 119 veya 221 → hata mesajı.
- [ ] Porsiyon: 0 veya negatif gram → "Geçerli bir gram girin" veya hesaplama 0.

## 7. Boş durumlar
- [ ] Profil yokken dashboard’da "Profil oluştur" mesajı ve buton.
- [ ] Öğünde hiç kayıt yokken "Henüz eklenmedi." mesajı.
- [ ] Yemek aramada sonuç yokken "Sonuç yok." mesajı.
