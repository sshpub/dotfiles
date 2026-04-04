# Dotfiles Overhaul — Design Specification

**Date:** 2026-04-04
**Author:** Anton Swartz
**Status:** Draft

## Overview

Complete overhaul and restructuring of the dotfiles repository into a modular, multi-machine, AI-aware system. The project splits into two public repos under `github.com/sshpub` (part of the larger ssh.pub ecosystem) plus the user's personal fork:

- **`sshpub/dotfiles-cli`** — Go binary distributed via GitHub Releases. Self-updating.
- **`sshpub/dotfiles`** — The forkable framework: module system, loader, default modules, sane defaults. Versioned.
- **`necrogami/dotfiles`** — Anton's personal fork of dotfiles-core. Replaces the current repo. Personal modules, profiles for 6 machines, overrides, private registries.

### Target Users

People who already have dotfiles and want to reorganize. Not beginners, not people who need hand-holding — these are experienced CLI users who see the mess in their shell config and want structure. They'll fork, make it theirs, and own it.

### Success Criteria

- Shell startup under 200ms (full interactive), under 50ms (minimal/AI mode)
- Any of the 6 current machines (2 macOS, 2 Linux, 2 WSL) can be set up with one command
- Adding a new module = adding a directory
- AI CLI tools (Claude, Gemini, Codex, OpenCode, Grok) get a clean, fast shell
- Others can fork dotfiles-core and have a working system immediately

---

## Architecture

### Repository Structure (dotfiles-core)

```
dotfiles-core/
├── CLAUDE.md                      # Root — repo overview, key principles (~30 lines)
├── .claudeignore                  # Exclude binaries, themes, generated files
├── .gitignore
├── README.md
├── VERSION                        # Core framework version (semver)
├── install.sh                     # One-liner bootstrap script
│
├── core/                          # Always loaded — the thin foundation
│   ├── CLAUDE.md
│   ├── platform.sh                # Platform detection (OS, arch, distro, pkg manager)
│   ├── loader.sh                  # Module discovery, section guards, minimal mode
│   ├── path.sh                    # Base PATH management
│   ├── exports.sh                 # Base environment variables
│   ├── prompt.sh                  # Prompt configuration (oh-my-posh / starship / fallback)
│   ├── aliases.sh                 # Essential aliases (.., ll, mkd, reload)
│   ├── functions.sh               # Essential functions (extract, mkd, server, backup)
│   ├── completions.sh             # Base completion setup
│   └── sync-check.sh              # Cached git sync check + shell notification
│
├── modules/                       # Self-describing feature modules
│   ├── CLAUDE.md                  # Module system conventions
│   ├── git/
│   │   ├── module.json
│   │   ├── CLAUDE.md
│   │   ├── aliases.sh
│   │   ├── functions.sh
│   │   └── config/                # .gitconfig, .gitignore, .gitattributes
│   ├── kubernetes/
│   ├── cloud/
│   ├── containers/
│   ├── python/
│   ├── node/
│   ├── rust/
│   ├── vim/
│   ├── tmux/
│   ├── fzf/
│   ├── modern-tools/              # eza, bat, ripgrep, fd, zoxide
│   └── ...
│
├── overrides/                     # Repo-level overrides (tracked in git)
│   └── CLAUDE.md
│
├── profiles/                      # Example profiles + schema
│   ├── CLAUDE.md
│   ├── schema.json                # JSON schema for ~/.dotfiles.json
│   └── examples/
│       ├── work-macos.json
│       ├── personal-linux.json
│       └── personal-wsl.json
│
├── platform/                      # Platform-specific core overrides
│   ├── macos.sh                   # Clipboard, open, Homebrew setup
│   ├── linux.sh                   # Linux-specific core
│   └── wsl.sh                     # WSL interop, clipboard, Windows paths
│
├── setup/                         # Installation scripts
│   ├── bootstrap.sh               # Symlink creation
│   ├── macos-defaults.sh          # macOS system preferences
│   └── fonts.sh                   # Font installation
│
└── docs/
    ├── MODULE-SPEC.md             # Module contract for marketplace authors
    └── TROUBLESHOOTING.md
```

GitHub Wiki for `dotfiles-core` hosts extensive documentation and guides:
- Getting started (new users)
- Migration guide (existing dotfiles)
- Module authoring guide
- Registry/marketplace guide
- Per-platform guides (macOS, Linux, WSL)
- CLI reference

### Repository Structure (dotfiles-cli)

```
dotfiles-cli/
├── main.go
├── cmd/                           # CLI commands
├── pkg/
│   ├── module/                    # Module discovery, loading, validation
│   ├── profile/                   # Profile parsing, cache generation
│   ├── symlink/                   # Symlink management
│   ├── installer/                 # Package installation per platform
│   ├── registry/                  # Registry management
│   ├── migrate/                   # Migration analyzer
│   ├── selfupdate/                # Self-update from GH releases
│   └── ui/                        # Terminal UI (bubbletea for TUI mode)
├── go.mod
├── Makefile                       # Cross-compile for 4 targets
└── .goreleaser.yml                # Automated releases
```

---

## Loading System

### Shell Startup Sequence

```
~/.bash_profile (symlink -> dotfiles/.bash_profile)
│
├─ 1. CORE ESSENTIALS (always loaded)
│  ├─ core/platform.sh           # Detect OS, arch, distro, pkg manager
│  ├─ core/loader.sh             # Define dotfiles_section(), load_module(), minimal mode
│  ├─ core/path.sh               # Base PATH (~/.local/bin, ~/bin)
│  └─ core/exports.sh            # EDITOR, LANG, HISTSIZE, etc.
│
├─ 2. MINIMAL MODE CHECK
│  └─ If AI tool / CI detected -> load profile-specified minimal extras, then return
│     (skips everything below — no aliases, no modules, no prompt)
│
├─ 3. CORE INTERACTIVE (skipped in minimal mode)
│  ├─ core/aliases.sh            # .., ll, la, mkd, reload
│  ├─ core/functions.sh          # extract, server, mkd, backup
│  └─ core/completions.sh        # Base bash completion setup
│
├─ 4. PLATFORM LAYER
│  └─ platform/{detected}.sh     # macos.sh, linux.sh, or wsl.sh
│
├─ 5. LOAD PROFILE
│  └─ Read cached profile        # CLI pre-generates shell-sourceable cache
│     Build DOTFILES_ENABLED_MODULES and DOTFILES_DISABLED_SECTIONS
│
├─ 6. MODULE LOADING (for each enabled module)
│  ├─ a. Check platform compatibility (from module.json cache)
│  ├─ b. Source shell files in load_order with section guards
│  └─ c. Add module PATH entries
│
├─ 7. OVERRIDES
│  ├─ overrides/*.sh             # Repo-level (tracked, all machines)
│  └─ ~/.dotfiles/local/*.sh     # Local-level (untracked, this machine)
│
├─ 8. PRIVATE CONFIG
│  ├─ ~/.extra                   # Secrets, API keys, work credentials
│  └─ ~/.local                   # Additional local config
│
├─ 9. PROMPT
│  └─ core/prompt.sh             # Oh My Posh / Starship / fallback
│
└─ 10. SYNC CHECK
    └─ core/sync-check.sh        # Read cached state, notify if behind
```

### Section Guard System

Defined in `core/loader.sh`. Modules wrap shell blocks in guards that check the disabled list:

```bash
dotfiles_section() {
  local section="$1"
  [[ ! " ${DOTFILES_DISABLED_SECTIONS[*]} " =~ " ${section} " ]]
}

# Usage:
dotfiles_section "git.shortcuts" && {
  alias g='git'
  alias gs='git status'
}
```

If a section is in `DOTFILES_DISABLED_SECTIONS` (populated from the profile), the entire block is skipped — never parsed, never executed.

### Minimal Mode (AI / CI)

Detects non-interactive contexts via environment variables and exits early after loading only platform, PATH, and exports.

```bash
DOTFILES_MINIMAL_TRIGGERS=(
  CLAUDE_CODE CODEX GEMINI_CLI OPENCODE GROK_CLI
  CI GITHUB_ACTIONS GITLAB_CI
)

dotfiles_is_minimal() {
  [[ "$DOTFILES_MINIMAL" == "true" ]] && return 0
  for var in "${DOTFILES_MINIMAL_TRIGGERS[@]}"; do
    [[ -n "${!var}" ]] && return 0
  done
  return 1
}
```

Profile-configurable:

```json
{
  "minimal_mode": {
    "env_triggers": ["CLAUDE_CODE", "CODEX", "GEMINI_CLI", "CI"],
    "always_load": ["platform", "path", "exports"],
    "include_modules": ["git"],
    "never_load": ["prompt", "atuin", "ohmyposh", "completions", "sync-check"]
  }
}
```

### Performance Budget

- **Minimal mode:** <50ms startup
- **Full interactive:** <200ms startup
- **Profile parsing:** CLI pre-generates a shell-sourceable cache from JSON (~1ms to source)
- **Module discovery:** Cached — CLI builds a module manifest on `dotfiles update`
- **Section guards:** Array lookup, negligible per-check
- **Sync check:** Reads cache file only, no network on startup

---

## Module Contract

### Module Structure

```
modules/{name}/
├── module.json          # Required — metadata, install recipes, sections
├── CLAUDE.md            # Optional — scoped AI context
├── aliases.sh           # Optional — aliases with section guards
├── functions.sh         # Optional — functions with section guards
├── completions.sh       # Optional — tab completion setup
├── path.sh              # Optional — PATH additions
├── exports.sh           # Optional — environment variables
└── config/              # Optional — config files to symlink
```

### module.json Specification

```json
{
  "name": "kubernetes",
  "version": "1.0.0",
  "description": "Kubernetes CLI tools, aliases, and shell helpers",
  "author": "Anton Swartz",

  "platforms": ["macos", "linux", "wsl"],

  "dependencies": ["containers"],

  "sections": {
    "kubernetes.core": "Base kubectl aliases and functions",
    "kubernetes.helm": "Helm package manager aliases",
    "kubernetes.k9s": "K9s terminal UI shortcuts",
    "kubernetes.ctx": "Context and namespace switching helpers"
  },

  "shell": {
    "load_order": ["exports.sh", "path.sh", "aliases.sh", "functions.sh", "completions.sh"]
  },

  "install": {
    "macos": {
      "brew": ["kubectl", "helm", "k9s", "kubectx"]
    },
    "linux": {
      "apt": ["kubectl"],
      "snap": ["helm --classic"],
      "binary": [
        {
          "name": "k9s",
          "url": "https://github.com/derailed/k9s/releases/latest",
          "arch": { "amd64": "k9s_Linux_amd64.tar.gz", "arm64": "k9s_Linux_arm64.tar.gz" }
        }
      ]
    },
    "wsl": {
      "inherit": "linux"
    }
  },

  "symlinks": {
    "config/.kube/config.template": "~/.kube/config.template"
  },

  "hooks": {
    "post_install": "echo 'Run: kubectl cluster-info to verify'",
    "post_enable": "echo 'Kubernetes module enabled. Reload shell.'"
  }
}
```

Minimal module (simplest case):

```json
{
  "name": "modern-tools",
  "version": "1.0.0",
  "description": "Aliases for eza, bat, ripgrep, fd, zoxide",
  "sections": {
    "modern-tools.listing": "eza/exa ls replacements",
    "modern-tools.cat": "bat as cat replacement",
    "modern-tools.search": "ripgrep and fd aliases",
    "modern-tools.cd": "zoxide smart cd"
  },
  "shell": {
    "load_order": ["aliases.sh"]
  }
}
```

### Contract Rules

**MUST:**
- Have a `module.json` with name, version, description
- Use `dotfiles_section()` guards for all shell blocks
- Use `{module_name}.{section}` naming for sections
- Declare all sections in module.json
- Be self-contained — no references to other module internals

**MUST NOT:**
- Modify PATH outside of `path.sh`
- Source files from other modules directly
- Write to files outside the module directory
- Contain secrets or machine-specific values
- Have side effects on load (no network calls, no prompts)

### Config Conflict Resolution

When a module wants to symlink a config that already exists:

```
Config conflict detected:
  ~/.vimrc already exists (not managed by dotfiles)

  [b] Backup & link  — move to ~/.vimrc.backup.20260404, symlink module's
  [m] Merge          — open a diff between yours and the module's version
  [s] Skip           — keep yours, don't symlink
  [a] Adopt          — copy your file INTO the module, then symlink
```

Choice is recorded in `~/.dotfiles.json` so it doesn't re-prompt:

```json
{
  "modules": {
    "vim": {
      "shell": true,
      "symlinks": { ".vimrc": "adopted" }
    }
  }
}
```

---

## Profile System

### Machine Profile (~/.dotfiles.json)

```json
{
  "_comment": "Machine profile for WSL desktop - Anton",
  "role": ["personal", "work"],
  "platform": {
    "_comment": "Auto-detected on first run, override if needed",
    "os": "linux",
    "variant": "wsl",
    "distro": "ubuntu"
  },
  "modules": {
    "git": true,
    "modern-tools": true,
    "kubernetes": {
      "shell": true,
      "install": true,
      "disable": ["kubernetes.helm"]
    },
    "cloud": { "shell": true, "install": false },
    "vim": true,
    "containers": true,
    "python": true,
    "node": true
  },
  "git": {
    "name": "Anton Swartz",
    "email": "anton@work.com"
  },
  "minimal_mode": {
    "env_triggers": ["CLAUDE_CODE", "CODEX", "GEMINI_CLI", "CI"],
    "always_load": ["platform", "path", "exports"],
    "include_modules": ["git"],
    "never_load": ["prompt", "atuin", "ohmyposh", "completions", "sync-check"]
  },
  "registries": [
    { "name": "default", "url": "https://github.com/sshpub/dotfiles-modules" },
    { "name": "acme-corp", "url": "git@github.com:acme-corp/dotfiles-modules.git", "private": true }
  ]
}
```

Shorthand `true` means `{ "shell": true, "install": true }`. Explicit object for fine-grained control.

---

## Override System

### Three Layers

1. **Module defaults** — what the module ships with
2. **Repo overrides** (`overrides/`) — your preferences, tracked in git, shared across all machines
3. **Local overrides** (`~/.dotfiles/local/`) — per-machine tweaks, untracked

Loading order: module -> repo override -> local override. Last write wins.

### CLI Override Commands

```
dotfiles module override kubernetes.helm              # Clone section -> overrides/ (tracked)
dotfiles module override kubernetes.helm --local      # Clone section -> ~/.dotfiles/local/
dotfiles module override kubernetes.helm --disable    # Disable section, no clone
dotfiles module reset kubernetes.helm                 # Remove override, restore default
```

The `override` command extracts the section from the module source and copies it to the override location with a header comment:

```bash
# Overridden from: modules/kubernetes/aliases.sh
# Section: kubernetes.helm
# To disable entirely, remove the contents below.

alias h='helm'
alias hi='helm install'
```

---

## CLI (dotfiles-cli)

### Command Tree

```
dotfiles
|
+-- setup                           # First-run wizard (interactive)
+-- setup --non-interactive         # For automation/scripts
|
+-- bootstrap                       # Create symlinks for core + enabled modules
|   +-- --force                     # Skip confirmation prompts
|   +-- --dry-run                   # Show what would be linked
|
+-- update                          # Pull latest, rebuild cache, re-link
|   +-- --check                     # Just check, don't apply
|   +-- --diff                      # Show what changed before applying
|   +-- --core                      # Fetch upstream dotfiles-core updates
|
+-- self-update                     # Update CLI binary from GH releases
|   +-- --check                     # Just check, don't install
|
+-- module                          # Module management
|   +-- list                        # All modules + enabled/disabled status
|   +-- list --interactive          # TUI browser with search/toggle
|   +-- browse                      # Alias for list --interactive
|   +-- info <name>                 # Module details, sections, install recipes
|   +-- enable <name>               # Add to profile, link configs
|   +-- disable <name>              # Remove from profile, unlink configs
|   +-- install <name>              # Install module's packages
|   +-- install --all               # Install all enabled modules' packages
|   +-- override <section>          # Clone section to overrides/
|   |   +-- --local                 # Clone to ~/.dotfiles/local/ instead
|   |   +-- --disable               # Just disable, don't clone
|   +-- reset <section>             # Remove override, restore default
|   +-- create <name>               # Scaffold new module from template
|   +-- validate [name]             # Validate module.json + section guards
|   +-- add <registry/name>         # Install module from registry
|   +-- update [name]               # Update module(s) from registry
|   |   +-- --all                   # Update all registry-installed modules
|   |   +-- --check                 # Show available updates without applying
|   +-- search <query>              # Search all registries
|
+-- profile                         # Profile management
|   +-- show                        # Display current profile
|   +-- edit                        # Open ~/.dotfiles.json in $EDITOR
|   +-- wizard                      # Re-run interactive profile wizard
|   +-- export                      # Export profile to share as example
|
+-- registry                        # Registry management
|   +-- add <name> <url>            # Add a registry
|   |   +-- --private               # Mark as private (SSH auth)
|   +-- list                        # List configured registries
|   +-- remove <name>               # Remove a registry
|   +-- sync                        # Pull latest from all registries
|
+-- migrate <file>                  # Analyze existing dotfiles
|                                   # Suggest modules, identify custom config
|
+-- minimal                         # Minimal mode management
|   +-- show                        # Show what loads in minimal mode
|   +-- test                        # Spawn a minimal shell to try it
|   +-- add-trigger <ENV_VAR>       # Add new AI tool trigger
|   +-- include <module>            # Add module to minimal mode
|   +-- exclude <module>            # Remove module from minimal mode
|
+-- platform                        # Show detected platform info
+-- doctor                          # Health check (symlinks, modules, profile, deps)
+-- cache rebuild                   # Regenerate shell cache
+-- cache clear                     # Clear all cached state
+-- sync status                     # Show sync state
+-- sync check                      # Background fetch + update cache
```

### Binary Distribution

- CLI is its own repo: `sshpub/dotfiles-cli`
- Cross-compiled for 4 targets: darwin-arm64, darwin-amd64, linux-arm64, linux-amd64
- Distributed via GitHub Releases (goreleaser)
- CLI self-updates: `dotfiles self-update` downloads latest from GH releases
- No binaries committed to dotfiles-core repo

### Shell Wrapper (install.sh)

The one-liner bootstrap. Detects OS/arch, downloads the CLI binary, runs setup:

```bash
curl -fsSL https://raw.githubusercontent.com/sshpub/dotfiles/main/install.sh | bash
```

The script:
1. Detects OS and architecture
2. Downloads latest CLI binary from `sshpub/dotfiles-cli` GitHub releases
3. Places it in `~/.local/bin/dotfiles`
4. Runs `dotfiles setup`

### Core Version Checking

- `dotfiles-core` has a `VERSION` file at root (semver)
- CLI knows the current core version and checks upstream for updates
- On `dotfiles update`, CLI compares local VERSION against upstream
- Notification on shell startup if core is behind (via sync-check)
- `dotfiles update --core` fetches and merges upstream changes

### TUI Mode

Brew-style CLI as default. Optional TUI (bubbletea) for browsing:

```
dotfiles module list                    # Simple table output
dotfiles module browse                  # TUI with search, toggle, section preview
dotfiles setup                          # Interactive wizard (TUI-lite)
dotfiles setup --non-interactive        # For scripts/automation
```

---

## AI-Aware Context

### Two Concerns

**1. Shell weight (runtime):** Minimal mode ensures AI tools get a fast, clean shell.

**2. Development context (CLAUDE.md):** Hierarchical files give AI tools scoped project knowledge.

### Hierarchical CLAUDE.md

```
CLAUDE.md                   # Root (~30 lines) — overview, key principles
core/CLAUDE.md              # (~40 lines) — loading chain, performance
modules/CLAUDE.md           # (~50 lines) — module contract, authoring
modules/*/CLAUDE.md         # (~15 lines) — per-module: sections, deps, files
overrides/CLAUDE.md         # (~10 lines) — how overrides work
profiles/CLAUDE.md          # (~15 lines) — schema, examples
```

### .claudeignore

```
modules/vim/config/.vim/colors/
setup/macos-defaults.sh
.superpowers/
.cache/
```

### Module CLAUDE.md Template

Auto-generated by `dotfiles module create`:

```markdown
# {Module Name}

{description from module.json}

## Sections
- {module}.{section} — {description}

## Dependencies
- {list or "None"}

## Files
- {file} — {purpose}
```

---

## Registries

### Configurable via CLI

```
dotfiles registry add default https://github.com/sshpub/dotfiles-modules
dotfiles registry add acme-corp git@github.com:acme-corp/modules.git --private
dotfiles registry list
dotfiles registry remove acme-corp
dotfiles registry sync
```

Stored in `~/.dotfiles.json`:

```json
{
  "registries": [
    { "name": "default", "url": "https://github.com/sshpub/dotfiles-modules" },
    { "name": "acme-corp", "url": "git@github.com:acme-corp/dotfiles-modules.git", "private": true }
  ]
}
```

### How Registries Work

- Registries are git repos containing modules (each subdirectory is a module)
- `dotfiles module search <query>` searches all configured registries
- `dotfiles module add <registry>/<module>` clones the module into `modules/`
- Private registries use existing SSH/git authentication
- Businesses maintain curated module sets for teams

### Pasteable Onboarding (for businesses)

A company README just needs:

```bash
dotfiles registry add acme git@github.com:acme-corp/dotfiles-modules.git --private
dotfiles module add acme/standard-dev
```

---

## Migration Strategy

### Guiding Principle

The shell must work at every step. No big-bang migration. Each phase produces a working system.

### Phase 1: Scaffold & Core

Create the new directory structure. Build the core loader with minimal mode and section guard system.

- Create core/, modules/, overrides/, profiles/, platform/, setup/
- Extract platform detection into core/platform.sh
- Build core/loader.sh with dotfiles_section() and minimal mode
- Move essential PATH/exports/aliases/functions into core/
- Move platform-specific code into platform/
- New .bash_profile that sources the new structure
- **Test:** shell works identically to before

### Phase 2: Extract Modules

Break monolithic files into self-contained modules.

- Split .aliases (426 lines) into ~12 modules
- Split .functions (1,385 lines) into core (~300 lines) + modules (~1,085 lines)
- Create module.json for each with sections, install recipes, platform support
- Add dotfiles_section() guards to all shell blocks
- Move config files into their modules
- **Test:** all aliases/functions still work via module system

### Phase 3: Profile System

Implement profile-driven loading.

- Define ~/.dotfiles.json schema
- Loader reads profile, builds enabled/disabled lists
- Implement shell cache (CLI generates sourceable file from JSON)
- Implement minimal mode with env triggers
- Create example profiles for all 6 machines
- **Test:** different profiles produce different shell environments

### Phase 4: Go CLI Overhaul

Rebuild the CLI as a separate repo (sshpub/dotfiles-cli).

- New command tree: setup, bootstrap, update, module, profile, doctor, registry, migrate, minimal
- Module management: enable/disable/install/override/reset/create/validate
- Config conflict resolution (backup/merge/skip/adopt)
- Profile wizard (interactive + non-interactive)
- Self-update from GH releases
- Core version checking
- Shell wrapper + cross-compile for 4 targets
- Optional bubbletea TUI for module browsing
- **Test:** full setup workflow on a fresh machine

### Phase 5: Registry & Sync

Add registry support and multi-machine sync.

- Registry add/remove/list/sync CLI commands
- Module search and install from registries
- Private registry support (SSH auth)
- Sync check: background git fetch, cached state, shell notification
- Core version update notifications
- **Test:** install a module from a test registry

### Phase 6: Public Release & Cleanup

Prepare dotfiles-core for public consumption.

- Write hierarchical CLAUDE.md files
- Create .claudeignore
- Remove old flat files from personal repo
- GitHub Wiki: getting started, migration guide, module authoring, registry guide, per-platform guides, CLI reference
- MODULE-SPEC.md for marketplace authors
- install.sh one-liner bootstrap
- **Test:** full deploy on all 6 machines + test fork by a fresh user

### Rollback Safety

- All work on feature branches. Main stays working.
- Each phase is a merge to main. Deploy one phase at a time.
- Phases 1-3 coexist with old files. Backward compatible until phase 6 cleanup.

### Deployment Order

- Phases 1-3: Test on current WSL machine first (fastest to rebuild)
- Phase 4: CLI available via GH releases to all machines
- Phases 5-6: Roll out to remaining machines one at a time, Macbooks last

---

## Module Breakdown (from current files)

### From .aliases (426 lines) -> ~12 modules

| Module | Sections | Est. Lines |
|--------|----------|------------|
| git | git.shortcuts, git.log, git.branch | ~50 |
| containers | containers.docker, containers.compose | ~30 |
| kubernetes | kubernetes.core, kubernetes.helm, kubernetes.k9s, kubernetes.ctx | ~30 |
| cloud | cloud.aws, cloud.gcp, cloud.azure | ~25 |
| python | python.core, python.venv | ~20 |
| node | node.npm, node.scripts | ~15 |
| terraform | terraform.core | ~15 |
| modern-tools | modern-tools.listing, modern-tools.cat, modern-tools.search, modern-tools.cd | ~40 |
| navigation | navigation.dirs, navigation.bookmarks | ~20 |
| safety | safety.interactive, safety.disk | ~15 |
| network | network.ip, network.http | ~15 |
| system | system.info, system.processes | ~20 |

### From .functions (1,385 lines) -> core + modules

| Destination | Content | Est. Lines |
|-------------|---------|------------|
| core/functions.sh | mkd, extract, server, backup, fs, json, dataurl, gz, diff | ~300 |
| modules/git/functions.sh | Git helpers | ~80 |
| modules/cloud/functions.sh | AWS, GCP, Azure helpers | ~200 |
| modules/containers/functions.sh | Docker, K8s utilities | ~150 |
| modules/security/ | SSH/GPG key management | ~250 |
| modules/network/functions.sh | dig, cert, connectivity | ~80 |
| modules/development/functions.sh | Dev environment helpers | ~150 |
| modules/system/functions.sh | System info, process helpers | ~100 |

---

## Resolved Design Decisions

1. **Module dependency resolution order** — Topological sort. The CLI parses module.json and knows the dependency graph. Manual ordering is error-prone and hostile to new users.

2. **Registry format** — Flat. Each subdirectory is a module. Categories handled via tags in module.json, not directory nesting.

3. **Core update conflict resolution** — Standard git upstream merge. `dotfiles update --core` adds sshpub/dotfiles as upstream remote, fetches, and starts a merge. User resolves conflicts with normal git tools. CLI shows a summary of what changed upstream before merging.

4. **Module versioning in registries** — Semver from day one. Users should be able to lock module versions in their profile (e.g., `"kubernetes": { "version": "1.2.0" }`). Version pinning prevents unexpected breakage when a registry module updates.
