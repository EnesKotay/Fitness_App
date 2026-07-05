#!/usr/bin/env python3
"""Simple import script for exercises - reads from /tmp/exercises.json"""
import json
import psycopg2
from psycopg2.extras import execute_batch
import sys

def main():
    # Read exercises
    with open('/tmp/exercises.json', 'r', encoding='utf-8') as f:
        exercises = json.load(f)

    print(f"📦 Loaded {len(exercises)} exercises")

    # Connect to DB (using defaults)
    try:
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            database='fitness_db',
            user='postgres',
            password='postgres'  # Adjust if needed
        )
    except Exception as e:
        print(f"❌ DB connection failed: {e}")
        print("💡 Update password in script if needed")
        sys.exit(1)

    cur = conn.cursor()

    # Prepare rows
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
            instructions.get('en'),
            instructions.get('tr'),
            instructions.get('es'),
            instructions.get('it'),
            instructions.get('ru'),
            instructions.get('zh'),
            json.dumps(instruction_steps.get('en', []), ensure_ascii=False),
            json.dumps(instruction_steps.get('tr', []), ensure_ascii=False),
            ex.get('muscle_group'),
            json.dumps(ex.get('secondary_muscles', []), ensure_ascii=False),
            ex.get('target'),
            ex.get('media_id')
        )
        rows.append(row)

    # Insert
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
            instructions_tr = EXCLUDED.instructions_tr
    """

    try:
        execute_batch(cur, insert_sql, rows, page_size=100)
        conn.commit()
        print(f"✅ Imported {len(rows)} exercises")

        # Stats
        cur.execute("SELECT category, COUNT(*) FROM exercise_library GROUP BY category ORDER BY COUNT(*) DESC")
        print("\n📊 Top categories:")
        for category, count in cur.fetchall()[:5]:
            print(f"  {category}: {count}")

    except Exception as e:
        print(f"❌ Import failed: {e}")
        conn.rollback()
        sys.exit(1)
    finally:
        cur.close()
        conn.close()

if __name__ == '__main__':
    main()
