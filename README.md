# go-code-verify

Sandboxed build/test/lint execution service for
[go-code](https://github.com/anatolykoptev/go-code)'s `verify_environment`
feature (ADR 0002 Phase 1).

## What this is

go-code is a purely static code-intelligence MCP server — it never runs a
target repository's own build/test/install commands. `verify_environment`
closes that gap by actually executing the commands go-code's `envdetect`
package detects, so signals like `code_health`'s `buildable` sub-score
reflect ground truth instead of a static guess.

Doing that safely means running **arbitrary, potentially adversarial,
repo-authored code** — a fundamentally different trust requirement from
anything else go-code does. This service exists so that requirement never
touches go-code itself:

- **go-code never mounts `docker.sock`.** This service is the sole holder of
  Docker access in the deployment; a go-code compromise cannot start a
  single container.
- **This service never holds go-code's secrets.** It refuses to boot if
  `DATABASE_URL`, `GITHUB_TOKEN`, `LLM_API_KEY`, or any other go-code secret
  is present in its environment.
- **Both git-cloning the target repo and running its build/test/lint command
  happen inside gVisor (`runsc`) sandboxes** with `userns-remap`,
  `--network=none` for the actual job, capability drops, and hard resource
  caps — not bare processes on the host.

See [`docs/wire-contract.md`](docs/wire-contract.md) for the full request/
response schema, and go-code's
[ADR 0002](https://github.com/anatolykoptev/go-code/blob/main/docs/adr/0002-environment-detect-and-verify.md)
for the complete design and its three-round security review.

## Status

Build-only skeleton (implementation Phase 0 of
`plans/go-code/2026-07-06-verify-environment-phase1-implementation.md` in the
operator's deploy repo). The HTTP API, sandboxing, and job execution land in
later phases.

## Build

```bash
make preflight   # gofmt + vet + build + test + govulncheck
```
