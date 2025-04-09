#!/bin/sh


START_DATE=${1:-"2020-01-01T00:00:00.000"}

echo "📡 Fetching COVID-19 data from NYC API after $START_DATE..."


API_URL="https://data.cityofnewyork.us/resource/rc75-m7u3.json?\$where=date_of_interest>'$START_DATE'&\$limit=1000"


curl -s "$API_URL" | jq '.' > /app/covid_data.json
echo "✅ JSON data saved to covid_data.json"


CSV_FILE="/app/covid_data.csv"

# Create CSV with headers if it doesn't exist
if [ ! -f "$CSV_FILE" ]; then
    echo "📝 Creating new CSV file with headers..."
    HEADERS=$(jq -r 'map(keys) | add | unique | @csv' /app/covid_data.json)
    echo "$HEADERS" > "$CSV_FILE"
fi


echo "➕ Appending new data to CSV..."
cat /app/covid_data.json | jq -r 'map([.[] // "NULL"])[] | @csv' >> "$CSV_FILE"
echo "✅ Data successfully appended to covid_data.csv"


if [ -n "$POSTGRES_HOST" ]; then
    echo "📥 Attempting to import data into Postgres at $POSTGRES_HOST..."


    cat <<EOF > /app/import.sql
CREATE TABLE IF NOT EXISTS covid_data (
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

COPY covid_data FROM STDIN WITH CSV HEADER;
EOF



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
