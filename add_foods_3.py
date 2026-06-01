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
            "source":"Kullanici Excel - Eksik Eklenenler 2024-C"}

new_foods = [
    # ── MEZELER ──────────────────────────────────────────────────────
    food("tr_food_3111_saksuka","Şakşuka","Meze & Salata",150,"g",152,2,9,12,
         "1 porsiyon (150g)",None,["şakşuka meze"],["meze","patlican","domates"]),
    food("tr_food_3112_atom_meze","Atom meze","Meze & Salata",150,"g",182,6,8,14,
         "1 porsiyon (150g)",None,["atom yoğurt"],["meze","yogurt","aci"]),
    food("tr_food_3113_fava","Fava","Meze & Salata",150,"g",184,8,20,8,
         "1 porsiyon (150g)",None,["bakla fava"],["meze","bakla","zeytinyagli"]),
    food("tr_food_3114_muhammara","Muhammara","Meze & Salata",100,"g",262,4,12,22,
         "1 porsiyon (100g)",None,["acuka","cevizli biber"],["meze","ceviz","biber","aci"]),
         
    # ── YEMEKLER ──────────────────────────────────────────────────────
    food("tr_food_3115_ciger_sis","Ciğer şiş","Et Yemeği",200,"g",244,30,4,12,
         "1 porsiyon (200g)",[{"id":"s_piece","label":"1 şiş (~50g)","grams":50,"isDefault":False}],
         ["ciğer kebap"],["et","ciger","kebap","sakatat"]),
         
    # ── TATLILAR ──────────────────────────────────────────────────────
    food("tr_food_3116_bici_bici","Bici bici","Tatlı",250,"g",164,1,40,0,
         "1 porsiyon (250g)",None,["bici bici tatlısı"],["tatli","buz","nisasta"]),
    food("tr_food_3117_soguk_baklava","Soğuk baklava","Tatlı",100,"g",340,5,35,20,
         "1 porsiyon (100g)",[{"id":"s_piece","label":"1 dilim (~40g)","grams":40,"isDefault":False}],
         ["sütlü baklava"],["tatli","baklava","sutlu"]),
    food("tr_food_3118_san_sebastian","San Sebastian Cheesecake","Tatlı",150,"g",440,8,30,32,
         "1 porsiyon (150g)",None,["yanık cheesecake"],["tatli","cheesecake","peynir"]),
    food("tr_food_3119_cennet_camuru","Cennet çamuru","Tatlı",100,"g",378,4,50,18,
         "1 porsiyon (100g)",None,["kilis tatlısı","fıstıklı tatlı"],["tatli","fistik","kadayif"]),
    food("tr_food_3120_belcika_waffle","Belçika waffle","Tatlı",150,"g",348,6,45,16,
         "1 porsiyon (150g)",None,["waffle","çikolatalı waffle"],["tatli","waffle","cikolata"]),
    food("tr_food_3121_magnolia","Magnolia tatlısı","Tatlı",150,"g",295,5,35,15,
         "1 porsiyon (150g)",None,["çilekli magnolia","muzlu magnolia"],["tatli","sutlu","biskuvi"]),
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

print(f"\n{added} yemek eklendi. Yeni toplam: {len(data['foods'])}")
