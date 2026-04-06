# Goreleaser Setup Design — Issue #29

**Date:** 2026-04-05
**Author:** Anton Swartz
**Status:** Approved

## Overview

Set up goreleaser for automated cross-platform releases of `sshpub/dotfiles-cli`, plus CI workflow for test/build on every push.

## Decisions

- **9 build targets:** darwin (arm64/amd64), linux (arm64/amd64/386), windows (amd64/arm64/386), freebsd (amd64)
- **Archives:** tar.gz for unix, zip for windows
- **Two workflows:** CI (test+build on push/PR) and Release (goreleaser on tag push)
- **Semver tags only:** No `latest` tag. GitHub API `/releases/latest` handles that.

---

## 1. `.goreleaser.yml`

```yaml
project_name: dotfiles
builds:
  - env:
      - CGO_ENABLED=0
    goos:
      - darwin
      - linux
      - windows
      - freebsd
    goarch:
      - amd64
      - arm64
      - "386"
    ignore:
      - goos: darwin
        goarch: "386"
      - goos: freebsd
        goarch: arm64
      - goos: freebsd
        goarch: "386"
    ldflags:
      - -s -w -X github.com/sshpub/dotfiles-cli/cmd.Version={{.Version}}
    binary: dotfiles

archives:
  - format: tar.gz
    format_overrides:
      - goos: windows
        format: zip
    name_template: "{{ .ProjectName }}-{{ .Os }}-{{ .Arch }}"

checksum:
  name_template: "checksums.txt"

release:
  github:
    owner: sshpub
    name: dotfiles-cli
```

- `CGO_ENABLED=0` — static binaries, no runtime deps
- 9 targets (ignore rules remove impossible combos: darwin-386, freebsd-arm64, freebsd-386)
- Binary named `dotfiles`
- Version injected via ldflags matching Makefile convention
- Checksums included in release

---

## 2. CI Workflow (`.github/workflows/ci.yml`)

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: go test ./...
      - run: go build -o /dev/null .
```

Runs on every push/PR to main. Tests + build verify. Uses `go-version-file` to stay in sync with `go.mod`.

---

## 3. Release Workflow (`.github/workflows/release.yml`)

```yaml
name: Release
on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - uses: goreleaser/goreleaser-action@v6
        with:
          version: latest
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- `fetch-depth: 0` — goreleaser needs full history for changelog
- `contents: write` — permission to create releases
- `GITHUB_TOKEN` is automatic for public repos
- Triggers on `v*` tags (e.g., `git tag v0.1.0 && git push --tags`)

---

## 4. Release Process

```bash
git tag v0.1.0
git push --tags
# GitHub Actions runs goreleaser automatically
# Binaries + checksums uploaded to GitHub Releases
```

---

## 5. Deliverables

| File | Repo | Purpose |
|------|------|---------|
| `.goreleaser.yml` | dotfiles-cli | 9-target build config with checksums |
| `.github/workflows/ci.yml` | dotfiles-cli | Test + build on push/PR |
| `.github/workflows/release.yml` | dotfiles-cli | Goreleaser on tag push |

## 6. Out of Scope

- Tagging first release (manual when ready)
- `install.sh` one-liner (#28)
- `dotfiles self-update` (#26)
