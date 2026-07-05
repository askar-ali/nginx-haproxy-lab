# Notes

## Request flow
HAProxy health-checks both NGINX nodes (`/healthz`, every 3s, 3 failures to eject,
2 successes to re-add). NGINX balances across app replicas and passes
`X-Forwarded-*` headers. Per-IP rate limit is 10 r/s with burst 20.

## Production differences
- Replace the self-signed cert with a real one (e.g. certbot/ACME) and reload HAProxy.
- Run two HAProxy nodes with keepalived/VRRP for a floating IP.
- In Kubernetes, ingress-nginx plays the NGINX role; HAProxy fronts the node ports.
- Restrict the stats listener to an internal network and add auth.

## Validation
`haproxy -c -f haproxy/haproxy.cfg` and `nginx -t` (the compose images include both).

## What the tests found
- NGINX `upstream` without a `zone` keeps balancing state per worker; with `worker_processes auto`
  low traffic always hit the first backend. Fixed with `zone` + `least_conn`.
- The Ubuntu nginx build hard-codes /var/lib/nginx temp paths; the harness overrides them.

## Operations
- Maintenance: `scripts/lb-server.sh drain nginx1`, wait for sessions to end, patch, then `ready nginx1`.
- Metrics: HAProxy `:8404/metrics`; NGINX `:8081/stub_status` (private ranges only).
- Rate limit: 100 requests/10s per IP at HAProxy, 10 r/s (burst 20) per IP at NGINX, both answer 429.

## Validation
`make test-local` (real configs on localhost, no Docker) is what was run here. The Docker
compose path itself was not started in this environment.
