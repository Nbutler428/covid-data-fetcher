FROM python:3.10-slim

WORKDIR /app

# Install psycopg2 dependencies
RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# Copy and run the script
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

CMD ["./run.sh"]
