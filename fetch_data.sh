#!/bin/sh

set -e

START_DATE=${1:-"2020-01-01T00:00:00.000"}

# Required ENV VARS
if [ -z "$DATABASE_URL" ] || [ -z "$SITE_URL" ] || [ -z "$TABLE_NAME" ]; then
  echo "❌ Missing required environment variables: DATABASE_URL, SITE_URL, TABLE_NAME"
  exit 1
fi

echo "📡 Fetching COVID-19 data from $SITE_URL after $START_DATE..."

API_URL="${SITE_URL}?\$where=date_of_interest>'$START_DATE'&\$limit=1000"

curl -s "$API_URL" | jq '.' > /app/covid_data.json
echo "✅ JSON data saved to covid_data.json"

CSV_FILE="/app/covid_data.csv"

echo "📝 Converting JSON to CSV..."
HEADERS=$(jq -r 'map(keys) | add | unique | @csv' /app/covid_data.json)
echo "$HEADERS" > "$CSV_FILE"
jq -r 'map([.[] // "NULL"])[] | @csv' /app/covid_data.json >> "$CSV_FILE"
echo "✅ Data saved to covid_data.csv"

echo "📄 CSV headers:"
head -n 1 "$CSV_FILE"

echo "📥 Importing data into PostgreSQL..."

cat <<EOF > /app/import.sql
DROP TABLE IF EXISTS $TABLE_NAME;

CREATE TABLE $TABLE_NAME (
    date_of_interest TEXT,
    case_count TEXT,
    probable_case_count TEXT,
    hospitalized_count TEXT,
    death_count TEXT,
    case_count_7day_avg TEXT,
    all_case_count_7day_avg TEXT,
    hosp_count_7day_avg TEXT,
    death_count_7day_avg TEXT,
    bx_case_count TEXT,
    bx_probable_case_count TEXT,
    bx_hospitalized_count TEXT,
    bx_death_count TEXT,
    bx_case_count_7day_avg TEXT,
    bx_probable_case_count_7day_avg TEXT,
    bx_all_case_count_7day_avg TEXT,
    bx_hospitalized_count_7day_avg TEXT,
    bx_death_count_7day_avg TEXT,
    bk_case_count TEXT,
    bk_probable_case_count TEXT,
    bk_hospitalized_count TEXT,
    bk_death_count TEXT,
    bk_case_count_7day_avg TEXT,
    bk_probable_case_count_7day_avg TEXT,
    bk_all_case_count_7day_avg TEXT,
    bk_hospitalized_count_7day_avg TEXT,
    bk_death_count_7day_avg TEXT,
    mn_case_count TEXT,
    mn_probable_case_count TEXT,
    mn_hospitalized_count TEXT,
    mn_death_count TEXT,
    mn_case_count_7day_avg TEXT,
    mn_probable_case_count_7day_avg TEXT,
    mn_all_case_count_7day_avg TEXT,
    mn_hospitalized_count_7day_avg TEXT,
    mn_death_count_7day_avg TEXT,
    qn_case_count TEXT,
    qn_probable_case_count TEXT,
    qn_hospitalized_count TEXT,
    qn_death_count TEXT,
    qn_case_count_7day_avg TEXT,
    qn_probable_case_count_7day_avg TEXT,
    qn_all_case_count_7day_avg TEXT,
    qn_hospitalized_count_7day_avg TEXT,
    qn_death_count_7day_avg TEXT,
    si_case_count TEXT,
    si_probable_case_count TEXT,
    si_hospitalized_count TEXT,
    si_death_count TEXT,
    si_probable_case_count_7day_avg TEXT,
    si_case_count_7day_avg TEXT,
    si_all_case_count_7day_avg TEXT,
    si_hospitalized_count_7day_avg TEXT,
    si_death_count_7day_avg TEXT,
    incomplete TEXT
);

COPY $TABLE_NAME FROM STDIN WITH CSV HEADER;
EOF

echo "🔐 Connecting to Postgres using DATABASE_URL..."
psql "$DATABASE_URL" -f /app/import.sql < "$CSV_FILE"

echo "✅ Import complete!"
