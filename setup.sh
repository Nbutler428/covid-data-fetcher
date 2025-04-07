#!/bin/sh

# Exit on error
set -e

echo "🚀 Setting up the COVID-19 Data Fetcher..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker is not installed. Installing Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "✅ Docker installed successfully."
else
    echo "✅ Docker is already installed."
fi

# Ensure Docker is running
if ! sudo systemctl is-active --quiet docker; then
    echo "🚀 Starting Docker service..."
    sudo systemctl start docker
fi

# Create Docker network if it doesn't exist
if ! docker network ls | grep -q "covid_network"; then
    echo "🚀 Creating Docker network covid_network..."
    docker network create covid_network
else
    echo "✅ Docker network covid_network already exists."
fi

# Create project directory if not exists
if [ ! -d "covid_project" ]; then
    echo "📂 Creating project directory..."
    mkdir covid_project
fi

cd covid_project

# Create .env file if it doesn't exist
if [ ! -f "vars.env" ]; then
    echo "🔧 Creating vars.env file..."
    cat <<EOL > vars.env
POSTGRES_HOST=covid_pg
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin
POSTGRES_DB=covid_db
EOL
fi

# Create fetch_data.sh script
cat <<EOL > fetch_data.sh
#!/bin/sh

START_DATE=\${1:-"2020-01-01T00:00:00.000"}

echo "Fetching COVID-19 data from NYC API after \$START_DATE..."

API_URL="https://data.cityofnewyork.us/resource/rc75-m7u3.json?\$where=date_of_interest>'\$START_DATE'&\$limit=1000"

curl -s "\$API_URL" | jq '.' > /app/covid_data.json

echo "✅ JSON data saved to covid_data.json"

CSV_FILE="/app/covid_data.csv"

if [ ! -f "\$CSV_FILE" ]; then
    echo "Creating new CSV file with headers..."
    HEADERS=\$(jq -r 'map(keys) | add | unique | @csv' /app/covid_data.json)
    echo "\$HEADERS" > "\$CSV_FILE"
fi

echo "Appending new data to CSV..."
cat /app/covid_data.json | jq -r '
    map([.[] // "NULL"])[] | @csv' >> "\$CSV_FILE"

echo "✅ Data successfully appended to covid_data.csv"
EOL

chmod +x fetch_data.sh

# Create Dockerfile
cat <<EOL > Dockerfile
FROM alpine:latest

RUN apk add --no-cache curl jq

WORKDIR /app

COPY fetch_data.sh .

RUN chmod +x fetch_data.sh

ENTRYPOINT ["sh", "/app/fetch_data.sh"]
CMD ["2020-01-01T00:00:00.000"]
EOL

# Create start_all.sh script
cat <<EOL > start_all.sh
#!/bin/sh

START_DATE=\${1:-"2020-01-01T00:00:00.000"}

echo "🚀 Checking if PostgreSQL container exists..."
if [ "\$(docker ps -aq -f name=covid_pg)" ]; then
    echo "✅ PostgreSQL container already exists."
    if [ "\$(docker ps -q -f name=covid_pg)" ]; then
        echo "✅ PostgreSQL is already running."
    else
        echo "🔄 Starting the existing PostgreSQL container..."
        docker start covid_pg
    fi
else
    echo "🚀 Creating a new PostgreSQL container..."
    docker run -d --name covid_pg --env-file vars.env --network covid_network -p 5432:5432 postgres
fi

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

echo "✅ PostgreSQL is running. Now fetching data from \$START_DATE..."
docker run --rm -v "\$(pwd):/app" --network covid_network fetcher "\$START_DATE"

echo "✅ Data fetching complete!"
EOL

chmod +x start_all.sh

echo "📦 Building the Docker container..."
docker build -t fetcher .

echo "🚀 Setup complete! To start fetching data, run: ./start_all.sh \"YYYY-MM-DDT00:00:00.000\""

