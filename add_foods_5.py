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
            "source":"Kullanici - Kahvaltilik Gevrek & Toz"}

new_foods = [
    food("tr_food_3141_nesquik_toz", "Nesquik Çikolatalı İçecek Tozu", "Atıştırmalık & Tatlı", 100, "g", 375, 3.5, 73, 1.5,
         "100g", [{"id":"s_spoon", "label":"1 yemek kaşığı (~15g)", "grams":15, "isDefault":False}],
         ["nesquik toz", "kakaolu toz"], ["nesquik", "kakao", "icecek"]),
         
    food("tr_food_3142_nesquik_gevrek", "Nesquik Kahvaltılık Gevrek", "Kahvaltılık", 100, "g", 385, 8, 73, 4.5,
         "100g", [{"id":"s_portion", "label":"1 porsiyon (~30g)", "grams":30, "isDefault":False},
                  {"id":"s_bowl", "label":"1 büyük kase (~50g)", "grams":50, "isDefault":False}],
         ["kakaolu gevrek", "nesquik topu"], ["gevrek", "nesquik", "kahvaltilik"]),

    food("tr_food_3143_coco_pops", "Coco Pops Kahvaltılık Gevrek", "Kahvaltılık", 100, "g", 395, 7, 78, 5,
         "100g", [{"id":"s_portion", "label":"1 porsiyon (~30g)", "grams":30, "isDefault":False},
                  {"id":"s_bowl", "label":"1 büyük kase (~50g)", "grams":50, "isDefault":False}],
         ["koko pops", "çikolatalı gevrek"], ["gevrek", "cocopops", "kahvaltilik"]),

    food("tr_food_3144_misir_gevregi", "Mısır Gevreği (Sade)", "Kahvaltılık", 100, "g", 370, 7, 80, 1,
         "100g", [{"id":"s_portion", "label":"1 porsiyon (~30g)", "grams":30, "isDefault":False},
                  {"id":"s_bowl", "label":"1 kase (~45g)", "grams":45, "isDefault":False}],
         ["corn flakes", "sade gevrek"], ["gevrek", "misir", "kahvaltilik"]),

    food("tr_food_3145_yulaf_ezmesi", "Yulaf Ezmesi", "Kahvaltılık", 100, "g", 360, 14, 53, 7.5,
         "100g", [{"id":"s_spoon", "label":"1 yemek kaşığı (~10g)", "grams":10, "isDefault":False},
                  {"id":"s_portion", "label":"1 porsiyon (~40g)", "grams":40, "isDefault":False}],
         ["yulaf", "lifalif"], ["yulaf", "diyet", "kahvaltilik"]),

    food("tr_food_3146_granola_sade", "Granola (Sade/Ortalama)", "Kahvaltılık", 100, "g", 435, 10, 60, 18,
         "100g", [{"id":"s_portion", "label":"1 porsiyon (~40g)", "grams":40, "isDefault":False},
                  {"id":"s_spoon", "label":"1 yemek kaşığı (~12g)", "grams":12, "isDefault":False}],
         ["granola", "çıtır yulaf"], ["granola", "yulaf", "kahvaltilik"]),

    food("tr_food_3147_musli_meyveli", "Müsli (Meyveli)", "Kahvaltılık", 100, "g", 370, 9, 65, 6,
         "100g", [{"id":"s_portion", "label":"1 porsiyon (~40g)", "grams":40, "isDefault":False}],
         ["meyveli müsli", "müsli"], ["musli", "meyveli", "kahvaltilik"])
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

print(f"\\n{added} kahvaltılık eklendi. Yeni toplam: {len(data['foods'])}")
