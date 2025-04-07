# Use a lightweight base image
FROM alpine:latest

# Install necessary tools
RUN apk add --no-cache curl jq

# Set working directory
WORKDIR /app

# Copy fetch script
COPY fetch_data.sh .

# Ensure the script is executable
RUN chmod +x fetch_data.sh

# Run the script when the container starts
ENTRYPOINT ["sh", "/app/fetch_data.sh"]
CMD ["2020-01-01T00:00:00.000"] 

