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
            "source":"Toplu Ekleme - Soslar, Sosis, Sokak Lezzeti, Tatlilar"}

new_foods = [
    # 1. Soslar
    food("tr_food_5001_ranch", "Ranch Sos", "Yağ & Sos", 100, "g", 450, 1, 5, 47,
         "100g", [{"id":"s_pack", "label":"1 Küçük Paket (15g)", "grams":15, "isDefault":False}],
         ["renç sos", "ranch"], ["sos", "yağlı", "salata sosu"]),
    food("tr_food_5002_barbeku", "Barbekü Sos", "Yağ & Sos", 100, "g", 170, 0.5, 40, 0.2,
         "100g", [{"id":"s_pack", "label":"1 Küçük Paket (15g)", "grams":15, "isDefault":False}],
         ["bbq sos"], ["sos", "şekerli"]),
    food("tr_food_5003_sezar", "Sezar Sos", "Yağ & Sos", 100, "g", 400, 2, 5, 42,
         "100g", [{"id":"s_spoon", "label":"1 Yemek Kaşığı (15g)", "grams":15, "isDefault":False}],
         ["caesar sos"], ["sos", "salata sosu", "yağlı"]),
    food("tr_food_5004_sriracha", "Sriracha / Acı Sos", "Yağ & Sos", 100, "g", 80, 1, 18, 0.5,
         "100g", [{"id":"s_spoon", "label":"1 Tatlı Kaşığı (5g)", "grams":5, "isDefault":False}],
         ["acı sos", "hot sauce"], ["sos", "acı"]),
    food("tr_food_5005_soyasosu", "Soya Sosu", "Yağ & Sos", 100, "g", 53, 8, 5, 0,
         "100g", [{"id":"s_spoon", "label":"1 Yemek Kaşığı (15g)", "grams":15, "isDefault":False}],
         ["soy sauce"], ["sos", "tuzlu", "asya"]),
    food("tr_food_5006_nareksisi", "Nar Ekşili Sos", "Yağ & Sos", 100, "g", 300, 0, 75, 0,
         "100g", [{"id":"s_spoon", "label":"1 Yemek Kaşığı (15g)", "grams":15, "isDefault":False}],
         ["nar sosu", "salata sosu"], ["sos", "şekerli", "ekşi"]),
    food("tr_food_5007_teriyaki", "Teriyaki Sos", "Yağ & Sos", 100, "g", 150, 6, 30, 0,
         "100g", [{"id":"s_spoon", "label":"1 Yemek Kaşığı (15g)", "grams":15, "isDefault":False}],
         ["teriyaki"], ["sos", "tatlı", "asya"]),

    # 2. Sosis ve Şarküteri
    food("tr_food_5008_danasosis", "Dana Sosis", "Et & Protein", 100, "g", 280, 12, 2, 25,
         "100g", [{"id":"s_piece", "label":"1 Adet (Uzun - 50g)", "grams":50, "isDefault":False}],
         ["sosis"], ["şarküteri", "et", "işlenmiş"]),
    food("tr_food_5009_pilicsosis", "Piliç Sosis", "Et & Protein", 100, "g", 220, 13, 3, 17,
         "100g", [{"id":"s_piece", "label":"1 Adet (Kokteyl - 35g)", "grams":35, "isDefault":False}],
         ["tavuk sosis", "hindi sosis"], ["şarküteri", "tavuk", "işlenmiş"]),
    food("tr_food_5010_sosislisandvic", "Sosisli Sandviç", "Fast Food", 100, "g", 290, 10, 28, 15,
         "100g", [{"id":"s_piece", "label":"1 Adet (150g)", "grams":150, "isDefault":False}],
         ["hot dog", "sosisli"], ["fast food", "sandviç", "sosis"]),
    food("tr_food_5011_salcalisosis", "Salçalı Sosis (Sosis Tava)", "Kahvaltılık", 100, "g", 260, 10, 5, 22,
         "100g", [{"id":"s_portion", "label":"1 Porsiyon (150g)", "grams":150, "isDefault":False}],
         ["sosis tava"], ["kahvaltılık", "sosis", "sıcak"]),

    # 3. Sokak Lezzetleri ve Pratik Hamur İşleri
    food("tr_food_5012_islakhamburger", "Islak Hamburger", "Sokak Yemeği", 100, "g", 270, 12, 30, 11,
         "100g", [{"id":"s_piece", "label":"1 Adet (130g)", "grams":130, "isDefault":False}],
         ["kızılkayalar", "soslu hamburger"], ["sokak lezzeti", "hamburger", "fast food"]),
    food("tr_food_5013_gorali", "Goralı Sandviç", "Sokak Yemeği", 100, "g", 280, 9, 26, 15,
         "100g", [{"id":"s_piece", "label":"1 Adet (160g)", "grams":160, "isDefault":False}],
         ["goralı"], ["sokak lezzeti", "sandviç", "sosis"]),
    food("tr_food_5014_pisi", "Pişi (Kızarmış Hamur)", "Kahvaltılık", 100, "g", 360, 7, 40, 19,
         "100g", [{"id":"s_piece", "label":"1 Adet (50g)", "grams":50, "isDefault":False}],
         ["hamur kızartması", "lokma hamuru"], ["kahvaltılık", "hamur işi", "kızartma"]),
    food("tr_food_5015_boyoz", "Boyoz", "Kahvaltılık", 100, "g", 390, 6, 40, 23,
         "100g", [{"id":"s_piece", "label":"1 Adet (60g)", "grams":60, "isDefault":False}],
         ["izmir boyoz"], ["kahvaltılık", "hamur işi", "yağlı"]),
    food("tr_food_5016_krep", "Ev Yapımı Krep", "Kahvaltılık", 100, "g", 220, 7, 28, 8,
         "100g", [{"id":"s_piece", "label":"1 Adet (70g)", "grams":70, "isDefault":False}],
         ["akıtma", "krep"], ["kahvaltılık", "hamur işi"]),

    # 4. Türk Tatlıları
    food("tr_food_5017_kunefe", "Künefe", "Tatlı", 100, "g", 380, 6, 45, 18,
         "100g", [{"id":"s_portion", "label":"1 Porsiyon (150g)", "grams":150, "isDefault":False}],
         ["hatay künefe", "peynirli kadayıf"], ["tatlı", "şerbetli", "peynirli"]),
    food("tr_food_5018_firinsutlac", "Fırın Sütlaç", "Tatlı", 100, "g", 130, 3, 22, 3,
         "100g", [{"id":"s_bowl", "label":"1 Kase (200g)", "grams":200, "isDefault":False}],
         ["sütlaç"], ["tatlı", "sütlü"]),
    food("tr_food_5019_trilece", "Trileçe", "Tatlı", 100, "g", 240, 5, 35, 9,
         "100g", [{"id":"s_slice", "label":"1 Dilim (150g)", "grams":150, "isDefault":False}],
         ["balkan tatlısı", "karamelli trileçe"], ["tatlı", "sütlü", "kek"]),
    food("tr_food_5020_sansebastian", "San Sebastian Cheesecake", "Tatlı", 100, "g", 360, 6, 25, 26,
         "100g", [{"id":"s_slice", "label":"1 Dilim (160g)", "grams":160, "isDefault":False}],
         ["yanık cheesecake", "bask cheesecake"], ["tatlı", "peynirli", "kek"])
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
