#!/bin/bash

# ==========================================
# BÀI 4 - CUSTOM NETWORK & NAMED VOLUME
# ==========================================

# 1. Tạo Custom Bridge Network
docker network create --driver bridge app-net

# 2. Tạo Named Volume
docker volume create db-data

# 3. Chạy PostgreSQL Database Container
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=apppass \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine

# 4. Chờ PostgreSQL khởi động
echo "Waiting for PostgreSQL..."
sleep 10

# 5. Chạy Backend Container
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASSWORD=apppass \
  alpine:3.20 \
  sh -c "while true; do sleep 3600; done"

echo "=========================================="
echo "Containers:"
docker ps

echo "=========================================="
echo "Network:"
docker network inspect app-net

echo "=========================================="
echo "Volume:"
docker volume inspect db-data

echo "=========================================="
echo "DNS test:"
docker exec app-container ping -c 2 db-server
