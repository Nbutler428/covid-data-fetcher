FROM alpine:latest

WORKDIR /app

RUN apk add --no-cache curl jq postgresql-client

COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

CMD ["./run.sh"]
