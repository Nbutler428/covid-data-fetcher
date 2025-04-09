#!/bin/bash

echo "Installing Python dependencies..."
pip install --no-cache-dir requests psycopg2-binary

echo "Running data fetch and insert..."
python3 - <<EOF
import os
import requests
import psycopg2

db_url = os.getenv("DATABASE_URL")
site_url = os.getenv("SITE_URL")
table_name = os.getenv("TABLE_NAME")

if not all([db_url, site_url, table_name]):
    raise Exception("Missing one or more required environment variables.")

print(f"Fetching data from {site_url}...")
resp = requests.get(site_url)
resp.raise_for_status()
data = resp.json()

print("Connecting to PostgreSQL...")
conn = psycopg2.connect(db_url)
cur = conn.cursor()

print("Creating table if it doesn't exist...")
cur.execute(f'''
    CREATE TABLE IF NOT EXISTS {table_name} (
        case_id SERIAL PRIMARY KEY,
        case_count INTEGER,
        borough TEXT,
        age_group TEXT,
        sex TEXT
    );
''')

print("Inserting data...")
for entry in data:
    try:
        cur.execute(
            f"INSERT INTO {table_name} (case_count, borough, age_group, sex) VALUES (%s, %s, %s, %s);",
            (
                int(entry.get("case_count", 0)),
                entry.get("borough"),
                entry.get("age_group"),
                entry.get("sex"),
            )
        )
    except Exception as e:
        print(f"Insert error: {e}")

conn.commit()
cur.close()
conn.close()
print("Done!")
EOF
