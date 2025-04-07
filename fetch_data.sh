#!/bin/sh

# Set default start date if not provided
START_DATE=${1:-"2020-01-01T00:00:00.000"}

echo "Fetching COVID-19 data from NYC API after $START_DATE..."

# API Endpoint with filtering for date
API_URL="https://data.cityofnewyork.us/resource/rc75-m7u3.json?\$where=date_of_interest>'$START_DATE'&\$limit=1000"

# Fetch JSON data
curl -s "$API_URL" | jq '.' > /app/covid_data.json

echo "✅ JSON data saved to covid_data.json"

# Check if covid_data.csv exists
CSV_FILE="/app/covid_data.csv"

if [ ! -f "$CSV_FILE" ]; then
    echo "Creating new CSV file with headers..."
    HEADERS=$(jq -r 'map(keys) | add | unique | @csv' /app/covid_data.json)
    echo "$HEADERS" > "$CSV_FILE"
fi

echo "Appending new data to CSV..."
cat /app/covid_data.json | jq -r '
    map([.[] // "NULL"])[] | @csv' >> "$CSV_FILE"

echo "✅ Data successfully appended to covid_data.csv"

