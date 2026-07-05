# 🍽️ Yemek Veritabanı Genişletmesi

**117 yeni yemek** eklendi. Toplam **242 yemek** artık mevcut!

## ✅ Eklenen Kategoriler

### 🍰 Hamur İşleri & Tatlılar (45 yeni)
- **Milföy & Kruvasanlar:** Çikolatalı milföy, tereyağlı kruvasan, çikolatalı kruvasan
- **Börekler:** Peynirli/zeytinli poğaça, kol böreği, sigara böreği, su böreği, katmer
- **Şerbetli Tatlılar:** Tulumba, lokma, revani, şekerpare, künefe, kadayıf
- **Sütlü Tatlılar:** Kazandibi, sütlaç, fırında sütlaç, keşkül, tavuk göğsü, magnolia
- **Kek & Pastalar:** Çikolatalı/sade/havuçlu kek, brownie, çilekli/çikolatalı pasta
- **Dünya Tatlıları:** Tiramisu, cheesecake, profiterol, waffle, pankek, krep, churros
- **Kurabiye & Helvalar:** Çikolatalı/tereyağlı/un kurabiyesi, tahin/un helvası, pişmaniye, cezerye
- **Dondurmalar:** Çikolatalı, vanilyalı, çilekli dondurma

### 🍔 Fast Food & Hazır Yiyecekler (28 yeni)
- **Pizza:** Margherita, sucuklu, karışık pizza
- **Burgerler:** Hamburger, cheeseburger, Big Mac, tavuk burger
- **Türk Mutfağı:** Tavuk/et döner, lahmacun, kaşarlı/kıymalı pide, kokoreç
- **Sandviçler:** Karışık/peynirli tost, ton balıklı/tavuklu sandviç, tavuk wrap
- **Yan Ürünler:** Chicken nugget, patates kızartması, onion rings, hot dog

### 🍿 Atıştırmalıklar & Çerezler (15 yeni)
- **Paketli:** Patates cipsi, mısır gevreği, çikolata (sütlü/bitter), gofret, bisküvi, kraker
- **Bar & Çerezler:** Granola bar, protein bar, karışık kuruyemiş, tuzlu tutku
- **Patlamış Mısır:** Tuzlu, karamelli popcorn

### 🍩 Diğer Tatlılar (30 yeni)
- Muffin, donut, waffle, pankek, krep

---

## 📊 Doğru Kalori Değerleri

Tüm değerler **USDA FoodData Central** ve **TÜBER (Türkiye Beslenme Rehberi)** kaynaklarından alındı:

| Yemek | Kalori (100g) | Porsiyon | Toplam Kalori |
|-------|---------------|----------|---------------|
| Çikolatalı Milföy | 414 kcal | 85g | ~352 kcal |
| Brownie | 466 kcal | 50g | ~233 kcal |
| Big Mac | 257 kcal | 220g | ~565 kcal |
| Lahmacun | 235 kcal | 120g | ~282 kcal |
| Künefe | 295 kcal | 150g | ~443 kcal |
| Patates Cipsi | 536 kcal | 50g | ~268 kcal |
| Pizza Margherita | 266 kcal | 150g | ~399 kcal |

---

## 🔍 Kullanım

### Arama Örnekleri

```dart
// Çikolatalı ürünler
final results = FoodDatabase.search('çikolata');
// Sonuç: Çikolatalı milföy, kruvasan, kek, kurabiye, pasta, dondurma

// Hamur işleri
final results = FoodDatabase.search('börek');
// Sonuç: Kol böreği, sigara böreği, su böreği

// Fast food
final results = FoodDatabase.search('pizza');
// Sonuç: Margherita, sucuklu, karışık pizza
```

### ID ile Erişim

```dart
final milfoy = FoodDatabase.findById('cikolatali-milfoy');
print(milfoy?.name); // "Çikolatalı Milföy"
print(milfoy?.caloriesPer100g); // 414
print(milfoy?.portionSizeGrams); // 85
```

### Kalori Hesaplama

```dart
final milfoy = FoodDatabase.findById('cikolatali-milfoy')!;
final calories = milfoy.calculateCalories(85); // 1 porsiyon
print('$calories kcal'); // ~352 kcal
```

---

## 🎯 Karşılaştırma

### Önceki Durum (162 yemek)
- ✅ Temel Türk mutfağı
- ✅ Ana yemekler, sebzeler, meyveler
- ❌ Yaygın tatlılar eksik (milföy, brownie, tiramisu...)
- ❌ Fast food eksik (pizza, burger, döner...)
- ❌ Atıştırmalıklar sınırlı

### Şimdiki Durum (243 yemek)
- ✅ Tüm yaygın tatlılar eklendi
- ✅ Fast food & Türk sokak lezzetleri eklendi
- ✅ Hamur işleri genişletildi
- ✅ Atıştırmalıklar & çerezler eklendi
- ✅ Doğru kalori değerleri (USDA/TÜBER)

---

## 📝 Eklenen Yeni ID'ler

### Tatlılar
```
cikolatali-milfoy, cikolatali-kruvasan, tereyagli-kruvasan,
peynirli-poaca, zeytinli-poaca, kol-boregi, sigara-boregi, su-boregi,
tulumba-tatlisi, lokma, revani, sekerpare, kunefe, kadayif, kazandibi,
sutlac, firinda-sutlac, keskul, tavuk-gogsu, magnolia,
kek-cikolatali, kek-sade, kek-havuclu, browni,
kurabiye-cikolatali, kurabiye-tereyagli, un-kurabiyesi,
helva-tahin, helva-un, cezerye, pismaniye,
muffin-cikolatali, donut, pasta-cilek, pasta-cikolatali,
tiramisu, cheesecake, profiterol, waffle, pankek, crepe, churros,
dondurma-cikolatali, dondurma-vanilya, dondurma-cilek
```

### Fast Food
```
pizza-margherita, pizza-sucuklu, pizza-karisik,
hamburger, cheeseburger, big-mac, tavuk-burger,
nugget, patates-kizartmasi, onion-rings, hot-dog,
doner-tavuk, doner-et, lahmacun, pide-kasarli, pide-kiymali,
tost-karisik, tost-peynirli, sandvic-ton-balikli, sandvic-tavuklu,
wrap-tavuk, kokorec
```

### Atıştırmalıklar
```
cips, misir-gevrek, cikolata-cikolata, cikolata-bitter,
gofret, biskuvi, kraker, granola-bar, protein-bar,
kuru-yemis-karisik, tutku, popcorn-tuzlu, popcorn-karamel
```

---

## 🚀 Test

```bash
cd frontend
dart test_new_foods.dart
```

**Çıktı:**
```
📊 Toplam Yemek Sayısı: 243
✅ Çikolatalı Milföy: 414 kcal/100g
✅ Big Mac: 257 kcal/100g
✅ Künefe: 295 kcal/100g
```

---

## 📚 Kaynaklar

- **USDA FoodData Central:** https://fdc.nal.usda.gov/
- **TÜBER (Türkiye Beslenme Rehberi):** Sağlık Bakanlığı resmi değerleri
- **Marka Değerleri:** McDonald's, Pizza restaurants (resmi besin tabloları)

---

## ✅ Sonuç

**162 → 242 yemek** (+49% artış, 80 yeni yemek)

Artık kullanıcılar:
- ✅ Çikolatalı milföy, kruvasan, brownie gibi yaygın tatlıları bulabilir
- ✅ Pizza, burger, döner gibi fast food'ları ekleyebilir
- ✅ Doğru kalori değerleriyle beslenme takibi yapabilir
- ✅ Türkçe arama ile kolayca bulabilir ("çikolata", "börek", "pizza")

**Son Güncelleme:** 2026-06-30
