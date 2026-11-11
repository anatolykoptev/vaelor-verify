# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); there are no tagged releases.

## [Unreleased]

### Changed
- Module renamed from `go-code-verify` to `vaelor-verify` (17 July 2026); private
  infrastructure references and internal plans removed from the tree.
- Preflight runs on a GitHub-hosted ARM runner, with `gostall` pinned to v1.0.0.

### Added
- Phase 0 skeleton (6 July 2026): build-only service with the wire contract in
  `docs/wire-contract.md`, `make preflight` gate (gofmt, gostall, vet, build, tests,
  govulncheck) and a CI status badge. The HTTP API, sandboxing and job execution are
  not implemented yet.
