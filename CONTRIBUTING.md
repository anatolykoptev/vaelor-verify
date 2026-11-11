# Contributing

Issues and pull requests are welcome. Read [CLAUDE.md](CLAUDE.md) first: this service
runs untrusted repository code and holds the only Docker access in its deployment, so
its invariants (no inherited environment, argv-only execution, sandboxed clone and
build, strict request decoding) are not negotiable.

## Build and test

Requires the Go version in `go.mod`.

```sh
make build        # static binary in bin/ (CGO_ENABLED=0)
make test         # go test -timeout 20m ./...
make lint         # gofmt check, then golangci-lint
make preflight    # gofmt, gostall, go vet, build, tests, govulncheck
```

CI runs `make preflight` on every pull request; run it before pushing. `gostall` is
installed at the pinned version when missing, `govulncheck` likewise.

## Commits and pull requests

- Use Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `ci:`, `chore:`), as
  in the history.
- Keep a pull request to one concern and describe what changed, why, and how you tested
  it using the template. A security-relevant change should say which invariant it
  touches.
- Behaviour changes need a test; Docker and `os/exec` calls go through the `Execer`
  interface so they can be tested with a fake.
- Never commit secrets, hostnames or local paths.
- Update [docs/INDEX.md](docs/INDEX.md) when you add or rename a document.

## Security

Report vulnerabilities as described in [SECURITY.md](SECURITY.md), not in public issues.
