#!/bin/sh

echo "Waiting for PostgreSQL to start..."
sleep 5  # Give it a few seconds to start

echo "Creating table if not exists..."
PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
$(cat /app/create_table.sql)
"

echo "Inserting data from JSON..."
cat /app/covid_data.json | jq -c '.[]' | while read line; do
    date_of_interest=$(echo "$line" | jq -r '.date_of_interest')
    case_count=$(echo "$line" | jq -r '.case_count')
    probable_case_count=$(echo "$line" | jq -r '.probable_case_count')
    hospitalized_count=$(echo "$line" | jq -r '.hospitalized_count')
    death_count=$(echo "$line" | jq -r '.death_count')
    
    PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
    INSERT INTO covid_daily_counts (date_of_interest, case_count, probable_case_count, hospitalized_count, death_count)
    VALUES ('$date_of_interest', $case_count, $probable_case_count, $hospitalized_count, $death_count);
    "
done

echo "Data inserted successfully!"

