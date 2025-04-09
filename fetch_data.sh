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
    all_case_count_7day_avg TEXT,
    bk_all_case_count_7day_avg TEXT,
    bk_case_count TEXT,
    bk_case_count_7day_avg TEXT,
    bk_death_count TEXT,
    bk_death_count_7day_avg TEXT,
    bk_hospitalized_count TEXT,
    bk_hospitalized_count_7day_avg TEXT,
    bk_probable_case_count TEXT,
    bk_probable_case_count_7day_avg TEXT,
    bx_all_case_count_7day_avg TEXT,
    bx_case_count TEXT,
    bx_case_count_7day_avg TEXT,
    bx_death_count TEXT,
    bx_death_count_7day_avg TEXT,
    bx_hospitalized_count TEXT,
    bx_hospitalized_count_7day_avg TEXT,
    bx_probable_case_count TEXT,
    bx_probable_case_count_7day_avg TEXT,
    case_count TEXT,
    case_count_7day_avg TEXT,
    date_of_interest TEXT,
    death_count TEXT,
    death_count_7day_avg TEXT,
    hosp_count_7day_avg TEXT,
    hospitalized_count TEXT,
    incomplete TEXT,
    mn_all_case_count_7day_avg TEXT,
    mn_case_count TEXT,
    mn_case_count_7day_avg TEXT,
    mn_death_count TEXT,
    mn_death_count_7day_avg TEXT,
    mn_hospitalized_count TEXT,
    mn_hospitalized_count_7day_avg TEXT,
    mn_probable_case_count TEXT,
    mn_probable_case_count_7day_avg TEXT,
    probable_case_count TEXT,
    qn_all_case_count_7day_avg TEXT,
    qn_case_count TEXT,
    qn_case_count_7day_avg TEXT,
    qn_death_count TEXT,
    qn_death_count_7day_avg TEXT,
    qn_hospitalized_count TEXT,
    qn_hospitalized_count_7day_avg TEXT,
    qn_probable_case_count TEXT,
    qn_probable_case_count_7day_avg TEXT,
    si_all_case_count_7day_avg TEXT,
    si_case_count TEXT,
    si_case_count_7day_avg TEXT,
    si_death_count TEXT,
    si_death_count_7day_avg TEXT,
    si_hospitalized_count TEXT,
    si_hospitalized_count_7day_avg TEXT,
    si_probable_case_count TEXT,
    si_probable_case_count_7day_avg TEXT
);

COPY $TABLE_NAME (
    all_case_count_7day_avg,
    bk_all_case_count_7day_avg,
    bk_case_count,
    bk_case_count_7day_avg,
    bk_death_count,
    bk_death_count_7day_avg,
    bk_hospitalized_count,
    bk_hospitalized_count_7day_avg,
    bk_probable_case_count,
    bk_probable_case_count_7day_avg,
    bx_all_case_count_7day_avg,
    bx_case_count,
    bx_case_count_7day_avg,
    bx_death_count,
    bx_death_count_7day_avg,
    bx_hospitalized_count,
    bx_hospitalized_count_7day_avg,
    bx_probable_case_count,
    bx_probable_case_count_7day_avg,
    case_count,
    case_count_7day_avg,
    date_of_interest,
    death_count,
    death_count_7day_avg,
    hosp_count_7day_avg,
    hospitalized_count,
    incomplete,
    mn_all_case_count_7day_avg,
    mn_case_count,
    mn_case_count_7day_avg,
    mn_death_count,
    mn_death_count_7day_avg,
    mn_hospitalized_count,
    mn_hospitalized_count_7day_avg,
    mn_probable_case_count,
    mn_probable_case_count_7day_avg,
    probable_case_count,
    qn_all_case_count_7day_avg,
    qn_case_count,
    qn_case_count_7day_avg,
    qn_death_count,
    qn_death_count_7day_avg,
    qn_hospitalized_count,
    qn_hospitalized_count_7day_avg,
    qn_probable_case_count,
    qn_probable_case_count_7day_avg,
    si_all_case_count_7day_avg,
    si_case_count,
    si_case_count_7day_avg,
    si_death_count,
    si_death_count_7day_avg,
    si_hospitalized_count,
    si_hospitalized_count_7day_avg,
    si_probable_case_count,
    si_probable_case_count_7day_avg
) FROM STDIN WITH CSV HEADER;
EOF

echo "🔐 Connecting to Postgres using DATABASE_URL..."
psql "$DATABASE_URL" -f /app/import.sql < "$CSV_FILE"

echo "✅ Import complete!"
