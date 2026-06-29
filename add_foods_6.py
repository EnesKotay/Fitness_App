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
            "source":"Toplu Ekleme - Kategori 1,2,4,5,6"}

new_foods = [
    # 1. Paketli Gıdalar ve Abur Cubur
    food("tr_food_4001_ulker_cikolatali_gofret", "Ülker Çikolatalı Gofret", "Atıştırmalık & Tatlı", 100, "g", 527, 6, 61, 28,
         "100g", [{"id":"s_piece", "label":"1 Adet (36g)", "grams":36, "isDefault":False}],
         ["çikolatalı gofret", "ülker gofret"], ["atıştırmalık", "çikolata", "gofret"]),
    food("tr_food_4002_eti_puf", "Eti Puf (Kakaolu/Hindistan Cevizli)", "Atıştırmalık & Tatlı", 100, "g", 444, 5, 66, 17,
         "100g", [{"id":"s_piece", "label":"1 Adet (18g)", "grams":18, "isDefault":False}],
         ["puf", "eti puf"], ["atıştırmalık", "tatlı", "bisküvi"]),
    food("tr_food_4003_eti_tutku", "Eti Tutku", "Atıştırmalık & Tatlı", 100, "g", 490, 5, 65, 23,
         "100g", [{"id":"s_pack", "label":"1 Paket (100g)", "grams":100, "isDefault":False}],
         ["tutku bisküvi", "mozaik bisküvi"], ["atıştırmalık", "bisküvi", "çikolata"]),
    food("tr_food_4004_doritos", "Doritos / Mısır Cipsi", "Atıştırmalık", 100, "g", 500, 6, 60, 26,
         "100g", [{"id":"s_bowl", "label":"1 Kase (~40g)", "grams":40, "isDefault":False}],
         ["cips", "doritos taco", "nacho"], ["atıştırmalık", "cips", "tuzlu"]),
    food("tr_food_4005_ruffles", "Ruffles / Patates Cipsi", "Atıştırmalık", 100, "g", 540, 6, 52, 33,
         "100g", [{"id":"s_bowl", "label":"1 Kase (~40g)", "grams":40, "isDefault":False}],
         ["patates cipsi", "lays", "ruffles"], ["atıştırmalık", "cips", "patates"]),
    food("tr_food_4006_magnum", "Magnum (Klasik/Bademli)", "Atıştırmalık & Tatlı", 100, "g", 330, 4, 31, 21,
         "100g", [{"id":"s_piece", "label":"1 Adet (~100g)", "grams":100, "isDefault":False}],
         ["dondurma", "magnum badem", "çubuk dondurma"], ["atıştırmalık", "tatlı", "dondurma"]),

    # 2. Kahveciler ve İçecekler
    food("tr_food_4007_latte", "Caffe Latte (Tam Yağlı Sütlü)", "İçecek", 100, "ml", 60, 3, 5, 3,
         "100ml", [{"id":"s_tall", "label":"Küçük Boy (Tall - 354ml)", "grams":354, "isDefault":False},
                   {"id":"s_grande", "label":"Orta Boy (Grande - 473ml)", "grams":473, "isDefault":False}],
         ["latte", "sütlü kahve"], ["içecek", "kahve", "sütlü"]),
    food("tr_food_4008_mocha", "Caffe Mocha", "İçecek", 100, "ml", 75, 2.5, 10, 3,
         "100ml", [{"id":"s_tall", "label":"Küçük Boy (Tall - 354ml)", "grams":354, "isDefault":False},
                   {"id":"s_grande", "label":"Orta Boy (Grande - 473ml)", "grams":473, "isDefault":False}],
         ["moka", "çikolatalı kahve"], ["içecek", "kahve", "çikolatalı"]),
    food("tr_food_4009_americano", "Filtre Kahve / Americano (Şekersiz)", "İçecek", 100, "ml", 2, 0.2, 0, 0,
         "100ml", [{"id":"s_cup", "label":"1 Kupa (~250ml)", "grams":250, "isDefault":False}],
         ["filtre kahve", "sade kahve"], ["içecek", "kahve", "şekersiz"]),
    food("tr_food_4010_ice_tea", "Soğuk Çay / Ice Tea (Şeftali/Limon)", "İçecek", 100, "ml", 30, 0, 7.5, 0,
         "100ml", [{"id":"s_can", "label":"1 Kutu (330ml)", "grams":330, "isDefault":False}],
         ["buzlu çay", "lipton", "fuse tea"], ["içecek", "soğuk", "çay"]),
    food("tr_food_4011_redbull", "Enerji İçeceği (Standart)", "İçecek", 100, "ml", 45, 0, 11, 0,
         "100ml", [{"id":"s_can", "label":"1 Kutu (250ml)", "grams":250, "isDefault":False}],
         ["red bull", "monster", "burn"], ["içecek", "enerji", "kafein"]),

    # 4. Kuruyemiş ve Çekirdek
    food("tr_food_4012_aycekirdegi", "Ay Çekirdeği (İç / Kabuksuz)", "Kuru Meyve & Kuruyemiş", 100, "g", 580, 21, 20, 51,
         "100g", [{"id":"s_bowl", "label":"1 Avuç (~30g)", "grams":30, "isDefault":False}],
         ["gündöndü", "çekirdek içi", "kavrulmuş çekirdek"], ["kuruyemiş", "çekirdek", "yağlı tohum"]),
    food("tr_food_4013_kabakcekirdegi", "Kabak Çekirdeği (İç)", "Kuru Meyve & Kuruyemiş", 100, "g", 570, 30, 15, 49,
         "100g", [{"id":"s_bowl", "label":"1 Avuç (~30g)", "grams":30, "isDefault":False}],
         ["kabak çekirdek"], ["kuruyemiş", "çekirdek", "yağlı tohum"]),
    food("tr_food_4014_sarileblebi", "Sarı Leblebi", "Kuru Meyve & Kuruyemiş", 100, "g", 380, 19, 58, 5,
         "100g", [{"id":"s_bowl", "label":"1 Avuç (~30g)", "grams":30, "isDefault":False}],
         ["kavrulmuş nohut", "leblebi"], ["kuruyemiş", "bakliyat", "karbonhidrat"]),
    food("tr_food_4015_kaju", "Kaju (Kavrulmuş)", "Kuru Meyve & Kuruyemiş", 100, "g", 570, 15, 30, 46,
         "100g", [{"id":"s_bowl", "label":"1 Avuç (~30g)", "grams":30, "isDefault":False}],
         ["kaju fıstığı", "cashew"], ["kuruyemiş", "kaju", "yağ"]),
    food("tr_food_4016_antepfistigi", "Antep Fıstığı", "Kuru Meyve & Kuruyemiş", 100, "g", 560, 20, 27, 45,
         "100g", [{"id":"s_bowl", "label":"1 Avuç (~30g)", "grams":30, "isDefault":False}],
         ["şam fıstığı"], ["kuruyemiş", "fıstık", "yağ"]),

    # 5. Vegan Alternatifler
    food("tr_food_4017_yulafsutu", "Yulaf Sütü (Şekersiz)", "Süt Ürünleri", 100, "ml", 40, 1, 7, 1.5,
         "100ml", [{"id":"s_cup", "label":"1 Su Bardağı (200ml)", "grams":200, "isDefault":False}],
         ["vegan süt", "yulaf içeceği"], ["vegan", "süt", "içecek"]),
    food("tr_food_4018_bademsutu", "Badem Sütü (Şekersiz)", "Süt Ürünleri", 100, "ml", 13, 0.5, 0.5, 1,
         "100ml", [{"id":"s_cup", "label":"1 Su Bardağı (200ml)", "grams":200, "isDefault":False}],
         ["vegan süt", "badem içeceği"], ["vegan", "süt", "içecek", "düşük kalori"]),
    food("tr_food_4019_soyakıyması", "Soya Kıyması (Kuru)", "Ana Yemek – Veg", 100, "g", 340, 50, 30, 1,
         "100g", [{"id":"s_portion", "label":"1 Porsiyon (~50g kuru)", "grams":50, "isDefault":False}],
         ["soya proteini", "vegan kıyma"], ["vegan", "soya", "yüksek protein"]),
    food("tr_food_4020_veganpeynir", "Vegan Peynir (Hindistan Cevizi Yağlı)", "Kahvaltılık", 100, "g", 280, 0, 20, 22,
         "100g", [{"id":"s_slice", "label":"1 Dilim (30g)", "grams":30, "isDefault":False}],
         ["bitkisel peynir", "vegan kaşar"], ["vegan", "peynir", "yağ"]),
    food("tr_food_4021_veganburger", "Vegan Burger Köftesi", "Ana Yemek – Veg", 100, "g", 250, 15, 10, 16,
         "100g", [{"id":"s_piece", "label":"1 Adet (100g)", "grams":100, "isDefault":False}],
         ["bitkisel köfte", "beyond meat", "vegan köfte"], ["vegan", "burger", "köfte"]),

    # 6. Sporcu Takviyeleri
    food("tr_food_4022_whey", "Whey Protein Tozu", "Sporcu Ürünleri", 100, "g", 380, 75, 5, 6,
         "100g", [{"id":"s_scoop", "label":"1 Ölçek / Scoop (30g)", "grams":30, "isDefault":False}],
         ["protein tozu", "peynir altı suyu"], ["sporcu", "protein", "takviye"]),
    food("tr_food_4023_bcaa", "BCAA / Amino Asit Tozu", "Sporcu Ürünleri", 100, "g", 380, 95, 0, 0,
         "100g", [{"id":"s_scoop", "label":"1 Ölçek (10g)", "grams":10, "isDefault":False}],
         ["esansiyel amino asit", "eaa"], ["sporcu", "amino", "takviye"]),
    food("tr_food_4024_preworkout", "Pre-Workout (Antrenman Öncesi Toz)", "Sporcu Ürünleri", 100, "g", 10, 0, 2, 0,
         "100g", [{"id":"s_scoop", "label":"1 Ölçek (15g)", "grams":15, "isDefault":False}],
         ["enerji tozu", "pump"], ["sporcu", "enerji", "takviye"]),
    food("tr_food_4025_gainer", "Karbonhidrat Tozu (Gainer)", "Sporcu Ürünleri", 100, "g", 390, 15, 80, 1,
         "100g", [{"id":"s_scoop", "label":"1 Büyük Ölçek (100g)", "grams":100, "isDefault":False}],
         ["mass gainer", "kilo aldırıcı"], ["sporcu", "karbonhidrat", "takviye"]),
    food("tr_food_4026_proteinbar", "Protein Bar (Ortalama)", "Sporcu Ürünleri", 100, "g", 360, 30, 35, 12,
         "100g", [{"id":"s_bar", "label":"1 Adet (50g)", "grams":50, "isDefault":False}],
         ["proteinli bar", "sporcu barı"], ["sporcu", "protein", "atıştırmalık"])
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
