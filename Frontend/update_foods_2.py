import json

filepath = 'assets/foods/verified_tr_extras.json'

new_foods = [
    {
      "id": "trverified_wasa_original",
      "name": "Wasa Original Gevrek Ekmek",
      "category": "Tahıl ve Ekmek",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 334,
        "protein": 9.0,
        "carb": 61.0,
        "fat": 1.5
      },
      "servings": [
        { "id": "s_default", "label": "1 dilim (9g)", "grams": 9, "isDefault": True },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["wasa", "wasa sade", "gevrek ekmek", "kıtır ekmek"],
      "tags": ["verified-source", "wasa", "ekmek", "diyet", "lif kaynağı"],
      "brand": "Wasa",
      "barcode": None,
      "imageUrl": None,
      "source": "Wasa Besin Değerleri"
    },
    {
      "id": "trverified_polonez_hindi_fume",
      "name": "Polonez Hindi Füme",
      "category": "Şarküteri",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 83,
        "protein": 17.0,
        "carb": 1.0,
        "fat": 1.0
      },
      "servings": [
        { "id": "s_default", "label": "1 dilim (10g)", "grams": 10, "isDefault": True },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False },
        { "id": "s_paket", "label": "1 paket (60g)", "grams": 60, "isDefault": False }
      ],
      "aliases": ["hindi füme", "polonez", "polonez hindi", "hindi salam"],
      "tags": ["verified-source", "hindi", "şarküteri", "protein", "füme"],
      "brand": "Polonez",
      "barcode": None,
      "imageUrl": None,
      "source": "Polonez Besin Tablosu"
    },
    {
      "id": "trverified_icim_fit_sut",
      "name": "İçim Fit Protein Süt (Çikolatalı)",
      "category": "Süt ve Süt Ürünleri",
      "basis": { "amount": 100, "unit": "ml" },
      "nutrientsPerBasis": {
        "kcal": 47,
        "protein": 6.5,
        "carb": 5.0,
        "fat": 0.1
      },
      "servings": [
        { "id": "s_default", "label": "1 şişe (500 ml)", "grams": 500, "isDefault": True },
        { "id": "s_100", "label": "100 ml", "grams": 100, "isDefault": False }
      ],
      "aliases": ["içim fit", "protein süt", "içim süt kakaolu"],
      "tags": ["verified-source", "süt", "protein", "içim fit"],
      "brand": "İçim",
      "barcode": None,
      "imageUrl": None,
      "source": "İçim Fit Besin Tablosu"
    },
    {
      "id": "trverified_pinar_lor",
      "name": "Pınar Lor Peyniri",
      "category": "Peynir",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 105,
        "protein": 15.0,
        "carb": 4.0,
        "fat": 3.0
      },
      "servings": [
        { "id": "s_default", "label": "3 yemek kaşığı (50g)", "grams": 50, "isDefault": True },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["lor", "lor peyniri", "pınar lor"],
      "tags": ["verified-source", "peynir", "lor", "protein"],
      "brand": "Pınar",
      "barcode": None,
      "imageUrl": None,
      "source": "Ortalama Lor Peyniri"
    },
    {
      "id": "trverified_uno_tam_bugday",
      "name": "Uno Tam Buğday Ekmeği",
      "category": "Ekmek",
      "basis": { "amount": 100, "unit": "g" },
      "nutrientsPerBasis": {
        "kcal": 245,
        "protein": 10.0,
        "carb": 42.0,
        "fat": 2.5
      },
      "servings": [
        { "id": "s_default", "label": "1 dilim (30g)", "grams": 30, "isDefault": True },
        { "id": "s_100", "label": "100 g", "grams": 100, "isDefault": False }
      ],
      "aliases": ["uno ekmek", "tam buğday", "kepek ekmeği", "uno tam buğday"],
      "tags": ["verified-source", "ekmek", "tam buğday", "uno"],
      "brand": "Uno",
      "barcode": None,
      "imageUrl": None,
      "source": "Uno Besin Tablosu"
    }
]

with open(filepath, 'r') as f:
    data = json.load(f)

data['foods'].extend(new_foods)

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("İkinci parti yemekler eklendi!")
