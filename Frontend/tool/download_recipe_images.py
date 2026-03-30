#!/usr/bin/env python3
"""Download recipe images from Wikimedia Commons and wire them into recipes_tr.json.

The script searches Commons for each recipe using translated keywords, downloads
the best thumbnail match, and stores license/source metadata separately.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
from urllib.error import HTTPError
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path


COMMONS_API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "FitnessAppRecipeImageImporter/1.0"
SUPPORTED_EXTENSIONS = (".jpg", ".jpeg", ".webp")
BANNED_WORDS = {
    "logo",
    "icon",
    "drawing",
    "illustration",
    "vector",
    "map",
    "flag",
    "packaging",
    "label",
    "advertisement",
    "poster",
    "dessert",
    "baklava",
    "kunefe",
    "cake",
    "cookie",
    "candy",
}

RAW_TOKEN_TRANSLATIONS = {
    "yüksek": "high",
    "yuksek": "high",
    "protein": "protein",
    "buddha": "buddha",
    "akdeniz": "mediterranean",
    "humus": "hummus",
    "smoothie": "smoothie",
    "dondurulmus": "frozen",
    "ton": "tuna",
    "balığı": "tuna",
    "balikli": "tuna",
    "balık": "fish",
    "poke": "poke",
    "fırın": "baked",
    "firin": "baked",
    "sarimsakli": "garlic",
    "sarımsaklı": "garlic",
    "somon": "salmon",
    "kırmızı": "red",
    "mercimek": "lentil",
    "çorbası": "soup",
    "corbasi": "soup",
    "corbasi": "soup",
    "baharatlı": "spiced",
    "baharatli": "spiced",
    "tavuk": "chicken",
    "gogsu": "breast",
    "sote": "saute",
    "sebzeli": "vegetable",
    "sebze": "vegetable",
    "kinoa": "quinoa",
    "pilav": "pilaf",
    "salatası": "salad",
    "salatasi": "salad",
    "salata": "salad",
    "narlı": "pomegranate",
    "narli": "pomegranate",
    "keçi": "goat",
    "keci": "goat",
    "peynirli": "cheese",
    "peyniri": "cheese",
    "roka": "arugula",
    "yeşil": "green",
    "yesil": "green",
    "detoks": "detox",
    "muz": "banana",
    "shake": "shake",
    "topları": "balls",
    "toplari": "balls",
    "avokado": "avocado",
    "tam": "whole",
    "tahıllı": "grain",
    "tahilli": "grain",
    "toast": "toast",
    "tost": "toast",
    "yulaf": "oat",
    "ezmesi": "oatmeal",
    "lapası": "porridge",
    "lapasi": "porridge",
    "yoğurtlu": "yogurt",
    "yogurtlu": "yogurt",
    "yoğurt": "yogurt",
    "yogurt": "yogurt",
    "marine": "marinated",
    "bulgur": "bulgur",
    "kasesi": "bowl",
    "kase": "bowl",
    "izgara": "grilled",
    "köfte": "meatball",
    "kofte": "meatball",
    "hindi": "turkey",
    "güveç": "stew",
    "guvec": "stew",
    "levrek": "sea bass",
    "haşlanmış": "boiled",
    "haslanmis": "boiled",
    "brokoli": "broccoli",
    "lor": "cottage cheese",
    "ıspanaklı": "spinach",
    "ispanakli": "spinach",
    "omlet": "omelette",
    "nohutlu": "chickpea",
    "nohut": "chickpea",
    "kavurma": "saute",
    "dolgulu": "stuffed",
    "biber": "pepper",
    "yumurtalı": "egg",
    "yumurtali": "egg",
    "yumurta": "egg",
    "süzme": "greek",
    "suzme": "greek",
    "çilek": "strawberry",
    "cilek": "strawberry",
    "fıstık": "peanut",
    "fistik": "peanut",
    "ezmesi": "butter",
    "taze": "fresh",
    "sebze": "vegetable",
    "kefir": "kefir",
    "yaban": "blueberry",
    "mersini": "blueberry",
    "salatalik": "cucumber",
    "ceviz": "walnut",
    "domates": "tomato",
    "karnabahar": "cauliflower",
    "pirinç": "rice",
    "pirinc": "rice",
    "sade": "plain",
    "hurma": "date",
    "fındık": "hazelnut",
    "findik": "hazelnut",
    "makarna": "pasta",
    "ev": "homemade",
    "yapımı": "homemade",
    "yapimi": "homemade",
    "granola": "granola",
    "bar": "bar",
    "meyve": "fruit",
    "parfait": "parfait",
    "katmanlı": "layered",
    "katmanli": "layered",
    "kuru": "dried",
    "pirinç": "rice",
    "keki": "cake",
    "süt": "milk",
    "sut": "milk",
    "kepekli": "whole wheat",
    "ekmek": "bread",
    "elma": "apple",
    "badem": "almond",
    "klasik": "classic",
    "post": "post workout",
    "workout": "workout",
    "hızlı": "quick",
    "hizli": "quick",
    "ızgara": "grilled",
    "izgara": "grilled",
    "kiyma": "ground beef",
    "kıyma": "ground beef",
    "hafif": "light",
    "yağlı": "fat",
    "yagli": "fat",
}

RAW_PHRASE_TRANSLATIONS = {
    "yuksek protein": "high protein",
    "protein shake": "protein shake",
    "yulaf ezmesi": "oatmeal",
    "fistik ezmesi": "peanut butter",
    "suzme yogurt": "greek yogurt",
    "tam bugday": "whole wheat",
    "tam tahilli": "whole grain",
    "kirmizi mercimek corbasi": "red lentil soup",
    "dusuk yag": "low fat",
    "az yagli": "low fat",
    "ton baligi": "tuna",
    "ton balikli": "tuna",
    "tuna baligi": "tuna",
    "keci peyniri": "goat cheese",
    "lor peyniri": "cottage cheese",
    "muzlu": "banana",
    "yogurtlu": "yogurt",
    "firin tavuk": "baked chicken",
    "firin somon": "baked salmon",
    "izgara tavuk": "grilled chicken",
    "izgara kofte": "grilled meatballs",
    "kabak dolmasi": "stuffed zucchini",
    "muzlu yulaf lapasi": "banana oatmeal",
    "tam bugday ekmek": "whole wheat bread",
    "pirinc keki": "rice cake",
    "protein bar": "protein bar",
    "enerji toplari": "energy balls",
    "mercimek corbasi": "lentil soup",
    "haslanmis patates": "boiled potatoes",
    "meyve yogurt parfait": "fruit yogurt parfait",
}

CATEGORY_TERMS = {
    "bowl": ["bowl meal"],
    "ana_yemek": [],
    "salata": ["salad"],
    "smoothie": ["smoothie drink", "healthy smoothie"],
    "atistirmalik": ["healthy snack"],
}
QUERY_STOPWORDS = {
    "high",
    "protein",
    "healthy",
    "light",
    "quick",
    "classic",
    "homemade",
    "portion",
    "kontrollu",
}
GENERIC_QUERY_TOKENS = {
    "bowl",
    "salad",
    "smoothie",
    "shake",
    "dish",
    "meal",
    "food",
    "healthy",
    "main",
    "drink",
    "snack",
    "protein",
}
IGNORED_INGREDIENT_TOKENS = {
    "g",
    "kg",
    "ml",
    "l",
    "adet",
    "yarim",
    "orta",
    "buyuk",
    "kucuk",
    "boy",
    "su",
    "yemek",
    "kasigi",
    "tatli",
    "cay",
    "bardak",
    "kase",
    "parca",
    "parcalari",
}


def normalize_text(value: str) -> str:
    replacements = str.maketrans(
        {
            "ı": "i",
            "İ": "i",
            "ğ": "g",
            "Ğ": "g",
            "ü": "u",
            "Ü": "u",
            "ş": "s",
            "Ş": "s",
            "ö": "o",
            "Ö": "o",
            "ç": "c",
            "Ç": "c",
        }
    )
    value = value.translate(replacements)
    value = (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


TOKEN_TRANSLATIONS = {
    normalize_text(key): value for key, value in RAW_TOKEN_TRANSLATIONS.items()
}
PHRASE_TRANSLATIONS = {
    normalize_text(key): value for key, value in RAW_PHRASE_TRANSLATIONS.items()
}


def split_tokens(text: str) -> list[str]:
    return [token for token in normalize_text(text).split() if token]


def translate_text(text: str) -> str:
    normalized = normalize_text(text)
    for phrase, replacement in sorted(
        PHRASE_TRANSLATIONS.items(),
        key=lambda item: len(item[0]),
        reverse=True,
    ):
        normalized = normalized.replace(phrase, replacement)
    tokens = normalized.split()
    translated = [TOKEN_TRANSLATIONS.get(token, token) for token in tokens]
    return " ".join(part for part in translated if part)


def category_fallback(recipe: dict) -> str:
    fallbacks = CATEGORY_TERMS.get(recipe.get("category", ""), ["healthy food"])
    return fallbacks[0] if fallbacks else ""


def strong_keywords(recipe: dict) -> list[str]:
    keywords: list[str] = []
    keywords.extend(split_tokens(translate_text(recipe["name"])))
    for ingredient in recipe.get("ingredients", [])[:4]:
      keywords.extend(split_tokens(translate_text(ingredient.get("name", ""))))
    deduped: list[str] = []
    for keyword in keywords:
        if keyword.isdigit():
            continue
        if keyword in IGNORED_INGREDIENT_TOKENS:
            continue
        if keyword not in deduped and keyword not in {"healthy", "food"}:
            deduped.append(keyword)
    return deduped[:8]


def build_queries(recipe: dict) -> list[str]:
    name_query = translate_text(recipe["name"])
    name_tokens = split_tokens(name_query)
    reduced_name = " ".join(
        token for token in name_tokens if token not in QUERY_STOPWORDS
    )
    ingredient_only = [
        token
        for token in strong_keywords(recipe)
        if token not in name_tokens and token not in QUERY_STOPWORDS
    ]
    ingredient_query = " ".join(ingredient_only[:3])
    fallbacks = CATEGORY_TERMS.get(recipe.get("category", ""), [])
    queries = [
        name_query,
        reduced_name,
        f"{reduced_name} {ingredient_query}".strip(),
        f"{ingredient_query} {category_fallback(recipe)}".strip(),
        f"{ingredient_query} healthy food".strip(),
        *fallbacks,
    ]
    deduped: list[str] = []
    for query in queries:
        query = normalize_text(query)
        if query and query not in deduped:
            deduped.append(query)
    return deduped


@dataclass
class Candidate:
    title: str
    description_url: str
    image_url: str
    source_url: str
    license_name: str
    license_url: str
    artist: str
    description: str
    categories: list[str]
    score: float


def commons_api(params: dict[str, str]) -> dict:
    query = urllib.parse.urlencode(params)
    request = urllib.request.Request(
        f"{COMMONS_API}?{query}",
        headers={"User-Agent": USER_AGENT},
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            if exc.code != 429 or attempt == 3:
                raise
            time.sleep(15.0 * (attempt + 1))
    raise RuntimeError("Unreachable")


def pick_image_url(image_info: dict) -> str | None:
    return (
        image_info.get("thumburl")
        or image_info.get("url")
        or image_info.get("descriptionurl")
    )


def extract_meta_value(metadata: dict, key: str) -> str:
    value = metadata.get(key, {})
    if isinstance(value, dict):
        return str(value.get("value", "")).strip()
    return ""


def score_candidate(
    recipe: dict,
    candidate_text: str,
    query_tokens: set[str],
    recipe_keywords: set[str],
) -> float:
    score = 0.0
    overlap_tokens = {token for token in query_tokens if token in candidate_text}
    specific_overlap = overlap_tokens - GENERIC_QUERY_TOKENS
    keyword_overlap = {
        token
        for token in recipe_keywords
        if token not in GENERIC_QUERY_TOKENS and token in candidate_text
    }

    if not specific_overlap and not keyword_overlap:
        return -50.0

    score += len(overlap_tokens) * 3.0
    score += len(specific_overlap) * 5.0
    score += len(keyword_overlap) * 4.0

    recipe_category = recipe.get("category", "")
    if recipe_category == "bowl" and "bowl" in candidate_text:
        score += 6
    if recipe_category == "salata" and "salad" in candidate_text:
        score += 6
    if recipe_category == "smoothie" and ("smoothie" in candidate_text or "shake" in candidate_text):
        score += 6
    if "soup" in candidate_text and "corba" in normalize_text(recipe["name"]):
        score += 6
    if "omelette" in candidate_text and "omlet" in normalize_text(recipe["name"]):
        score += 6
    if "toast" in candidate_text and ("toast" in normalize_text(recipe["name"]) or "tost" in normalize_text(recipe["name"])):
        score += 6

    if any(word in candidate_text for word in BANNED_WORDS):
        score -= 25
    if "food" in candidate_text or "dish" in candidate_text or "meal" in candidate_text:
        score += 1.5

    return score


def search_candidates(recipe: dict, query: str) -> list[Candidate]:
    response = commons_api(
        {
            "action": "query",
            "generator": "search",
            "gsrsearch": query,
            "gsrnamespace": "6",
            "gsrlimit": "8",
            "prop": "imageinfo|categories|info",
            "cllimit": "max",
            "inprop": "url",
            "iiprop": "url|extmetadata",
            "iiurlwidth": "1200",
            "format": "json",
        }
    )
    pages = response.get("query", {}).get("pages", {})
    query_tokens = set(split_tokens(query))
    recipe_keywords = set(strong_keywords(recipe))
    candidates: list[Candidate] = []
    for page in pages.values():
        title = str(page.get("title", ""))
        title_lower = title.lower()
        if not title_lower.endswith(SUPPORTED_EXTENSIONS):
            continue
        image_info = (page.get("imageinfo") or [{}])[0]
        image_url = pick_image_url(image_info)
        if not image_url:
            continue
        metadata = image_info.get("extmetadata", {})
        categories = [str(cat.get("title", "")) for cat in page.get("categories", [])]
        candidate_text = normalize_text(
            " ".join(
                [
                    title,
                    extract_meta_value(metadata, "ImageDescription"),
                    " ".join(categories),
                ]
            )
        )
        score = score_candidate(recipe, candidate_text, query_tokens, recipe_keywords)
        candidates.append(
            Candidate(
                title=title,
                description_url=str(image_info.get("descriptionurl", "")),
                image_url=str(image_url),
                source_url=str(page.get("fullurl", "")),
                license_name=extract_meta_value(metadata, "LicenseShortName"),
                license_url=extract_meta_value(metadata, "LicenseUrl"),
                artist=extract_meta_value(metadata, "Artist"),
                description=extract_meta_value(metadata, "ImageDescription"),
                categories=categories,
                score=score,
            )
        )
    candidates.sort(key=lambda item: item.score, reverse=True)
    return candidates


def best_candidate(recipe: dict) -> tuple[Candidate | None, str | None]:
    for query in build_queries(recipe):
        candidates = search_candidates(recipe, query)
        if candidates and candidates[0].score > 0:
            return candidates[0], query
    return None, None


def download_binary(url: str, output_path: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                output_path.write_bytes(response.read())
                return
        except HTTPError as exc:
            if exc.code != 429 or attempt == 3:
                raise
            time.sleep(20.0 * (attempt + 1))


def file_extension_from_url(url: str) -> str:
    path = urllib.parse.urlparse(url).path.lower()
    for extension in SUPPORTED_EXTENSIONS:
        if path.endswith(extension):
            return ".jpg" if extension in {".jpeg", ".jpg"} else extension
    return ".jpg"


def persist_state(recipes_path: Path, metadata_path: Path, recipes: list[dict], metadata: dict) -> None:
    recipes_path.write_text(
        json.dumps(recipes, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    metadata_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def update_recipe_image_assets(
    recipes_path: Path,
    image_dir: Path,
    metadata_path: Path,
    pause: float,
    limit: int | None,
    match: str | None,
    overwrite: bool,
) -> int:
    recipes = json.loads(recipes_path.read_text(encoding="utf-8"))
    image_dir.mkdir(parents=True, exist_ok=True)
    metadata = {}
    if metadata_path.exists():
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    updated = 0

    for recipe in recipes:
        normalized_id = normalize_text(recipe["id"])
        if match and match not in normalized_id and match not in normalize_text(recipe["name"]):
            continue
        if not overwrite and str(recipe.get("imageAsset", "")).strip():
            continue

        try:
            candidate, query = best_candidate(recipe)
            if candidate is None:
                print(f"[warn] no image found for {recipe['id']} | {recipe['name']}", file=sys.stderr)
                continue

            extension = file_extension_from_url(candidate.image_url)
            filename = f"{recipe['id']}{extension}"
            output_path = image_dir / filename
            download_binary(candidate.image_url, output_path)
            recipe["imageAsset"] = f"assets/recipes/images/{filename}"
            metadata[recipe["id"]] = {
                "name": recipe["name"],
                "query": query,
                "asset": recipe["imageAsset"],
                "title": candidate.title,
                "imageUrl": candidate.image_url,
                "descriptionUrl": candidate.description_url,
                "sourceUrl": candidate.source_url,
                "licenseName": candidate.license_name,
                "licenseUrl": candidate.license_url,
                "artist": candidate.artist,
            }
            persist_state(recipes_path, metadata_path, recipes, metadata)
            updated += 1
            print(f"[ok] {recipe['id']} <= {candidate.title} ({query})")
            if limit is not None and updated >= limit:
                break
            time.sleep(pause)
        except Exception as exc:  # pragma: no cover - defensive batch behavior
            print(
                f"[warn] skipped {recipe['id']} | {recipe['name']} | {exc}",
                file=sys.stderr,
            )
            continue
    return updated


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--recipes",
        default="frontend/assets/recipes/recipes_tr.json",
    )
    parser.add_argument(
        "--image-dir",
        default="frontend/assets/recipes/images",
    )
    parser.add_argument(
        "--metadata",
        default="frontend/assets/recipes/image_sources.json",
    )
    parser.add_argument(
        "--pause",
        type=float,
        default=0.2,
    )
    parser.add_argument(
        "--limit",
        type=int,
    )
    parser.add_argument(
        "--match",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
    )
    args = parser.parse_args()

    updated = update_recipe_image_assets(
        recipes_path=Path(args.recipes),
        image_dir=Path(args.image_dir),
        metadata_path=Path(args.metadata),
        pause=args.pause,
        limit=args.limit,
        match=normalize_text(args.match) if args.match else None,
        overwrite=args.overwrite,
    )
    print(f"Updated {updated} recipe images.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
