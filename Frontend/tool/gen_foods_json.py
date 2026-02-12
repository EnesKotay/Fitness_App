# Generates assets/foods/foods_tr.json with 30 real + 270 template items
import json
import os

real = [
    {"id":"f1","name":"Tavuk göğsü (haşlanmış)","kcalPer100g":165,"proteinPer100g":31,"carbPer100g":0,"fatPer100g":3.6},
    {"id":"f2","name":"Pirinç (pişmiş)","kcalPer100g":130,"proteinPer100g":2.7,"carbPer100g":28,"fatPer100g":0.3},
    {"id":"f3","name":"Bulgur (pişmiş)","kcalPer100g":83,"proteinPer100g":3.1,"carbPer100g":18.6,"fatPer100g":0.2},
    {"id":"f4","name":"Yumurta (haşlanmış)","kcalPer100g":155,"proteinPer100g":13,"carbPer100g":1.1,"fatPer100g":11},
    {"id":"f5","name":"Süt (yarım yağlı)","kcalPer100g":50,"proteinPer100g":3.4,"carbPer100g":4.8,"fatPer100g":2},
    {"id":"f6","name":"Yoğurt (sade)","kcalPer100g":59,"proteinPer100g":10,"carbPer100g":3.5,"fatPer100g":0.4},
    {"id":"f7","name":"Peynir (beyaz)","kcalPer100g":264,"proteinPer100g":18,"carbPer100g":3.2,"fatPer100g":20},
    {"id":"f8","name":"Zeytinyağı","kcalPer100g":884,"proteinPer100g":0,"carbPer100g":0,"fatPer100g":100},
    {"id":"f9","name":"Tereyağı","kcalPer100g":717,"proteinPer100g":0.9,"carbPer100g":0.1,"fatPer100g":81},
    {"id":"f10","name":"Ekmek (beyaz)","kcalPer100g":265,"proteinPer100g":9,"carbPer100g":49,"fatPer100g":3.2},
    {"id":"f11","name":"Ekmek (tam buğday)","kcalPer100g":247,"proteinPer100g":10.7,"carbPer100g":41.3,"fatPer100g":3.4},
    {"id":"f12","name":"Makarna (pişmiş)","kcalPer100g":131,"proteinPer100g":5,"carbPer100g":25,"fatPer100g":1.1},
    {"id":"f13","name":"Mercimek (pişmiş)","kcalPer100g":116,"proteinPer100g":9,"carbPer100g":20,"fatPer100g":0.4},
    {"id":"f14","name":"Nohut (pişmiş)","kcalPer100g":164,"proteinPer100g":8.9,"carbPer100g":27.4,"fatPer100g":2.6},
    {"id":"f15","name":"Kırmızı et (dana, ızgara)","kcalPer100g":250,"proteinPer100g":26,"carbPer100g":0,"fatPer100g":15},
    {"id":"f16","name":"Somon (ızgara)","kcalPer100g":208,"proteinPer100g":20,"carbPer100g":0,"fatPer100g":13},
    {"id":"f17","name":"Ton balığı (konserve, süzülmüş)","kcalPer100g":116,"proteinPer100g":26,"carbPer100g":0,"fatPer100g":0.8},
    {"id":"f18","name":"Brokoli (haşlanmış)","kcalPer100g":35,"proteinPer100g":2.4,"carbPer100g":7,"fatPer100g":0.4},
    {"id":"f19","name":"Ispanak (haşlanmış)","kcalPer100g":23,"proteinPer100g":2.9,"carbPer100g":3.6,"fatPer100g":0.3},
    {"id":"f20","name":"Domates","kcalPer100g":18,"proteinPer100g":0.9,"carbPer100g":3.9,"fatPer100g":0.2},
    {"id":"f21","name":"Salatalık","kcalPer100g":15,"proteinPer100g":0.7,"carbPer100g":3.6,"fatPer100g":0.1},
    {"id":"f22","name":"Biber (dolmalık)","kcalPer100g":31,"proteinPer100g":1,"carbPer100g":6,"fatPer100g":0.3},
    {"id":"f23","name":"Havuç (çiğ)","kcalPer100g":41,"proteinPer100g":0.9,"carbPer100g":9.6,"fatPer100g":0.2},
    {"id":"f24","name":"Patates (haşlanmış)","kcalPer100g":87,"proteinPer100g":1.9,"carbPer100g":20,"fatPer100g":0.1},
    {"id":"f25","name":"Elma","kcalPer100g":52,"proteinPer100g":0.3,"carbPer100g":14,"fatPer100g":0.2},
    {"id":"f26","name":"Muz","kcalPer100g":89,"proteinPer100g":1.1,"carbPer100g":23,"fatPer100g":0.3},
    {"id":"f27","name":"Portakal","kcalPer100g":47,"proteinPer100g":0.9,"carbPer100g":12,"fatPer100g":0.1},
    {"id":"f28","name":"Çilek","kcalPer100g":32,"proteinPer100g":0.7,"carbPer100g":7.7,"fatPer100g":0.3},
    {"id":"f29","name":"Üzüm","kcalPer100g":69,"proteinPer100g":0.7,"carbPer100g":18,"fatPer100g":0.2},
    {"id":"f30","name":"Kivi","kcalPer100g":61,"proteinPer100g":1.1,"carbPer100g":15,"fatPer100g":0.5},
]
template = [
    {"id": f"f{i}", "name": f"Yiyecek {i}", "kcalPer100g": 80 + (i % 60), "proteinPer100g": i % 12, "carbPer100g": 5 + (i % 18), "fatPer100g": i % 8}
    for i in range(31, 301)
]
out = real + template
path = os.path.join(os.path.dirname(__file__), "..", "assets", "foods", "foods_tr.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=0)
print("Wrote", len(out), "items to", path)
