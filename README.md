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
docker compose up -d
curl -s localhost:8080/            # served round-robin by app replicas
curl -s localhost:8080/healthz
open http://localhost:8404/stats   # HAProxy stats
```
