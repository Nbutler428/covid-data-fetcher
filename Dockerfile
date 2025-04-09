FROM alpine:latest

WORKDIR /app

RUN apk add --no-cache \
    python3 \
    py3-pip \
    gcc \
    musl-dev \
    libpq \
    postgresql-dev \
    libffi-dev \
    build-base

COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

CMD ["./run.sh"]
