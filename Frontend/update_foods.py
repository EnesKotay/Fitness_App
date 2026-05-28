import json

filepath = 'assets/foods/verified_tr_extras.json'

new_foods = [
    {
      "id": "trverified_zuber_peanut_butter",
      "name": "Züber %100 Yer Fıstığı Ezmesi",
      "category": "Kahvaltılık – Ezme",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 625,
        "protein": 27.0,
        "carb": 16.0,
        "fat": 49.0
      },
      "servings": [
        { "id": "s_default", "label": "1 tatlı kaşığı (10g)", "grams": 10, "isDefault": True },
        { "id": "s_yemek", "label": "1 yemek kaşığı (15g)", "grams": 15, "isDefault": False },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["züber fıstık ezmesi", "zuber fistik ezmesi", "katkısız fıstık ezmesi", "şekersiz fıstık ezmesi"],
      "tags": ["verified-source", "fıstık ezmesi", "züber", "sağlıklı yağ", "kahvaltı"],
      "brand": "Züber",
      "barcode": None,
      "imageUrl": None,
      "source": "Züber Resmi Web Sitesi"
    },
    {
      "id": "trverified_eti_lifalif",
      "name": "Eti Lifalif Yulaf Ezmesi",
      "category": "Tahıl ve Gevrekler",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 365,
        "protein": 14.0,
        "carb": 60.0,
        "fat": 7.5
      },
      "servings": [
        { "id": "s_default", "label": "1 kase (50g)", "grams": 50, "isDefault": True },
        { "id": "s_kasik", "label": "1 yemek kaşığı (10g)", "grams": 10, "isDefault": False },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["eti lifalif", "yulaf", "yulaf ezmesi"],
      "tags": ["verified-source", "yulaf", "lifalif", "kahvaltı", "kompleks karbonhidrat", "lif kaynağı"],
      "brand": "Eti",
      "barcode": None,
      "imageUrl": None,
      "source": "Eti Ürün Analiz Değerleri"
    },
    {
      "id": "trverified_dardanel_ton",
      "name": "Dardanel Zeytinyağlı Ton Balığı (Süzülmüş)",
      "category": "Deniz Ürünleri",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 212,
        "protein": 20.0,
        "carb": 0.1,
        "fat": 11.0
      },
      "servings": [
        { "id": "s_default", "label": "1 kutu süzülmüş ağırlık (104g)", "grams": 104, "isDefault": True },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["dardanel ton", "ton balığı", "konserve ton", "zeytinyağlı ton"],
      "tags": ["verified-source", "ton balığı", "balık", "protein", "dardanel"],
      "brand": "Dardanel",
      "barcode": None,
      "imageUrl": None,
      "source": "Dardanel Ambalaj Değerleri"
    },
    {
      "id": "trverified_pinar_protein_sut",
      "name": "Pınar Protein Süt (Kakaolu)",
      "category": "Süt ve Süt Ürünleri",
      "basis": { "amount": 100, "unit": "ml" },
      "nutrientsPerBasis": {
        "kcal": 49,
        "protein": 5.2,
        "carb": 6.5,
        "fat": 0.4
      },
      "servings": [
        { "id": "s_default", "label": "1 kutu (500 ml)", "grams": 500, "isDefault": True },
        { "id": "s_bardak", "label": "1 su bardağı (200 ml)", "grams": 200, "isDefault": False },
        { "id": "s_100", "label": "100 ml", "grams": 100, "isDefault": False }
      ],
      "aliases": ["pınar protein", "protein süt", "kakaolu protein süt"],
      "tags": ["verified-source", "süt", "protein", "pınar", "kakaolu süt"],
      "brand": "Pınar",
      "barcode": None,
      "imageUrl": None,
      "source": "Pınar Resmi Değerleri"
    },
    {
      "id": "trverified_fellas_protein_bar",
      "name": "Fellas Protein Bar (Kakaolu)",
      "category": "Atıştırmalık – Bar",
      "basis": { "amount": 45, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 166,
        "protein": 15.0,
        "carb": 18.0,
        "fat": 3.0
      },
      "servings": [
        { "id": "s_default", "label": "1 paket (45g)", "grams": 45, "isDefault": True },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["fellas", "fellas bar", "protein bar kakaolu", "fellas protein"],
      "tags": ["verified-source", "protein bar", "fellas", "atıştırmalık"],
      "brand": "Fellas",
      "barcode": None,
      "imageUrl": None,
      "source": "Fellas Foods Besin Tablosu"
    }
]

with open(filepath, 'r') as f:
    data = json.load(f)

data['foods'].extend(new_foods)

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Yemekler eklendi!")
