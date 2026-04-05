# Dotfiles CLI Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the `sshpub/dotfiles-cli` Go project with a working binary, full stubbed command tree, cross-compilation, and package stubs.

**Architecture:** Cobra-based CLI with one file per command group in `cmd/`, library packages in `pkg/` as doc.go stubs. Version injected via ldflags at build time. Makefile handles 9 cross-compile targets.

**Tech Stack:** Go 1.25+, Cobra, Make

---

**Spec:** `docs/superpowers/specs/2026-04-05-dotfiles-cli-scaffold-design.md` (in sshpub/dotfiles repo)

**Working directory:** `~/code/sshpub/dotfiles-cli/`

**Branch:** `main` (greenfield repo, direct commits OK for initial scaffold)

**File Map:**

| File | Purpose |
|------|---------|
| `main.go` | Entry point |
| `go.mod` / `go.sum` | Go module + Cobra dependency |
| `Makefile` | build, build-all (9 targets), test, clean |
| `.gitignore` | dist/, binaries, OS junk |
| `CLAUDE.md` | AI context |
| `README.md` | Basic readme |
| `cmd/root.go` | Root command + version |
| `cmd/setup.go` | setup stub |
| `cmd/bootstrap.go` | bootstrap stub |
| `cmd/update.go` | update stub |
| `cmd/selfupdate.go` | self-update stub |
| `cmd/module.go` | module + all subcommands stub |
| `cmd/profile.go` | profile subcommands stub |
| `cmd/registry.go` | registry subcommands stub |
| `cmd/migrate.go` | migrate stub |
| `cmd/minimal.go` | minimal subcommands stub |
| `cmd/platform.go` | platform stub |
| `cmd/doctor.go` | doctor stub |
| `cmd/cache.go` | cache subcommands stub |
| `cmd/sync.go` | sync subcommands stub |
| `pkg/*/doc.go` | 8 package stubs |

---

### Task 1: Initialize Go module and core files

**Files:**
- Create: `go.mod`
- Create: `main.go`
- Create: `.gitignore`
- Create: `CLAUDE.md`
- Create: `README.md`

- [ ] **Step 1: Initialize Go module**

```bash
cd ~/code/sshpub/dotfiles-cli
go mod init github.com/sshpub/dotfiles-cli
```

- [ ] **Step 2: Add Cobra dependency**

```bash
cd ~/code/sshpub/dotfiles-cli
go get github.com/spf13/cobra@latest
```

- [ ] **Step 3: Create main.go**

Create `~/code/sshpub/dotfiles-cli/main.go`:

```go
package main

import "github.com/sshpub/dotfiles-cli/cmd"

func main() {
	cmd.Execute()
}
```

- [ ] **Step 4: Create .gitignore**

Create `~/code/sshpub/dotfiles-cli/.gitignore`:

```
# Build output
dist/
*.exe

# OS
.DS_Store
Desktop.ini
._*
Thumbs.db

# Editor
*.swp
*.swo
*~
.vscode/
.idea/

# Go
vendor/

# AI tooling
.superpowers/
```

- [ ] **Step 5: Create CLAUDE.md**

Create `~/code/sshpub/dotfiles-cli/CLAUDE.md`:

```markdown
# CLAUDE.md — sshpub/dotfiles-cli

Go CLI for the sshpub/dotfiles framework. Manages profiles, modules, caches, and symlinks.

## Build

- `make build` — builds to `dist/dotfiles`
- `make build-all` — cross-compiles for 9 targets
- `make test` — runs tests
- `make clean` — removes dist/

## Architecture

- `cmd/` — Cobra commands (one file per command group)
- `pkg/` — library packages (module, profile, symlink, installer, registry, migrate, selfupdate, ui)
- Version injected via `-ldflags` at build time

## Conventions

- JSON for all config, never YAML
- Companion repo: `sshpub/dotfiles` (the shell framework this CLI manages)
- Design specs and plans live in the companion repo under `docs/superpowers/`
```

- [ ] **Step 6: Create README.md**

Create `~/code/sshpub/dotfiles-cli/README.md`:

```markdown
# dotfiles-cli

CLI tool for the [sshpub/dotfiles](https://github.com/sshpub/dotfiles) modular dotfiles framework.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sshpub/dotfiles/main/install.sh | bash
```

## Build from source

```bash
git clone https://github.com/sshpub/dotfiles-cli.git
cd dotfiles-cli
make build
./dist/dotfiles version
```

## Usage

```bash
dotfiles setup          # First-run wizard
dotfiles module list    # List available modules
dotfiles doctor         # Health check
dotfiles version        # Print version
```

## License

Apache 2.0
```

- [ ] **Step 7: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add go.mod go.sum main.go .gitignore CLAUDE.md README.md
git commit -m "feat: initialize Go module with Cobra dependency"
```

---

### Task 2: Root command and version

**Files:**
- Create: `cmd/root.go`

- [ ] **Step 1: Create cmd directory and root.go**

Create `~/code/sshpub/dotfiles-cli/cmd/root.go`:

```go
package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// Version is set at build time via -ldflags
var Version = "dev"

var rootCmd = &cobra.Command{
	Use:   "dotfiles",
	Short: "Modular dotfiles manager",
	Long:  "A modular, cross-platform dotfiles framework CLI.\n\nManages profiles, modules, caches, and symlinks for the sshpub/dotfiles framework.",
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the CLI version",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println(Version)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}

// Execute runs the root command.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd ~/code/sshpub/dotfiles-cli
go build -o dist/dotfiles .
```

Expected: Binary created at `dist/dotfiles`.

- [ ] **Step 3: Test version command**

```bash
cd ~/code/sshpub/dotfiles-cli
./dist/dotfiles version
```

Expected: `dev`

- [ ] **Step 4: Test help output**

```bash
cd ~/code/sshpub/dotfiles-cli
./dist/dotfiles --help
```

Expected: Shows "Modular dotfiles manager" with `version` subcommand listed.

- [ ] **Step 5: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add cmd/root.go
git commit -m "feat: add Cobra root command and version subcommand"
```

---

### Task 3: Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Create Makefile**

Create `~/code/sshpub/dotfiles-cli/Makefile`:

```makefile
VERSION  := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS  := -s -w -X github.com/sshpub/dotfiles-cli/cmd.Version=$(VERSION)
BINARY   := dotfiles

.PHONY: build build-all test clean

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

- [ ] **Step 2: Test make build**

```bash
cd ~/code/sshpub/dotfiles-cli
make clean && make build
./dist/dotfiles version
```

Expected: Version output (git hash or `dev`).

- [ ] **Step 3: Test make build-all**

```bash
cd ~/code/sshpub/dotfiles-cli
make clean && make build-all
ls -la dist/
```

Expected: 9 binaries in `dist/` (darwin-arm64, darwin-amd64, linux-arm64, linux-amd64, linux-386, windows-amd64.exe, windows-arm64.exe, windows-386.exe, freebsd-amd64).

- [ ] **Step 4: Test make test**

```bash
cd ~/code/sshpub/dotfiles-cli
make test
```

Expected: `ok` (no test files yet, but no errors).

- [ ] **Step 5: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
make clean
git add Makefile
git commit -m "feat: add Makefile with 9 cross-compile targets"
```

---

### Task 4: Stub all command files

**Files:**
- Create: `cmd/setup.go`
- Create: `cmd/bootstrap.go`
- Create: `cmd/update.go`
- Create: `cmd/selfupdate.go`
- Create: `cmd/module.go`
- Create: `cmd/profile.go`
- Create: `cmd/registry.go`
- Create: `cmd/migrate.go`
- Create: `cmd/minimal.go`
- Create: `cmd/platform.go`
- Create: `cmd/doctor.go`
- Create: `cmd/cache.go`
- Create: `cmd/sync.go`

- [ ] **Step 1: Create cmd/setup.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var setupCmd = &cobra.Command{
	Use:   "setup",
	Short: "First-run setup wizard",
	Long:  "Interactive setup wizard for configuring dotfiles on a new machine.",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	setupCmd.Flags().Bool("non-interactive", false, "Run setup without prompts (for automation)")
	rootCmd.AddCommand(setupCmd)
}
```

- [ ] **Step 2: Create cmd/bootstrap.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var bootstrapCmd = &cobra.Command{
	Use:   "bootstrap",
	Short: "Create symlinks for core and enabled modules",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	bootstrapCmd.Flags().Bool("force", false, "Skip confirmation prompts")
	bootstrapCmd.Flags().Bool("dry-run", false, "Show what would be linked")
	rootCmd.AddCommand(bootstrapCmd)
}
```

- [ ] **Step 3: Create cmd/update.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var updateCmd = &cobra.Command{
	Use:   "update",
	Short: "Pull latest, rebuild cache, re-link",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	updateCmd.Flags().Bool("check", false, "Just check, don't apply")
	updateCmd.Flags().Bool("diff", false, "Show what changed before applying")
	updateCmd.Flags().Bool("core", false, "Fetch upstream dotfiles-core updates")
	rootCmd.AddCommand(updateCmd)
}
```

- [ ] **Step 4: Create cmd/selfupdate.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var selfUpdateCmd = &cobra.Command{
	Use:   "self-update",
	Short: "Update the CLI binary from GitHub releases",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	selfUpdateCmd.Flags().Bool("check", false, "Just check, don't install")
	rootCmd.AddCommand(selfUpdateCmd)
}
```

- [ ] **Step 5: Create cmd/module.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var moduleCmd = &cobra.Command{
	Use:   "module",
	Short: "Module management",
	Long:  "List, enable, disable, install, and manage dotfiles modules.",
}

var moduleListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all modules with enabled/disabled status",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleBrowseCmd = &cobra.Command{
	Use:   "browse",
	Short: "Interactive TUI module browser",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleInfoCmd = &cobra.Command{
	Use:   "info [name]",
	Short: "Show module details, sections, and install recipes",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleEnableCmd = &cobra.Command{
	Use:   "enable [name]",
	Short: "Enable a module in the profile",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleDisableCmd = &cobra.Command{
	Use:   "disable [name]",
	Short: "Disable a module in the profile",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleInstallCmd = &cobra.Command{
	Use:   "install [name]",
	Short: "Install a module's packages",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleOverrideCmd = &cobra.Command{
	Use:   "override [section]",
	Short: "Clone a section to overrides",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleResetCmd = &cobra.Command{
	Use:   "reset [section]",
	Short: "Remove override, restore module default",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleCreateCmd = &cobra.Command{
	Use:   "create [name]",
	Short: "Scaffold a new module from template",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleValidateCmd = &cobra.Command{
	Use:   "validate [name]",
	Short: "Validate module.json and section guards",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleAddCmd = &cobra.Command{
	Use:   "add [registry/name]",
	Short: "Install a module from a registry",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleUpdateCmd = &cobra.Command{
	Use:   "update [name]",
	Short: "Update module(s) from registry",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var moduleSearchCmd = &cobra.Command{
	Use:   "search [query]",
	Short: "Search all registries for modules",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	moduleListCmd.Flags().Bool("interactive", false, "TUI browser with search/toggle")
	moduleInstallCmd.Flags().Bool("all", false, "Install all enabled modules' packages")
	moduleOverrideCmd.Flags().Bool("local", false, "Clone to ~/.dotfiles/local/ instead")
	moduleOverrideCmd.Flags().Bool("disable", false, "Just disable, don't clone")
	moduleUpdateCmd.Flags().Bool("all", false, "Update all registry-installed modules")
	moduleUpdateCmd.Flags().Bool("check", false, "Show available updates without applying")

	moduleCmd.AddCommand(moduleListCmd)
	moduleCmd.AddCommand(moduleBrowseCmd)
	moduleCmd.AddCommand(moduleInfoCmd)
	moduleCmd.AddCommand(moduleEnableCmd)
	moduleCmd.AddCommand(moduleDisableCmd)
	moduleCmd.AddCommand(moduleInstallCmd)
	moduleCmd.AddCommand(moduleOverrideCmd)
	moduleCmd.AddCommand(moduleResetCmd)
	moduleCmd.AddCommand(moduleCreateCmd)
	moduleCmd.AddCommand(moduleValidateCmd)
	moduleCmd.AddCommand(moduleAddCmd)
	moduleCmd.AddCommand(moduleUpdateCmd)
	moduleCmd.AddCommand(moduleSearchCmd)
	rootCmd.AddCommand(moduleCmd)
}
```

- [ ] **Step 6: Create cmd/profile.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var profileCmd = &cobra.Command{
	Use:   "profile",
	Short: "Profile management",
}

var profileShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Display current profile",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var profileEditCmd = &cobra.Command{
	Use:   "edit",
	Short: "Open profile in $EDITOR",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var profileWizardCmd = &cobra.Command{
	Use:   "wizard",
	Short: "Re-run interactive profile wizard",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var profileExportCmd = &cobra.Command{
	Use:   "export",
	Short: "Export profile to share as example",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	profileCmd.AddCommand(profileShowCmd)
	profileCmd.AddCommand(profileEditCmd)
	profileCmd.AddCommand(profileWizardCmd)
	profileCmd.AddCommand(profileExportCmd)
	rootCmd.AddCommand(profileCmd)
}
```

- [ ] **Step 7: Create cmd/registry.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var registryCmd = &cobra.Command{
	Use:   "registry",
	Short: "Registry management",
}

var registryAddCmd = &cobra.Command{
	Use:   "add [name] [url]",
	Short: "Add a module registry",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var registryListCmd = &cobra.Command{
	Use:   "list",
	Short: "List configured registries",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var registryRemoveCmd = &cobra.Command{
	Use:   "remove [name]",
	Short: "Remove a registry",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var registrySyncCmd = &cobra.Command{
	Use:   "sync",
	Short: "Pull latest from all registries",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	registryAddCmd.Flags().Bool("private", false, "Mark as private (SSH auth)")
	registryCmd.AddCommand(registryAddCmd)
	registryCmd.AddCommand(registryListCmd)
	registryCmd.AddCommand(registryRemoveCmd)
	registryCmd.AddCommand(registrySyncCmd)
	rootCmd.AddCommand(registryCmd)
}
```

- [ ] **Step 8: Create cmd/migrate.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var migrateCmd = &cobra.Command{
	Use:   "migrate [file]",
	Short: "Analyze existing dotfiles and suggest modules",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	rootCmd.AddCommand(migrateCmd)
}
```

- [ ] **Step 9: Create cmd/minimal.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var minimalCmd = &cobra.Command{
	Use:   "minimal",
	Short: "Minimal mode management",
}

var minimalShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show what loads in minimal mode",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var minimalTestCmd = &cobra.Command{
	Use:   "test",
	Short: "Spawn a minimal shell to try it",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var minimalAddTriggerCmd = &cobra.Command{
	Use:   "add-trigger [ENV_VAR]",
	Short: "Add a new AI tool trigger",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var minimalIncludeCmd = &cobra.Command{
	Use:   "include [module]",
	Short: "Add module to minimal mode",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var minimalExcludeCmd = &cobra.Command{
	Use:   "exclude [module]",
	Short: "Remove module from minimal mode",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	minimalCmd.AddCommand(minimalShowCmd)
	minimalCmd.AddCommand(minimalTestCmd)
	minimalCmd.AddCommand(minimalAddTriggerCmd)
	minimalCmd.AddCommand(minimalIncludeCmd)
	minimalCmd.AddCommand(minimalExcludeCmd)
	rootCmd.AddCommand(minimalCmd)
}
```

- [ ] **Step 10: Create cmd/platform.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var platformCmd = &cobra.Command{
	Use:   "platform",
	Short: "Show detected platform information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	rootCmd.AddCommand(platformCmd)
}
```

- [ ] **Step 11: Create cmd/doctor.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Health check for symlinks, modules, profile, and dependencies",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	rootCmd.AddCommand(doctorCmd)
}
```

- [ ] **Step 12: Create cmd/cache.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var cacheCmd = &cobra.Command{
	Use:   "cache",
	Short: "Cache management",
}

var cacheRebuildCmd = &cobra.Command{
	Use:   "rebuild",
	Short: "Regenerate shell cache",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var cacheClearCmd = &cobra.Command{
	Use:   "clear",
	Short: "Clear all cached state",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	cacheCmd.AddCommand(cacheRebuildCmd)
	cacheCmd.AddCommand(cacheClearCmd)
	rootCmd.AddCommand(cacheCmd)
}
```

- [ ] **Step 13: Create cmd/sync.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var syncCmd = &cobra.Command{
	Use:   "sync",
	Short: "Sync status and background fetch",
}

var syncStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show sync state",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

var syncCheckCmd = &cobra.Command{
	Use:   "check",
	Short: "Background fetch and update cache",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("not implemented")
	},
}

func init() {
	syncCmd.AddCommand(syncStatusCmd)
	syncCmd.AddCommand(syncCheckCmd)
	rootCmd.AddCommand(syncCmd)
}
```

- [ ] **Step 14: Verify it compiles**

```bash
cd ~/code/sshpub/dotfiles-cli
make build
```

Expected: Compiles without errors.

- [ ] **Step 15: Verify full help tree**

```bash
cd ~/code/sshpub/dotfiles-cli
./dist/dotfiles --help
./dist/dotfiles module --help
./dist/dotfiles module list --help
```

Expected: All commands visible in help output. `module` shows 13 subcommands.

- [ ] **Step 16: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add cmd/
git commit -m "feat: stub full command tree (setup, module, profile, registry, etc.)

All commands from the design spec registered as Cobra commands.
Each prints 'not implemented' — future issues fill in the logic."
```

---

### Task 5: Package stubs

**Files:**
- Create: `pkg/module/doc.go`
- Create: `pkg/profile/doc.go`
- Create: `pkg/symlink/doc.go`
- Create: `pkg/installer/doc.go`
- Create: `pkg/registry/doc.go`
- Create: `pkg/migrate/doc.go`
- Create: `pkg/selfupdate/doc.go`
- Create: `pkg/ui/doc.go`

- [ ] **Step 1: Create all package stubs**

Create `~/code/sshpub/dotfiles-cli/pkg/module/doc.go`:
```go
// Package module handles module discovery, loading, and validation.
package module
```

Create `~/code/sshpub/dotfiles-cli/pkg/profile/doc.go`:
```go
// Package profile handles profile parsing and cache generation.
package profile
```

Create `~/code/sshpub/dotfiles-cli/pkg/symlink/doc.go`:
```go
// Package symlink manages symlink creation and removal for dotfiles.
package symlink
```

Create `~/code/sshpub/dotfiles-cli/pkg/installer/doc.go`:
```go
// Package installer handles per-platform package installation.
package installer
```

Create `~/code/sshpub/dotfiles-cli/pkg/registry/doc.go`:
```go
// Package registry manages module registry configuration and syncing.
package registry
```

Create `~/code/sshpub/dotfiles-cli/pkg/migrate/doc.go`:
```go
// Package migrate analyzes existing dotfiles and suggests modules.
package migrate
```

Create `~/code/sshpub/dotfiles-cli/pkg/selfupdate/doc.go`:
```go
// Package selfupdate handles CLI binary updates from GitHub releases.
package selfupdate
```

Create `~/code/sshpub/dotfiles-cli/pkg/ui/doc.go`:
```go
// Package ui provides terminal UI components (bubbletea, added later).
package ui
```

- [ ] **Step 2: Verify everything compiles**

```bash
cd ~/code/sshpub/dotfiles-cli
make test
```

Expected: `ok` — no errors.

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add pkg/
git commit -m "feat: add package stubs for module, profile, symlink, installer, registry, migrate, selfupdate, ui"
```

---

### Task 6: Final verification

- [ ] **Step 1: Clean build and cross-compile**

```bash
cd ~/code/sshpub/dotfiles-cli
make clean && make build-all
ls dist/ | wc -l
```

Expected: 9 binaries.

- [ ] **Step 2: Verify version injection**

```bash
cd ~/code/sshpub/dotfiles-cli
./dist/dotfiles-linux-amd64 version
```

Expected: Git hash (not `dev`).

- [ ] **Step 3: Spot check a few commands**

```bash
cd ~/code/sshpub/dotfiles-cli
./dist/dotfiles-linux-amd64 setup
./dist/dotfiles-linux-amd64 module list
./dist/dotfiles-linux-amd64 doctor
```

Expected: All print `not implemented`.

- [ ] **Step 4: Clean up dist**

```bash
cd ~/code/sshpub/dotfiles-cli
make clean
```

- [ ] **Step 5: Verify git log**

```bash
cd ~/code/sshpub/dotfiles-cli
git log --oneline
```

Expected: ~5 commits covering the full scaffold.

---

## Task Dependency Graph

```
Task 1 (go mod + core files) → Task 2 (root cmd + version) → Task 3 (Makefile) → Task 4 (all command stubs) → Task 5 (pkg stubs) → Task 6 (final verification)
```

All tasks are sequential.
