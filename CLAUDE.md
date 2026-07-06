# go-code-verify — agent rules

**Module**: `github.com/anatolykoptev/go-code-verify` | **Port**: 8910 (see `~/AGENTS.md` ports table)

## What this repo is, and why it is separate from go-code

This service executes a target repository's own build/test/lint commands
inside a sandbox, to back go-code's `verify_environment` feature (see
`docs/wire-contract.md` for the request/response schema, and go-code's
`docs/adr/0002-environment-detect-and-verify.md` for the full design —
three rounds of `architecture-security-cost` review, 2026-07-04/06).

It is a **separate repository and module from go-code on purpose**
(ADR decision D0), not a second `cmd/` binary in go-code's module: this is
the **sole holder of Docker socket access** in the deployment, while go-code
holds `DATABASE_URL`/`GITHUB_TOKEN`/`LLM_API_KEY`/Redis credentials. A
separate module makes "this service never imports go-code's secret-reading
packages" **structurally impossible to violate** — there is no import path
to them — rather than relying on lint/discipline in a shared module. The
only coupling to go-code is the wire contract (`docs/wire-contract.md`):
plain JSON over HTTP, no shared Go types.

**Public repo** — same discipline as go-code: no operator-specific secrets,
hostnames, or paths committed; `GOCODE_VERIFY_TOKEN` and friends live in env,
never in code.

## Non-negotiable invariants (do not weaken these without re-running
## `architecture-security-cost` review — see ADR 0002 for why each exists)

- **This service must never receive or hold any of go-code's secrets.**
  Boot-time deny-list + allowlist self-check refuses to start if
  `DATABASE_URL`, `LEARNINGS_DATABASE_URL`, `REDIS_URL`, `GITHUB_TOKEN`,
  `GITLAB_TOKEN`, `GITHUB_WEBHOOK_SECRET`, `LLM_API_KEY`, or
  `LLM_API_KEY_FALLBACK` is present and non-empty in its own environment.
- **Job containers get an explicit, minimal env slice — never
  `append(os.Environ(), ...)`.** This is the exact anti-pattern go-code's
  `internal/goanalysis/loader.go` was found to have; do not repeat it here,
  in the one binary where it would matter most.
- **All Docker/`os/exec` calls go through an `Execer`-style interface**
  (mirrors go-code's `internal/fleet/ssh/driver.go` pattern) — argv-slices
  only, never `sh -c` / shell-string composition, output capped
  (1 MiB stdout / 64 KiB stderr, cancel-on-overflow), a `fakeExecer` for
  tests.
- **Both the git-clone step and the build/test/lint step run inside a
  sandboxed job** (`docker run --runtime=runsc ...`) — neither ever runs as
  a bare process in this service's own PID namespace. The clone job is
  network-attached to `gocode-verify-egress` only; the build/test/lint job
  runs `--network=none`. This service's own HTTP listener is on the
  `gocode-verify` network only and is never attached to the egress network.
- **Request decoding uses `json.Decoder.DisallowUnknownFields()`.** An
  unrecognized field (`env`, `secrets`, `mounts`, `token`, `dockerArgs`, ...)
  is a hard `400`, not a silently-ignored key.
- **A job's exit code is repo-controlled, not ground truth.** `verified`
  means "the sandboxed command exited 0," full stop — never let it upgrade
  the confidence of any other signal on the go-code side.
- **Base images are pinned by digest (`@sha256:...`); refuse rather than
  fall back to `:latest`** when no pin exists for a requested image.
- **v1 scope: `build`/`test`/`lint` only.** No `install`-class execution, no
  caller-supplied argv (only argv go-code's `envdetect` actually detected),
  no `docker build` of a target repo's own Dockerfile.

## Build

```bash
make preflight   # gofmt + vet + build + test + govulncheck
```

No CGO, no database — `GOWORK=off CGO_ENABLED=0 go build -o bin/go-code-verify .`

## CI

Self-hosted runner `krolik-go-code-verify` (separate from go-code's own
runner — `.github/workflows/preflight.yml`), gate = `make preflight`. No
ephemeral-postgres step: this service has no database.

## Deploy

See `~/deploy/krolik-server/CLAUDE.md` for the compose stack this service is
part of, and
`~/deploy/krolik-server/plans/go-code/2026-07-06-verify-environment-phase1-implementation.md`
for the phased build-out this repo is Phase 0 of.
