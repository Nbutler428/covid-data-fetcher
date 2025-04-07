#!/bin/sh

# Set default start date if not provided
START_DATE=${1:-"2020-01-01T00:00:00.000"}

echo "📡 Fetching COVID-19 data from NYC API after $START_DATE..."

# API Endpoint with date filtering
API_URL="https://data.cityofnewyork.us/resource/rc75-m7u3.json?\$where=date_of_interest>'$START_DATE'&\$limit=1000"

# Fetch JSON data
curl -s "$API_URL" | jq '.' > /app/covid_data.json
echo "✅ JSON data saved to covid_data.json"

# Set output CSV path
CSV_FILE="/app/covid_data.csv"

# Create CSV with headers if it doesn't exist
if [ ! -f "$CSV_FILE" ]; then
    echo "📝 Creating new CSV file with headers..."
    HEADERS=$(jq -r 'map(keys) | add | unique | @csv' /app/covid_data.json)
    echo "$HEADERS" > "$CSV_FILE"
fi

# Append new data to the CSV
echo "➕ Appending new data to CSV..."
cat /app/covid_data.json | jq -r 'map([.[] // "NULL"])[] | @csv' >> "$CSV_FILE"
echo "✅ Data successfully appended to covid_data.csv"

# 📥 Optional: Import CSV into Railway Postgres
if [ -n "$POSTGRES_HOST" ]; then
    echo "📥 Attempting to import data into Postgres at $POSTGRES_HOST..."

    # Create SQL script
    cat <<EOF > /app/import.sql
CREATE TABLE IF NOT EXISTS covid_data (
    date_of_interest TEXT,
    case_count TEXT,
    probable_case_count TEXT,
    hospitalized_count TEXT,
    death_count TEXT
    -- Add additional fields based on the actual dataset
);

COPY covid_data FROM STDIN WITH CSV HEADER;
EOF

    # Run SQL import using psql
    PGPASSWORD=$POSTGRES_PASSWORD psql \
        -h "$POSTGRES_HOST" \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        -p "${POSTGRES_PORT:-5432}" \
        -f /app/import.sql < "$CSV_FILE"

    echo "✅ Data successfully imported to Postgres!"
else
    echo "⚠️  No database credentials found. Skipping database import."
fi
