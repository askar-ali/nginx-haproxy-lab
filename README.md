# nginx-haproxy-lab

Ingress, reverse proxy and load balancing in front of containerised workloads:

```
client -> HAProxy (L4/L7 LB, health checks) -> NGINX (reverse proxy, TLS-ready, rate limit) -> app replicas
```

> Lab recreation of the proxy layer I use in production (since 10/2025).

## Why both

| Tool | Role |
|------|------|
| HAProxy | Fast load balancer, active health checks, stats page, easy failover |
| NGINX | Reverse proxy: routing, caching, rate limiting, security headers |

## Run

```bash
scripts/gen-cert.sh && docker compose up -d
scripts/gen-cert.sh                # self-signed cert for the lab (once)
curl -sk https://localhost:8443/   # TLS terminated at HAProxy, balanced across replicas
curl -s  http://localhost:8080/healthz
open http://localhost:8404/stats   # HAProxy stats
```

## Notes

- Lab caveat: `redirect scheme https` keeps the request's port, so on the lab's
  8080/8443 mapping use https://localhost:8443 directly. On standard 80/443 it just works.
- The redirect skips `/healthz` so external probes can stay on plain HTTP.

## Test without Docker

`make test-local` starts 2 app servers, 2 NGINX proxies and HAProxy on localhost with the
real configs (needs `nginx`, `haproxy`, `openssl`, `curl`) and checks redirect, TLS 1.2+,
HSTS, forwarded scheme, balancing, headers, failover and HAProxy DOWN detection.
