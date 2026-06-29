import json

with open('frontend/assets/foods/foods_tr.json', encoding='utf-8') as f:
    data = json.load(f)

existing = {i['name'].lower() for i in data['foods']}

def food(fid, name, cat, bg, bu, kcal, prot, carb, fat, slabel, extras=None, aliases=None, tags=None):
    s = [{"id":"s_default","label":slabel,"grams":float(bg),"isDefault":True},
         {"id":"s_100","label":f"100 {bu}","grams":100,"isDefault":False}]
    if extras:
        s += extras
    return {"id":fid,"name":name,"category":cat,
            "basis":{"amount":float(bg),"unit":bu},
            "nutrientsPerBasis":{"kcal":float(kcal),"protein":float(prot),"carb":float(carb),"fat":float(fat)},
            "servings":s,"aliases":aliases or [],"tags":tags or [],
            "brand":None,"barcode":None,"imageUrl":None,
            "source":"Toplu Ekleme - Global, Çikolata, Pratik"}

new_foods = [
    # 1. Global / Asya Fast Food
    food("tr_food_6001_sushi", "Sushi (Karışık Roll)", "Fast Food", 100, "g", 140, 4, 30, 1,
         "100g", [{"id":"s_portion", "label":"1 Porsiyon (6 Parça - 150g)", "grams":150, "isDefault":False},
                  {"id":"s_piece", "label":"1 Adet Roll (25g)", "grams":25, "isDefault":False}],
         ["suşi", "maki", "california roll"], ["fast food", "asya", "pirinç"]),
    food("tr_food_6002_burrito", "Burrito (Etli/Tavuklu)", "Fast Food", 100, "g", 200, 10, 25, 7,
         "100g", [{"id":"s_piece", "label":"1 Adet Dürüm (250g)", "grams":250, "isDefault":False}],
         ["meksika dürümü"], ["fast food", "dürüm", "meksika"]),

    # 2. Market Çikolataları
    food("tr_food_6003_albeni", "Ülker Albeni", "Atıştırmalık & Tatlı", 100, "g", 510, 5, 62, 26,
         "100g", [{"id":"s_piece", "label":"1 Adet (40g)", "grams":40, "isDefault":False}],
         ["albeni çikolata", "karamelli bar"], ["atıştırmalık", "çikolata", "bisküvi"]),
    food("tr_food_6004_dido", "Ülker Dido", "Atıştırmalık & Tatlı", 100, "g", 520, 6, 58, 28,
         "100g", [{"id":"s_piece", "label":"1 Adet (35g)", "grams":35, "isDefault":False}],
         ["dido çikolata", "gofret"], ["atıştırmalık", "çikolata", "gofret"]),
    food("tr_food_6005_metro", "Ülker Metro", "Atıştırmalık & Tatlı", 100, "g", 470, 4, 68, 18,
         "100g", [{"id":"s_piece", "label":"1 Adet (36g)", "grams":36, "isDefault":False}],
         ["metro çikolata", "nugat"], ["atıştırmalık", "çikolata", "karamel"]),
    food("tr_food_6006_karam", "Eti Karam Gurme", "Atıştırmalık & Tatlı", 100, "g", 540, 6, 54, 32,
         "100g", [{"id":"s_piece", "label":"1 Adet (50g)", "grams":50, "isDefault":False}],
         ["karam", "bitter gofret"], ["atıştırmalık", "çikolata", "bitter"]),
    food("tr_food_6007_laviva", "Ülker Laviva", "Atıştırmalık & Tatlı", 100, "g", 530, 5, 58, 30,
         "100g", [{"id":"s_piece", "label":"1 Adet (35g)", "grams":35, "isDefault":False}],
         ["laviva çikolata"], ["atıştırmalık", "çikolata"]),

    # 3. Pratik Yiyecekler
    food("tr_food_6008_hazir_noodle", "Hazır Noodle / Noodle Paketi (Kuru)", "Hazır Gıda", 100, "g", 460, 9, 60, 18,
         "100g", [{"id":"s_pack", "label":"1 Paket (75g)", "grams":75, "isDefault":False}],
         ["indomie", "kıvırcık erişte"], ["hazır gıda", "noodle", "karbonhidrat"]),

    # 4. Kahvaltılık ve Çorba
    food("tr_food_6009_hellim", "Hellim Peyniri", "Kahvaltılık", 100, "g", 330, 22, 2, 26,
         "100g", [{"id":"s_slice", "label":"1 Kalın Dilim (35g)", "grams":35, "isDefault":False}],
         ["kızarmış peynir", "kıbrıs peyniri"], ["kahvaltılık", "peynir", "yağlı"]),
    food("tr_food_6010_iskembe", "İşkembe Çorbası", "Çorba", 100, "g", 90, 8, 3, 5,
         "100g", [{"id":"s_bowl", "label":"1 Kase (250g)", "grams":250, "isDefault":False}],
         ["sakatat çorbası"], ["çorba", "sakatat", "geleneksel"])
]

added = 0
for f in new_foods:
    if f['name'].lower() not in existing:
        data['foods'].append(f)
        existing.add(f['name'].lower())
        added += 1
        print(f"  ✓ {f['name']}")
    else:
        print(f"  – Zaten var: {f['name']}")

with open('frontend/assets/foods/foods_tr.json', 'w', encoding='utf-8') as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)

print(f"\\n{added} yeni gıda eklendi. Yeni toplam: {len(data['foods'])}")
