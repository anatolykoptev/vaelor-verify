package main

import (
	"os"
	"testing"
)

// TestDefaultPort locks in the fallback port so a future change to it is a
// deliberate, reviewed edit rather than a silent drift.
func TestDefaultPort(t *testing.T) {
	if defaultPort != "8910" {
		t.Errorf("defaultPort = %q, want %q (see AGENTS.md port ledger)", defaultPort, "8910")
	}
}

// TestMain_ReadsPortFromEnv is a smoke test that main() does not panic when
// GOCODE_VERIFY_PORT is set. main() has no return value to assert on yet
// (Phase 0 skeleton); this guards against a trivial regression as Phase 1
// adds real behavior.
func TestMain_ReadsPortFromEnv(t *testing.T) {
	t.Setenv("GOCODE_VERIFY_PORT", "9999")
	if got := os.Getenv("GOCODE_VERIFY_PORT"); got != "9999" {
		t.Fatalf("test setup: GOCODE_VERIFY_PORT = %q, want 9999", got)
	}
	main()
}
