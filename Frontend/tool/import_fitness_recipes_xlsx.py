#!/usr/bin/env python3

import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "p": "http://schemas.openxmlformats.org/package/2006/relationships",
}


def normalize(text: str) -> str:
    return (
        text.lower()
        .replace("ı", "i")
        .replace("ğ", "g")
        .replace("ü", "u")
        .replace("ş", "s")
        .replace("ö", "o")
        .replace("ç", "c")
    )


def read_sheet_rows(xlsx_path: Path):
    with zipfile.ZipFile(xlsx_path) as zf:
        shared = []
        if "xl/sharedStrings.xml" in zf.namelist():
            root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
            for si in root.findall("a:si", NS):
                shared.append("".join(t.text or "" for t in si.findall(".//a:t", NS)))

        workbook = ET.fromstring(zf.read("xl/workbook.xml"))
        rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
        rel_map = {
            rel.attrib["Id"]: rel.attrib["Target"]
            for rel in rels.findall("p:Relationship", NS)
        }

        first_sheet = workbook.find("a:sheets/a:sheet", NS)
        rid = first_sheet.attrib[
            "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
        ]
        target = rel_map[rid].lstrip("/")
        if not target.startswith("xl/"):
            target = "xl/" + target

        sheet_root = ET.fromstring(zf.read(target))
        rows = []
        for row in sheet_root.findall("a:sheetData/a:row", NS):
            values = []
            for cell in row.findall("a:c", NS):
                cell_type = cell.attrib.get("t")
                value_node = cell.find("a:v", NS)
                inline_node = cell.find("a:is", NS)
                if cell_type == "s" and value_node is not None:
                    value = shared[int(value_node.text)]
                elif cell_type == "inlineStr" and inline_node is not None:
                    value = "".join(
                        txt.text or "" for txt in inline_node.findall(".//a:t", NS)
                    )
                elif value_node is not None:
                    value = value_node.text or ""
                else:
                    value = ""
                values.append(value)
            rows.append(values)
        return rows


UNIT_DISPLAY = {
    "yemek kasigi": "yemek kaşığı",
    "tatli kasigi": "tatlı kaşığı",
    "cay kasigi": "çay kaşığı",
    "su bardagi": "su bardağı",
    "kg": "kg",
    "g": "g",
    "ml": "ml",
    "l": "l",
    "litre": "litre",
    "adet": "adet",
    "dis": "diş",
}


def infer_category(name: str) -> str:
    value = normalize(name)
    if any(token in value for token in ["tavuk", "hindi", "levrek", "somon", "ton bal", "dana", "kofte", "kıyma", "kiyma", "balik", "balık"]):
        return "et"
    if any(token in value for token in ["yogurt", "yoğurt", "lor", "peynir", "sut", "süt", "kefir"]):
        return "süt ürünleri"
    if any(token in value for token in ["nohut", "mercimek", "humus", "fasulye"]):
        return "baklagil"
    if any(token in value for token in ["yulaf", "bulgur", "pirinc", "pirinç", "granola", "tam bugday", "tam buğday", "quinoa", "kinoa"]):
        return "tahıl"
    if any(token in value for token in ["zeytinyagi", "zeytinyağı", "fistik ezmesi", "fıstık ezmesi", "avokado", "ceviz", "badem"]):
        return "yağ/sos"
    if any(token in value for token in ["baharat", "tuz", "karabiber", "kimyon", "kekik", "pul biber", "tarcin", "tarçın"]):
        return "baharat"
    return "sebze/meyve"


def parse_ingredient(raw: str):
    item = raw.strip(" .")
    if not item:
        return None
    compact = normalize(item)
    for unit, display_unit in UNIT_DISPLAY.items():
        pattern = rf"^(\d+(?:[.,]\d+)?)\s*{re.escape(unit)}\s+(.+)$"
        match = re.match(pattern, compact)
        if match:
            amount = float(match.group(1).replace(",", "."))
            name = item[len(match.group(1)) :].strip()
            name = re.sub(
                rf"^{re.escape(display_unit)}\s*",
                "",
                name,
                flags=re.IGNORECASE,
            )
            if name == item:
                normalized_name = re.sub(
                    rf"^{re.escape(unit)}\s*",
                    "",
                    compact,
                    flags=re.IGNORECASE,
                ).strip()
                name = normalized_name
            return {
                "name": name.strip(),
                "amount": amount,
                "unit": display_unit,
                "category": infer_category(name),
            }
    if re.match(r"^\d+(?:[.,]\d+)?\s+", compact):
        amount_text, remainder = item.split(" ", 1)
        return {
            "name": remainder.strip(),
            "amount": float(amount_text.replace(",", ".")),
            "unit": "adet",
            "category": infer_category(remainder),
        }
    return {
        "name": item,
        "amount": 1,
        "unit": "tutam" if "," in item else "adet",
        "category": infer_category(item),
    }


def parse_ingredients(blob: str):
    parts = [part.strip() for part in blob.split("·")]
    parsed = []
    for part in parts:
        ingredient = parse_ingredient(part)
        if ingredient:
            parsed.append(ingredient)
    return parsed


def parse_steps(blob: str):
    cleaned = blob.replace("\n", " ").strip()
    split = [part.strip(" .") for part in re.split(r"\s*\d+\)\s*", cleaned) if part.strip()]
    return [step + "." if not step.endswith(".") else step for step in split]


def map_recipe_category(source_category: str, name: str):
    normalized_name = normalize(name)
    source = normalize(source_category)
    if "shake" in normalized_name or "smoothie" in normalized_name:
        return "smoothie"
    if "salata" in normalized_name:
        return "salata"
    if "smoothie" in normalized_name:
        return "smoothie"
    if "bowl" in normalized_name or "kase" in normalized_name or "kasesi" in normalized_name:
        return "bowl"
    if "ana ogun" in source:
        return "ana_yemek"
    if "post workout" in source or "pre workout" in source:
        return "atistirmalik" if "smoothie" not in normalized_name else "smoothie"
    if "hafif ara ogun" in source:
        return "atistirmalik"
    return "ana_yemek"


def split_time(total_minutes: int, recipe_category: str, steps: list[str]):
    normalized_steps = normalize(" ".join(steps))
    has_cooking = any(
        token in normalized_steps
        for token in ["firin", "ızgara", "izgara", "pisir", "pişir", "kavur", "hasla", "haşla", "tava", "ocak", "blender"]
    )
    if recipe_category in {"smoothie", "salata"} and not has_cooking:
        return total_minutes, 0
    if recipe_category == "bowl" and not has_cooking:
        return total_minutes, 0
    if total_minutes <= 10 and not has_cooking:
        return total_minutes, 0
    cook = max(5, round(total_minutes * 0.6))
    prep = max(3, total_minutes - cook)
    if prep + cook != total_minutes:
        cook = total_minutes - prep
    return prep, cook


def emoji_for(name: str, recipe_category: str):
    normalized_name = normalize(name)
    if "smoothie" in normalized_name:
        return "🥤"
    if "somon" in normalized_name or "levrek" in normalized_name or "balik" in normalized_name or "balık" in normalized_name:
        return "🐟"
    if "tavuk" in normalized_name or "hindi" in normalized_name:
        return "🍗"
    if "kofte" in normalized_name:
        return "🍖"
    if "omlet" in normalized_name or "yumurta" in normalized_name:
        return "🍳"
    if "salata" in normalized_name:
        return "🥗"
    if "corba" in normalized_name or "çorba" in normalized_name:
        return "🍲"
    if "bowl" in normalized_name or "kase" in normalized_name:
        return "🥣"
    if recipe_category == "atistirmalik":
        return "⚡"
    return "🍽️"


def description_for(name: str, goal: str, meal: str, recipe_category: str):
    category_text = {
        "bowl": "dengeli bir bowl",
        "ana_yemek": "yüksek proteinli bir ana öğün",
        "salata": "hafif ama doyurucu bir salata",
        "smoothie": "pratik bir smoothie",
        "atistirmalik": "kontrollü bir ara öğün",
    }[recipe_category]
    goal_text = goal.replace("/", " / ").lower()
    meal_text = meal.replace("/", " / ").lower()
    return f"{name}, {goal_text} hedeflerine uygun {category_text} olarak {meal_text} için hazırlandı."


def tags_for(goal: str, meal: str, recipe_category: str, protein: float, carb: float, total_minutes: int):
    tags = []
    for token in re.split(r"[/,]", goal):
        normalized = token.strip().lower()
        if normalized:
            tags.append(normalized)
    for token in re.split(r"[/,]", meal):
        normalized = token.strip().lower()
        if normalized:
            tags.append(normalized)
    if protein >= 25:
        tags.append("yüksek protein")
    if carb <= 15:
        tags.append("düşük karb")
    if total_minutes <= 10:
        tags.append("hızlı")
    if "sabah" in normalize(meal):
        tags.append("kahvaltılık")
    if "post-workout" in meal.lower():
        tags.append("antrenman sonrası")
    if "pre-workout" in meal.lower():
        tags.append("antrenman öncesi")
    if recipe_category == "bowl":
        tags.append("bowl")
    return list(dict.fromkeys(tags))


def convert_row(row_index: int, row: list[str]):
    _, name, goal, source_category, meal, total_time, ingredients_blob, steps_blob, kcal, protein, carb, fat = row[:12]
    recipe_category = map_recipe_category(source_category, name)
    ingredients = parse_ingredients(ingredients_blob)
    steps = parse_steps(steps_blob)
    total_minutes = int(float(total_time))
    prep_time, cook_time = split_time(total_minutes, recipe_category, steps)
    protein_val = float(protein)
    carb_val = float(carb)
    return {
        "id": f"xlsx_{row_index:03d}",
        "name": name,
        "description": description_for(name, goal, meal, recipe_category),
        "category": recipe_category,
        "servings": 1,
        "prepTimeMinutes": prep_time,
        "cookTimeMinutes": cook_time,
        "imageEmoji": emoji_for(name, recipe_category),
        "kcalPerServing": float(kcal),
        "proteinPerServing": protein_val,
        "carbPerServing": carb_val,
        "fatPerServing": float(fat),
        "tags": tags_for(goal, meal, recipe_category, protein_val, carb_val, total_minutes),
        "difficulty": "kolay" if total_minutes <= 15 else "orta" if total_minutes <= 30 else "zor",
        "ingredients": ingredients,
        "steps": steps,
    }


def main():
    if len(sys.argv) != 3:
        print("Usage: import_fitness_recipes_xlsx.py <xlsx_path> <recipes_json_path>")
        raise SystemExit(1)

    xlsx_path = Path(sys.argv[1])
    recipes_json_path = Path(sys.argv[2])
    rows = read_sheet_rows(xlsx_path)
    source_rows = [row for row in rows[1:] if row and row[0].strip().isdigit()]

    with recipes_json_path.open() as fh:
        existing = json.load(fh)

    base_recipes = [item for item in existing if not item["id"].startswith("xlsx_")]
    existing_names = {normalize(item["name"]) for item in base_recipes}
    generated = []
    for index, row in enumerate(source_rows, start=1):
        recipe = convert_row(index, row)
        if normalize(recipe["name"]) in existing_names:
            continue
        generated.append(recipe)
        existing_names.add(normalize(recipe["name"]))

    merged = base_recipes + generated
    recipes_json_path.write_text(
        json.dumps(merged, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Added {len(generated)} recipes. Total recipes: {len(merged)}")


if __name__ == "__main__":
    main()
