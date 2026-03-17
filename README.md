# Fitness App

Modern bir fitness, beslenme ve ilerleme takip uygulamasi. Proje; Flutter tabanli mobil uygulama ve Quarkus tabanli backend servisinden olusur.

## Ozellikler

- Gunluk kalori, makro ve beslenme takibi
- Antrenman planlama ve bolge bazli egzersiz kesfi
- Kilo ve vucut olcusu takibi
- AI destekli koçluk ve beslenme yardimcisi
- Premium akislar, bildirimler ve offline/senkronizasyon altyapisi

## Ekran Goruntuleri

<p align="center">
  <img src="frontend/assets/images/anasayfa.png" alt="Ana sayfa" width="220" />
  <img src="frontend/assets/images/workout_chest.png" alt="Antrenman" width="220" />
  <img src="frontend/assets/images/tracking_bg_v2.jpg" alt="Takip" width="220" />
  <img src="frontend/assets/images/nutrition_bg_dark.png" alt="Beslenme" width="220" />
</p>

## Proje Yapisi

- `frontend/`: Flutter mobil uygulamasi
- `backend/`: Quarkus REST API ve is mantigi

## Hizli Baslangic

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

AI ozellikleri icin `frontend/.env` dosyasina asagidaki anahtari ekleyebilirsin:

```env
GEMINI_API_KEY=your_api_key
```

### Backend

```bash
cd backend
./mvnw quarkus:dev
```

Mail tabanli sifre sifirlama akisini gercek SMTP ile calistirmak istersen gerekli `MAIL_*` degiskenlerini tanimlamalisin. Ayrintilar icin [backend/README.md](/Users/eneskotay/Development/Fitness_App-main/backend/README.md) dosyasina bakabilirsin.

## Dokumantasyon

- [frontend/README.md](/Users/eneskotay/Development/Fitness_App-main/frontend/README.md)
- [backend/README.md](/Users/eneskotay/Development/Fitness_App-main/backend/README.md)

