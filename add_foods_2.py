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
            "source":"Kullanici Excel - Eksik Eklenenler 2024-B"}

new_foods = [
    # ── KAHVALTI ──────────────────────────────────────────────────────
    food("tr_food_3001_marmelat","Marmelat","Kahvaltılık",20,"g",52,0,13,0,
         "1 yemek kaşığı (20g)",[{"id":"s_two","label":"2 kaşık (40g)","grams":40,"isDefault":False}],
         ["reçel","marmelade"],["kahvalti","tatli","meyve"]),
    food("tr_food_3002_tahini_omlet","Tahinli omlet","Kahvaltılık",150,"g",290,16,8,22,
         "1 adet (150g)",None,["tahini omlet"],["kahvalti","omlet","tahini","yumurta"]),
    food("tr_food_3003_yulaf_sutu","Yulaf sütü","İçecek",200,"ml",80,2,14,2,
         "1 bardak (200ml)",[{"id":"s_small","label":"Küçük bardak (100ml)","grams":100,"isDefault":False}],
         ["oat milk"],["icecek","tahil","bitki sutu","vegan"]),
    food("tr_food_3004_cop_sis","Çöp şiş","Sokak Yemeği",150,"g",280,22,4,20,
         "1 porsiyon (150g)",[{"id":"s_piece","label":"1 şiş (~50g)","grams":50,"isDefault":False}],
         ["çöp şiş kebap"],["et","sis","sokak","kebap"]),

    # ── ÇORBALAR ──────────────────────────────────────────────────────
    food("tr_food_3010_domates_mercimek_corbasi","Domatesli mercimek çorbası","Çorba",250,"ml",110,7,16,2,
         "1 kase (250ml)",None,["mercimek domates"],["corba","mercimek","domates"]),
    food("tr_food_3011_kremali_mantar_corbasi","Kremalı mantar çorbası","Çorba",250,"ml",130,4,10,8,
         "1 kase (250ml)",None,["kremali mantar"],["corba","mantar","krema"]),
    food("tr_food_3012_midye_corbasi","Midye çorbası","Çorba",250,"ml",100,7,10,4,
         "1 kase (250ml)",None,["midye corbasi"],["corba","midye","deniz urunu"]),

    # ── ET YEMEKLERİ ──────────────────────────────────────────────────
    food("tr_food_3020_kofte_sos","Köfte sos (domates soslu)","Et Yemeği",250,"g",380,24,14,26,
         "1 porsiyon (250g)",None,["köfte domates sos"],["et","kofte","sos","domates"]),
    food("tr_food_3021_kuzu_sis","Kuzu şiş","Et Yemeği",200,"g",360,28,2,26,
         "1 porsiyon (200g)",[{"id":"s_piece","label":"1 şiş (~70g)","grams":70,"isDefault":False}],
         ["kuzu şiş kebap"],["et","kuzu","sis","kebap"]),
    food("tr_food_3022_kiyma_sarma","Kıyma sarma (lahana)","Et Yemeği",200,"g",320,18,22,16,
         "1 porsiyon (200g)",[{"id":"s_piece","label":"1 adet (~40g)","grams":40,"isDefault":False}],
         ["lahana sarma","kıymalı sarma"],["et","sarma","lahana","kiyma"]),
    food("tr_food_3023_beyti_durum","Beyti dürüm","Sokak Yemeği",280,"g",560,30,46,24,
         "1 adet (280g)",None,["beyti","beyti wrap"],["et","durum","kebap","beyti"]),
    food("tr_food_3024_icli_kofte","İçli köfte","Sokak Yemeği",150,"g",340,14,34,16,
         "1 porsiyon (150g)",[{"id":"s_piece","label":"1 adet (~50g)","grams":50,"isDefault":False}],
         ["içli köfte"],["et","kofte","icli","hamur"]),

    # ── TAVUK ──────────────────────────────────────────────────────────
    food("tr_food_3030_tavuk_nugget","Tavuk nugget","Fast Food",150,"g",370,18,28,20,
         "1 porsiyon (150g)",[{"id":"s_piece","label":"1 adet (~15g)","grams":15,"isDefault":False}],
         ["nugget"],["tavuk","fast food","kizartma"]),
    food("tr_food_3031_buffalo_tavuk_kanadi","Buffalo tavuk kanadı","Fast Food",200,"g",420,24,10,32,
         "1 porsiyon (200g)",[{"id":"s_piece","label":"2 kanat (~80g)","grams":80,"isDefault":False}],
         ["buffalo wings","tavuk kanat"],["tavuk","kanat","baharatlı","fast food"]),
    food("tr_food_3032_tavuk_schnitzel","Tavuk schnitzel","Ana Yemek – Tavuk",180,"g",360,30,18,18,
         "1 adet (180g)",None,["tavuk şnitzel","kızarmış tavuk"],["tavuk","schnitzel","kizartma"]),
    food("tr_food_3033_tavuk_kizartma","Tavuk kızartma","Ana Yemek – Tavuk",250,"g",480,34,14,34,
         "1 porsiyon (250g)",None,["kızartma tavuk"],["tavuk","kizartma","baharatlı"]),
    food("tr_food_3034_tavuk_wrap","Tavuk wrap","Sokak Yemeği",220,"g",390,26,38,14,
         "1 adet (220g)",None,["wrap tavuk","dürüm"],["tavuk","wrap","durum","sokak"]),

    # ── BALIK ──────────────────────────────────────────────────────────
    food("tr_food_3040_ringa_baligi","Ringa balığı","Balık",150,"g",260,22,0,18,
         "1 porsiyon (150g)",None,["ringa","herring"],["balik","ringa","omega3"]),
    food("tr_food_3041_levrek_bugulama","Levrek buğulama","Ana Yemek – Balık",250,"g",230,36,2,9,
         "1 porsiyon (250g)",None,["levrek","buğulama"],["balik","levrek","bugulama","diyetik"]),
    food("tr_food_3042_hamsi_pilavi","Hamsi pilavı","Ana Yemek – Balık",300,"g",420,28,44,12,
         "1 porsiyon (300g)",None,["hamsi pirinç"],["balik","hamsi","pilav","karadeniz"]),

    # ── SEBZE YEMEKLERİ ────────────────────────────────────────────────
    food("tr_food_3050_ispanak_yemegi","Ispanak yemeği","Sebze Yemeği",250,"g",140,6,14,6,
         "1 porsiyon (250g)",None,["ıspanak","kavurma ıspanak"],["sebze","ispanak","zeytinyagli"]),
    food("tr_food_3051_brokoli_kavurma","Brokoli kavurma","Sebze Yemeği",200,"g",110,5,8,6,
         "1 porsiyon (200g)",None,["brokoli sote"],["sebze","brokoli","sote"]),
    food("tr_food_3052_havuc_tarator","Havuç tarator","Meze & Salata",120,"g",110,3,14,5,
         "1 porsiyon (120g)",None,["havuç yoğurtlu"],["meze","havuc","yoğurt"]),
    food("tr_food_3053_portakal_havuc_salatasi","Portakallı havuç salatası","Salata",150,"g",90,2,18,2,
         "1 porsiyon (150g)",None,["portakal havuç"],["salata","havuc","portakal","taze"]),
    food("tr_food_3054_kirmizi_lahana_salatasi","Kırmızı lahana salatası","Salata",150,"g",60,2,10,2,
         "1 porsiyon (150g)",None,["kırmızı lahana"],["salata","lahana","taze"]),
    food("tr_food_3055_semizotu_salatasi","Semizotu salatası","Salata",150,"g",55,2,6,3,
         "1 porsiyon (150g)",None,["semizotu"],["salata","semizotu","ot"]),
    food("tr_food_3056_zeytinyagli_ispanak","Zeytinyağlı ıspanak","Sebze Yemeği",200,"g",100,4,8,6,
         "1 porsiyon (200g)",None,["zeytinyağlı ıspanak"],["sebze","ispanak","zeytinyagli"]),

    # ── PİLAV & MAKARNA ────────────────────────────────────────────────
    food("tr_food_3060_mercimekli_pilav","Mercimekli pilav","Pilav & Makarna",250,"g",290,12,50,5,
         "1 porsiyon (250g)",None,["mercimek pilav"],["pilav","mercimek","tahil"]),
    food("tr_food_3061_sebzeli_pilav","Sebzeli pilav","Pilav & Makarna",250,"g",270,6,50,6,
         "1 porsiyon (250g)",None,["sebze pilav"],["pilav","sebze","tahil"]),
    food("tr_food_3062_eristeli_pilav","Erişteli pilav","Pilav & Makarna",250,"g",285,8,52,6,
         "1 porsiyon (250g)",None,["erişte pilav","erişte"],["pilav","eriste","tahil"]),
    food("tr_food_3063_pesto_makarna","Pesto makarna","Pilav & Makarna",300,"g",480,14,60,20,
         "1 porsiyon (300g)",None,["pesto"],["makarna","pesto","fesleyen"]),
    food("tr_food_3064_firin_lazanya","Fırın lazanya","Pilav & Makarna",350,"g",560,26,52,26,
         "1 porsiyon (350g)",None,["lazanya"],["makarna","lazanya","firin","et"]),
    food("tr_food_3065_deniz_urunlu_makarna","Deniz ürünlü makarna","Pilav & Makarna",350,"g",460,26,54,14,
         "1 porsiyon (350g)",None,["deniz mahsulleri makarna"],["makarna","deniz","karides","midye"]),

    # ── PİDE ───────────────────────────────────────────────────────────
    food("tr_food_3070_pide_kasarli","Kaşarlı pide","Fırın & Pide",300,"g",560,22,66,22,
         "1 adet (300g)",None,["kaşar pide"],["pide","kasar","firin"]),
    food("tr_food_3071_pide_kiymali","Kıymalı pide","Fırın & Pide",300,"g",580,26,62,24,
         "1 adet (300g)",None,["kıyma pide"],["pide","kiyma","firin"]),
    food("tr_food_3072_pide_kusbasili","Kuşbaşılı pide","Fırın & Pide",350,"g",620,30,64,26,
         "1 adet (350g)",None,["kuşbaşı pide"],["pide","kusbasi","firin","et"]),
    food("tr_food_3073_pisi","Pişi","Hamur İşi",80,"g",270,5,34,12,
         "1 adet (80g)",None,["pişi"],["hamur","kahvalti","kizartma"]),

    # ── TATLILAR ───────────────────────────────────────────────────────
    food("tr_food_3080_kadayif_dolmasi","Kadayıf dolması","Tatlı",100,"g",340,6,42,16,
         "1 porsiyon (100g)",None,["kadayıf dolma"],["tatli","kadayif","ceviz"]),

    # ── İÇECEKLER ──────────────────────────────────────────────────────
    food("tr_food_3090_uzum_suyu","Üzüm suyu","İçecek",200,"ml",130,0,32,0,
         "1 bardak (200ml)",None,["üzüm suyu"],["icecek","meyve suyu","uzum"]),
    food("tr_food_3091_nar_eksisi","Nar ekşisi","Yağ & Sos",15,"ml",30,0,7,0,
         "1 yemek kaşığı (15ml)",None,["nar ekşisi","narşarap"],["sos","nar","salata"]),
    food("tr_food_3092_soguk_cay","Soğuk çay","İçecek",300,"ml",80,0,20,0,
         "1 bardak (300ml)",None,["ice tea","buzlu çay"],["icecek","cay","soguk"]),
    food("tr_food_3093_kombucha","Kombucha","İçecek",250,"ml",30,0,7,0,
         "1 şişe (250ml)",None,["kombucha"],["icecek","fermente","probiyotik"]),
    food("tr_food_3094_soya_sutu","Soya sütü","İçecek",200,"ml",70,7,4,4,
         "1 bardak (200ml)",None,["soy milk"],["icecek","soya","bitki sutu","vegan"]),
    food("tr_food_3095_pirinc_sutu","Pirinç sütü","İçecek",200,"ml",95,1,22,2,
         "1 bardak (200ml)",None,["rice milk"],["icecek","pirinc","bitki sutu","glutensiz"]),

    # ── SAĞLIKLI / FITNESS ──────────────────────────────────────────────
    food("tr_food_3100_protein_waffle","Protein waffle","Kahvaltı",120,"g",280,20,26,10,
         "1 adet (120g)",None,["waffle protein"],["kahvalti","waffle","protein","sporcu"]),
    food("tr_food_3101_yumurta_aki","Yumurta akı (pişmiş)","Et & Protein",100,"g",52,11,1,0,
         "100 g",[{"id":"s_piece","label":"1 adet (~30g)","grams":30,"isDefault":False}],
         ["egg white","beyaz"],["protein","yumurta","diyetik","sporcu"]),
    food("tr_food_3102_suzme_yogurt_yagsiz","Yağsız süzme yoğurt","Süt Ürünleri",150,"g",75,14,5,0,
         "1 kase (150g)",None,["yağsız yoğurt","süzme","Greek yogurt"],["sutur","protein","probiyotik","diyetik"]),
    food("tr_food_3103_skyr","Skyr","Süt Ürünleri",150,"g",90,15,6,0,
         "1 kase (150g)",None,["skyr","islandalı yoğurt"],["sutur","protein","probiyotik"]),
    food("tr_food_3104_tofu","Tofu","Et & Protein",150,"g",120,14,3,6,
         "1 porsiyon (150g)",None,["tofu","soya peyniri"],["protein","vegan","soya"]),
    food("tr_food_3105_tempeh","Tempeh","Et & Protein",100,"g",195,19,8,11,
         "1 porsiyon (100g)",None,["tempeh"],["protein","vegan","fermente","soya"]),
    food("tr_food_3106_edamame","Edamame (haşlanmış)","Tahıl & Bakliyat",100,"g",120,11,9,5,
         "1 kase (100g)",None,["edamame","soya fasulyesi"],["protein","vegan","baklagil"]),

    # ── YAĞ & SOS ──────────────────────────────────────────────────────
    food("tr_food_3110_margarin","Margarin","Yağ & Sos",10,"g",72,0,0,8,
         "1 çay kaşığı (10g)",[{"id":"s_tbsp","label":"1 yemek kaşığı (15g)","grams":15,"isDefault":False}],
         ["margarine"],["yag","margarin","tereyag"]),
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
