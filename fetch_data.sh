#!/bin/sh

set -e

START_DATE=${1:-"2020-01-01T00:00:00.000"}
TABLE_NAME="covid_data"

if [ -z "$DATABASE_URL" ]; then
  echo "❌ DATABASE_URL is required"
  exit 1
fi

echo "📡 Fetching COVID data..."
curl -s "https://data.cityofnewyork.us/resource/rc75-m7u3.json?\$where=date_of_interest>'$START_DATE'&\$limit=1000" > /app/data.json
echo "✅ Got JSON"

# Actual headers (cleaned and comma-separated)
HEADERS="all_case_count_7day_avg,bk_all_case_count_7day_avg,bk_case_count,bk_case_count_7day_avg,bk_death_count,bk_death_count_7day_avg,bk_hospitalized_count,bk_hospitalized_count_7day_avg,bk_probable_case_count,bk_probable_case_count_7day_avg,bx_all_case_count_7day_avg,bx_case_count,bx_case_count_7day_avg,bx_death_count,bx_death_count_7day_avg,bx_hospitalized_count,bx_hospitalized_count_7day_avg,bx_probable_case_count,bx_probable_case_count_7day_avg,case_count,case_count_7day_avg,date_of_interest,death_count,death_count_7day_avg,hosp_count_7day_avg,hospitalized_count,incomplete,mn_all_case_count_7day_avg,mn_case_count,mn_case_count_7day_avg,mn_death_count,mn_death_count_7day_avg,mn_hospitalized_count,mn_hospitalized_count_7day_avg,mn_probable_case_count,mn_probable_case_count_7day_avg,probable_case_count,qn_all_case_count_7day_avg,qn_case_count,qn_case_count_7day_avg,qn_death_count,qn_death_count_7day_avg,qn_hospitalized_count,qn_hospitalized_count_7day_avg,qn_probable_case_count,qn_probable_case_count_7day_avg,si_all_case_count_7day_avg,si_case_count,si_case_count_7day_avg,si_death_count,si_death_count_7day_avg,si_hospitalized_count,si_hospitalized_count_7day_avg,si_probable_case_count,si_probable_case_count_7day_avg"

# Create CSV with header
echo "$HEADERS" > /app/data.csv

# Convert each JSON row into a CSV row with exact matching header order
jq -r --arg header "$HEADERS" '
  $header | split(",") as $cols |
  map([.[ $cols[] ] // "NULL"])[] | @csv
' /app/data.json >> /app/data.csv

echo "✅ CSV created"
echo "📊 $(tail -n +2 /app/data.csv | wc -l) rows"

# Generate CREATE TABLE SQL using all TEXT types
CREATE_COLUMNS=$(echo "$HEADERS" | tr ',' '\n' | awk '{print $0 " TEXT,"}' | sed '$ s/,$//')

cat <<EOF > /app/import.sql
DROP TABLE IF EXISTS $TABLE_NAME;
CREATE TABLE $TABLE_NAME (
$CREATE_COLUMNS
);
COPY $TABLE_NAME ($HEADERS)
FROM STDIN WITH CSV HEADER;
EOF

# Import into PostgreSQL
echo "📥 Importing into Postgres..."
psql "$DATABASE_URL" -f /app/import.sql < /app/data.csv

echo "✅ Import complete!"
