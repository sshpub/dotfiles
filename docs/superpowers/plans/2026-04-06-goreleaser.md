# Goreleaser Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up goreleaser for automated cross-platform releases and CI for the dotfiles-cli repo.

**Architecture:** `.goreleaser.yml` defines 9 build targets with static linking. Two GitHub Actions workflows — CI on push/PR, Release on tag push via goreleaser-action.

**Tech Stack:** GoReleaser, GitHub Actions

---

**Spec:** `docs/superpowers/specs/2026-04-05-goreleaser-design.md` (in sshpub/dotfiles repo)

**Working directory:** `~/code/sshpub/dotfiles-cli/`

**Branch:** `main` (direct commits — this is config, not feature code)

**File Map:**

| File | Purpose |
|------|---------|
| `.goreleaser.yml` | 9-target build config with checksums |
| `.github/workflows/ci.yml` | Test + build on push/PR to main |
| `.github/workflows/release.yml` | Goreleaser on semver tag push |

---

### Task 1: Goreleaser config

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/.goreleaser.yml`

- [ ] **Step 1: Create `.goreleaser.yml`**

Create `~/code/sshpub/dotfiles-cli/.goreleaser.yml`:

```yaml
version: 2

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

- [ ] **Step 2: Validate the config is valid YAML**

```bash
cd ~/code/sshpub/dotfiles-cli
python3 -c "import yaml; yaml.safe_load(open('.goreleaser.yml'))" && echo "Valid YAML"
```

Expected: "Valid YAML" (or use `yq` if available).

If python3 yaml isn't available:

```bash
cd ~/code/sshpub/dotfiles-cli
cat .goreleaser.yml | head -1
```

At minimum confirm the file exists and starts with `version: 2`.

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add .goreleaser.yml
git commit -m "feat: add goreleaser config for 9 cross-platform targets

Static binaries (CGO_ENABLED=0), tar.gz for unix, zip for windows.
Targets: darwin (arm64/amd64), linux (arm64/amd64/386),
windows (amd64/arm64/386), freebsd (amd64).
Checksums included in release."
```

---

### Task 2: CI workflow

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/.github/workflows/ci.yml`

- [ ] **Step 1: Create workflow directory**

```bash
mkdir -p ~/code/sshpub/dotfiles-cli/.github/workflows
```

- [ ] **Step 2: Create CI workflow**

Create `~/code/sshpub/dotfiles-cli/.github/workflows/ci.yml`:

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

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add .github/workflows/ci.yml
git commit -m "ci: add test and build workflow on push/PR to main"
```

---

### Task 3: Release workflow

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/.github/workflows/release.yml`

- [ ] **Step 1: Create release workflow**

Create `~/code/sshpub/dotfiles-cli/.github/workflows/release.yml`:

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

- [ ] **Step 2: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add .github/workflows/release.yml
git commit -m "ci: add goreleaser release workflow on tag push"
```

---

### Task 4: Push and verify CI

- [ ] **Step 1: Push to main**

```bash
cd ~/code/sshpub/dotfiles-cli
git push origin main
```

- [ ] **Step 2: Verify CI workflow runs**

```bash
gh run list --repo sshpub/dotfiles-cli --limit 1
```

Expected: A "CI" workflow run triggered by the push.

- [ ] **Step 3: Wait for CI to complete and verify**

```bash
gh run watch --repo sshpub/dotfiles-cli
```

Expected: CI passes (test + build succeed).

- [ ] **Step 4: Verify git log**

```bash
cd ~/code/sshpub/dotfiles-cli
git log --oneline -5
```

Expected: 3 new commits for goreleaser config, CI workflow, and release workflow.

---

## Task Dependency Graph

```
Task 1 (.goreleaser.yml) → Task 2 (ci.yml) → Task 3 (release.yml) → Task 4 (push + verify)
```

All sequential. Task 4 pushes everything and verifies CI runs.
