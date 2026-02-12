import json
import random

# Base templates for generating variations
BASES = [
    {"name": "Sandviç", "kcal": 250, "p": 10, "c": 30, "f": 10},
    {"name": "Salata", "kcal": 150, "p": 5, "c": 10, "f": 8},
    {"name": "Çorba", "kcal": 80, "p": 3, "c": 10, "f": 2},
    {"name": "Smoothie", "kcal": 180, "p": 4, "c": 30, "f": 2},
    {"name": "Wrap", "kcal": 300, "p": 12, "c": 35, "f": 12},
]

INGREDIENTS = [
    "Peynirli", "Tavuklu", "Ton Balıklı", "Sebzeli", "Meyveli", "Çikolatalı", 
    "Avokadolu", "Hindistan Cevizli", "Yulaflı", "Kinoalı"
]

OUTPUT_FILE = "../assets/foods/foods_tr.json"

def generate_items(count=50):
    new_items = []
    start_id = 1000  # Start IDs from 1000 to avoid conflict
    
    for i in range(count):
        base = random.choice(BASES)
        ing = random.choice(INGREDIENTS)
        
        name = f"{ing} {base['name']}"
        
        # Vary macros slightly (+- 20%)
        factor = random.uniform(0.8, 1.2)
        
        item = {
            "id": f"gen_{start_id + i}",
            "name": name,
            "kcalPer100g": int(base['kcal'] * factor),
            "proteinPer100g": round(base['p'] * factor, 1),
            "carbPer100g": round(base['c'] * factor, 1),
            "fatPer100g": round(base['f'] * factor, 1),
            "unit": "1 porsiyon"
        }
        new_items.append(item)
        
    return new_items

def main():
    try:
        with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
            current_data = json.load(f)
    except FileNotFoundError:
        current_data = []

    print(f"Mevcut kayıt sayısı: {len(current_data)}")
    
    # Generate 50 new items
    new_items = generate_items(50)
    
    # Append (checking for dupes by name would be better, but IDs are unique)
    current_data.extend(new_items)
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(current_data, f, indent=2, ensure_ascii=False)
        
    print(f"Yeni kayıt sayısı: {len(current_data)}")
    print(f"{len(new_items)} adet yeni yiyecek eklendi.")

if __name__ == "__main__":
    main()
