# CLI Commands Design — Issue #25

**Date:** 2026-04-06
**Author:** Anton Swartz
**Status:** Approved

## Overview

Implement the profile, platform, doctor, cache, and mode commands for `sshpub/dotfiles-cli`. This includes two foundational packages (`pkg/profile`, `pkg/module`) that future CLI commands (#23, #24) will also use. The `cache rebuild` command is the Go replacement for the throwaway `setup/generate-cache.sh`.

## Decisions

- **Dotfiles dir discovery:** `$DOTFILES_DIR` env var > `dotfiles_dir` key in profile > error
- **Data dir discovery:** Same search chain as shell (`$DOTFILES_DATA_DIR` > `~/.dotfiles` > `~/.config/dotfiles` > `~/.local/share/dotfiles`)
- **`cache rebuild` regenerates all caches** — both `profile.sh` and `platform.sh`
- **`doctor` reports with fix hints** — pass/warn/fail checklist, prints which command fixes each issue, doesn't auto-fix
- **`minimal` renamed to `mode`** — generic mode commands with `--mode` flag defaulting to `minimal`, matching the modes system from #19/#20
- **Editor fallback chain:** `$EDITOR` > `$VISUAL` > `vim` > `vi` > `nano`
- **`profile wizard` is a stub** — prints "not implemented, use `dotfiles setup`" until #23 lands, then becomes an alias

---

## 1. Shared Infrastructure

### `pkg/profile/profile.go`

Profile loading, saving, and path resolution:

- `FindProfile() (string, error)` — search chain: `$DOTFILES_PROFILE` > `~/.dotfiles.json` > `~/.config/dotfiles/profile.json` > `~/.config/dotfiles.json` > `~/.local/dotfiles.json` > `$DOTFILES_DIR/dotfiles.json` > `$DOTFILES_DIR/profiles/default.json`
- `LoadProfile(path string) (*Profile, error)` — parses JSON into Go struct
- `SaveProfile(path string, profile *Profile) error` — writes pretty-printed JSON
- `FindDotfilesDir(profile *Profile) (string, error)` — `$DOTFILES_DIR` > profile's `dotfiles_dir` field > error
- `FindDataDir() string` — `$DOTFILES_DATA_DIR` > first existing of `~/.dotfiles`, `~/.config/dotfiles`, `~/.local/share/dotfiles` > default `~/.dotfiles`

Profile struct mirrors JSON schema:

```go
type Profile struct {
    Comment    string                 `json:"_comment,omitempty"`
    Role       []string               `json:"role,omitempty"`
    Platform   *PlatformOverride      `json:"platform,omitempty"`
    Modules    map[string]interface{} `json:"modules,omitempty"`
    Git        *GitConfig             `json:"git,omitempty"`
    Modes      map[string]*Mode       `json:"modes,omitempty"`
    DotfilesDir string                `json:"dotfiles_dir,omitempty"`
    Registries []Registry             `json:"registries,omitempty"`
}

type Mode struct {
    Comment        string   `json:"_comment,omitempty"`
    Type           string   `json:"type,omitempty"`
    EnvTriggers    []string `json:"env_triggers,omitempty"`
    IncludeModules []string `json:"include_modules,omitempty"`
    NeverLoad      []string `json:"never_load,omitempty"`
}
```

Module entries in `Modules` map: `true` (shorthand) or `ModuleConfig` object with `shell`, `install`, `disable` fields.

### `pkg/profile/platform.go`

Platform detection in Go:

- `DetectPlatform() *PlatformInfo` — OS (`runtime.GOOS`), Arch (`runtime.GOARCH`), WSL (check `/proc/version`), Distro (parse `/etc/os-release`), Package manager (check PATH), Container (`/.dockerenv`)

Same detection logic as `core/platform.sh`.

### `pkg/profile/cache.go`

Cache generation:

- `GeneratePlatformCache(dataDir string, info *PlatformInfo) error` — writes `{dataDir}/cache/platform.sh`
- `GenerateProfileCache(dataDir string, profilePath string, profile *Profile) error` — writes `{dataDir}/cache/profile.sh`
- `ClearCache(dataDir string) error` — removes `{dataDir}/cache/`

Output format identical to what the shell expects (same variables, same naming conventions).

### `pkg/module/module.go`

Module discovery and validation:

- `DiscoverModules(dotfilesDir string) ([]Module, error)` — finds all `modules/*/module.json`
- `LoadModule(path string) (*Module, error)` — parses single `module.json`
- `ValidateModule(mod *Module) []string` — returns list of validation errors

Module struct mirrors the module JSON schema.

---

## 2. `platform` Command

`dotfiles platform` — detects and prints platform info:

```
Platform Information:
  OS:              linux
  Architecture:    amd64
  WSL:             yes
  Distribution:    ubuntu 25.10
  Package Manager: apt
  Container:       no
```

Uses `pkg/profile.DetectPlatform()`. Output format matches `platform_info()` shell function.

---

## 3. `cache` Commands

**`dotfiles cache rebuild`:**
1. Find profile via search chain
2. Find data dir
3. Detect platform → write `{dataDir}/cache/platform.sh`
4. Parse profile → write `{dataDir}/cache/profile.sh`
5. Print paths written

If no profile found, clears profile cache (loader falls back to all-modules default).

**`dotfiles cache clear`:**
Removes `{dataDir}/cache/` directory entirely. Prints confirmation.

---

## 4. `profile` Commands

**`dotfiles profile show`** — formatted human-readable summary:

```
Profile: ~/.dotfiles.json
Dotfiles: ~/code/sshpub/dotfiles

Role: personal, work
Modules (11 enabled):
  git, modern-tools, containers, kubernetes, cloud,
  python, node, vim, fzf, tmux, safety
Disabled sections: kubernetes.helm
Modes:
  minimal (include): triggers CI, CLAUDE_CODE → loads git
  server (exclude): triggers SSH_SESSION → skips prompt, fzf
Git: Anton Swartz <anton@work.com>
```

**`dotfiles profile edit`** — opens profile in editor. Fallback: `$EDITOR` > `$VISUAL` > `vim` > `vi` > `nano`. After editor exits, runs `cache rebuild` automatically.

**`dotfiles profile wizard`** — stub: prints "not implemented — use `dotfiles setup`". Becomes alias to setup when #23 lands.

**`dotfiles profile export`** — prints profile to stdout with git name/email replaced with placeholders. Pipe-friendly for sharing.

---

## 5. `doctor` Command

Runs health checks, reports pass/warn/fail with fix hints:

```
dotfiles doctor

  ✓ Profile found: ~/.dotfiles.json
  ✓ Profile valid JSON
  ✓ Dotfiles directory: ~/code/sshpub/dotfiles
  ✓ 11 modules enabled, all directories exist
  ✗ Module kubernetes: missing dependency "containers"
    → Fix: dotfiles module enable containers
  ✓ Platform cache current
  ⚠ Profile cache stale (profile modified after cache)
    → Fix: dotfiles cache rebuild
  ✓ No broken symlinks
  ✓ Binary matches platform (linux/amd64)

7 passed, 1 warning, 1 failure
```

**Checks:**
1. Profile found and valid JSON
2. Dotfiles directory exists
3. All enabled modules have directories and valid `module.json`
4. Module dependencies satisfied (all deps in enabled list)
5. Platform cache exists and matches current platform
6. Profile cache exists and newer than profile file (mtime comparison)
7. Symlinks intact (module symlink targets exist)
8. Binary architecture matches detected platform

Exit code 0 if no failures (warnings OK), exit code 1 if any failures.

---

## 6. `mode` Commands (replaces `minimal`)

`cmd/minimal.go` renamed to `cmd/mode.go`. All commands take `--mode` flag defaulting to `"minimal"`.

**`dotfiles mode show [--mode NAME]`** — shows mode config:

```
Mode: minimal (type: include)
Triggers: CLAUDE_CODE, CODEX, GEMINI_CLI, CI
Loads modules: git
```

**`dotfiles mode test [--mode NAME]`** — spawns `DOTFILES_MODE=<name> bash -l`.

**`dotfiles mode add-trigger VAR [--mode NAME]`** — adds env trigger to mode in profile, regenerates cache.

**`dotfiles mode include MODULE [--mode NAME]`** — adds to `include_modules`, regenerates cache.

**`dotfiles mode exclude MODULE [--mode NAME]`** — for include-type: removes from `include_modules`. For exclude-type: adds to `never_load`. Regenerates cache.

All mutation commands: load profile → modify → save → cache rebuild.

---

## 7. Deliverables

| File | Repo | Purpose |
|------|------|---------|
| `pkg/profile/profile.go` | dotfiles-cli | Profile loading, saving, search chains, data dir |
| `pkg/profile/platform.go` | dotfiles-cli | Platform detection in Go |
| `pkg/profile/cache.go` | dotfiles-cli | Cache generation (profile.sh + platform.sh) |
| `pkg/module/module.go` | dotfiles-cli | Module discovery, loading, validation |
| `cmd/platform.go` | dotfiles-cli | Rewrite with real logic |
| `cmd/cache.go` | dotfiles-cli | Rewrite with real logic |
| `cmd/profile.go` | dotfiles-cli | Rewrite with real logic |
| `cmd/doctor.go` | dotfiles-cli | Rewrite with real logic |
| `cmd/mode.go` | dotfiles-cli | New file replacing cmd/minimal.go |

**Removed:** `cmd/minimal.go` — replaced by `cmd/mode.go`

## 8. Out of Scope

- `profile wizard` implementation (#23)
- Module install/enable/disable (#24)
- Setup wizard (#23)
- `dotfiles_dir` field in profile schema — adding to schema is a dotfiles repo change, tracked separately
