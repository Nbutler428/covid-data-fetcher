FROM alpine:latest

RUN apk add --no-cache curl jq postgresql-client

WORKDIR /app

COPY fetch_data.sh .

RUN chmod +x fetch_data.sh

ENTRYPOINT ["sh", "/app/fetch_data.sh"]
CMD ["2020-01-01T00:00:00.000"]
