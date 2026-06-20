.PHONY: up down test test-local
up:
	docker compose up -d

down:
	docker compose down

test:
	scripts/smoke-test.sh

# No Docker needed: runs the real configs on localhost with nginx + haproxy binaries.
test-local:
	tests/local-stack.sh
