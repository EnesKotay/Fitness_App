#!/usr/bin/env python3
"""Backfill recipe images from the closest trustworthy recipe asset.

Used for recipes where Commons did not return a reliable direct match.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from frontend.tool.download_recipe_images import (
    GENERIC_QUERY_TOKENS,
    normalize_text,
    persist_state,
    strong_keywords,
)


BAD_TITLE_SNIPPETS = {
    "airasia",
    "healthy snacks",
    "domestic science",
    "betasheet",
    "mustard sauce",
    "roast lamb",
    "tomato fondue",
    "banana milkshake",
    "suite breakfast",
    "cassava roll",
    "grilled halloumi",
    "power protein salad bowl",
    "butter chicken",
}


def is_suspicious_title(title: str) -> bool:
    lowered = normalize_text(title)
    return any(snippet in lowered for snippet in BAD_TITLE_SNIPPETS)


def keyword_set(recipe: dict) -> set[str]:
    return {
        keyword
        for keyword in strong_keywords(recipe)
        if keyword not in GENERIC_QUERY_TOKENS and len(keyword) > 2
    }


def donor_score(target: dict, donor: dict) -> float:
    target_keywords = keyword_set(target)
    donor_keywords = keyword_set(donor)
    overlap = target_keywords & donor_keywords
    score = len(overlap) * 8.0
    if target.get("category") == donor.get("category"):
        score += 5.0
    if not overlap and target.get("category") == donor.get("category"):
        score += 2.0
    return score


def main() -> int:
    recipes_path = Path("frontend/assets/recipes/recipes_tr.json")
    metadata_path = Path("frontend/assets/recipes/image_sources.json")

    recipes = json.loads(recipes_path.read_text(encoding="utf-8"))
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    by_id = {recipe["id"]: recipe for recipe in recipes}

    trusted_donors = []
    for recipe in recipes:
        image_asset = str(recipe.get("imageAsset", "")).strip()
        if not image_asset:
            continue
        title = str(metadata.get(recipe["id"], {}).get("title", ""))
        if is_suspicious_title(title):
            continue
        trusted_donors.append(recipe)

    updated = 0
    for recipe in recipes:
        recipe_id = recipe["id"]
        image_asset = str(recipe.get("imageAsset", "")).strip()
        title = str(metadata.get(recipe_id, {}).get("title", ""))
        needs_backfill = not image_asset or is_suspicious_title(title)
        if not needs_backfill:
            continue

        candidates = [donor for donor in trusted_donors if donor["id"] != recipe_id]
        candidates.sort(key=lambda donor: donor_score(recipe, donor), reverse=True)
        if not candidates:
            continue
        donor = candidates[0]
        donor_meta = metadata.get(donor["id"], {})
        recipe["imageAsset"] = donor["imageAsset"]
        metadata[recipe_id] = {
            "name": recipe["name"],
            "asset": recipe["imageAsset"],
            "sourceStrategy": "closest_recipe_asset",
            "fallbackFromRecipeId": donor["id"],
            "fallbackFromRecipeName": donor["name"],
            "title": donor_meta.get("title", ""),
            "imageUrl": donor_meta.get("imageUrl", ""),
            "descriptionUrl": donor_meta.get("descriptionUrl", ""),
            "sourceUrl": donor_meta.get("sourceUrl", ""),
            "licenseName": donor_meta.get("licenseName", ""),
            "licenseUrl": donor_meta.get("licenseUrl", ""),
            "artist": donor_meta.get("artist", ""),
        }
        updated += 1

    persist_state(recipes_path, metadata_path, recipes, metadata)
    print(f"Backfilled {updated} recipes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
