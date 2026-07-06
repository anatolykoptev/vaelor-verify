# Wire Contract — go-code ↔ go-code-verify

This is the entire coupling surface between the two repositories. Neither
repo imports the other's Go packages; `internal/envdetect`'s
`Command`/`Toolchain`/`Environment` types (go-code) never cross the wire —
go-code extracts their fields into this plain JSON shape.

Source of design: `github.com/anatolykoptev/go-code`
`docs/adr/0002-environment-detect-and-verify.md`, decisions D2–D6 (three
`architecture-security-cost` review rounds, 2026-07-04/06).

## Transport

- HTTP, POST only, one endpoint: `POST /verify`.
- Network: a dedicated `gocode-verify` docker-compose network,
  `internal: true`, attached to exactly go-code and go-code-verify — no
  other service, no host-published port.
- Auth: `Authorization: Bearer <token>` where `<token>` is
  `GOCODE_VERIFY_TOKEN` (≥32 bytes, CSPRNG-generated, provisioned via
  `~/deploy/krolik-server/.env`). Verified with `crypto/subtle.
  ConstantTimeCompare` over fixed-length SHA-256 digests. Mismatch or
  missing header → `401`, no body detail.
- Body: JSON, decoded with `encoding/json`'s `Decoder.DisallowUnknownFields`
  — any field not listed below is a hard `400`, not a silent ignore. This is
  the mechanism that makes "the request cannot carry a secret" a structural
  guarantee rather than a convention (ADR decision D3).

## Request

```json
{
  "repoURL": "https://github.com/owner/repo",
  "gitSHA": "a1b2c3d4e5f6...",
  "argv": ["go", "test", "./..."],
  "workDir": "services/api",
  "image": "golang:1-bookworm@sha256:...",
  "limits": {
    "timeoutSeconds": 300
  }
}
```

| Field | Type | Notes |
|---|---|---|
| `repoURL` | string | A repo reference, **never a filesystem path**. go-code-verify clones this itself (ADR decision D4) — go-code's own clone is never handed across the boundary. |
| `gitSHA` | string | The exact commit go-code resolved `argv` against. |
| `argv` | `[]string` | An argv slice — never a shell string. Must be one of the commands go-code's `envdetect.Detect` surfaced for this repo (detected-only, ADR decision D5); go-code-verify does not accept caller-invented commands. |
| `workDir` | string | Repo-relative working directory for the command. |
| `image` | string | A digest-pinned (`@sha256:...`) base image from the curated v1 table (ADR decision D5). A tag-only reference (e.g. `golang:1-bookworm` with no digest) is rejected — refuse-on-miss, never falls back to `:latest`. |
| `limits.timeoutSeconds` | int | Optional; capped server-side at the service's hard ceiling regardless of what's requested. |

## Response

```json
{
  "exitCode": 0,
  "cappedStdout": "...",
  "cappedStderr": "...",
  "durationMs": 4213,
  "killedReason": ""
}
```

| Field | Type | Notes |
|---|---|---|
| `exitCode` | int | The sandboxed command's exit code. **Attacker/repo-controlled — never treated as ground truth beyond "the process exited with this code."** `code_health`'s `buildable` sub-score reflects this plainly and MUST NOT upgrade the confidence of any other go-code signal (ADR decision D5 binding contract). |
| `cappedStdout` / `cappedStderr` | string | Capped at 1 MiB / 64 KiB respectively (mirrors `internal/fleet/ssh`'s `cappedWriter` in go-code). Treated as untrusted output — go-code must never forward these verbatim into an LLM prompt. |
| `durationMs` | int | Wall-clock time of the sandboxed job. |
| `killedReason` | string | Empty on normal exit; `"timeout"`, `"oom"`, or `"output_cap_exceeded"` otherwise. |

## Non-2xx responses

| Status | Meaning |
|---|---|
| `401` | Missing/invalid bearer token. |
| `400` | Malformed JSON, unknown field, or `image` missing a pinned digest. |
| `409` (`computing`) | This repo+SHA is already being verified — an *acceptance*; poll again. Mirrors go-code's `code_health` async convention. |
| `429` (`queue_full`) | The bounded job queue (depth 8) is full — a *rejection*, distinct from `computing`; the request was not enqueued. Back off and retry later. |
| `503` | Host admission gate refused (available memory < 6 GiB or PSI `memory some avg10` > 20) — try again once host pressure subsides. |

## What this contract deliberately does NOT carry

No field for `env`, `secrets`, `mounts`, `token`, or `dockerArgs` exists in
the request schema — `DisallowUnknownFields` turns any attempt to add one
into a hard error rather than a silent no-op. There is no field for a
filesystem path (only `repoURL`+`gitSHA`) and no field for an arbitrary
command string (only a pre-vetted `argv` slice). This is deliberate: the
contract itself is part of the security boundary, not just the code behind
it.
