#!/bin/sh

set -e

# Default start date if not passed
START_DATE=${1:-"2020-01-01T00:00:00.000"}

# Check environment variables
if [ -z "$DATABASE_URL" ] || [ -z "$SITE_URL" ] || [ -z "$TABLE_NAME" ]; then
  echo "❌ Missing required environment variables: DATABASE_URL, SITE_URL, TABLE_NAME"
  exit 1
fi

echo "📡 Downloading COVID-19 data from NYC API..."

# Fetch JSON from API
curl -s "${SITE_URL}?\$where=date_of_interest>'$START_DATE'&\$limit=1000" > /app/data.json

echo "✅ JSON data saved."

# Extract CSV headers from JSON
HEADERS=$(jq -r 'map(keys) | add | unique | join(",")' /app/data.json)
echo "$HEADERS" > /app/data.csv

# Write rows aligned with the headers
jq -r --arg header "$HEADERS" '
  $header | split(",") as $cols |
  map([.[ $cols[] ] // "NULL"])[] | @csv
' /app/data.json >> /app/data.csv

echo "✅ CSV created with headers:"
echo "$HEADERS"
echo "📊 $(tail -n +2 /app/data.csv | wc -l) data rows"

# Generate CREATE TABLE SQL with TEXT columns
echo "📐 Generating SQL to create table: $TABLE_NAME"
CREATE_SQL=$(echo "$HEADERS" | tr ',' '\n' | awk '{print $0 " TEXT,"}' | sed '$ s/,$//')

cat <<EOF > /app/import.sql
DROP TABLE IF EXISTS $TABLE_NAME;
CREATE TABLE $TABLE_NAME (
$CREATE_SQL
);
COPY $TABLE_NAME ($HEADERS)
FROM STDIN WITH CSV HEADER;
EOF

# Run the SQL import
echo "📥 Importing into PostgreSQL..."
psql "$DATABASE_URL" -f /app/import.sql < /app/data.csv

echo "✅ Done!"
