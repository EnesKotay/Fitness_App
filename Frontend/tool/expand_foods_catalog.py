#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
1) Mevcut foods_tr.json (v2) oku; her kayda "tags" ekle (kategori + isim kelimeleri + anlamsal).
2) Varyasyon üret: base yemekler × pişirme × içerik modifier → 1000-3000 kayıt hedef.
Çalıştırma: python tool/expand_foods_catalog.py  (proje kökünden)
"""

import json
import os
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_FOODS = os.path.join(SCRIPT_DIR, "..", "assets", "foods")
FOODS_JSON = os.path.join(ASSETS_FOODS, "foods_tr.json")

# Kelime çıkarma için gereksiz kelimeler (ızgara/haşlanmış vb. STOP'tan çıkarıldı — kullanıcı "ızgara tavuk" arayabilir)
STOP = {"ve", "ile", "veya", "bir", "için", "sade", "dolu", "orta", "küçük", "büyük", "pişmiş", "çiğ"}


def norm(s):
    if s is None:
        return ""
    s = str(s).lower().strip()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"[()\-_/&]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def food_key(name, category):
    return f"{norm(name)}|{norm(category)}"


def add_food_unique(foods, seen_keys, item):
    k = food_key(item.get("name", ""), item.get("category", ""))
    if k in seen_keys:
        return False
    seen_keys.add(k)
    foods.append(item)
    return True


def category_to_tag_tokens(category):
    """Et / Tavuk -> ['et', 'tavuk'], Tahıl & Bakliyat -> ['tahil', 'bakliyat'] (lowercase, bölünmüş)."""
    if not category or category == "Diğer":
        return []
    c = norm(category)
    c = c.replace("ı", "i").replace("ğ", "g").replace("ü", "u").replace("ş", "s").replace("ö", "o").replace("ç", "c")
    tokens = [t for t in re.split(r"[\s/&]+", c) if len(t) >= 2]
    return tokens


# İsimden anlamsal tag türet: lowercase, kategori token'ları (et, tavuk, tahil, bakliyat), pişirme tag'lenir.
def semantic_tags(name, category, aliases_list):
    name_lower = name.lower()
    cat_lower = category.lower() if category else ""
    combined = name_lower + " " + cat_lower + " " + " ".join(aliases_list or [])
    tags = set()
    # Kategori token'ları (lowercase, bölünmüş)
    tags.update(category_to_tag_tokens(category))
    # İsimdeki anlamlı kelimeler (en az 2 harf)
    for word in re.findall(r"[a-zçğıöşü]+", name_lower):
        if len(word) >= 2 and word not in STOP:
            tags.add(word.lower())
    # Pişirme yöntemleri tag (ızgara tavuk, haşlanmış yumurta araması için) — hepsi lowercase
    combined_asc = combined.replace("ı", "i").replace("ğ", "g").replace("ü", "u").replace("ş", "s").replace("ö", "o").replace("ç", "c")
    for cooking in ["izgara", "haslanmis", "kizartma", "firin", "sote"]:
        if cooking in combined_asc or cooking.replace("i", "ı") in combined:
            tags.add(cooking)
    # Anahtar kelimeler -> ek tag (hepsi lowercase)
    if "tavuk" in combined: tags.update(["tavuk", "protein"])
    if "et " in combined or "et/" in combined or "dana" in combined or "kıyma" in combined or "köfte" in combined: tags.update(["et", "protein"])
    if "pilav" in combined or "pirinç" in combined or "bulgur" in combined: tags.update(["pilav", "tahil", "karbonhidrat"])
    if "makarna" in combined or "spagetti" in combined or "erişte" in combined: tags.update(["makarna", "karbonhidrat"])
    if "çorba" in combined or "mercimek" in combined or "ezogelin" in combined or "yayla" in combined or "tarhana" in combined: tags.update(["corba", "ev yemegi"])
    if "salata" in combined or "çoban" in combined or "sezar" in combined or "cacık" in combined: tags.add("salata")
    if "tatlı" in combined or "baklava" in combined or "sütlaç" in combined or "kadayıf" in combined or "pasta" in combined or "kek" in combined: tags.add("tatli")
    if "kahvaltı" in combined or "yumurta" in combined or "peynir" in combined or "zeytin" in combined or "reçel" in combined: tags.add("kahvalti")
    if "balık" in combined or "somon" in combined or "ton" in combined or "levrek" in combined: tags.update(["balik", "protein"])
    if "fast" in combined or "hamburger" in combined or "pizza" in combined or "döner" in combined or "pide" in combined or "lahmacun" in combined: tags.add("fast food")
    # Tutarlı arama için tüm tag'leri lowercase + ASCII normalize
    def asc(s):
        return s.replace("ı", "i").replace("ğ", "g").replace("ü", "u").replace("ş", "s").replace("ö", "o").replace("ç", "c")
    return list({asc(t) for t in tags})


def infer_servings(name, category):
    """Kategoriye ve isme göre otomatik servings: 100g default + 1 Kase / 1 Tabak / 1 Porsiyon / 1 Adet."""
    n = norm(name)
    c = norm(category)
    n = n.replace("ı", "i").replace("ğ", "g").replace("ü", "u").replace("ş", "s").replace("ö", "o").replace("ç", "c")
    c = c.replace("ı", "i").replace("ğ", "g").replace("ü", "u").replace("ş", "s").replace("ö", "o").replace("ç", "c")

    servings = [{"id": "s_100g", "label": "100 g", "grams": 100, "isDefault": True}]

    if "corba" in n or "çorba" in n or "corba" in c:
        servings += [{"id": "s_bowl", "label": "1 Kase", "grams": 250, "isDefault": False}]
    if any(x in n for x in ["pilav", "makarna", "spagetti", "eriste", "noodle", "ramen"]) or "tahil" in c:
        servings += [{"id": "s_plate", "label": "1 Tabak", "grams": 200, "isDefault": False}]
    if any(x in c for x in ["et", "tavuk"]) or any(x in n for x in ["tavuk", "dana", "kuzu", "kofte"]):
        servings += [{"id": "s_portion", "label": "1 Porsiyon", "grams": 150, "isDefault": False}]
    if "kahvalt" in c or any(x in n for x in ["yumurta", "tost", "simit", "pogaca", "omlet", "ekmek"]):
        servings += [{"id": "s_piece", "label": "1 Adet", "grams": 60, "isDefault": False}]

    return servings


def v2_food(id_, name, category, kcal, protein, carb, fat, aliases=None, tags=None, servings=None):
    if servings is None:
        servings = infer_servings(name, category)
    return {
        "id": id_,
        "name": name,
        "category": category,
        "basis": {"amount": 100, "unit": "g"},
        "nutrientsPerBasis": {
            "kcal": round(kcal, 0),
            "protein": round(protein, 1),
            "carb": round(carb, 1),
            "fat": round(fat, 1),
        },
        "servings": servings,
        "aliases": aliases or [],
        "tags": tags or [],
        "brand": None,
    }


def add_tags_to_existing(food):
    name = food.get("name", "")
    category = food.get("category", "Diğer")
    aliases = food.get("aliases") or []
    food["tags"] = semantic_tags(name, category, aliases)
    # Mevcut servings yoksa veya sadece tek kayıt varsa kategoriye göre servings ekle (çakışan label/id ekleme)
    existing = list(food.get("servings") or [])
    if len(existing) <= 1:
        inferred = infer_servings(name, category)
        seen_labels = {s.get("label") for s in existing}
        seen_ids = {s.get("id") for s in existing}
        for s in inferred:
            if s.get("label") not in seen_labels and s.get("id") not in seen_ids:
                existing.append(s)
                seen_labels.add(s.get("label"))
                seen_ids.add(s.get("id"))
        food["servings"] = existing if existing else inferred
    return food


# --- Base yemekler: (isim, kategori, kcal, protein, carb, fat)
BASES = [
    ("Tavuk Göğsü", "Et / Tavuk", 165, 31, 0, 3.6),
    ("Tavuk But", "Et / Tavuk", 209, 26, 0, 12),
    ("Tavuk Kanat", "Et / Tavuk", 203, 30, 0, 9),
    ("Dana Kıyma", "Et / Tavuk", 250, 26, 0, 15),
    ("Dana Bonfile", "Et / Tavuk", 250, 26, 0, 15),
    ("Kuzu Pirzola", "Et / Tavuk", 294, 25, 0, 21),
    ("Köfte", "Et / Tavuk", 220, 18, 8, 14),
    ("Pirinç Pilavı", "Tahıl & Bakliyat", 130, 2.7, 28, 0.3),
    ("Bulgur Pilavı", "Tahıl & Bakliyat", 83, 3.1, 18.6, 0.2),
    ("Şehriyeli Pilav", "Tahıl & Bakliyat", 140, 3, 29, 1),
    ("Makarna", "Tahıl & Bakliyat", 131, 5, 25, 1.1),
    ("Spagetti", "Tahıl & Bakliyat", 131, 5, 25, 1.1),
    ("Erişte", "Tahıl & Bakliyat", 138, 4.5, 25, 2),
    ("Mercimek Çorbası", "Çorba", 75, 4.5, 11, 2),
    ("Ezogelin Çorbası", "Çorba", 70, 3, 12, 1.5),
    ("Yayla Çorbası", "Çorba", 65, 2.5, 10, 2),
    ("Tarhana Çorbası", "Çorba", 55, 2, 10, 1),
    ("Domates Çorbası", "Çorba", 45, 1.5, 8, 1),
    ("Tavuk Suyu Çorba", "Çorba", 35, 3, 2, 1.5),
    ("Çoban Salata", "Salata", 45, 2, 5, 2),
    ("Sezar Salata", "Salata", 120, 8, 6, 8),
    ("Mevsim Salata", "Salata", 35, 2, 4, 1.5),
    ("Cacık", "Salata", 40, 3, 4, 1.5),
    ("Ton Balıklı Salata", "Salata", 95, 14, 3, 3),
    ("Tavuklu Salata", "Salata", 90, 12, 4, 3),
    ("Haşlanmış Yumurta", "Kahvaltılık", 155, 13, 1.1, 11),
    ("Sahanda Yumurta", "Kahvaltılık", 195, 13, 1.5, 15),
    ("Menemen", "Kahvaltılık", 95, 5, 6, 5),
    ("Beyaz Peynir", "Kahvaltılık", 264, 18, 3.2, 20),
    ("Simit", "Kahvaltılık", 275, 10, 52, 4),
    ("Poğaça", "Kahvaltılık", 360, 8, 42, 18),
    ("Sütlaç", "Tatlı", 120, 3, 22, 2.5),
    ("Baklava", "Tatlı", 428, 6, 52, 22),
    ("Kadayıf", "Tatlı", 350, 5, 48, 16),
    ("Revani", "Tatlı", 320, 5, 52, 11),
    ("Dondurma", "Tatlı", 207, 3.5, 24, 11),
    ("Süt", "İçecek", 42, 3.4, 5, 1),
    ("Ayran", "İçecek", 35, 2, 4, 1),
    ("Türk Kahvesi", "İçecek", 2, 0.2, 0, 0),
    ("Çay", "İçecek", 1, 0, 0.2, 0),
    # Ek yemekler (daha fazla çeşit)
    ("Tavuklu Nohut", "Yemek", 165, 14, 18, 5),
    ("Kıymalı Mercimek", "Yemek", 180, 14, 20, 6),
    ("Tavuklu Şehriyeli Pilav", "Yemek", 145, 8, 22, 3),
    ("Etli Nohut", "Yemek", 195, 16, 20, 8),
    ("Zeytinyağlı Taze Fasulye", "Yemek", 55, 2, 8, 2),
    ("Zeytinyağlı Biber Dolma", "Yemek", 70, 2, 10, 2.5),
    ("Imam Bayıldı", "Yemek", 95, 2, 12, 4),
    ("Patlıcan Musakka", "Yemek", 120, 6, 10, 7),
    ("Karnıyarık", "Yemek", 130, 6, 12, 8),
    ("Lahmacun", "Yemek", 275, 12, 38, 10),
    ("Döner (Porsiyon)", "Yemek", 250, 18, 22, 12),
    ("İskender", "Yemek", 280, 22, 28, 12),
    ("Kuru Fasulye", "Yemek", 115, 8, 18, 2),
    ("Nohut Yemeği", "Yemek", 165, 8, 22, 5),
    ("Mercimek Köftesi", "Yemek", 180, 9, 25, 6),
    ("Börek (Su)", "Yemek", 265, 8, 32, 12),
    ("Börek (Talaş)", "Yemek", 320, 9, 35, 17),
    ("Gözleme (Peynirli)", "Yemek", 280, 11, 38, 11),
    ("Pizza (Dilim)", "Yemek", 265, 12, 32, 11),
    ("Hamburger", "Yemek", 295, 17, 28, 14),
    ("Patates Kızartması", "Atıştırmalık", 312, 3.5, 41, 15),
    ("Soğan Halkası", "Atıştırmalık", 350, 5, 35, 22),
    ("Çiğ Köfte", "Atıştırmalık", 180, 8, 28, 5),
    ("Midye Dolma", "Atıştırmalık", 185, 10, 18, 8),
    ("Balık Ekmek", "Yemek", 220, 18, 22, 8),
    ("Köfte Ekmek", "Yemek", 310, 18, 32, 14),
    ("Tantuni", "Yemek", 240, 20, 22, 10),
    ("Çorba (Unlu)", "Çorba", 60, 2, 10, 1.5),
    ("İşkembe Çorbası", "Çorba", 55, 5, 2, 3),
    ("Paça Çorbası", "Çorba", 70, 8, 2, 4),
    ("Brokoli Çorbası", "Çorba", 45, 2.5, 6, 1.5),
    ("Kabak Çorbası", "Çorba", 40, 2, 7, 1),
    ("Mantar Çorbası", "Çorba", 50, 2, 6, 2),
    ("Kremalı Tavuk Çorbası", "Çorba", 95, 6, 8, 4),
    ("Peynirli Makarna", "Tahıl & Bakliyat", 175, 8, 25, 4),
    ("Fettuccine Alfredo", "Tahıl & Bakliyat", 220, 9, 28, 10),
    ("Lazanya", "Yemek", 135, 8, 15, 5),
    ("Mantı", "Yemek", 215, 10, 28, 8),
    ("Kısır", "Salata", 185, 5, 28, 6),
    ("Bulgur Köftesi", "Yemek", 155, 5, 28, 4),
    ("Humus", "Atıştırmalık", 166, 8, 15, 9),
    ("Haydari", "Salata", 120, 6, 4, 9),
]

# Tekil kayıtlar: 1000+ hedef için ek yemekler (tags script tarafından türetilecek)
EXTRA_SINGLES = [
    ("Omlet", "Kahvaltılık", 154, 11, 1, 12),
    ("Sucuklu Yumurta", "Kahvaltılık", 220, 12, 2, 18),
    ("Kaşar Peynir", "Kahvaltılık", 350, 25, 2, 27),
    ("Tereyağlı Ekmek", "Kahvaltılık", 380, 9, 48, 17),
    ("Reçel", "Kahvaltılık", 265, 0, 70, 0),
    ("Tahin Pekmez", "Kahvaltılık", 380, 10, 55, 14),
    ("Mısır Gevreği", "Kahvaltılık", 375, 8, 84, 1),
    ("Müsli", "Kahvaltılık", 352, 12, 66, 6),
    ("Pankek", "Kahvaltılık", 227, 6, 28, 10),
    ("Waffle", "Kahvaltılık", 310, 8, 33, 17),
    ("Krep", "Kahvaltılık", 230, 7, 25, 11),
    ("Tost", "Kahvaltılık", 315, 14, 35, 14),
    ("Kaşarlı Tost", "Kahvaltılık", 340, 16, 34, 17),
    ("Sucuklu Tost", "Kahvaltılık", 365, 18, 32, 20),
    ("Yumurtalı Ekmek", "Kahvaltılık", 280, 12, 30, 13),
    ("Közlenmiş Biber", "Yemek", 32, 1, 6, 0.3),
    ("Cacık", "Salata", 40, 3, 4, 1.5),
    ("Gavurdağı Salata", "Salata", 85, 2, 8, 5),
    ("Roka Salata", "Salata", 25, 2, 3, 0.5),
    ("Yeşil Salata", "Salata", 15, 1, 2, 0.2),
    ("Ton Balığı (Konserve)", "Et / Tavuk", 116, 26, 0, 0.8),
    ("Somon (Fırın)", "Et / Tavuk", 208, 20, 0, 13),
    ("Alabalık (Izgara)", "Et / Tavuk", 190, 22, 0, 11),
    ("Levrek (Fırın)", "Et / Tavuk", 105, 20, 0, 2),
    ("Hamsi (Kızartma)", "Et / Tavuk", 250, 18, 10, 16),
    ("Calzone", "Yemek", 270, 14, 32, 11),
    ("Margarita Pizza", "Yemek", 266, 11, 33, 10),
    ("Karışık Pizza", "Yemek", 280, 13, 32, 12),
    ("Patlıcan Kebab", "Yemek", 120, 6, 12, 6),
    ("Adana Kebap", "Yemek", 305, 22, 5, 23),
    ("Urfa Kebap", "Yemek", 285, 21, 4, 21),
    ("Şiş Kebap", "Yemek", 225, 26, 2, 13),
    ("Tavuk Şiş", "Yemek", 165, 28, 2, 5),
    ("Kuzu Tandır", "Yemek", 235, 24, 0, 15),
    ("Etli Ekmek", "Yemek", 265, 14, 32, 10),
    ("Pide (Kıymalı)", "Yemek", 265, 13, 32, 11),
    ("Pide (Kaşarlı)", "Yemek", 290, 14, 32, 14),
    ("Kuru Köfte", "Yemek", 195, 18, 8, 11),
    ("Sulu Köfte", "Yemek", 115, 12, 8, 5),
    ("İçli Köfte", "Yemek", 245, 11, 28, 11),
    ("Dolma (Biber)", "Yemek", 75, 2, 12, 2),
    ("Dolma (Yaprak)", "Yemek", 95, 5, 14, 2.5),
    ("Sarma", "Yemek", 95, 5, 14, 2.5),
    ("Mücver", "Yemek", 145, 6, 15, 7),
    ("Patates Köftesi", "Yemek", 185, 3, 28, 7),
    ("Ispanaklı Börek", "Yemek", 255, 9, 30, 12),
    ("Peynirli Börek", "Yemek", 285, 11, 31, 14),
    ("Su Böreği", "Yemek", 265, 8, 32, 12),
    ("Sigara Böreği", "Atıştırmalık", 320, 9, 28, 19),
    ("Tulumba", "Tatlı", 350, 4, 45, 18),
    ("Lokum", "Tatlı", 320, 0.5, 88, 0.2),
    ("İrmik Helvası", "Tatlı", 380, 6, 55, 15),
    ("Aşure", "Tatlı", 150, 4, 32, 2),
    ("Pumpkin Pie (Dilim)", "Tatlı", 260, 4, 36, 12),
    ("Cheesecake (Dilim)", "Tatlı", 321, 5, 25, 23),
    ("Brownie", "Tatlı", 405, 5, 52, 21),
    ("Kurabiye", "Tatlı", 420, 6, 58, 20),
    ("Meyveli Pasta", "Tatlı", 265, 4, 38, 11),
    ("Profiterol", "Tatlı", 340, 6, 32, 22),
    ("Trileçe", "Tatlı", 280, 5, 35, 14),
    ("Künefe", "Tatlı", 380, 7, 48, 18),
    ("Güllaç", "Tatlı", 165, 4, 38, 1),
    ("Kabak Tatlısı", "Tatlı", 95, 1, 22, 0.5),
    ("Aşurelik Kabak", "Tatlı", 45, 1, 11, 0.2),
    ("Hoşaf", "İçecek", 45, 0.2, 11, 0),
    ("Limonata", "İçecek", 40, 0, 11, 0),
    ("Meyve Suyu (Portakal)", "İçecek", 45, 0.6, 10, 0.2),
    ("Smoothie (Meyveli)", "İçecek", 65, 1, 15, 0.3),
    ("Soda", "İçecek", 0, 0, 0, 0),
    ("Kola", "İçecek", 42, 0, 11, 0),
    ("Gazoz", "İçecek", 40, 0, 10, 0),
    ("Ayran (Sade)", "İçecek", 35, 2, 4, 1),
    ("Süt (Laktozsuz)", "İçecek", 40, 3.4, 4.8, 1),
    ("Badem Sütü", "İçecek", 35, 1, 2, 2.5),
    ("Fındık", "Atıştırmalık", 628, 15, 17, 61),
    ("Antep Fıstığı", "Atıştırmalık", 560, 20, 28, 45),
    ("Çekirdek (Ayçekirdeği)", "Atıştırmalık", 584, 21, 20, 52),
    ("Leblebi", "Atıştırmalık", 369, 12, 63, 6),
    ("Kestane", "Atıştırmalık", 224, 3, 50, 2.3),
    ("Cips", "Atıştırmalık", 536, 7, 50, 35),
    ("Çikolata (Sütlü)", "Atıştırmalık", 535, 8, 60, 30),
    ("Çikolata (Bitter)", "Atıştırmalık", 546, 5, 33, 42),
    ("Gofret", "Atıştırmalık", 520, 7, 62, 28),
    ("Bisküvi", "Atıştırmalık", 450, 7, 68, 18),
    ("Kraker", "Atıştırmalık", 450, 8, 72, 15),
    ("Granola Bar", "Atıştırmalık", 450, 10, 65, 18),
    ("Meyve Salatası", "Tatlı", 55, 0.8, 14, 0.2),
    ("Elma (Yeşil)", "Meyve & Sebze", 52, 0.3, 14, 0.2),
    ("Muz", "Meyve & Sebze", 89, 1.1, 23, 0.3),
    ("Portakal", "Meyve & Sebze", 47, 0.9, 12, 0.1),
    ("Mandalin", "Meyve & Sebze", 53, 0.8, 13, 0.3),
    ("Üzüm", "Meyve & Sebze", 69, 0.7, 18, 0.2),
    ("Karpuz", "Meyve & Sebze", 30, 0.6, 8, 0.2),
    ("Kavun", "Meyve & Sebze", 34, 0.8, 8, 0.2),
    ("Çilek", "Meyve & Sebze", 32, 0.7, 8, 0.3),
    ("Kiraz", "Meyve & Sebze", 50, 1, 12, 0.3),
    ("Şeftali", "Meyve & Sebze", 39, 0.9, 10, 0.3),
    ("Kayısı", "Meyve & Sebze", 48, 1.4, 11, 0.4),
    ("Armut", "Meyve & Sebze", 57, 0.4, 15, 0.1),
    ("İncir", "Meyve & Sebze", 74, 0.8, 19, 0.3),
    ("Nar", "Meyve & Sebze", 83, 1.2, 19, 1.2),
    ("Avokado", "Meyve & Sebze", 160, 2, 9, 15),
    ("Domates", "Meyve & Sebze", 18, 0.9, 4, 0.2),
    ("Salatalık", "Meyve & Sebze", 15, 0.7, 4, 0.1),
    ("Marul", "Meyve & Sebze", 15, 1.4, 3, 0.2),
    ("Havuç", "Meyve & Sebze", 41, 0.9, 10, 0.2),
    ("Patates (Haşlanmış)", "Meyve & Sebze", 87, 2, 20, 0.1),
    ("Soğan", "Meyve & Sebze", 40, 1.1, 9, 0.1),
    ("Sarımsak", "Meyve & Sebze", 149, 6, 33, 0.5),
    ("Ispanak", "Meyve & Sebze", 23, 3, 4, 0.3),
    ("Brokoli", "Meyve & Sebze", 34, 2.8, 7, 0.4),
    ("Karnabahar", "Meyve & Sebze", 25, 2, 5, 0.1),
    ("Bezelye", "Meyve & Sebze", 81, 5, 14, 0.4),
    ("Mercimek (Pişmiş)", "Tahıl & Bakliyat", 116, 9, 20, 0.4),
    ("Nohut (Pişmiş)", "Tahıl & Bakliyat", 164, 9, 27, 3),
    ("Kuru Fasulye (Haşlanmış)", "Tahıl & Bakliyat", 127, 9, 23, 0.5),
    ("Barbunya (Zeytinyağlı)", "Yemek", 95, 6, 16, 2),
    ("Börülce", "Yemek", 115, 8, 21, 0.5),
]

# 1000+ için ikinci blok: daha fazla tekil yemek
EXTRA_SINGLES_2 = [
    ("Tavuk Çorbası", "Çorba", 45, 5, 3, 1.5),
    ("Şehriye Çorbası", "Çorba", 55, 2, 10, 1),
    ("Düğün Çorbası", "Çorba", 70, 4, 9, 2),
    ("Pilav Üstü Tavuk", "Yemek", 155, 18, 18, 3),
    ("Pilav Üstü Kuru", "Yemek", 140, 10, 22, 2),
    ("Pilav Üstü Nohut", "Yemek", 160, 9, 25, 3),
    ("Tavuk Döner Dürüm", "Yemek", 280, 22, 28, 11),
    ("Et Döner Dürüm", "Yemek", 310, 20, 26, 15),
    ("Köz Patlıcan", "Yemek", 45, 2, 10, 0.5),
    ("Zeytinyağlı Enginar", "Yemek", 65, 3, 12, 1.5),
    ("Pırasa Yemeği", "Yemek", 50, 2, 10, 1),
    ("Ispanak Yemeği", "Yemek", 55, 4, 6, 2),
    ("Kereviz Yemeği", "Yemek", 50, 2, 10, 1),
    ("Pırasa (Zeytinyağlı)", "Yemek", 55, 2, 11, 1),
    ("Taze Fasulye (Zeytinyağlı)", "Yemek", 50, 2, 9, 2),
    ("Bamya Yemeği", "Yemek", 45, 3, 8, 1),
    ("Bamya (Zeytinyağlı)", "Yemek", 50, 3, 9, 1.5),
    ("Kızartma (Patlıcan)", "Yemek", 180, 2, 18, 11),
    ("Kızartma (Kabak)", "Yemek", 165, 2, 16, 10),
    ("Kızartma (Biber)", "Yemek", 155, 2, 15, 9),
    ("Mantarlı Makarna", "Yemek", 125, 5, 22, 2),
    ("Sebzeli Makarna", "Yemek", 95, 4, 18, 1.5),
    ("Napoliten Soslu Makarna", "Yemek", 115, 4, 22, 1.5),
    ("Carbonara", "Yemek", 195, 9, 24, 8),
    ("Pesto Soslu Makarna", "Yemek", 205, 6, 22, 11),
    ("Ravioli", "Yemek", 165, 8, 24, 4),
    ("Tortellini", "Yemek", 170, 8, 25, 4),
    ("Noodle (Sebzeli)", "Yemek", 110, 4, 20, 2),
    ("Ramen", "Yemek", 135, 7, 22, 3),
    ("Udon", "Yemek", 125, 5, 25, 0.5),
    ("Tavuklu Sandviç", "Yemek", 245, 20, 26, 9),
    ("Ton Balıklı Sandviç", "Yemek", 220, 22, 24, 7),
    ("Peynirli Sandviç", "Yemek", 310, 15, 32, 15),
    ("Veggie Sandviç", "Yemek", 185, 6, 28, 6),
    ("Club Sandviç", "Yemek", 295, 22, 28, 12),
    ("Croissant", "Kahvaltılık", 406, 8, 46, 22),
    ("Açma", "Kahvaltılık", 380, 8, 48, 18),
    ("Börek (Çeşit)", "Yemek", 275, 9, 31, 13),
    ("Lahana Sarma", "Yemek", 75, 4, 12, 1.5),
    ("Etli Lahana Sarma", "Yemek", 115, 8, 12, 4),
    ("Zeytinyağlı Yaprak Sarma", "Yemek", 85, 4, 14, 2),
    ("Kuru Biber Dolma", "Yemek", 70, 2, 12, 2),
    ("Domates Dolma", "Yemek", 55, 2, 10, 1.5),
    ("Kabak Çiçeği Dolma", "Yemek", 60, 3, 10, 1.5),
    ("Pirinç (Sade)", "Tahıl & Bakliyat", 130, 2.7, 28, 0.3),
    ("Bulgur (Sade)", "Tahıl & Bakliyat", 83, 3, 19, 0.2),
    ("Kuskus", "Tahıl & Bakliyat", 112, 4, 23, 0.2),
    ("Kinoa (Pişmiş)", "Tahıl & Bakliyat", 120, 4, 21, 2),
    ("Arpa (Pişmiş)", "Tahıl & Bakliyat", 123, 2.3, 28, 0.4),
    ("Yulaf (Pişmiş)", "Tahıl & Bakliyat", 68, 2.5, 12, 1.5),
    ("Mısır (Haşlanmış)", "Meyve & Sebze", 96, 3.4, 21, 1.5),
    ("Bezelye Püresi", "Yemek", 85, 5, 15, 0.5),
    ("Patates Püresi", "Yemek", 85, 2, 20, 0.1),
    ("Havuç Püresi", "Yemek", 45, 1, 10, 0.2),
    ("Kumpir (Karışık)", "Yemek", 185, 6, 28, 6),
    ("Fırın Patates", "Yemek", 95, 2, 22, 0.1),
    ("Patates (Püre)", "Yemek", 85, 2, 20, 0.1),
    ("Kızarmış Patates (Orta)", "Atıştırmalık", 320, 4, 42, 15),
    ("Soğan Rings", "Atıştırmalık", 350, 5, 36, 22),
    ("Mozzarella Stick", "Atıştırmalık", 305, 15, 25, 18),
    ("Nugget (Tavuk)", "Atıştırmalık", 280, 15, 15, 18),
    ("Fish & Chips", "Yemek", 280, 18, 28, 12),
    ("Tavuk Burger", "Yemek", 265, 18, 28, 11),
    ("Veggie Burger", "Yemek", 205, 8, 28, 8),
    ("Double Burger", "Yemek", 380, 28, 30, 20),
    ("Cheese Burger", "Yemek", 315, 20, 30, 16),
    ("Tavuk Wrap", "Yemek", 255, 22, 26, 9),
    ("Falafel", "Yemek", 330, 13, 32, 18),
    ("Falafel Dürüm", "Yemek", 280, 10, 35, 12),
    ("Köfte (Izgara)", "Et / Tavuk", 195, 20, 5, 11),
    ("Şiş Köfte", "Et / Tavuk", 185, 22, 4, 10),
    ("Kadınbudu Köfte", "Yemek", 220, 14, 12, 14),
    ("Sulu Köfte (Çorba)", "Çorba", 85, 10, 6, 2.5),
    ("Yoğurtlu Kebap", "Yemek", 220, 22, 8, 12),
    ("Ali Nazik", "Yemek", 185, 18, 8, 10),
    ("Çökertme Kebab", "Yemek", 240, 22, 15, 12),
    ("Testi Kebab", "Yemek", 195, 20, 8, 10),
    ("Fırın Tavuk", "Et / Tavuk", 175, 28, 0, 6),
    ("Tavuk Kanat (Soslu)", "Et / Tavuk", 265, 22, 12, 15),
    ("Tavuk Baget", "Et / Tavuk", 295, 20, 22, 15),
    ("Tavuk Şinitzel", "Et / Tavuk", 240, 22, 12, 12),
    ("Pane", "Et / Tavuk", 255, 20, 15, 14),
    ("Sote Tavuk", "Et / Tavuk", 165, 26, 4, 5),
    ("Tavuk Sote", "Et / Tavuk", 160, 25, 5, 5),
    ("Tavuk Yahnisi", "Yemek", 125, 18, 8, 3),
    ("Et Yahnisi", "Yemek", 185, 22, 6, 8),
    ("Kuzu Kapama", "Yemek", 220, 22, 8, 13),
    ("Kuzu Güveç", "Yemek", 195, 22, 6, 10),
    ("Tandır (Kuzu)", "Yemek", 240, 24, 0, 15),
    ("Kebap (Karışık)", "Yemek", 285, 24, 8, 18),
    ("Patlıcan Kebab", "Yemek", 115, 6, 12, 5),
    ("Fırın Köfte", "Yemek", 210, 20, 8, 12),
    ("Izgara Köfte", "Yemek", 200, 22, 4, 11),
    ("Lahmacun (1 Adet)", "Yemek", 275, 12, 38, 10),
    ("Pide (1 Adet)", "Yemek", 280, 14, 34, 12),
    ("Pizza (Dilim Margarita)", "Yemek", 260, 11, 32, 10),
    ("Pizza (Dilim Karışık)", "Yemek", 285, 13, 32, 13),
    ("Pizza (Dilim Pepperoni)", "Yemek", 298, 14, 30, 15),
    ("Pizza (Dilim Vejetaryen)", "Yemek", 220, 9, 30, 8),
    ("Makarna (Domates Sos)", "Yemek", 105, 4, 21, 1),
    ("Makarna (Krema Sos)", "Yemek", 165, 5, 22, 7),
    ("Spagetti (Sade)", "Yemek", 131, 5, 25, 1),
    ("Erişte (Tavuklu)", "Yemek", 145, 9, 24, 2),
    ("Erişte (Etli)", "Yemek", 165, 12, 23, 4),
    ("Mantı (Yoğurtlu)", "Yemek", 215, 10, 28, 8),
    ("Lazanya (Sebzeli)", "Yemek", 115, 7, 16, 4),
    ("Lazanya (Etli)", "Yemek", 155, 12, 16, 7),
    ("Kısır (Porsiyon)", "Salata", 185, 5, 28, 6),
    ("Mercimek Köftesi (5 Adet)", "Atıştırmalık", 180, 9, 25, 6),
    ("Bulgur Köftesi (5 Adet)", "Yemek", 155, 5, 28, 4),
    ("İçli Köfte (4 Adet)", "Yemek", 245, 11, 28, 11),
    ("Sigara Böreği (2 Adet)", "Atıştırmalık", 320, 9, 28, 19),
    ("Su Böreği (1 Dilim)", "Yemek", 265, 8, 32, 12),
    ("Gözleme (1 Adet)", "Yemek", 280, 11, 38, 11),
    ("Gözleme (Ispanaklı)", "Yemek", 255, 10, 36, 10),
    ("Gözleme (Kıymalı)", "Yemek", 295, 14, 35, 13),
    ("Köy Kahvaltısı (Porsiyon)", "Kahvaltılık", 420, 18, 42, 22),
    ("Serpme Kahvaltı (Kişi)", "Kahvaltılık", 550, 22, 55, 28),
    ("Sahanda (2 Yumurta)", "Kahvaltılık", 195, 13, 1.5, 15),
    ("Menemen (Porsiyon)", "Kahvaltılık", 95, 5, 6, 5),
    ("Sucuklu Menemen", "Kahvaltılık", 165, 10, 6, 12),
    ("Pastırma Yumurta", "Kahvaltılık", 245, 22, 2, 16),
    ("Kaşarlı Omlet", "Kahvaltılık", 235, 16, 2, 18),
    ("Mantarlı Omlet", "Kahvaltılık", 125, 11, 3, 8),
    ("Sebzeli Omlet", "Kahvaltılık", 95, 9, 4, 5),
    ("French Toast", "Kahvaltılık", 265, 10, 32, 11),
    ("Pankek (3 Adet)", "Kahvaltılık", 227, 6, 28, 10),
    ("Waffle (1 Adet)", "Kahvaltılık", 310, 8, 33, 17),
    ("Sütlaç (Kase)", "Tatlı", 120, 3, 22, 2.5),
    ("Kemalpaşa Tatlısı", "Tatlı", 285, 6, 52, 8),
    ("Cevizli Sucuk", "Tatlı", 385, 8, 55, 16),
    ("Pestil", "Tatlı", 340, 5, 82, 0.5),
    ("Aşure (Kase)", "Tatlı", 150, 4, 32, 2),
    ("Baklava (2 Dilim)", "Tatlı", 428, 6, 52, 22),
    ("Künefe (Porsiyon)", "Tatlı", 380, 7, 48, 18),
    ("Katmer", "Tatlı", 420, 8, 48, 22),
    ("Lokma", "Tatlı", 330, 4, 42, 16),
    ("Hanım Göbeği", "Tatlı", 350, 5, 48, 15),
    ("Tulumba (3 Adet)", "Tatlı", 350, 4, 45, 18),
    ("Şekerpare", "Tatlı", 340, 5, 48, 14),
    ("İrmik Helvası (Porsiyon)", "Tatlı", 380, 6, 55, 15),
    ("Revani (Dilim)", "Tatlı", 320, 5, 52, 11),
    ("Kadayıf (Porsiyon)", "Tatlı", 350, 5, 48, 16),
    ("Dondurma (2 Top)", "Tatlı", 207, 3.5, 24, 11),
    ("Dondurma (Külah)", "Tatlı", 250, 4, 32, 12),
    ("Magnolia", "Tatlı", 285, 4, 38, 12),
    ("Tiramisu", "Tatlı", 320, 6, 35, 18),
    ("Cheesecake (Dilim)", "Tatlı", 321, 5, 25, 23),
    ("Brownie (Dilim)", "Tatlı", 405, 5, 52, 21),
    ("Meyve Salatası (Kase)", "Tatlı", 55, 0.8, 14, 0.2),
    ("Pasta (Dilim)", "Tatlı", 265, 4, 38, 11),
    ("Profiterol (3 Adet)", "Tatlı", 340, 6, 32, 22),
    ("Trileçe (Dilim)", "Tatlı", 280, 5, 35, 14),
    ("Güllaç (Dilim)", "Tatlı", 165, 4, 38, 1),
    ("Kabak Tatlısı (Porsiyon)", "Tatlı", 95, 1, 22, 0.5),
    ("Ayva Tatlısı", "Tatlı", 125, 0.5, 32, 0.2),
    ("Elma Tatlısı", "Tatlı", 95, 0.5, 24, 0.5),
    ("İncir Tatlısı", "Tatlı", 145, 2, 35, 0.5),
    ("Cevizli Kuru Üzüm", "Atıştırmalık", 385, 8, 45, 18),
    ("Hurma", "Meyve & Sebze", 282, 2.5, 75, 0.4),
    ("Kuru Kayısı", "Meyve & Sebze", 241, 3.4, 63, 0.5),
    ("Kuru İncir", "Meyve & Sebze", 249, 3.3, 64, 1),
    ("Kuru Üzüm", "Meyve & Sebze", 299, 3.1, 79, 0.5),
    ("Ceviz (5 Adet)", "Atıştırmalık", 654, 15, 14, 65),
    ("Badem (10 Adet)", "Atıştırmalık", 575, 21, 22, 49),
    ("Fındık (10 Adet)", "Atıştırmalık", 628, 15, 17, 61),
    ("Antep Fıstığı (1 Avuç)", "Atıştırmalık", 560, 20, 28, 45),
    ("Çikolatalı Fındık", "Atıştırmalık", 550, 8, 48, 38),
    ("Nutella (1 Yemek Kaşığı)", "Atıştırmalık", 100, 1, 12, 6),
    ("Fıstık Ezmesi (1 Yemek Kaşığı)", "Kahvaltılık", 95, 4, 3, 8),
    ("Tahin (1 Yemek Kaşığı)", "Kahvaltılık", 90, 2.5, 3, 8),
    ("Pekmez (1 Yemek Kaşığı)", "Kahvaltılık", 65, 0, 16, 0),
    ("Bal (1 Yemek Kaşığı)", "Kahvaltılık", 64, 0, 17, 0),
    ("Reçel (1 Yemek Kaşığı)", "Kahvaltılık", 55, 0, 14, 0),
]

# Pişirme yöntemleri: (ek ad, kcal çarpanı, yağ ekleme yaklaşık)
COOKING = [
    ("Haşlanmış", 1.0, 0),
    ("Izgara", 1.05, 0),
    ("Fırın", 1.05, 0),
    ("Sote", 1.15, 2),
    ("Kızartma", 1.35, 8),
]

# İçerik modifier'ları (pilav/makarna/çorba için): (ek ad, +kcal, +p, +c, +f)
MODIFIERS_PILAV = [
    ("Sade", 0, 0, 0, 0),
    ("Tavuklu", 15, 3, 0, 0.5),
    ("Nohutlu", 25, 2, 4, 0.5),
    ("Mercimekli", 20, 2, 3, 0.2),
    ("Kıymalı", 35, 4, 0, 2),
]
MODIFIERS_MAKARNA = [
    ("Sade", 0, 0, 0, 0),
    ("Domates Soslu", 25, 1, 5, 1),
    ("Peynirli", 45, 3, 2, 3),
    ("Kıymalı", 40, 5, 2, 2),
    ("Tavuklu", 20, 4, 1, 0.5),
]
MODIFIERS_CORBA = [
    ("Sade", 0, 0, 0, 0),
    ("Tavuklu", 15, 3, 0, 0.5),
]


def main():
    os.makedirs(ASSETS_FOODS, exist_ok=True)

    # Mevcut kataloğu oku
    if os.path.exists(FOODS_JSON):
        with open(FOODS_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
    else:
        data = {"schemaVersion": 2, "locale": "tr-TR", "foods": []}

    foods = data.get("foods") if isinstance(data.get("foods"), list) else []
    existing_ids = {f.get("id") for f in foods if f.get("id")}
    seen_keys = {food_key(f.get("name", ""), f.get("category", "")) for f in foods if f.get("name")}
    next_id = 1
    for f in foods:
        try:
            n = int((f.get("id") or "0").replace("tr_", "").replace("f", ""))
            if n >= next_id:
                next_id = n + 1
        except Exception:
            pass

    # 1) Mevcut kayıtlara tags + servings güncelle (duplicate key'e dokunma)
    for food in foods:
        add_tags_to_existing(food)

    # 2) Varyasyon üret: base × pişirme (et/tavuk için)
    def next_tr_id():
        nonlocal next_id
        while True:
            sid = f"tr_{next_id}"
            next_id += 1
            if sid not in existing_ids:
                existing_ids.add(sid)
                return sid

    et_bases = [(n, c, k, p, car, fa) for n, c, k, p, car, fa in BASES if "Tavuk" in n or "Dana" in n or "Kuzu" in n or "Köfte" in n]
    for (name, category, kcal, protein, carb, fat) in et_bases:
        for (cook_name, mult, add_fat) in COOKING:
            new_name = f"{name} ({cook_name})"
            item = v2_food(
                next_tr_id(), new_name, category,
                kcal * mult, protein, carb, fat + add_fat,
                aliases=[name.lower(), cook_name.lower()],
                tags=semantic_tags(new_name, category, [name, cook_name]),
                servings=infer_servings(new_name, category),
            )
            add_food_unique(foods, seen_keys, item)

    # 3) Pilav varyasyonları
    pilav_bases = [(n, c, k, p, car, fa) for n, c, k, p, car, fa in BASES if "Pilav" in n or "Pirinç" in n or "Bulgur" in n]
    for (name, category, kcal, protein, carb, fat) in pilav_bases:
        for (mod_name, dk, dp, dc, df) in MODIFIERS_PILAV:
            if mod_name == "Sade":
                new_name = name
            else:
                new_name = f"{mod_name} {name}"
            item = v2_food(
                next_tr_id(), new_name, category,
                kcal + dk, protein + dp, carb + dc, fat + df,
                aliases=[name.lower(), mod_name.lower()],
                tags=semantic_tags(new_name, category, [name, mod_name]),
                servings=infer_servings(new_name, category),
            )
            add_food_unique(foods, seen_keys, item)

    # 4) Makarna varyasyonları
    makarna_bases = [(n, c, k, p, car, fa) for n, c, k, p, car, fa in BASES if "Makarna" in n or "Spagetti" in n or "Erişte" in n]
    for (name, category, kcal, protein, carb, fat) in makarna_bases:
        for (mod_name, dk, dp, dc, df) in MODIFIERS_MAKARNA:
            if mod_name == "Sade":
                new_name = name
            else:
                new_name = f"{name} ({mod_name})"
            item = v2_food(
                next_tr_id(), new_name, category,
                kcal + dk, protein + dp, carb + dc, fat + df,
                aliases=[name.lower(), mod_name.lower()],
                tags=semantic_tags(new_name, category, [name, mod_name]),
                servings=infer_servings(new_name, category),
            )
            add_food_unique(foods, seen_keys, item)

    # 5) Çorba varyasyonları
    corba_bases = [(n, c, k, p, car, fa) for n, c, k, p, car, fa in BASES if "Çorba" in n]
    for (name, category, kcal, protein, carb, fat) in corba_bases:
        for (mod_name, dk, dp, dc, df) in MODIFIERS_CORBA:
            if mod_name == "Sade":
                new_name = name
            else:
                new_name = f"{mod_name} {name}"
            item = v2_food(
                next_tr_id(), new_name, category,
                kcal + dk, protein + dp, carb + dc, fat + df,
                aliases=[name.lower(), mod_name.lower()],
                tags=semantic_tags(new_name, category, [name, mod_name]),
                servings=infer_servings(new_name, category),
            )
            add_food_unique(foods, seen_keys, item)

    # 6) Kalan base'leri tek kayıt olarak ekle
    other_bases = [(n, c, k, p, car, fa) for n, c, k, p, car, fa in BASES
                   if not any(x in n for x in ["Tavuk", "Dana", "Kuzu", "Köfte", "Pilav", "Pirinç", "Bulgur", "Makarna", "Spagetti", "Erişte", "Çorba"])]
    for (name, category, kcal, protein, carb, fat) in other_bases:
        item = v2_food(
            next_tr_id(), name, category, kcal, protein, carb, fat,
            tags=semantic_tags(name, category, [name]),
            servings=infer_servings(name, category),
        )
        add_food_unique(foods, seen_keys, item)

    # 7) Ek tekil yemekler
    for (name, category, kcal, protein, carb, fat) in EXTRA_SINGLES:
        item = v2_food(
            next_tr_id(), name, category, kcal, protein, carb, fat,
            tags=semantic_tags(name, category, [name]),
            servings=infer_servings(name, category),
        )
        add_food_unique(foods, seen_keys, item)

    # 8) İkinci blok tekil yemekler
    for (name, category, kcal, protein, carb, fat) in EXTRA_SINGLES_2:
        item = v2_food(
            next_tr_id(), name, category, kcal, protein, carb, fat,
            tags=semantic_tags(name, category, [name]),
            servings=infer_servings(name, category),
        )
        add_food_unique(foods, seen_keys, item)

    data["foods"] = foods
    with open(FOODS_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"Tamamlandı: {len(foods)} kayıt -> {FOODS_JSON}")


if __name__ == "__main__":
    main()
