# 🏋️ Exercise Library Integration

**1,324 egzersiz** içeren [hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) PusulaFit'e entegre edildi.

## ✅ Tamamlanan Entegrasyonlar

### Backend (Quarkus)

#### 1. Database Migration
- **V13__create_exercise_library.sql**
- Tablo: `exercise_library`
- 6 dil desteği (EN, TR, ES, IT, RU, ZH)
- Index'ler: category, equipment, target, body_part

#### 2. Entity & DTO
- `ExerciseLibrary.java` (Panache entity)
- `ExerciseLibraryDTO.java`

#### 3. Service Layer
- `ExerciseLibraryService.java`
  - Dil bazlı filtering
  - JSON array parsing (secondary_muscles, instruction_steps)
  - Category/equipment/target bazlı sorgular

#### 4. REST API
- `ExerciseLibraryResource.java`
- Endpoint: `/api/exercises`

#### 5. Data Import Script
- `backend/scripts/import_exercises.py`
- PostgreSQL'e otomatik import

### Frontend (Flutter)

#### 1. Model
- `ExerciseLibrary` (freezed model)
- `ExerciseFilter`
- `ExerciseCategory` (10 kategori)
- `ExerciseEquipment` (11 ekipman tipi)

#### 2. Service & Provider
- `ExerciseLibraryService` (Dio HTTP client)
- `ExerciseLibraryProvider` (ChangeNotifier state management)

#### 3. UI Screen
- `ExerciseLibraryScreen`
  - Arama özelliği
  - Kategori/ekipman filtreleri
  - Detay bottom sheet (adım adım talimatlar)

#### 4. Routes
- `/exercise-library` route eklendi
- `app_providers.dart` içinde provider kaydı

---

## 🚀 Kullanım

### Backend Deployment

```bash
cd /Users/eneskotay/Development/Fitness_App-main/backend

# 1. Migration çalıştır (Quarkus otomatik Flyway migration yapar)
./mvnw quarkus:dev

# 2. Egzersizleri import et
python3 scripts/import_exercises.py
```

#### DB Config (Python script için)
`scripts/import_exercises.py` dosyasındaki `DB_CONFIG` değişkenini güncelle:

```python
DB_CONFIG = {
    'host': 'localhost',  # veya production DB host
    'port': 5432,
    'database': 'fitness_db',
    'user': 'postgres',
    'password': 'your_password'
}
```

### REST API Endpoints

```bash
# Tüm egzersizler (Türkçe)
GET /api/exercises?language=tr

# Arama
GET /api/exercises?search=bench&language=tr

# Kategori filtresi
GET /api/exercises?category=chest&language=tr

# Ekipman filtresi
GET /api/exercises?equipment=dumbbell&language=tr

# Ekipmansız egzersizler
GET /api/exercises/bodyweight?language=tr

# Tek egzersiz detayı
GET /api/exercises/0001?language=tr

# Kategoriler
GET /api/exercises/categories

# Ekipman tipleri
GET /api/exercises/equipment
```

### Frontend Navigation

```dart
// Egzersiz kütüphanesini aç
Navigator.pushNamed(context, AppRoutes.exerciseLibrary);
```

#### Provider Kullanımı

```dart
// Load all exercises
final provider = context.read<ExerciseLibraryProvider>();
await provider.loadExercises();

// Search
await provider.searchExercises('push up');

// Filter by category
await provider.filterByCategory('chest');

// Bodyweight only
await provider.loadBodyweightExercises();

// Get exercise by ID
final exercise = provider.getExerciseById('0001');
```

---

## 📊 Dataset İstatistikleri

### Vücut Bölgelerine Göre Dağılım

| Kategori | Egzersiz Sayısı |
|----------|-----------------|
| Upper Arms | 292 |
| Upper Legs | 227 |
| Back | 203 |
| Waist | 169 |
| Chest | 163 |
| Shoulders | 143 |
| Lower Legs | 59 |
| Lower Arms | 37 |
| Cardio | 29 |
| Neck | 2 |

### Ekipmana Göre Dağılım

| Ekipman | Egzersiz Sayısı |
|---------|-----------------|
| Body Weight | 325 |
| Dumbbell | 294 |
| Cable | 157 |
| Barbell | 154 |
| Leverage Machine | 81 |
| Band | 54 |
| Smith Machine | 48 |
| Kettlebell | 41 |
| Other | 110 |

**⚠️ Not:** %25 egzersiz ekipmansız → Evde antrenman için ideal

---

## 🎯 AI Coach Entegrasyonu (Sonraki Adım)

### Önerilen İyileştirmeler

1. **AI Coach'a Exercise Library Bağla**
   - Kullanıcı "göğüs egzersizleri öner" dediğinde dataset'ten seç
   - Premium kullanıcılar için Claude API ile kişiselleştirilmiş program

2. **Workout Screen'e "Kütüphaneden Seç" Butonu**
   - Kullanıcı kendi egzersizini yazmak yerine listeden seçebilir
   - Adım adım talimatlar zaten hazır

3. **Smart Recommendations**
   - Kullanıcının ekipmanına göre filtrele (`equipmentType` preference)
   - Kullanıcının hedefine göre sırala (kilo verme → cardio, kas yapma → strength)

### Örnek AI Coach Prompt Enhancement

```dart
// AI Coach'a gönderilecek context
final availableEquipment = StorageHelper.getEquipmentType(); // "body weight" | "dumbbell" | "full gym"
final userGoal = profile?.goal; // "weight_loss" | "muscle_gain" | "maintenance"

// Backend'de CoachPromptBuilder.java güncelleme
String prompt = """
Kullanıcı hedefi: ${userGoal}
Mevcut ekipman: ${availableEquipment}

Egzersiz önerirken /api/exercises endpoint'inden 
kategori ve ekipman filtreleyerek seç.
""";
```

---

## 🐛 Troubleshooting

### Backend

**Flyway migration hatası:**
```bash
# Migration'ı manuel çalıştır
psql -U postgres -d fitness_db -f backend/src/main/resources/db/migration/V13__create_exercise_library.sql
```

**Import script hatası:**
```bash
# psycopg2 yükle
pip3 install psycopg2-binary

# Veya PostgreSQL client library eksikse
brew install postgresql
```

### Frontend

**Freezed code generation:**
```bash
cd Frontend
dart run build_runner build --delete-conflicting-outputs
```

**Provider not found:**
```dart
// app_providers.dart içinde ExerciseLibraryProvider kayıtlı olmalı
Provider(create: (_) => ExerciseLibraryService(ApiClient())),
ChangeNotifierProvider(
  create: (context) => ExerciseLibraryProvider(
    context.read<ExerciseLibraryService>(),
  ),
),
```

---

## 📚 Referanslar

- Dataset: https://github.com/hasaneyldrm/exercises-dataset
- Original source: ExerciseDB v1 by AscendAPI
- Media: Görseller dataset'e dahil DEĞİL (telif hakkı belirsizliği nedeniyle)

---

## ✅ Next Steps

1. ✅ Backend migration + entity + REST API
2. ✅ Frontend model + service + provider + UI
3. ⏳ Import 1,324 exercises to DB
4. ⏳ AI Coach entegrasyonu
5. ⏳ Workout screen'e "Kütüphaneden Seç" özelliği
6. ⏳ Ekipman bazlı smart filtering

**Son Güncelleme:** 2026-06-30
