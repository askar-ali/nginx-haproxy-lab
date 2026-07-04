#!/usr/bin/env bash
# Control backend servers through HAProxy's runtime API: zero-downtime maintenance
# and blue/green style switches without reloading or restarting HAProxy.
#
# Usage: lb-server.sh <status | drain <server> | ready <server> | maint <server>>
#   drain  - stop NEW sessions, let existing ones finish (do this before maintenance)
#   ready  - put the server back in rotation
#   maint  - take it fully out
set -euo pipefail

SOCK="${HAPROXY_SOCK:-/tmp/haproxy-admin.sock}"
BACKEND="${BACKEND:-nginx_pool}"

cmd() {
  python3 -I - "$SOCK" "$1" <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
s.sendall((sys.argv[2] + "\n").encode())
out = b""
while True:
    chunk = s.recv(4096)
    if not chunk:
        break
    out += chunk
sys.stdout.write(out.decode())
PY
}

case "${1:-}" in
  status)
    cmd "show servers state $BACKEND" | awk 'NR>2 && NF {print $4, "admin_state=" $7}' ;;
  drain|ready|maint)
    srv="${2:?server name}"
    out="$(cmd "set server $BACKEND/$srv state $1")"
    [[ -z "${out//[$'\n ']/}" ]] || { echo "$out" >&2; exit 1; }
    echo "$srv -> $1" ;;
  *) echo "usage: $0 status | drain <server> | ready <server> | maint <server>" >&2; exit 2 ;;
esac
