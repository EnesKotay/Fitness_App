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
            "source":"Kullanici Excel - Eksik Eklenenler 2024-D"}

new_foods = [
    # ── EKMEK ÇEŞİTLERİ ────────────────────────────────────────────────
    # kcal = prot*4 + carb*4 + fat*9
    food("tr_food_3130_lavas","Lavaş","Fırın & Pide",100,"g",268,8,50,4,
         "1 adet (100g)",[{"id":"s_piece","label":"1 küçük adet (~50g)","grams":50,"isDefault":False}],
         ["lavaş ekmeği","dürüm ekmeği"],["ekmek","lavas","durum"]),
         
    food("tr_food_3131_ramazan_pidesi","Ramazan pidesi","Fırın & Pide",100,"g",242,8,48,2,
         "100g",[{"id":"s_piece","label":"1 çeyrek (~75g)","grams":75,"isDefault":False}],
         ["pide ekmeği","pide"],["ekmek","pide","ramazan"]),
         
    food("tr_food_3132_misir_ekmegi","Mısır ekmeği","Fırın & Pide",100,"g",238,6,40,6,
         "100g",[{"id":"s_piece","label":"1 dilim (~50g)","grams":50,"isDefault":False}],
         ["mısır unu ekmeği"],["ekmek","misir","karadeniz"]),
         
    food("tr_food_3133_cavdar_ekmegi","Çavdar ekmeği","Fırın & Pide",100,"g",210,8,40,2,
         "100g",[{"id":"s_piece","label":"1 dilim (~30g)","grams":30,"isDefault":False}],
         ["çavdarlı ekmek"],["ekmek","cavdar","diyet"]),
         
    food("tr_food_3134_eksi_mayali","Ekşi mayalı ekmek","Fırın & Pide",100,"g",234,8,46,2,
         "100g",[{"id":"s_piece","label":"1 kalın dilim (~40g)","grams":40,"isDefault":False}],
         ["ekşi maya ekmek"],["ekmek","eksimaya"]),
         
    food("tr_food_3135_trabzon_ekmegi","Trabzon ekmeği","Fırın & Pide",100,"g",233,8,48,1,
         "100g",[{"id":"s_piece","label":"1 kalın dilim (~60g)","grams":60,"isDefault":False}],
         ["vakfıkebir ekmeği"],["ekmek","trabzon","somun"]),
         
    food("tr_food_3136_hamburger_ekmegi","Hamburger ekmeği","Fırın & Pide",100,"g",272,9,50,4,
         "1 adet (100g)",None,
         ["burger ekmeği"],["ekmek","hamburger","fastfood"]),
         
    food("tr_food_3137_sandvic_ekmegi","Sandviç ekmeği","Fırın & Pide",100,"g",262,8,50,2,
         "1 adet (100g)",None,
         ["sosisli ekmeği","kumru ekmeği"],["ekmek","sandvic"]),
         
    food("tr_food_3138_yulaf_ekmegi","Yulaf ekmeği","Fırın & Pide",100,"g",228,10,40,2,
         "100g",[{"id":"s_piece","label":"1 dilim (~35g)","grams":35,"isDefault":False}],
         ["yulaflı ekmek"],["ekmek","yulaf","diyet"]),
         
    food("tr_food_3139_tam_bugday_ekmek_100g","Tam buğday ekmeği (100g)","Fırın & Pide",100,"g",236,10,42,2,
         "100g",[{"id":"s_piece","label":"1 dilim (~30g)","grams":30,"isDefault":False}],
         ["tam buğday","esmer ekmek"],["ekmek","tambugday","diyet"]),
         
    food("tr_food_3140_beyaz_ekmek_100g","Beyaz ekmek (somun 100g)","Fırın & Pide",100,"g",252,8,50,2,
         "100g",[{"id":"s_piece","label":"1 dilim (~30g)","grams":30,"isDefault":False}],
         ["somun ekmek","francala"],["ekmek","beyaz","somun"])
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

print(f"\n{added} ekmek eklendi. Yeni toplam: {len(data['foods'])}")
