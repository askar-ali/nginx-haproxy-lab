# Notes

## Request flow
HAProxy health-checks both NGINX nodes (`/healthz`, every 3s, 3 failures to eject,
2 successes to re-add). NGINX balances across app replicas and passes
`X-Forwarded-*` headers. Per-IP rate limit is 10 r/s with burst 20.

## Production differences
- Terminate TLS at HAProxy (`bind *:443 ssl crt ...`) and redirect 80 -> 443.
- Run two HAProxy nodes with keepalived/VRRP for a floating IP.
- In Kubernetes, ingress-nginx plays the NGINX role; HAProxy fronts the node ports.
- Restrict the stats listener to an internal network and add auth.

## Validation
`haproxy -c -f haproxy/haproxy.cfg` and `nginx -t` (the compose images include both).
