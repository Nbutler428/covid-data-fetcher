#!/bin/sh

# Get date argument (default to 2020-01-01 if not provided)
START_DATE=${1:-"2020-01-01T00:00:00.000"}

echo "🚀 Checking if PostgreSQL is already running..."
if [ "$(docker ps -q -f name=covid_pg)" ]; then
    echo "✅ PostgreSQL is already running."
else
    echo "🚀 Starting PostgreSQL Docker container..."
    docker run -d --name covid_pg --env-file vars.env --network covid_network -p 5432:5432 postgres
fi

# Wait for PostgreSQL to initialize
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

echo "✅ PostgreSQL is running. Now fetching data from $START_DATE..."
docker run --rm -v "$(pwd):/app" --network covid_network fetcher "$START_DATE"

echo "✅ Data fetching complete!"

