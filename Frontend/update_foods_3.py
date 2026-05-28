import json

filepath = 'assets/foods/verified_tr_extras.json'

new_foods = [
    {
      "id": "trverified_tavuk_gogsu_cig",
      "name": "Tavuk Göğsü (Çiğ)",
      "category": "Et ve Tavuk",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 110,
        "protein": 23.0,
        "carb": 0.0,
        "fat": 1.5
      },
      "servings": [
        { "id": "s_default", "label": "100 g", "grams": 100, "isDefault": True },
        { "id": "s_paket", "label": "1 standart paket (500g)", "grams": 500, "isDefault": False }
      ],
      "aliases": ["tavuk", "tavuk göğsü", "çiğ tavuk", "tavuk göğsü çiğ"],
      "tags": ["verified-source", "tavuk", "protein", "et"],
      "brand": None,
      "barcode": None,
      "imageUrl": None,
      "source": "Ortalama Çiğ Tavuk Göğsü Değerleri"
    },
    {
      "id": "trverified_zuber_lokma_kakaolu",
      "name": "Züber Lokma (Kakaolu Fındıklı)",
      "category": "Atıştırmalık – Meyve Tatlısı",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 355,
        "protein": 7.9,
        "carb": 45.0,
        "fat": 12.0
      },
      "servings": [
        { "id": "s_default", "label": "1 paket (96g)", "grams": 96, "isDefault": True },
        { "id": "s_top", "label": "3 top / lokma (28g)", "grams": 28, "isDefault": False },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["züber lokma", "zuber lokma kakaolu", "meyve topu"],
      "tags": ["verified-source", "züber", "atıştırmalık", "sağlıklı tatlı"],
      "brand": "Züber",
      "barcode": None,
      "imageUrl": None,
      "source": "Züber Lokma Besin Tablosu"
    },
    {
      "id": "trverified_torku_suzme_peynir",
      "name": "Torku Süzme Peynir (Tam Yağlı)",
      "category": "Peynir",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 244,
        "protein": 11.5,
        "carb": 2.5,
        "fat": 21.0
      },
      "servings": [
        { "id": "s_default", "label": "1 dilim (30g)", "grams": 30, "isDefault": True },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False },
        { "id": "s_paket", "label": "1 kutu (500g)", "grams": 500, "isDefault": False }
      ],
      "aliases": ["torku süzme", "süzme peynir", "tam yağlı süzme peynir"],
      "tags": ["verified-source", "peynir", "süzme", "torku", "kahvaltı"],
      "brand": "Torku",
      "barcode": None,
      "imageUrl": None,
      "source": "Torku Ambalaj Değerleri"
    },
    {
      "id": "trverified_karabugday_grecka_cig",
      "name": "Karabuğday / Greçka (Çiğ)",
      "category": "Tahıl ve Bakliyat",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 343,
        "protein": 13.3,
        "carb": 71.5,
        "fat": 3.4
      },
      "servings": [
        { "id": "s_default", "label": "1 porsiyon (60g)", "grams": 60, "isDefault": True },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["karabuğday", "greçka", "çiğ karabuğday", "greçka çiğ"],
      "tags": ["verified-source", "karabuğday", "tahıl", "glutensiz", "kompleks karbonhidrat"],
      "brand": None,
      "barcode": None,
      "imageUrl": None,
      "source": "Genel Karabuğday Değerleri"
    },
    {
      "id": "trverified_haslanmis_yumurta",
      "name": "Haşlanmış Yumurta",
      "category": "Yumurta",
      "basis": { "amount": 50, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 75,
        "protein": 6.3,
        "carb": 0.6,
        "fat": 5.3
      },
      "servings": [
        { "id": "s_default", "label": "1 adet L boy (50g)", "grams": 50, "isDefault": True },
        { "id": "s_m_boy", "label": "1 adet M boy (45g)", "grams": 45, "isDefault": False },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["yumurta haşlama", "haşlanmış yumurta", "katı yumurta"],
      "tags": ["verified-source", "yumurta", "protein", "kahvaltı"],
      "brand": None,
      "barcode": None,
      "imageUrl": None,
      "source": "Ortalama Yumurta Değerleri"
    }
]

with open(filepath, 'r') as f:
    data = json.load(f)

data['foods'].extend(new_foods)

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Üçüncü parti yemekler eklendi!")
