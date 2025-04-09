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

echo "🔍 First 3 records from covid_data.json:"
jq '.[0:3]' /app/covid_data.json

CSV_FILE="/app/covid_data.csv"

echo "📝 Converting JSON to CSV..."
HEADERS=$(jq -r 'map(keys) | add | unique | join(",")' /app/covid_data.json)
echo "$HEADERS" > "$CSV_FILE"

jq -r --arg header "$HEADERS" '
  $header | split(",") as $cols |
  map([.[ $cols[] ] // "NULL"])[] | @csv
' /app/covid_data.json >> "$CSV_FILE"

echo "✅ Data saved to covid_data.csv"

echo "📄 CSV headers:"
echo "$HEADERS"

echo "📊 Number of data rows (excluding header):"
tail -n +2 "$CSV_FILE" | wc -l

echo "📐 Creating table matching CSV headers..."

# Generate CREATE TABLE with all TEXT columns
CREATE_COLUMNS=$(echo "$HEADERS" | tr ',' '\n' | awk '{print $0 " TEXT,"}' | sed '$ s/,$//')

cat <<EOF > /app/import.sql
DROP TABLE IF EXISTS $TABLE_NAME;

CREATE TABLE $TABLE_NAME (
$CREATE_COLUMNS
);

COPY $TABLE_NAME ($HEADERS)
FROM STDIN WITH CSV HEADER;
EOF

echo "📥 Importing data into PostgreSQL..."
psql "$DATABASE_URL" -f /app/import.sql < "$CSV_FILE"

echo "✅ Import complete!"
