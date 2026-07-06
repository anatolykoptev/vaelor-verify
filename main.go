// Command go-code-verify is the sandboxed execution service for go-code's
// verify_environment feature (ADR 0002 Phase 1,
// github.com/anatolykoptev/go-code/docs/adr/0002-environment-detect-and-verify.md).
//
// It is the SOLE holder of Docker socket access in the go-code deployment.
// go-code never mounts docker.sock; this service does, and nothing else
// about it is trusted with go-code's secrets (DATABASE_URL, GITHUB_TOKEN,
// LLM_API_KEY, Redis credentials) — see internal/envcheck for the boot-time
// guarantee.
//
// This is currently a build-only skeleton (Phase 0 of the implementation
// plan, plans/go-code/2026-07-06-verify-environment-phase1-implementation.md
// in the krolik-server deploy repo). The HTTP API, auth, and job execution
// land in Phase 1 onward.
package main

import (
	"log/slog"
	"os"
)

// defaultPort is the service's listen port when GOCODE_VERIFY_PORT is unset.
// Chosen from the next-free range recorded in the operator's port ledger.
const defaultPort = "8910"

func main() {
	port := os.Getenv("GOCODE_VERIFY_PORT")
	if port == "" {
		port = defaultPort
	}

	slog.Info("go-code-verify: skeleton build, HTTP API not yet implemented",
		slog.String("port", port))
}
