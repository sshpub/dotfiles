# Dotfiles CLI Scaffold Design — Issue #22

**Date:** 2026-04-05
**Author:** Anton Swartz
**Status:** Approved

## Overview

Create the Go project scaffold for `sshpub/dotfiles-cli`. Produces a working binary with `dotfiles version`, the full stubbed command tree, cross-compilation for 9 targets, and package stubs for all Phase 4+ features.

## Decisions

- **CLI framework:** Cobra — handles the deep nested command tree (30+ subcommands across 3 levels)
- **Go module path:** `github.com/sshpub/dotfiles-cli`
- **No bubbletea yet** — added when TUI commands are implemented
- **All pkg/ dirs stubbed** — doc.go files showing architecture intent
- **All commands stubbed** — `fmt.Println("not implemented")`, full tree visible from day one

---

## 1. Repository Structure

```
dotfiles-cli/
├── main.go                    # Entry point — calls cmd.Execute()
├── go.mod                     # github.com/sshpub/dotfiles-cli
├── go.sum
├── Makefile                   # build, build-all, clean, test
├── CLAUDE.md                  # AI context
├── README.md                  # Basic readme
├── .gitignore                 # dist/, binaries, OS junk
├── cmd/
│   ├── root.go                # Root command + version subcommand
│   ├── setup.go               # setup, setup --non-interactive
│   ├── bootstrap.go           # bootstrap --force --dry-run
│   ├── update.go              # update --check --diff --core
│   ├── selfupdate.go          # self-update --check
│   ├── module.go              # module + all subcommands
│   ├── profile.go             # profile show, edit, wizard, export
│   ├── registry.go            # registry add, list, remove, sync
│   ├── migrate.go             # migrate <file>
│   ├── minimal.go             # minimal show, test, add-trigger, include, exclude
│   ├── platform.go            # platform (show detected info)
│   ├── doctor.go              # doctor (health check)
│   ├── cache.go               # cache rebuild, cache clear
│   └── sync.go                # sync status, sync check
├── pkg/
│   ├── module/doc.go          # Module discovery, loading, validation
│   ├── profile/doc.go         # Profile parsing, cache generation
│   ├── symlink/doc.go         # Symlink management
│   ├── installer/doc.go       # Package installation per platform
│   ├── registry/doc.go        # Registry management
│   ├── migrate/doc.go         # Migration analyzer
│   ├── selfupdate/doc.go      # Self-update from GH releases
│   └── ui/doc.go              # Terminal UI (bubbletea, added later)
└── dist/                      # Build output (gitignored)
```

---

## 2. Build System (Makefile)

```makefile
VERSION  := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS  := -s -w -X github.com/sshpub/dotfiles-cli/cmd.Version=$(VERSION)
BINARY   := dotfiles

build:
	go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY) .

build-all:
	GOOS=darwin  GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-darwin-arm64 .
	GOOS=darwin  GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-darwin-amd64 .
	GOOS=linux   GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-linux-arm64 .
	GOOS=linux   GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-linux-amd64 .
	GOOS=linux   GOARCH=386   go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-linux-386 .
	GOOS=windows GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-windows-amd64.exe .
	GOOS=windows GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-windows-arm64.exe .
	GOOS=windows GOARCH=386   go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-windows-386.exe .
	GOOS=freebsd GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o dist/$(BINARY)-freebsd-amd64 .

test:
	go test ./...

clean:
	rm -rf dist/
```

9 cross-compile targets. Version injected via `-ldflags`. Windows targets get `.exe` suffix.

---

## 3. Cobra Root Command and Version

`cmd/root.go` defines the root command and version subcommand. Version variable is set at build time via `-ldflags`.

`main.go` just calls `cmd.Execute()`.

`dotfiles version` prints the version string and exits.

---

## 4. Stubbed Command Tree

Every command from the design spec is registered as a Cobra command with `Run: func(...) { fmt.Println("not implemented") }`. One file per command group in `cmd/`.

Command groups:
- `setup` — setup, --non-interactive
- `bootstrap` — --force, --dry-run
- `update` — --check, --diff, --core
- `self-update` — --check
- `module` — list, info, enable, disable, install, override, reset, create, validate, add, update, search, browse
- `profile` — show, edit, wizard, export
- `registry` — add, list, remove, sync
- `migrate` — positional arg <file>
- `minimal` — show, test, add-trigger, include, exclude
- `platform` — shows detected info
- `doctor` — health check
- `cache` — rebuild, clear
- `sync` — status, check

---

## 5. Package Stubs

Each `pkg/*/doc.go` contains only a package comment:

```go
// Package module handles module discovery, loading, and validation.
package module
```

8 packages: module, profile, symlink, installer, registry, migrate, selfupdate, ui.

---

## 6. CLAUDE.md

Describes the repo, build commands, architecture, and conventions. Points to `sshpub/dotfiles` as the companion repo.

---

## 7. Acceptance Criteria

- [x] Repo scaffolded at sshpub/dotfiles-cli
- [x] `make build` produces a working binary
- [x] `make build-all` cross-compiles for 9 targets
- [x] `dotfiles version` works
- [x] Full command tree stubbed and visible via `dotfiles --help`
- [x] All pkg/ directories created with doc.go stubs
