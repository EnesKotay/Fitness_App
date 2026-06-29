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
            "source":"Toplu Ekleme - Diyet, Atıştırmalık, Reçel"}

new_foods = [
    # 1. Diyet Bisküvi ve Krakerler
    food("tr_food_7001_eti_form", "Eti Form Kepekli Bisküvi", "Atıştırmalık", 100, "g", 400, 9, 70, 7,
         "100g", [{"id":"s_pack", "label":"1 Paket (45g)", "grams":45, "isDefault":False}],
         ["form bisküvi", "diyet bisküvi"], ["atıştırmalık", "diyet", "kepekli"]),
    food("tr_food_7002_eti_burcak", "Eti Burçak Yulaflı Bisküvi", "Atıştırmalık & Tatlı", 100, "g", 450, 7, 65, 18,
         "100g", [{"id":"s_pack", "label":"1 Paket (130g)", "grams":130, "isDefault":False},
                  {"id":"s_piece", "label":"1 Adet (10g)", "grams":10, "isDefault":False}],
         ["burçak", "yulaflı bisküvi"], ["atıştırmalık", "bisküvi", "yulaf"]),
    food("tr_food_7003_altinbasak", "Ülker Altınbaşak Kepekli Kraker", "Atıştırmalık", 100, "g", 410, 10, 60, 10,
         "100g", [{"id":"s_pack", "label":"1 Paket (45g)", "grams":45, "isDefault":False}],
         ["altınbaşak", "diyet kraker"], ["atıştırmalık", "diyet", "kraker"]),
    food("tr_food_7004_wasa", "Wasa (Sade Gevrek Ekmek)", "Tahıl & Ekmek", 100, "g", 330, 10, 60, 2,
         "100g", [{"id":"s_slice", "label":"1 Dilim (10g)", "grams":10, "isDefault":False}],
         ["vaza", "gevrek ekmek", "wasa sade"], ["ekmek", "diyet", "lifli"]),
    food("tr_food_7005_kepekligaleta", "Kepekli Galeta", "Fırın & Pide", 100, "g", 380, 12, 75, 4,
         "100g", [{"id":"s_piece", "label":"1 Adet (10g)", "grams":10, "isDefault":False}],
         ["galeta", "kepekli çubuk"], ["atıştırmalık", "diyet", "fırın"]),
    food("tr_food_7006_grissini", "Grissini (Sade)", "Fırın & Pide", 100, "g", 400, 10, 72, 8,
         "100g", [{"id":"s_pack", "label":"1 Paket (40g)", "grams":40, "isDefault":False}],
         ["grisini", "kıtır çubuk"], ["atıştırmalık", "fırın"]),

    # 2. Yeni Nesil Barlar ve Patlaklar
    food("tr_food_7007_zuber", "Züber / Meyve Barı", "Ara Öğün", 100, "g", 380, 8, 60, 12,
         "100g", [{"id":"s_piece", "label":"1 Adet (40g)", "grams":40, "isDefault":False}],
         ["züber bar", "hurma barı", "şekersiz bar"], ["atıştırmalık", "diyet", "sağlıklı"]),
    food("tr_food_7008_pirincpatlagi", "Pirinç Patlağı (Sade / Rice Cake)", "Atıştırmalık", 100, "g", 390, 8, 80, 3,
         "100g", [{"id":"s_piece", "label":"1 Adet (7g)", "grams":7, "isDefault":False}],
         ["rice cake", "pirinç galetası"], ["atıştırmalık", "diyet", "glutensiz"]),
    food("tr_food_7009_misirpatlagi", "Mısır Patlağı (Sade)", "Atıştırmalık", 100, "g", 380, 7, 85, 1,
         "100g", [{"id":"s_piece", "label":"1 Adet (7g)", "grams":7, "isDefault":False}],
         ["mısır galetası", "corn cake"], ["atıştırmalık", "diyet", "glutensiz"]),

    # 3. Sokak Lezzetleri
    food("tr_food_7010_bardaktamisir", "Bardakta Mısır (Tereyağlı)", "Sokak Yemeği", 100, "g", 180, 4, 25, 7,
         "100g", [{"id":"s_cup", "label":"1 Bardak (150g)", "grams":150, "isDefault":False}],
         ["süt mısır", "haşlanmış mısır"], ["sokak lezzeti", "mısır", "yağlı"]),
    food("tr_food_7011_cigborek", "Çiğ Börek", "Hamur İşi", 100, "g", 340, 10, 40, 16,
         "100g", [{"id":"s_piece", "label":"1 Adet (100g)", "grams":100, "isDefault":False}],
         ["çibörek", "eskişehir böreği"], ["hamur işi", "kızartma", "et"]),

    # 4. Reçeller
    food("tr_food_7012_cilekreceli", "Çilek Reçeli", "Kahvaltılık", 100, "g", 280, 0.5, 68, 0,
         "100g", [{"id":"s_spoon_small", "label":"1 Tatlı Kaşığı (10g)", "grams":10, "isDefault":False},
                  {"id":"s_spoon_large", "label":"1 Yemek Kaşığı (20g)", "grams":20, "isDefault":False}],
         ["çilek marmelatı"], ["kahvaltılık", "reçel", "şeker"]),
    food("tr_food_7013_visnereceli", "Vişne Reçeli", "Kahvaltılık", 100, "g", 280, 0.5, 68, 0,
         "100g", [{"id":"s_spoon_small", "label":"1 Tatlı Kaşığı (10g)", "grams":10, "isDefault":False},
                  {"id":"s_spoon_large", "label":"1 Yemek Kaşığı (20g)", "grams":20, "isDefault":False}],
         ["vişne marmelatı"], ["kahvaltılık", "reçel", "şeker"]),
    food("tr_food_7014_kayisireceli", "Kayısı Reçeli", "Kahvaltılık", 100, "g", 280, 0.5, 68, 0,
         "100g", [{"id":"s_spoon_small", "label":"1 Tatlı Kaşığı (10g)", "grams":10, "isDefault":False},
                  {"id":"s_spoon_large", "label":"1 Yemek Kaşığı (20g)", "grams":20, "isDefault":False}],
         ["kayısı marmelatı"], ["kahvaltılık", "reçel", "şeker"]),
    food("tr_food_7015_paketbal", "Küçük Paket Bal / Reçel (Piknik Tipi)", "Kahvaltılık", 100, "g", 290, 0, 72, 0,
         "100g", [{"id":"s_pack", "label":"1 Küçük Kutu (20g)", "grams":20, "isDefault":False}],
         ["piknik bal", "kahvaltılık mini reçel"], ["kahvaltılık", "şeker", "pratik"])
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
