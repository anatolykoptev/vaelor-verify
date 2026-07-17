BINARY  = bin/go-code-verify
SERVICE = go-code-verify
COMPOSE = cd $(HOME)/deploy/server-config && docker compose

GOSTALL_VERSION := v1.0.0
GOSTALL := $(shell command -v gostall 2>/dev/null || echo $$(go env GOPATH)/bin/gostall)

.PHONY: build lint fmt-check test govulncheck gostall preflight run deploy clean

# CGO_ENABLED=0: this service has no C dependencies (unlike go-code, which
# needs CGO for tree-sitter grammars) — a static binary is both simpler to
# build and a smaller attack surface in the one container that holds
# docker.sock (ADR 0002 Phase 1 decision D0).
build:
	GOWORK=off CGO_ENABLED=0 go build -o $(BINARY) .

fmt-check:
	@out=$$(GOWORK=off gofmt -l .); \
	if [ -n "$$out" ]; then \
	  echo "gofmt drift detected:" >&2; \
	  echo "$$out" >&2; \
	  exit 1; \
	fi

lint: fmt-check
	GOWORK=off golangci-lint run ./...

test:
	GOWORK=off go test -timeout 20m ./...

# govulncheck — same rationale as go-code's: dependency + toolchain
# vulnerability scan, mandatory for the one binary that holds docker.sock.
GOVULNCHECK_VERSION = v1.4.0

govulncheck:
	@GOBIN=$$(GOWORK=off go env GOPATH)/bin; \
	if [ ! -x "$$GOBIN/govulncheck" ]; then \
	  echo "==> installing golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION)"; \
	  GOWORK=off go install golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION); \
	fi; \
	echo "==> govulncheck -scan package ./..."; \
	GOWORK=off "$$GOBIN/govulncheck" -scan package ./...

# preflight — the merge gate: gofmt + vet + build + test + govulncheck, run
# from .github/workflows/preflight.yml on a dedicated self-hosted runner
# (krolik-go-code-verify — NOT shared with go-code's runner, matching the
# repo-level isolation this whole service exists for). Unlike go-code's
# preflight, there is no ephemeral-postgres step: this service has no
# database (a concrete proof of its smaller footprint, ADR 0002 decision D0).
.PHONY: gostall

# Uses -lockorder -missingunlock -starvation only; -waitgroup -channel -livelock
# excluded (intra-procedural false positives on defer wg.Done() in goroutines,
# signal.Notify channels, and test spin loops).
gostall:
	@[ -x "$(GOSTALL)" ] || { echo "gostall not installed: go install github.com/erfanmomeniii/gostall/cmd/gostall@$(GOSTALL_VERSION)"; exit 1; }
	@echo "==> gostall"
	GOWORK=off "$(GOSTALL)" -lockorder -missingunlock -starvation ./...

preflight: fmt-check gostall
	@echo "==> go vet ./..."
	GOWORK=off go vet ./...
	@echo "==> go build ./..."
	GOWORK=off CGO_ENABLED=0 go build ./...
	@echo "==> go test ./..."
	$(MAKE) test
	$(MAKE) govulncheck

run: build
	./$(BINARY)

deploy:
	$(COMPOSE) build --no-cache $(SERVICE)
	$(COMPOSE) up -d --no-deps --force-recreate $(SERVICE)
	@echo "Deployed and restarted $(SERVICE)"

clean:
	rm -f $(BINARY)
