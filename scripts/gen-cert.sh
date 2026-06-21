#!/usr/bin/env bash
# Generate a self-signed certificate for the lab (HAProxy wants cert+key in one PEM).
# Usage: gen-cert.sh [output-dir] [days]     NOT for production use.
set -euo pipefail

OUT="${1:-$(dirname "$0")/../certs}"
DAYS="${2:-365}"
mkdir -p "$OUT"

openssl req -x509 -newkey rsa:2048 -nodes -days "$DAYS" \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  -keyout "$OUT/lab.key" -out "$OUT/lab.crt" 2>/dev/null
cat "$OUT/lab.crt" "$OUT/lab.key" >"$OUT/lab.pem"
chmod 600 "$OUT/lab.key" "$OUT/lab.pem"
echo "Wrote $OUT/lab.pem"
