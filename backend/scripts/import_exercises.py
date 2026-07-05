#!/usr/bin/env python3
"""
Import exercises from hasaneyldrm/exercises-dataset into PostgreSQL
Usage: python3 import_exercises.py
"""

import json
import psycopg2
from psycopg2.extras import execute_batch

# Database config (adjust as needed)
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'fitness_db',
    'user': 'postgres',
    'password': 'postgres'
}

def load_exercises():
    """Load exercises.json from local file or download"""
    import os
    json_path = '/tmp/exercises.json'

    if not os.path.exists(json_path):
        print("Downloading exercises.json...")
        import urllib.request
        url = 'https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/data/exercises.json'
        urllib.request.urlretrieve(url, json_path)

    with open(json_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def import_to_db(exercises):
    """Import exercises to PostgreSQL"""
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    insert_sql = """
        INSERT INTO exercise_library (
            id, name, category, body_part, equipment,
            instructions_en, instructions_tr, instructions_es,
            instructions_it, instructions_ru, instructions_zh,
            instruction_steps_en, instruction_steps_tr,
            muscle_group, secondary_muscles, target, media_id
        ) VALUES (
            %s, %s, %s, %s, %s,
            %s, %s, %s,
            %s, %s, %s,
            %s, %s,
            %s, %s, %s, %s
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            category = EXCLUDED.category,
            instructions_tr = EXCLUDED.instructions_tr
    """

    rows = []
    for ex in exercises:
        instructions = ex.get('instructions', {})
        instruction_steps = ex.get('instruction_steps', {})

        row = (
            ex.get('id'),
            ex.get('name'),
            ex.get('category'),
            ex.get('body_part'),
            ex.get('equipment'),
            # Instructions
            instructions.get('en'),
            instructions.get('tr'),
            instructions.get('es'),
            instructions.get('it'),
            instructions.get('ru'),
            instructions.get('zh'),
            # Steps
            json.dumps(instruction_steps.get('en', []), ensure_ascii=False),
            json.dumps(instruction_steps.get('tr', []), ensure_ascii=False),
            # Metadata
            ex.get('muscle_group'),
            json.dumps(ex.get('secondary_muscles', []), ensure_ascii=False),
            ex.get('target'),
            ex.get('media_id')
        )
        rows.append(row)

    execute_batch(cur, insert_sql, rows, page_size=100)
    conn.commit()

    print(f"✅ Imported {len(rows)} exercises")

    # Stats
    cur.execute("SELECT category, COUNT(*) FROM exercise_library GROUP BY category ORDER BY COUNT(*) DESC")
    print("\n📊 Exercises by category:")
    for category, count in cur.fetchall():
        print(f"  {category}: {count}")

    cur.close()
    conn.close()

if __name__ == '__main__':
    print("🏋️ Importing exercises dataset...")
    exercises = load_exercises()
    print(f"📦 Loaded {len(exercises)} exercises")
    import_to_db(exercises)
    print("✅ Done!")
