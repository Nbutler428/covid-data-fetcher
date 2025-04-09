#!/bin/sh

echo "Installing Python dependencies..."
pip install --no-cache-dir requests psycopg2-binary

echo "Running data fetch and insert..."
python3 - <<EOF
import os
import requests
import psycopg2
from datetime import datetime

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

print("Creating table...")
cur.execute(f'''
CREATE TABLE IF NOT EXISTS {table_name} (
    id SERIAL PRIMARY KEY,
    date_of_interest DATE,
    case_count INTEGER,
    probable_case_count INTEGER,
    hospitalized_count INTEGER,
    death_count INTEGER,
    case_count_7day_avg INTEGER,
    all_case_count_7day_avg INTEGER,
    hosp_count_7day_avg INTEGER,
    death_count_7day_avg INTEGER,
    incomplete BOOLEAN
);
''')

print("Inserting records...")
for record in data:
    try:
        cur.execute(
            f"""
            INSERT INTO {table_name} (
                date_of_interest,
                case_count,
                probable_case_count,
                hospitalized_count,
                death_count,
                case_count_7day_avg,
                all_case_count_7day_avg,
                hosp_count_7day_avg,
                death_count_7day_avg,
                incomplete
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
            """,
            (
                datetime.strptime(record["date_of_interest"], "%Y-%m-%dT%H:%M:%S.%f").date(),
                int(record.get("case_count", 0)),
                int(record.get("probable_case_count", 0)),
                int(record.get("hospitalized_count", 0)),
                int(record.get("death_count", 0)),
                int(record.get("case_count_7day_avg", 0)),
                int(record.get("all_case_count_7day_avg", 0)),
                int(record.get("hosp_count_7day_avg", 0)),
                int(record.get("death_count_7day_avg", 0)),
                record.get("incomplete", "0") == "1"
            )
        )
    except Exception as e:
        print(f"Error inserting record: {e}")

conn.commit()
cur.close()
conn.close()
print("Done!")
EOF
