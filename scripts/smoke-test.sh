#!/usr/bin/env bash
# Verifies load balancing and failover. Run after `docker compose up -d`.
set -euo pipefail
URL="${URL:-http://localhost:8080}"

echo "== Round-robin across app replicas =="
for _ in $(seq 1 6); do curl -fsS "$URL/"; done | sort | uniq -c

echo "== Health endpoint =="
curl -fsS "$URL/healthz"

echo "== Failover: stopping nginx1 =="
docker compose stop nginx1 >/dev/null
sleep 10   # > inter*fall (3s*3)
for _ in $(seq 1 4); do curl -fsS "$URL/" >/dev/null && echo "still serving"; done
docker compose start nginx1 >/dev/null
echo "OK"
