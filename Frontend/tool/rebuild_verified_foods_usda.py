#!/usr/bin/env python3
"""Rebuild frontend/assets/foods/foods_tr.json from official USDA datasets.

Data sources:
- Foundation Foods JSON: https://fdc.nal.usda.gov/download-datasets/
- Survey Foods (FNDDS) JSON: https://fdc.nal.usda.gov/download-datasets/
- Selected SR Legacy foods JSON: https://fdc.nal.usda.gov/download-datasets/

The goal is not to preserve the old synthetic catalog size; the goal is to
retain only entries whose kcal/protein/carb/fat values come from official
FoodData Central records.
"""

from __future__ import annotations

import json
import re
import unicodedata
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT_PATH = ROOT / "assets" / "foods" / "foods_tr.json"

FOUNDATION_ZIP = Path("/tmp/foundation_2025_12_18.zip")
SURVEY_ZIP = Path("/tmp/survey_2024_10_31.zip")
SR_ZIP = Path("/tmp/sr_legacy_2018_04.zip")

ENERGY_NUMBERS = {"208", "1008"}
PROTEIN_NUMBERS = {"203", "1003"}
CARB_NUMBERS = {"205", "1005"}
FAT_NUMBERS = {"204", "1004"}
MAX_MACRO_KCAL_DIFF = 25.0

PHRASE_TRANSLATIONS = {
    "hot dog": "sosisli",
    "almond butter": "badem ezmesi",
    "apple juice": "elma suyu",
    "pineapple juice": "ananas suyu",
    "orange juice": "portakal suyu",
    "for use on a sandwich": "sandviç için",
    "in syrup": "şurupta",
    "juice pack": "meyve suyu paketli",
    "stir fry vegetables": "sote sebze",
    "white bread": "beyaz ekmek",
    "wheat bread": "buğday ekmeği",
    "white bun": "beyaz sandviç ekmeği",
    "wheat bun": "buğday sandviç ekmeği",
    "with dressing": "soslu",
    "with added vegetables": "sebzeli",
    "with added vitamin c": "c vitamini eklenmiş",
    "with vegetables": "sebzeli",
    "with meat and added vegetables": "etli ve sebzeli",
    "with poultry and added vegetables": "tavuklu ve sebzeli",
    "with seafood and added vegetables": "deniz ürünlü ve sebzeli",
    "with meat": "etli",
    "with poultry": "tavuklu",
    "with seafood": "deniz ürünlü",
    "with cheese": "peynirli",
    "with oil": "yağlı",
    "with butter or margarine": "tereyağlı veya margarinli",
    "with butter": "tereyağlı",
    "with skin": "kabuklu",
    "without skin": "kabuksuz",
    "skin not eaten": "derisiz",
    "from raw": "çiğden pişmiş",
    "no added fat": "yağ eklenmemiş",
    "no dressing": "sossuz",
    "plain, refrigerated": "sade, soğuk dolap",
    "plain, shelf stable": "sade, raf ömürlü",
    "shelf stable": "raf ömürlü",
    "from concentrate": "konsantreden",
    "lower sodium and lower sugar": "düşük sodyumlu ve düşük şekerli",
    "lower sodium": "düşük sodyumlu",
    "lower sugar": "düşük şekerli",
    "reduced fat": "az yağlı",
    "whole grain": "tam tahıllı",
    "whole milk": "tam yağlı süt",
    "fat free": "yağsız",
    "nonfat": "yağsız",
    "unsweetened": "şekersiz",
    "sweetened": "tatlandırılmış",
    "chocolate covered": "çikolata kaplı",
    "cooked, boiled": "haşlanmış",
    "baked, broiled, or roasted": "pişmiş",
    "baked or broiled": "pişmiş",
    "baked": "fırınlanmış",
    "broiled": "ızgara",
    "roasted": "kavrulmuş",
    "fried": "kızartılmış",
    "grilled": "ızgara",
    "boiled": "haşlanmış",
    "cooked": "pişmiş",
    "canned": "konserve",
    "frozen": "dondurulmuş",
    "fresh": "taze",
    "dried": "kurutulmuş",
    "raw": "çiğ",
}

WORD_TRANSLATIONS = {
    "abalone": "abalon",
    "agave": "agave",
    "alfalfa": "yonca",
    "almond": "badem",
    "almonds": "badem",
    "aloe": "aloe",
    "ambrosia": "ambrosia",
    "anchovies": "hamsi",
    "anchovy": "hamsi",
    "animal": "hayvansal",
    "and": "ve",
    "apple": "elma",
    "apples": "elma",
    "applesauce": "elma püresi",
    "apricot": "kayısı",
    "arepa": "arepa",
    "armadillo": "armadillo",
    "artichoke": "enginar",
    "artichokes": "enginar",
    "arugula": "roka",
    "asparagus": "kuşkonmaz",
    "asian": "asya usulü",
    "avocado": "avokado",
    "baby": "bebek",
    "bacon": "bacon",
    "baked": "fırınlanmış",
    "banana": "muz",
    "bar": "bar",
    "barley": "arpa",
    "basil": "fesleğen",
    "bean": "fasulye",
    "beans": "fasulye",
    "beef": "dana",
    "beet": "pancar",
    "berries": "orman meyveleri",
    "berry": "meyve",
    "beverage": "içecek",
    "black": "siyah",
    "blackberry": "böğürtlen",
    "blueberry": "yaban mersini",
    "bread": "ekmek",
    "broccoli": "brokoli",
    "broth": "et suyu",
    "brown": "esmer",
    "buckwheat": "karabuğday",
    "bulgur": "bulgur",
    "burger": "burger",
    "burrito": "burrito",
    "butter": "tereyağı",
    "buttermilk": "yayık ayranı",
    "cabbage": "lahana",
    "cake": "kek",
    "calcium": "kalsiyum",
    "candy": "şekerleme",
    "cantaloupe": "kavun",
    "capers": "kapari",
    "caramel": "karamel",
    "carrot": "havuç",
    "carrots": "havuç",
    "cauliflower": "karnabahar",
    "celery": "kereviz",
    "cereal": "tahıl gevreği",
    "cheese": "peynir",
    "cherry": "kiraz",
    "cherries": "kiraz",
    "chickpea": "nohut",
    "chickpeas": "nohut",
    "chicken": "tavuk",
    "chili": "acı biber",
    "chocolate": "çikolata",
    "chowder": "çorba",
    "cider": "elma şırası",
    "cilantro": "kişniş",
    "coconut": "hindistan cevizi",
    "cod": "morina",
    "coffee": "kahve",
    "coleslaw": "lahana salatası",
    "concentrate": "konsantre",
    "cookie": "kurabiye",
    "cookies": "kurabiye",
    "corn": "mısır",
    "cottage": "lor",
    "couscous": "kuskus",
    "crab": "yengeç",
    "cracker": "kraker",
    "crackers": "kraker",
    "cranberry": "turna yemişi",
    "cream": "krema",
    "creamy": "kremamsı",
    "crispy": "çıtır",
    "cucumber": "salatalık",
    "cupcake": "cupcake",
    "curry": "köri",
    "date": "hurma",
    "dates": "hurma",
    "dip": "dip sos",
    "dominicana": "dominicana",
    "dressing": "sos",
    "dough": "hamur",
    "drained": "süzülmüş",
    "drink": "içecek",
    "drippings": "damla yağı",
    "duck": "ördek",
    "egg": "yumurta",
    "eggs": "yumurta",
    "english": "ingiliz",
    "falafel": "falafel",
    "fat": "yağ",
    "feta": "beyaz peynir",
    "fig": "incir",
    "fish": "balık",
    "flavored": "aromalı",
    "flour": "un",
    "frankfurter": "sosis",
    "fries": "kızartması",
    "fritter": "mücver",
    "fruit": "meyve",
    "fry": "sote",
    "fuji": "fuji",
    "garlic": "sarımsak",
    "garden": "bahçe",
    "gala": "gala",
    "gin": "cin",
    "ginger": "zencefil",
    "goat": "keçi",
    "grain": "tahıl",
    "granny": "granny",
    "grape": "üzüm",
    "grapes": "üzüm",
    "grapefruit": "greyfurt",
    "gravy": "et sosu",
    "green": "yeşil",
    "ham": "jambon",
    "hamburger": "hamburger",
    "halves": "yarım",
    "hazelnut": "fındık",
    "herring": "ringa",
    "honey": "bal",
    "honeycrisp": "honeycrisp",
    "hummus": "humus",
    "ice": "buz",
    "jam": "reçel",
    "jelly": "jöle",
    "juice": "meyve suyu",
    "kale": "kara lahana",
    "kefir": "kefir",
    "kiwi": "kivi",
    "kiwifruit": "kivi",
    "lamb": "kuzu",
    "lasagna": "lazanya",
    "lettuce": "marul",
    "lemon": "limon",
    "lentil": "mercimek",
    "lime": "misket limonu",
    "liquid": "sıvı",
    "lobster": "ıstakoz",
    "macaroni": "makarna",
    "mango": "mango",
    "margarine": "margarin",
    "marshmallow": "marshmallow",
    "meat": "et",
    "melon": "kavun",
    "milk": "süt",
    "mix": "karışım",
    "mixture": "karışım",
    "mushroom": "mantar",
    "mussels": "midye",
    "mustard": "hardal",
    "navels": "navel",
    "nectar": "nektar",
    "no": "yok",
    "noodles": "erişte",
    "nuts": "kuruyemiş",
    "on": "üzerinde",
    "oat": "yulaf",
    "oatmeal": "yulaf ezmesi",
    "octopus": "ahtapot",
    "oil": "yağ",
    "olive": "zeytin",
    "omelet": "omlet",
    "onion": "soğan",
    "onions": "soğan",
    "orange": "portakal",
    "oranges": "portakal",
    "or": "veya",
    "oregano": "kekik",
    "other": "diğer",
    "pancake": "pankek",
    "pasta": "makarna",
    "paste": "ezme",
    "patty": "köfte",
    "pea": "bezelye",
    "peas": "bezelye",
    "peach": "şeftali",
    "peanut": "fıstık",
    "peanuts": "fıstık",
    "pear": "armut",
    "pepper": "biber",
    "pickle": "turşu",
    "pie": "turta",
    "pilaf": "pilav",
    "pineapple": "ananas",
    "pistachio": "antep fıstığı",
    "pizza": "pizza",
    "plain": "sade",
    "plum": "erik",
    "pork": "domuz",
    "potato": "patates",
    "potatoes": "patates",
    "powder": "toz",
    "pack": "paket",
    "peeled": "soyulmuş",
    "prawns": "karides",
    "pretzels": "pretzel",
    "pumpkin": "balkabağı",
    "quinoa": "kinoa",
    "radish": "turp",
    "raisin": "kuru üzüm",
    "raspberry": "ahududu",
    "red": "kırmızı",
    "reduced": "azaltılmış",
    "rice": "pirinç",
    "ricotta": "ricotta",
    "roasted": "kavrulmuş",
    "romaine": "romaine",
    "rye": "çavdar",
    "salad": "salata",
    "salmon": "somon",
    "sandwich": "sandviç",
    "sardines": "sardalya",
    "sauce": "sos",
    "sausage": "sosis",
    "seafood": "deniz ürünü",
    "seaweed": "deniz yosunu",
    "sesame": "susam",
    "shallots": "arpacık soğan",
    "shrimp": "karides",
    "smooth": "pürüzsüz",
    "snack": "atıştırmalık",
    "sodium": "sodyum",
    "soup": "çorba",
    "soy": "soya",
    "spaghetti": "spagetti",
    "spinach": "ıspanak",
    "sprouts": "filiz",
    "squash": "kabak",
    "steak": "biftek",
    "style": "usulü",
    "stew": "yahni",
    "stir": "sote",
    "strawberries": "çilek",
    "strawberry": "çilek",
    "substitute": "ikamesi",
    "sugar": "şeker",
    "sweet": "tatlı",
    "sweetener": "tatlandırıcı",
    "sweetpotato": "tatlı patates",
    "syrup": "şurup",
    "than": "hariç",
    "tea": "çay",
    "tequila": "tekila",
    "toast": "tost",
    "tomato": "domates",
    "tomatoes": "domates",
    "tuna": "ton balığı",
    "turkey": "hindi",
    "turnip": "şalgam",
    "unsalted": "tuzsuz",
    "unroasted": "kavrulmamış",
    "use": "kullanım",
    "vanilla": "vanilya",
    "vegetable": "sebze",
    "vegetables": "sebze",
    "vinegar": "sirke",
    "walnut": "ceviz",
    "walnuts": "ceviz",
    "water": "su",
    "watermelon": "karpuz",
    "wheat": "buğday",
    "whiskey": "viski",
    "white": "beyaz",
    "wild": "yabani",
    "whole": "tam",
    "with": "ile",
    "for": "için",
    "vegetarian": "vejetaryen",
    "yogurt": "yoğurt",
    "zucchini": "kabak",
}


OVERRIDES = [
    {
        "source": "sr",
        "match": "Egg, whole, cooked, hard-boiled",
        "name": "Yumurta (Haşlanmış)",
        "category": "Kahvaltılık",
        "aliases": ["haşlanmış yumurta", "yumurta"],
    },
    {
        "source": "foundation",
        "match": "Oats, whole grain, rolled, old fashioned",
        "name": "Yulaf Ezmesi",
        "category": "Tahıl",
        "aliases": ["yulaf", "oatmeal"],
    },
    {
        "source": "survey",
        "match": "Chicken breast, baked, broiled, or roasted, skin not eaten, from raw",
        "name": "Tavuk Göğsü (Pişmiş)",
        "category": "Et / Tavuk",
        "aliases": ["tavuk göğsü", "tavuk"],
    },
    {
        "source": "survey",
        "match": "Rice pilaf",
        "name": "Pirinç Pilavı",
        "category": "Tahıl",
        "aliases": ["pilav", "pirinç pilavı"],
    },
    {
        "source": "sr",
        "match": "Bulgur, cooked",
        "name": "Bulgur (Pişmiş)",
        "category": "Tahıl",
        "aliases": ["bulgur", "bulgur pilavı"],
    },
    {
        "source": "survey",
        "match": "Milk, reduced fat (2%)",
        "name": "Süt (Yarım Yağlı)",
        "category": "Süt Ürünleri",
        "aliases": ["süt", "yarım yağlı süt"],
    },
    {
        "source": "foundation",
        "match": "Yogurt, plain, whole milk",
        "name": "Yoğurt (Tam Yağlı)",
        "category": "Süt Ürünleri",
        "aliases": ["yoğurt", "yogurt"],
    },
    {
        "source": "survey",
        "match": "Kefir",
        "name": "Kefir",
        "category": "Süt Ürünleri",
        "aliases": ["kefir"],
    },
    {
        "source": "sr",
        "match": "Cheese, feta",
        "name": "Beyaz Peynir",
        "category": "Süt Ürünleri",
        "aliases": ["feta", "beyaz peynir"],
    },
    {
        "source": "foundation",
        "match": "Hummus, commercial",
        "name": "Humus",
        "category": "Meze",
        "aliases": ["hummus", "humus"],
    },
    {
        "source": "survey",
        "match": "Fish, tuna, canned",
        "name": "Ton Balığı (Konserve)",
        "category": "Balık",
        "aliases": ["ton balığı", "konserve ton balığı"],
    },
    {
        "source": "survey",
        "match": "Fish, salmon, baked or broiled",
        "name": "Somon (Pişmiş)",
        "category": "Balık",
        "aliases": ["somon"],
    },
    {
        "source": "sr",
        "match": "Broccoli, cooked, boiled, drained, with salt",
        "name": "Brokoli (Haşlanmış)",
        "category": "Sebze",
        "aliases": ["brokoli"],
    },
    {
        "source": "sr",
        "match": "Tomatoes, red, ripe, raw, year round average",
        "name": "Domates",
        "category": "Sebze",
        "aliases": ["domates"],
    },
    {
        "source": "foundation",
        "match": "Cucumber, with peel, raw",
        "name": "Salatalık",
        "category": "Sebze",
        "aliases": ["salatalık"],
    },
    {
        "source": "survey",
        "match": "Carrots, raw",
        "name": "Havuç (Çiğ)",
        "category": "Sebze",
        "aliases": ["havuç"],
    },
    {
        "source": "survey",
        "match": "Apple, raw",
        "name": "Elma",
        "category": "Meyve",
        "aliases": ["elma"],
    },
    {
        "source": "survey",
        "match": "Banana, raw",
        "name": "Muz",
        "category": "Meyve",
        "aliases": ["muz"],
    },
    {
        "source": "foundation",
        "match": "Oranges, raw, navels",
        "name": "Portakal",
        "category": "Meyve",
        "aliases": ["portakal"],
    },
    {
        "source": "foundation",
        "match": "Strawberries, raw",
        "name": "Çilek",
        "category": "Meyve",
        "aliases": ["çilek"],
    },
    {
        "source": "survey",
        "match": "Grapes, raw",
        "name": "Üzüm",
        "category": "Meyve",
        "aliases": ["üzüm"],
    },
    {
        "source": "foundation",
        "match": "Kiwifruit, green, raw",
        "name": "Kivi",
        "category": "Meyve",
        "aliases": ["kivi"],
    },
    {
        "source": "foundation",
        "match": "Peanut butter, creamy",
        "name": "Fıstık Ezmesi",
        "category": "Atıştırmalık",
        "aliases": ["fıstık ezmesi", "peanut butter"],
    },
    {
        "source": "foundation",
        "match": "Nuts, walnuts, English, halves, raw",
        "name": "Ceviz",
        "category": "Atıştırmalık",
        "aliases": ["ceviz"],
    },
    {
        "source": "survey",
        "match": "Coffee, brewed",
        "name": "Kahve (Demlenmiş)",
        "category": "İçecek",
        "aliases": ["kahve", "coffee"],
    },
    {
        "source": "sr",
        "match": "Beverages, tea, black, brewed, prepared with tap water",
        "name": "Çay (Demlenmiş)",
        "category": "İçecek",
        "aliases": ["çay", "tea"],
    },
    {
        "source": "survey",
        "match": "Baklava",
        "name": "Baklava",
        "category": "Tatlı",
        "aliases": ["baklava"],
    },
    {
        "source": "survey",
        "match": "Falafel",
        "name": "Falafel",
        "category": "Yemek",
        "aliases": ["falafel"],
    },
    {
        "source": "survey",
        "match": "Hamburger, NFS",
        "name": "Hamburger",
        "category": "Fast Food",
        "aliases": ["hamburger"],
    },
    {
        "source": "survey",
        "match": "Potato, french fries, NFS",
        "name": "Patates Kızartması",
        "category": "Fast Food",
        "aliases": ["patates kızartması", "french fries"],
    },
]


SURVEY_EXCLUDE_PATTERNS = [
    "babyfood",
    "baby food",
    "human",
    "from fast food",
    "from restaurant",
    "frozen meal",
    "diet frozen meal",
    "topping from",
    "nfs",
    "ns as to",
]


def load_dataset(zip_path: Path) -> list[dict]:
    with zipfile.ZipFile(zip_path) as archive:
        member = archive.namelist()[0]
        with archive.open(member) as handle:
            payload = json.load(handle)
    return payload[next(iter(payload))]


def normalize_text(value: str) -> str:
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return value.strip()


def title_case_tr(value: str) -> str:
    small_words = {"ve", "veya", "ile", "de", "da", "için", "ya", "bir"}
    parts = re.split(r"(\W+)", value.strip())
    titled = []
    for index, part in enumerate(parts):
        if not part or re.fullmatch(r"\W+", part):
            titled.append(part)
            continue
        lower = part.lower()
        if index != 0 and lower in small_words:
            titled.append(lower)
            continue
        titled.append(lower[:1].upper() + lower[1:])
    return "".join(titled).strip()


def translate_generic_text(description: str, *, title_case: bool = True) -> str:
    text = description.strip().lower()
    for source, target in sorted(
        PHRASE_TRANSLATIONS.items(),
        key=lambda item: len(item[0]),
        reverse=True,
    ):
        text = re.sub(rf"\b{re.escape(source)}\b", target, text)

    tokens = re.split(r"([a-z]+(?:'[a-z]+)?|\W+)", text)
    translated = []
    for token in tokens:
        if not token:
            continue
        if re.fullmatch(r"[a-z]+(?:'[a-z]+)?", token):
            translated.append(WORD_TRANSLATIONS.get(token, token))
        else:
            translated.append(token)

    result = "".join(translated)
    result = re.sub(r"\s+", " ", result)
    result = re.sub(r"\s+,", ",", result)
    result = re.sub(r",\s*", ", ", result)
    result = re.sub(r"\(\s+", "(", result)
    result = re.sub(r"\s+\)", ")", result)
    result = re.sub(r"\s+/\s+", "/", result)
    return title_case_tr(result) if title_case else result.strip()


def translate_modifier_phrase(text: str) -> str:
    value = normalize_text(text)
    exact = {
        "beans and vegetables": "Fasulyeli ve Sebzeli",
        "extra meat and extra vegetables": "Ekstra Etli ve Ekstra Sebzeli",
        "extra meat": "Ekstra Etli",
        "meat and beans": "Etli ve Fasulyeli",
        "chicken and beans": "Tavuklu ve Fasulyeli",
        "meat and cheese": "Etli ve Peynirli",
        "bacon and cheese": "Baconlu ve Peynirli",
        "sausage and cheese": "Sosisli ve Peynirli",
        "vegetables other than dark green and or tomatoes": "Sebzeli",
        "vegetables other than dark green and or tomatoes fat added": "Sebzeli",
        "vegetables other than dark green and or tomatoes no added fat": "Sebzeli",
        "vegetables other than dark green": "Sebzeli",
        "cheese and vegetables other than dark green and or tomatoes": "Peynirli Sebzeli",
        "cheese and tomatoes": "Peynirli Domatesli",
        "cheese": "Peynirli",
        "chicken": "Tavuklu",
        "turkey": "Hindili",
        "meat": "Etli",
        "beans": "Fasulyeli",
        "vegetables": "Sebzeli",
        "shrimp": "Karidesli",
        "bacon": "Baconlu",
        "ham": "Jambonlu",
        "sausage": "Sosisli",
        "meatless": "Etsiz",
    }
    if value in exact:
        return exact[value]
    return translate_generic_text(text)


def translate_carrier(text: str) -> str:
    value = normalize_text(text)
    exact = {
        "white": "Beyaz Ekmek",
        "white bread": "Beyaz Ekmek",
        "wheat": "Tam Buğday Ekmeği",
        "wheat bread": "Tam Buğday Ekmeği",
        "bagel": "Bagel",
        "biscuit": "Biscuit Ekmeği",
        "croissant": "Kruvasan",
        "english muffin": "English Muffin",
        "griddle pancake": "Pankek",
        "griddle pancake": "Pankek",
    }
    if value in exact:
        return exact[value]
    return translate_generic_text(text)


def translate_survey_description(description: str) -> str | None:
    text = description.strip().lower()

    if text == "breakfast pizza with egg":
        return "Yumurtalı Kahvaltı Pizzası"

    match = re.match(
        r"^pizza with (.+?)(?:, (thin|thick|medium|stuffed) crust)?$",
        text,
    )
    if match:
        modifiers = translate_modifier_phrase(match.group(1))
        crust = {
            "thin": "İnce Hamur",
            "thick": "Kalın Hamur",
            "medium": "Orta Hamur",
            "stuffed": "Kenarı Dolgulu",
        }.get(match.group(2) or "")
        suffix = f" ({crust})" if crust else ""
        return f"{modifiers} Pizza{suffix}"

    if text == "chili, white":
        return "Beyaz Chili"

    match = re.match(r"^chili with (.+?)(?:, canned)?$", text)
    if match:
        modifiers = translate_modifier_phrase(match.group(1))
        suffix = " (Konserve)" if text.endswith(", canned") else ""
        return f"{modifiers} Chili{suffix}"

    if text.startswith("egg omelet or scrambled egg"):
        modifiers = []
        if "with cheese" in text:
            modifiers.append("Peynirli")
        if "tomatoes" in text:
            modifiers.append("Domatesli")
        if "vegetables" in text:
            modifiers.append("Sebzeli")
        note = ""
        if "no added fat" in text:
            note = " (Yağ Eklenmemiş)"
        elif "fat added" in text:
            note = " (Yağ Eklenmiş)"
        prefix = " ".join(dict.fromkeys(modifiers))
        base = "Omlet veya Çırpılmış Yumurta"
        return f"{prefix} {base}{note}".strip()

    match = re.match(r"^egg roll, with (.+)$", text)
    if match:
        modifiers = translate_modifier_phrase(match.group(1))
        return f"{modifiers} Çin Böreği"
    if text == "egg roll, meatless":
        return "Etsiz Çin Böreği"

    match = re.match(r"^egg salad, made with (.+)$", text)
    if match:
        dressing = translate_generic_text(match.group(1))
        return f"{dressing} Yumurta Salatası"

    match = re.match(r"^egg salad sandwich on (.+)$", text)
    if match:
        carrier = translate_carrier(match.group(1))
        return f"{carrier} Üzerinde Yumurta Salatalı Sandviç"

    match = re.match(r"^egg sandwich on (.+?)(?:, with (.+))?$", text)
    if match:
        carrier = translate_carrier(match.group(1))
        modifiers = match.group(2)
        prefix = (
            f"{translate_modifier_phrase(modifiers)} "
            if modifiers
            else ""
        )
        return f"{prefix}{carrier} Üzerinde Yumurtalı Sandviç".strip()

    return None


def translate_display_name(description: str) -> str:
    survey_translation = translate_survey_description(description)
    if survey_translation:
        return survey_translation
    return translate_generic_text(description)


def extract_nutrients(food: dict) -> dict | None:
    nutrients = food.get("foodNutrients") or []
    kcal = protein = carb = fat = None
    for item in nutrients:
        nutrient = item.get("nutrient") or {}
        number = str(nutrient.get("number") or "")
        name = str(nutrient.get("name") or "").lower()
        unit = str(nutrient.get("unitName") or "").lower()
        amount = item.get("amount")
        if amount is None:
            continue
        amount = float(amount)
        if (
            number in ENERGY_NUMBERS
            or ("energy" in name and "kcal" in unit)
            or name == "energy"
        ):
            if "kj" not in unit:
                kcal = amount
        elif number in PROTEIN_NUMBERS or name == "protein":
            protein = amount
        elif number in CARB_NUMBERS or "carbohydrate, by difference" == name:
            carb = amount
        elif number in FAT_NUMBERS or name == "total lipid (fat)":
            fat = amount
    if None in (kcal, protein, carb, fat):
        return None
    return {
        "kcal": round(kcal),
        "protein": round(protein, 1),
        "carb": round(carb, 1),
        "fat": round(fat, 1),
    }


def infer_category(name: str, source_category: str) -> str:
    text = normalize_text(f"{name} {source_category}")
    if any(token in text for token in ["milk", "yogurt", "cheese", "kefir", "dairy"]):
        return "Süt Ürünleri"
    if any(token in text for token in ["egg", "omelet"]):
        return "Kahvaltılık"
    if any(token in text for token in ["chicken", "beef", "turkey", "lamb", "meat", "fish", "salmon", "tuna", "shrimp"]):
        return "Et / Protein"
    if any(token in text for token in ["apple", "banana", "orange", "grape", "berry", "fruit", "melon", "kiwi"]):
        return "Meyve"
    if any(token in text for token in ["tomato", "cucumber", "broccoli", "spinach", "carrot", "pepper", "onion", "vegetable", "lettuce", "potato"]):
        return "Sebze"
    if any(token in text for token in ["rice", "oat", "bulgur", "bread", "pasta", "grain", "cereal"]):
        return "Tahıl"
    if any(token in text for token in ["coffee", "tea", "drink", "beverage", "juice"]):
        return "İçecek"
    if any(token in text for token in ["baklava", "dessert", "cookie", "cake", "ice cream", "sweet"]):
        return "Tatlı"
    if any(token in text for token in ["hamburger", "pizza", "fries", "sandwich", "gyro"]):
        return "Fast Food"
    return "Yemek"


def infer_servings(name: str, category: str) -> list[dict]:
    text = normalize_text(f"{name} {category}")
    servings = [{"id": "s_100g", "label": "100 g", "grams": 100, "isDefault": True}]
    if any(token in text for token in ["egg", "omelet", "sandwich", "hamburger", "baklava"]):
        servings.append({"id": "s_piece", "label": "1 Adet", "grams": 60, "isDefault": False})
    if any(token in text for token in ["soup", "pilaf", "pasta", "rice", "meal", "gyro"]):
        servings.append({"id": "s_portion", "label": "1 Porsiyon", "grams": 180, "isDefault": False})
    if any(token in text for token in ["coffee", "tea", "milk", "juice", "kefir", "yogurt"]):
        servings.append({"id": "s_glass", "label": "1 Bardak", "grams": 200, "isDefault": False})
    return servings


def build_tags(name: str, aliases: list[str], category: str) -> list[str]:
    tags = set()
    for chunk in [name, category, *aliases]:
        normalized = normalize_text(chunk)
        if not normalized:
            continue
        tags.update(normalized.split())
    return sorted(tags)


def slug_id(prefix: str, fdc_id: int) -> str:
    return f"{prefix}_{fdc_id}"


def apply_override(source_key: str, food: dict) -> dict | None:
    description = food.get("description", "")
    for rule in OVERRIDES:
        if rule["source"] == source_key and description == rule["match"]:
            return rule
    return None


def source_category(food: dict) -> str:
    category = food.get("foodCategory")
    if isinstance(category, dict):
        return str(category.get("description") or "")
    survey_category = food.get("wweiaFoodCategory")
    if isinstance(survey_category, dict):
        return str(survey_category.get("wweiaFoodCategoryDescription") or "")
    return ""


def should_keep_survey_food(food: dict) -> bool:
    description = normalize_text(food.get("description", ""))
    if any(
        rule["source"] == "survey" and description == normalize_text(rule["match"])
        for rule in OVERRIDES
    ):
        return True
    return not any(pattern in description for pattern in SURVEY_EXCLUDE_PATTERNS)


def to_entry(source_key: str, food: dict, override: dict | None) -> dict | None:
    nutrients = extract_nutrients(food)
    if nutrients is None:
        return None
    description = str(food.get("description") or "").strip()
    display_name = override["name"] if override else translate_display_name(description)
    category = override["category"] if override else infer_category(
        display_name,
        source_category(food),
    )
    aliases = []
    if override:
        aliases.extend(override.get("aliases") or [])
        aliases.append(description)
    elif display_name != description:
        aliases.append(description)
    source_label = {
        "foundation": "USDA Foundation Foods",
        "survey": "USDA Survey Foods (FNDDS)",
        "sr": "USDA SR Legacy",
    }[source_key]
    return {
        "id": slug_id(source_key, int(food["fdcId"])),
        "name": display_name,
        "category": category,
        "basis": {"amount": 100, "unit": "g"},
        "nutrientsPerBasis": {
            "kcal": nutrients["kcal"],
            "protein": nutrients["protein"],
            "carb": nutrients["carb"],
            "fat": nutrients["fat"],
        },
        "servings": infer_servings(display_name, category),
        "aliases": sorted({alias.strip() for alias in aliases if alias.strip()}),
        "tags": build_tags(display_name, aliases, category),
        "brand": None,
        "barcode": None,
        "imageUrl": None,
        "source": source_label,
        "sourceDescription": description,
        "fdcId": food["fdcId"],
    }


def macro_kcal_delta(entry: dict) -> float:
    nutrients = entry["nutrientsPerBasis"]
    derived = (
        float(nutrients["protein"]) * 4
        + float(nutrients["carb"]) * 4
        + float(nutrients["fat"]) * 9
    )
    return abs(float(nutrients["kcal"]) - derived)


def build_catalog() -> list[dict]:
    foundation = load_dataset(FOUNDATION_ZIP)
    survey = load_dataset(SURVEY_ZIP)
    sr = load_dataset(SR_ZIP)

    entries = []
    seen_ids = set()

    for food in foundation:
        entry = to_entry("foundation", food, apply_override("foundation", food))
        if entry and entry["id"] not in seen_ids:
            seen_ids.add(entry["id"])
            entries.append(entry)

    for food in survey:
        if not should_keep_survey_food(food):
            continue
        entry = to_entry("survey", food, apply_override("survey", food))
        if entry and entry["id"] not in seen_ids:
            seen_ids.add(entry["id"])
            entries.append(entry)

    sr_matches = {rule["match"] for rule in OVERRIDES if rule["source"] == "sr"}
    for food in sr:
        if food.get("description") not in sr_matches:
            continue
        entry = to_entry("sr", food, apply_override("sr", food))
        if entry and entry["id"] not in seen_ids:
            seen_ids.add(entry["id"])
            entries.append(entry)

    entries.sort(key=lambda item: normalize_text(item["name"]))
    override_names = {rule["name"] for rule in OVERRIDES}
    return [
        entry
        for entry in entries
        if entry["name"] in override_names
        or macro_kcal_delta(entry) <= MAX_MACRO_KCAL_DIFF
    ]


def main() -> None:
    missing = [path for path in [FOUNDATION_ZIP, SURVEY_ZIP, SR_ZIP] if not path.exists()]
    if missing:
        raise SystemExit(
            "Missing USDA dataset zip(s):\n- " + "\n- ".join(str(path) for path in missing)
        )

    foods = build_catalog()
    payload = {
        "schemaVersion": 3,
        "locale": "tr-TR",
        "foods": foods,
    }
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(foods)} verified USDA-backed foods to {OUT_PATH}")


if __name__ == "__main__":
    main()
