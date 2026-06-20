#!/usr/bin/env bash
# Run the whole stack (2 app servers, 2 NGINX proxies, HAProxy) on localhost WITHOUT Docker,
# using the repo's real configs with only hostnames/ports rewritten, then test it.
#
# Needs nginx and haproxy binaries (set NGINX_BIN= / HAPROXY_BIN= if not on PATH).
# Usage: tests/local-stack.sh          (runs tests, always cleans up)
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
NGINX_BIN="${NGINX_BIN:-nginx}"      # not NGINX: nginx itself reads that variable
HAPROXY_BIN="${HAPROXY_BIN:-haproxy}"
command -v "$NGINX_BIN" >/dev/null || { echo "nginx not found" >&2; exit 2; }
command -v "$HAPROXY_BIN" >/dev/null || { echo "haproxy not found" >&2; exit 2; }

TMP="$(mktemp -d)"
LB=9080 STATS=9404 N1=9101 N2=9102 A1=9001 A2=9002
cleanup() {
  for pf in "$TMP"/*/nginx.pid "$TMP"/haproxy.pid; do
    [[ -f "$pf" ]] && kill "$(cat "$pf")" 2>/dev/null || true
  done
  sleep 0.3; rm -rf "$TMP"
}
trap cleanup EXIT

# Ubuntu's nginx hard-codes /var/lib/nginx temp dirs; point them at our tmp dir instead.
temp_paths() {
  local d="$1"
  echo "client_body_temp_path $d/body; proxy_temp_path $d/proxy; fastcgi_temp_path $d/fcgi; uwsgi_temp_path $d/uwsgi; scgi_temp_path $d/scgi;"
}

start_app() {  # name port
  local d="$TMP/$1"; mkdir -p "$d/logs"
  sed -e "s/listen 80;/listen 127.0.0.1:$2;/" -e "s/\$hostname/$1/" app/default.conf >"$d/site.conf"
  printf 'pid %s/nginx.pid;\nerror_log %s/error.log;\nevents {}\nhttp { access_log off; %s include %s/site.conf; }\n' \
    "$d" "$d" "$(temp_paths "$d")" "$d" >"$d/nginx.conf"
  "$NGINX_BIN" -p "$d" -c "$d/nginx.conf"
}

start_proxy() {  # name port
  local d="$TMP/$1"; mkdir -p "$d/conf.d"
  sed -e "s/app1:80/127.0.0.1:$A1/" -e "s/app2:80/127.0.0.1:$A2/" \
      -e "s#include /etc/nginx/conf.d/\*.conf;#include $d/conf.d/*.conf;#" \
      -e "1i pid $d/nginx.pid;\nerror_log $d/error.log;" \
      -e "s#^http {#http {\n  access_log $d/access.log; $(temp_paths "$d")#" nginx/nginx.conf >"$d/nginx.conf"
  sed -e "s/listen 80;/listen 127.0.0.1:$2;/" nginx/conf.d/proxy.conf >"$d/conf.d/proxy.conf"
  "$NGINX_BIN" -p "$d" -c "$d/nginx.conf"
}

start_haproxy() {
  sed -e "s/bind \*:80/bind 127.0.0.1:$LB/" -e "s/bind \*:8404/bind 127.0.0.1:$STATS/" \
      -e "s/nginx1:80/127.0.0.1:$N1/" -e "s/nginx2:80/127.0.0.1:$N2/" \
      -e "s/log stdout format raw local0/log stdout format raw local0/" haproxy/haproxy.cfg >"$TMP/haproxy.cfg"
  "$HAPROXY_BIN" -c -f "$TMP/haproxy.cfg" >/dev/null
  "$HAPROXY_BIN" -D -f "$TMP/haproxy.cfg" -p "$TMP/haproxy.pid"
}

wait_for() {  # url
  for _ in $(seq 1 30); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.2; done
  echo "timeout waiting for $1" >&2; return 1
}

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok   $*"; }

start_app app1 $A1; start_app app2 $A2
start_proxy nginx1 $N1; start_proxy nginx2 $N2
start_haproxy
wait_for "http://127.0.0.1:$LB/healthz"

# 1. Health endpoint
[[ "$(curl -fsS "http://127.0.0.1:$LB/healthz")" == "ok" ]] && pass "health endpoint" || fail "health"

# 2. Load balancing reaches both app replicas
seen="$(for _ in $(seq 1 20); do curl -fsS "http://127.0.0.1:$LB/"; done | sort -u | tr -d '\n')"
[[ "$seen" == *app1* && "$seen" == *app2* ]] && pass "requests reach both app replicas" || fail "no balancing, saw: $seen"

# 3. Security headers added by NGINX
hdrs="$(curl -fsSI "http://127.0.0.1:$LB/")"
grep -qi '^X-Content-Type-Options: nosniff' <<<"$hdrs" && pass "security headers present" || fail "missing headers"

# 4. Failover: stop nginx1, HAProxy must eject it and keep serving
kill "$(cat "$TMP/nginx1/nginx.pid")"
sleep 11   # inter 3s * fall 3 = 9s to eject
for _ in $(seq 1 10); do curl -fsS -o /dev/null "http://127.0.0.1:$LB/" || fail "request failed during failover"; done
pass "traffic survives losing one proxy"
curl -fsS "http://127.0.0.1:$STATS/stats;csv" | grep -E '^nginx_pool,nginx1,' | grep -q ',DOWN,' && pass "HAProxy marked nginx1 DOWN" || fail "nginx1 not marked down"

echo "all local-stack tests passed"
