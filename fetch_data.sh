#!/bin/sh

set -e

# Required environment variables
if [ -z "$DATABASE_URL" ]; then
  echo "❌ DATABASE_URL is required"
  exit 1
fi

# Static values
SITE_URL="https://data.cityofnewyork.us/resource/rc75-m7u3.json"
START_DATE=${1:-"2020-01-01T00:00:00.000"}
TABLE_NAME="covid_data"

# Fetch data
echo "📡 Fetching data from NYC API..."
curl -s "${SITE_URL}?\$where=date_of_interest>'$START_DATE'&\$limit=1000" > /app/data.json

# Convert to CSV
echo "📝 Converting to CSV..."
echo "date_of_interest,case_count,probable_case_count,hospitalized_count,death_count" > /app/data.csv
jq -r '.[] | [
  .date_of_interest,
  .case_count,
  .probable_case_count,
  .hospitalized_count,
  .death_count
] | @csv' /app/data.json >> /app/data.csv

# Create simple table
echo "📐 Creating table..."
cat <<EOF > /app/import.sql
DROP TABLE IF EXISTS $TABLE_NAME;
CREATE TABLE $TABLE_NAME (
  date_of_interest TEXT,
  case_count TEXT,
  probable_case_count TEXT,
  hospitalized_count TEXT,
  death_count TEXT
);
COPY $TABLE_NAME FROM STDIN WITH CSV HEADER;
EOF

# Import to Postgres
echo "📥 Importing into Postgres..."
psql "$DATABASE_URL" -f /app/import.sql < /app/data.csv

echo "✅ Done!"
