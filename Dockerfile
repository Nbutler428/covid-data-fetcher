FROM alpine:latest

RUN apk add --no-cache curl jq postgresql-client

WORKDIR /app

COPY fetch_data.sh .

RUN chmod +x fetch_data.sh

CMD ["/app/fetch_data.sh"]
