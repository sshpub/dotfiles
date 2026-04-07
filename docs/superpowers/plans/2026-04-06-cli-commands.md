# CLI Commands Implementation Plan — Issue #25

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement profile, platform, doctor, cache, and mode commands for `sshpub/dotfiles-cli`, plus the foundational `pkg/profile` and `pkg/module` packages that future commands (#23, #24) reuse.

**Architecture:** Two packages (`pkg/profile`, `pkg/module`) provide all shared logic. Five command files wire Cobra commands to package functions. Cache output must be byte-compatible with the existing shell scripts (`core/platform.sh`, `core/loader.sh`, `setup/generate-cache.sh`).

**Tech Stack:** Go 1.25, Cobra, encoding/json, os/exec, runtime

---

**Spec:** `docs/superpowers/specs/2026-04-06-cli-commands-design.md` (in sshpub/dotfiles repo)

**Working directory:** `~/code/sshpub/dotfiles-cli/`

**Branch:** `feat/25-cli-commands` (from main)

**File Map:**

| File | Action | Purpose |
|------|--------|---------|
| `pkg/profile/profile.go` | Rewrite (replace doc.go) | Profile struct, loading, saving, dir resolution |
| `pkg/profile/platform.go` | Create | Platform detection in Go |
| `pkg/profile/cache.go` | Create | Cache generation (platform.sh + profile.sh) |
| `pkg/module/module.go` | Rewrite (replace doc.go) | Module discovery, loading, validation |
| `cmd/platform.go` | Rewrite | Real platform detection output |
| `cmd/cache.go` | Rewrite | Real cache rebuild/clear |
| `cmd/profile.go` | Rewrite | Real profile show/edit/wizard/export |
| `cmd/doctor.go` | Rewrite | Real health checks |
| `cmd/mode.go` | Create | Replaces cmd/minimal.go |
| `cmd/minimal.go` | Delete | Replaced by cmd/mode.go |
| `pkg/profile/profile_test.go` | Create | Profile package tests |
| `pkg/profile/platform_test.go` | Create | Platform detection tests |
| `pkg/profile/cache_test.go` | Create | Cache generation tests |
| `pkg/module/module_test.go` | Create | Module package tests |

---

## Task 1: `pkg/profile` — Profile loading, saving, dir resolution

**Files:**
- Rewrite: `~/code/sshpub/dotfiles-cli/pkg/profile/profile.go` (replaces doc.go)
- Delete: `~/code/sshpub/dotfiles-cli/pkg/profile/doc.go`

- [ ] **Step 1: Delete doc.go, create profile.go**

Delete `pkg/profile/doc.go`. Create `pkg/profile/profile.go`:

```go
package profile

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

// Profile mirrors the ~/.dotfiles.json schema.
type Profile struct {
	Comment     string                 `json:"_comment,omitempty"`
	Role        []string               `json:"role,omitempty"`
	Platform    *PlatformOverride      `json:"platform,omitempty"`
	Modules     map[string]interface{} `json:"modules,omitempty"`
	Git         *GitConfig             `json:"git,omitempty"`
	Modes       map[string]*Mode       `json:"modes,omitempty"`
	DotfilesDir string                 `json:"dotfiles_dir,omitempty"`
	Registries  []Registry             `json:"registries,omitempty"`
}

type PlatformOverride struct {
	Comment string `json:"_comment,omitempty"`
	OS      string `json:"os,omitempty"`
	Variant string `json:"variant,omitempty"`
	Distro  string `json:"distro,omitempty"`
}

type GitConfig struct {
	Comment string `json:"_comment,omitempty"`
	Name    string `json:"name,omitempty"`
	Email   string `json:"email,omitempty"`
}

type Mode struct {
	Comment        string   `json:"_comment,omitempty"`
	Type           string   `json:"type,omitempty"`
	EnvTriggers    []string `json:"env_triggers,omitempty"`
	IncludeModules []string `json:"include_modules,omitempty"`
	NeverLoad      []string `json:"never_load,omitempty"`
}

type Registry struct {
	Comment string `json:"_comment,omitempty"`
	Name    string `json:"name"`
	URL     string `json:"url"`
	Private bool   `json:"private,omitempty"`
}

// ModuleConfig represents the object form of a module entry.
// The map value is either bool (true) or this struct.
type ModuleConfig struct {
	Comment string   `json:"_comment,omitempty"`
	Shell   bool     `json:"shell,omitempty"`
	Install bool     `json:"install,omitempty"`
	Disable []string `json:"disable,omitempty"`
}

// FindProfile searches the standard chain and returns the path to the first
// profile found. Returns empty string and nil if no profile exists.
func FindProfile() (string, error) {
	// Env var override
	if p := os.Getenv("DOTFILES_PROFILE"); p != "" {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}

	dotfilesDir := os.Getenv("DOTFILES_DIR")

	candidates := []string{
		filepath.Join(home, ".dotfiles.json"),
		filepath.Join(home, ".config", "dotfiles", "profile.json"),
		filepath.Join(home, ".config", "dotfiles.json"),
		filepath.Join(home, ".local", "dotfiles.json"),
	}

	if dotfilesDir != "" {
		candidates = append(candidates,
			filepath.Join(dotfilesDir, "dotfiles.json"),
			filepath.Join(dotfilesDir, "profiles", "default.json"),
		)
	}

	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c, nil
		}
	}

	return "", nil
}

// LoadProfile parses a JSON profile file.
func LoadProfile(path string) (*Profile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var p Profile
	if err := json.Unmarshal(data, &p); err != nil {
		return nil, err
	}
	return &p, nil
}

// SaveProfile writes a profile as pretty-printed JSON.
func SaveProfile(path string, p *Profile) error {
	data, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return os.WriteFile(path, data, 0644)
}

// FindDotfilesDir resolves the dotfiles repo directory.
// Search: $DOTFILES_DIR env > profile's dotfiles_dir field > error.
func FindDotfilesDir(p *Profile) (string, error) {
	if d := os.Getenv("DOTFILES_DIR"); d != "" {
		return d, nil
	}
	if p != nil && p.DotfilesDir != "" {
		return p.DotfilesDir, nil
	}
	return "", errors.New("dotfiles directory not found: set $DOTFILES_DIR or dotfiles_dir in profile")
}

// FindDataDir resolves the data directory.
// Search: $DOTFILES_DATA_DIR > first existing of ~/.dotfiles,
// ~/.config/dotfiles, ~/.local/share/dotfiles > default ~/.dotfiles.
func FindDataDir() string {
	if d := os.Getenv("DOTFILES_DATA_DIR"); d != "" {
		return d
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return filepath.Join(home, ".dotfiles")
	}

	candidates := []string{
		filepath.Join(home, ".dotfiles"),
		filepath.Join(home, ".config", "dotfiles"),
		filepath.Join(home, ".local", "share", "dotfiles"),
	}

	for _, c := range candidates {
		if info, err := os.Stat(c); err == nil && info.IsDir() {
			return c
		}
	}

	return filepath.Join(home, ".dotfiles")
}

// EnabledModules returns the list of module names that have shell loading
// enabled. A module entry of `true` (bool) or `{"shell": true}` counts.
func (p *Profile) EnabledModules() []string {
	if p.Modules == nil {
		return nil
	}
	var enabled []string
	for name, val := range p.Modules {
		switch v := val.(type) {
		case bool:
			if v {
				enabled = append(enabled, name)
			}
		case map[string]interface{}:
			shell, ok := v["shell"]
			if !ok || shell == true {
				enabled = append(enabled, name)
			}
		}
	}
	return enabled
}

// DisabledSections returns all disabled sections across all modules.
func (p *Profile) DisabledSections() []string {
	if p.Modules == nil {
		return nil
	}
	var disabled []string
	for _, val := range p.Modules {
		obj, ok := val.(map[string]interface{})
		if !ok {
			continue
		}
		disableRaw, ok := obj["disable"]
		if !ok {
			continue
		}
		arr, ok := disableRaw.([]interface{})
		if !ok {
			continue
		}
		for _, item := range arr {
			if s, ok := item.(string); ok {
				disabled = append(disabled, s)
			}
		}
	}
	return disabled
}
```

Key behaviors:
- `FindProfile` returns `("", nil)` when no profile exists (not an error — loader falls back to defaults)
- `EnabledModules` handles both `true` shorthand and `{"shell": true}` object form
- `DisabledSections` aggregates `disable` arrays from all module objects
- `FindDataDir` error path still returns `~/.dotfiles` default (matches shell behavior)

- [ ] **Step 2: Create profile_test.go**

Create `pkg/profile/profile_test.go` with tests for:
- `FindDataDir` — env var override, fallback to default
- `LoadProfile` — valid JSON, invalid JSON, missing file
- `SaveProfile` — round-trip (load → save → load, compare)
- `EnabledModules` — bool shorthand, object form, mixed
- `DisabledSections` — collects from multiple modules
- `FindDotfilesDir` — env var, profile field, neither (error)
- `FindProfile` — env var, search chain (use `t.TempDir()` for isolation)

Use `t.Setenv()` for env var tests (auto-restores).

- [ ] **Step 3: Verify tests pass**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./pkg/profile/...
```

- [ ] **Step 4: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add pkg/profile/
git rm pkg/profile/doc.go 2>/dev/null || true
git commit -m "feat(profile): add profile loading, saving, and dir resolution

FindProfile search chain, LoadProfile/SaveProfile JSON handling,
FindDotfilesDir/FindDataDir with env var overrides matching shell behavior.
EnabledModules handles both bool shorthand and object form.

Part of #25"
```

---

## Task 2: `pkg/profile` — Platform detection

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/pkg/profile/platform.go`

Depends on: Task 1 (same package)

- [ ] **Step 1: Create platform.go**

Create `pkg/profile/platform.go`:

```go
package profile

import (
	"os"
	"runtime"
	"strings"
)

// PlatformInfo holds detected platform details.
// Matches the variables exported by core/platform.sh.
type PlatformInfo struct {
	OS             string // "macos", "linux", "windows"
	Arch           string // runtime.GOARCH value
	WSL            bool
	Distro         string // e.g. "ubuntu"
	DistroVersion  string // e.g. "25.10"
	PkgManager     string // "apt", "dnf", "brew", etc.
	Container      bool
	HomebrewPrefix string
	MacOSVersion   string
}

// DetectPlatform detects the current platform, matching core/platform.sh logic.
func DetectPlatform() *PlatformInfo {
	info := &PlatformInfo{
		Arch: runtime.GOARCH,
	}

	// OS
	switch runtime.GOOS {
	case "darwin":
		info.OS = "macos"
	case "linux":
		info.OS = "linux"
	case "windows":
		info.OS = "windows"
	default:
		info.OS = "unknown"
	}

	// WSL detection
	if info.OS == "linux" {
		if data, err := os.ReadFile("/proc/version"); err == nil {
			if strings.Contains(strings.ToLower(string(data)), "microsoft") {
				info.WSL = true
			}
		}
	}

	// Distro (Linux)
	if info.OS == "linux" {
		info.Distro, info.DistroVersion = parseOSRelease()
	}

	// macOS version
	if info.OS == "macos" {
		info.MacOSVersion = detectMacOSVersion()
	}

	// Container detection
	if _, err := os.Stat("/.dockerenv"); err == nil {
		info.Container = true
	} else if _, err := os.Stat("/run/.containerenv"); err == nil {
		info.Container = true
	}

	// Package manager
	info.PkgManager, info.HomebrewPrefix = detectPackageManager(info)

	return info
}

// parseOSRelease reads /etc/os-release for distro ID and version.
func parseOSRelease() (distro, version string) {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return "", ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		val = strings.Trim(val, "\"")
		switch key {
		case "ID":
			distro = val
		case "VERSION_ID":
			version = val
		}
	}
	return distro, version
}

// detectMacOSVersion runs sw_vers -productVersion.
func detectMacOSVersion() string {
	// Only called on macOS — use os/exec
	out, err := execCommand("sw_vers", "-productVersion")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(out)
}

// detectPackageManager finds the system package manager.
func detectPackageManager(info *PlatformInfo) (manager, brewPrefix string) {
	if info.OS == "macos" {
		if commandExists("brew") {
			manager = "brew"
			if p := os.Getenv("HOMEBREW_PREFIX"); p != "" {
				brewPrefix = p
			} else if info.Arch == "arm64" {
				brewPrefix = "/opt/homebrew"
			} else {
				brewPrefix = "/usr/local"
			}
		}
		return
	}

	if info.OS == "linux" {
		for _, candidate := range []string{"apt", "dnf", "pacman", "zypper", "yum"} {
			if commandExists(candidate) {
				return candidate, ""
			}
		}
		if commandExists("brew") {
			if p := os.Getenv("HOMEBREW_PREFIX"); p != "" {
				brewPrefix = p
			} else {
				brewPrefix = "/home/linuxbrew/.linuxbrew"
			}
			return "brew", brewPrefix
		}
	}

	return "", ""
}

// commandExists checks if a command is in PATH.
func commandExists(name string) bool {
	_, err := execLookPath(name)
	return err == nil
}
```

Note: `execCommand` and `execLookPath` should be package-level vars for testability:

```go
// At top of platform.go (or a helpers file):
import "os/exec"

var execCommand = func(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return string(out), err
}

var execLookPath = exec.LookPath
```

Key behaviors:
- Arch uses `runtime.GOARCH` directly (not `uname -m`) — Go normalizes this
- WSL check reads `/proc/version` for "microsoft" (case-insensitive), same as shell
- Package manager check order matches `core/platform.sh` exactly: apt, dnf, pacman, zypper, yum, brew
- Homebrew prefix logic matches shell: arm64 darwin → `/opt/homebrew`, else `/usr/local`; linux → `/home/linuxbrew/.linuxbrew`

- [ ] **Step 2: Create platform_test.go**

Create `pkg/profile/platform_test.go` with tests for:
- `DetectPlatform` — smoke test (runs on current machine, verify non-empty OS/Arch)
- `parseOSRelease` — use temp file with known content
- `commandExists` — override `execLookPath` var for testing
- `detectPackageManager` — override `commandExists` behavior, test macOS arm64/amd64 brew prefix, linux apt/dnf priority

- [ ] **Step 3: Verify tests pass**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./pkg/profile/...
```

- [ ] **Step 4: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add pkg/profile/platform.go pkg/profile/platform_test.go
git commit -m "feat(profile): add Go platform detection matching core/platform.sh

DetectPlatform returns OS, arch, WSL, distro, package manager, container
status. Same detection logic and priority as the shell implementation.

Part of #25"
```

---

## Task 3: `pkg/profile` — Cache generation

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/pkg/profile/cache.go`

Depends on: Tasks 1 + 2 (uses Profile, PlatformInfo)

- [ ] **Step 1: Create cache.go**

Create `pkg/profile/cache.go`:

```go
package profile

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// GeneratePlatformCache writes {dataDir}/cache/platform.sh.
// Output format must match core/platform.sh's _dotfiles_write_platform_cache.
func GeneratePlatformCache(dataDir string, info *PlatformInfo) error {
	cacheDir := filepath.Join(dataDir, "cache")
	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return err
	}

	wsl := ""
	if info.WSL {
		wsl = "true"
	}
	container := ""
	if info.Container {
		container = "true"
	}

	var b strings.Builder
	b.WriteString("# Generated by dotfiles — do not edit\n")
	b.WriteString("# Re-generate: dotfiles cache rebuild\n")
	fmt.Fprintf(&b, "DOTFILES_OS=\"%s\"\n", info.OS)
	fmt.Fprintf(&b, "DOTFILES_ARCH=\"%s\"\n", info.Arch)
	fmt.Fprintf(&b, "DOTFILES_WSL=\"%s\"\n", wsl)
	fmt.Fprintf(&b, "DOTFILES_DISTRO=\"%s\"\n", info.Distro)
	fmt.Fprintf(&b, "DOTFILES_DISTRO_VERSION=\"%s\"\n", info.DistroVersion)
	fmt.Fprintf(&b, "DOTFILES_PKG_MANAGER=\"%s\"\n", info.PkgManager)
	fmt.Fprintf(&b, "DOTFILES_CONTAINER=\"%s\"\n", container)
	fmt.Fprintf(&b, "HOMEBREW_PREFIX=\"%s\"\n", info.HomebrewPrefix)
	fmt.Fprintf(&b, "MACOS_VERSION=\"%s\"\n", info.MacOSVersion)

	return os.WriteFile(filepath.Join(cacheDir, "platform.sh"), []byte(b.String()), 0644)
}

// GenerateProfileCache writes {dataDir}/cache/profile.sh.
// Output format must match setup/generate-cache.sh exactly.
func GenerateProfileCache(dataDir string, profilePath string, p *Profile) error {
	cacheDir := filepath.Join(dataDir, "cache")
	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return err
	}

	enabled := p.EnabledModules()
	sort.Strings(enabled)
	disabled := p.DisabledSections()
	sort.Strings(disabled)

	var b strings.Builder
	b.WriteString("# Generated by dotfiles — do not edit\n")
	fmt.Fprintf(&b, "# Source: %s\n", profilePath)
	fmt.Fprintf(&b, "# Generated: %s\n", time.Now().Format(time.RFC3339))
	b.WriteString("\n")
	fmt.Fprintf(&b, "DOTFILES_PROFILE_SOURCE=\"%s\"\n", profilePath)

	// Enabled modules
	fmt.Fprintf(&b, "DOTFILES_ENABLED_MODULES=(%s)\n", strings.Join(enabled, " "))

	// Disabled sections
	fmt.Fprintf(&b, "DOTFILES_DISABLED_SECTIONS=(%s)\n", strings.Join(disabled, " "))

	b.WriteString("\n")
	b.WriteString("# Modes — first triggered wins, checked in order\n")

	// Mode names (stable order)
	modeNames := make([]string, 0, len(p.Modes))
	for name := range p.Modes {
		modeNames = append(modeNames, name)
	}
	sort.Strings(modeNames)

	fmt.Fprintf(&b, "DOTFILES_MODE_NAMES=(%s)\n", strings.Join(modeNames, " "))

	// Per-mode variables
	for _, name := range modeNames {
		mode := p.Modes[name]
		modeType := mode.Type
		if modeType == "" {
			modeType = "include"
		}
		fmt.Fprintf(&b, "DOTFILES_MODE_%s_TYPE=%s\n", name, modeType)
		fmt.Fprintf(&b, "DOTFILES_MODE_%s_TRIGGERS=(%s)\n", name, strings.Join(mode.EnvTriggers, " "))
		fmt.Fprintf(&b, "DOTFILES_MODE_%s_MODULES=(%s)\n", name, strings.Join(mode.IncludeModules, " "))
		fmt.Fprintf(&b, "DOTFILES_MODE_%s_NEVER_LOAD=(%s)\n", name, strings.Join(mode.NeverLoad, " "))
	}

	return os.WriteFile(filepath.Join(cacheDir, "profile.sh"), []byte(b.String()), 0644)
}

// ClearCache removes the {dataDir}/cache/ directory entirely.
func ClearCache(dataDir string) error {
	return os.RemoveAll(filepath.Join(dataDir, "cache"))
}
```

Key behaviors:
- Platform cache output is variable-for-variable identical to `_dotfiles_write_platform_cache` in `core/platform.sh`
- Profile cache output matches `setup/generate-cache.sh` — same variable names, same bash array format
- Empty lists produce `DOTFILES_ENABLED_MODULES=()` (empty parens, no spaces)
- Module and mode lists are sorted for deterministic output
- `ClearCache` uses `os.RemoveAll` — no error if directory doesn't exist

- [ ] **Step 2: Create cache_test.go**

Create `pkg/profile/cache_test.go` with tests for:
- `GeneratePlatformCache` — write to temp dir, read back, verify each variable line
- `GenerateProfileCache` — create profile with known modules/modes, verify output format
- `GenerateProfileCache` — empty profile (no modules, no modes)
- `ClearCache` — creates dir, clears it, verifies gone
- `ClearCache` — no-op when cache dir doesn't exist (no error)
- Round-trip: generate cache → verify it's valid bash (`bash -n` syntax check)

- [ ] **Step 3: Verify tests pass**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./pkg/profile/...
```

- [ ] **Step 4: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add pkg/profile/cache.go pkg/profile/cache_test.go
git commit -m "feat(profile): add cache generation for platform.sh and profile.sh

Output format byte-compatible with core/platform.sh and setup/generate-cache.sh.
GeneratePlatformCache, GenerateProfileCache, ClearCache.

Part of #25"
```

---

## Task 4: `pkg/module` — Module discovery and validation

**Files:**
- Rewrite: `~/code/sshpub/dotfiles-cli/pkg/module/module.go` (replaces doc.go)
- Delete: `~/code/sshpub/dotfiles-cli/pkg/module/doc.go`

Independent of Tasks 1-3.

- [ ] **Step 1: Delete doc.go, create module.go**

Delete `pkg/module/doc.go`. Create `pkg/module/module.go`:

```go
package module

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
)

// Module mirrors the modules/schema.json definition.
type Module struct {
	Comment      string                       `json:"_comment,omitempty"`
	Name         string                       `json:"name"`
	Version      string                       `json:"version"`
	Description  string                       `json:"description"`
	Author       string                       `json:"author,omitempty"`
	Platforms    []string                     `json:"platforms,omitempty"`
	Dependencies []string                     `json:"dependencies,omitempty"`
	Sections     map[string]string            `json:"sections,omitempty"`
	Shell        *ShellConfig                 `json:"shell,omitempty"`
	Install      map[string]*InstallRecipes   `json:"install,omitempty"`
	Symlinks     map[string]string            `json:"symlinks,omitempty"`
	Hooks        *HookConfig                  `json:"hooks,omitempty"`

	// Dir is the absolute path to the module directory (set by DiscoverModules).
	Dir string `json:"-"`
}

type ShellConfig struct {
	LoadOrder []string `json:"load_order,omitempty"`
}

type InstallRecipes struct {
	Brew    []string `json:"brew,omitempty"`
	Apt     []string `json:"apt,omitempty"`
	Dnf     []string `json:"dnf,omitempty"`
	Pacman  []string `json:"pacman,omitempty"`
	Snap    []string `json:"snap,omitempty"`
	Zypper  []string `json:"zypper,omitempty"`
	Inherit string   `json:"inherit,omitempty"`
}

type HookConfig struct {
	PostInstall string `json:"post_install,omitempty"`
	PostEnable  string `json:"post_enable,omitempty"`
}

var namePattern = regexp.MustCompile(`^[a-z][a-z0-9-]*$`)
var versionPattern = regexp.MustCompile(`^\d+\.\d+\.\d+$`)

// DiscoverModules finds all modules/*/module.json under dotfilesDir.
func DiscoverModules(dotfilesDir string) ([]Module, error) {
	modulesDir := filepath.Join(dotfilesDir, "modules")
	entries, err := os.ReadDir(modulesDir)
	if err != nil {
		return nil, fmt.Errorf("reading modules directory: %w", err)
	}

	var modules []Module
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		jsonPath := filepath.Join(modulesDir, entry.Name(), "module.json")
		if _, err := os.Stat(jsonPath); err != nil {
			continue
		}
		mod, err := LoadModule(jsonPath)
		if err != nil {
			continue // skip invalid modules
		}
		mod.Dir = filepath.Join(modulesDir, entry.Name())
		modules = append(modules, *mod)
	}

	return modules, nil
}

// LoadModule parses a single module.json file.
func LoadModule(path string) (*Module, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var m Module
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	return &m, nil
}

// ValidateModule checks a module and returns a list of errors.
// Returns nil if valid.
func ValidateModule(mod *Module) []string {
	var errs []string

	if mod.Name == "" {
		errs = append(errs, "name is required")
	} else if !namePattern.MatchString(mod.Name) {
		errs = append(errs, fmt.Sprintf("name %q must match ^[a-z][a-z0-9-]*$", mod.Name))
	}

	if mod.Version == "" {
		errs = append(errs, "version is required")
	} else if !versionPattern.MatchString(mod.Version) {
		errs = append(errs, fmt.Sprintf("version %q must match semver (e.g. 1.0.0)", mod.Version))
	}

	if mod.Description == "" {
		errs = append(errs, "description is required")
	}

	for _, dep := range mod.Dependencies {
		if !namePattern.MatchString(dep) {
			errs = append(errs, fmt.Sprintf("dependency %q is not a valid module name", dep))
		}
	}

	for _, p := range mod.Platforms {
		switch p {
		case "macos", "linux", "wsl":
			// valid
		default:
			errs = append(errs, fmt.Sprintf("platform %q must be macos, linux, or wsl", p))
		}
	}

	return errs
}
```

Key behaviors:
- `DiscoverModules` skips directories without `module.json` and directories with invalid JSON (no error, just skip)
- `Dir` field is set by `DiscoverModules` but not serialized (json:"-")
- `ValidateModule` returns nil (not empty slice) when valid
- Validation patterns match `modules/schema.json` exactly

- [ ] **Step 2: Create module_test.go**

Create `pkg/module/module_test.go` with tests for:
- `LoadModule` — valid JSON, missing required fields, invalid JSON
- `ValidateModule` — valid module, missing name/version/description, bad name pattern, bad platform, bad dependency name
- `DiscoverModules` — set up temp dir with 2 valid modules + 1 dir without module.json, verify discovery count and names

- [ ] **Step 3: Verify tests pass**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./pkg/module/...
```

- [ ] **Step 4: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add pkg/module/
git rm pkg/module/doc.go 2>/dev/null || true
git commit -m "feat(module): add module discovery, loading, and validation

DiscoverModules finds modules/*/module.json, LoadModule parses them,
ValidateModule checks against the schema constraints. Struct mirrors
modules/schema.json.

Part of #25"
```

---

## Task 5: `cmd/platform.go` — Real implementation

**Files:**
- Rewrite: `~/code/sshpub/dotfiles-cli/cmd/platform.go`

Depends on: Task 2 (platform detection)

- [ ] **Step 1: Rewrite platform.go**

Replace `cmd/platform.go`:

```go
package cmd

import (
	"fmt"

	"github.com/sshpub/dotfiles-cli/pkg/profile"
	"github.com/spf13/cobra"
)

var platformCmd = &cobra.Command{
	Use:   "platform",
	Short: "Show detected platform information",
	Run: func(cmd *cobra.Command, args []string) {
		info := profile.DetectPlatform()
		fmt.Println("Platform Information:")
		fmt.Printf("  OS:              %s\n", info.OS)
		fmt.Printf("  Architecture:    %s\n", info.Arch)
		if info.Distro != "" {
			fmt.Printf("  Distribution:    %s %s\n", info.Distro, info.DistroVersion)
		}
		if info.WSL {
			fmt.Println("  WSL:             yes")
		}
		if info.MacOSVersion != "" {
			fmt.Printf("  macOS Version:   %s\n", info.MacOSVersion)
		}
		if info.PkgManager != "" {
			fmt.Printf("  Package Manager: %s\n", info.PkgManager)
		}
		if info.HomebrewPrefix != "" {
			fmt.Printf("  Homebrew Prefix: %s\n", info.HomebrewPrefix)
		}
		if info.Container {
			fmt.Println("  Container:       yes")
		}
	},
}

func init() {
	rootCmd.AddCommand(platformCmd)
}
```

Output format matches `platform_info()` in `core/platform.sh` — same labels, same conditional display.

- [ ] **Step 2: Verify build**

```bash
cd ~/code/sshpub/dotfiles-cli && go build -o /dev/null . && go run . platform
```

Expected: Platform info printed with real values for the current machine.

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add cmd/platform.go
git commit -m "feat(cmd): implement platform command with real detection

Output matches platform_info() shell function format.

Part of #25"
```

---

## Task 6: `cmd/cache.go` — Real implementation

**Files:**
- Rewrite: `~/code/sshpub/dotfiles-cli/cmd/cache.go`

Depends on: Tasks 1 + 2 + 3 (profile loading, platform detection, cache generation)

- [ ] **Step 1: Rewrite cache.go**

Replace `cmd/cache.go`:

```go
package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/sshpub/dotfiles-cli/pkg/profile"
	"github.com/spf13/cobra"
)

var cacheCmd = &cobra.Command{
	Use:   "cache",
	Short: "Cache management",
}

var cacheRebuildCmd = &cobra.Command{
	Use:   "rebuild",
	Short: "Regenerate shell cache",
	RunE: func(cmd *cobra.Command, args []string) error {
		dataDir := profile.FindDataDir()
		cacheDir := filepath.Join(dataDir, "cache")

		// Platform cache
		info := profile.DetectPlatform()
		if err := profile.GeneratePlatformCache(dataDir, info); err != nil {
			return fmt.Errorf("generating platform cache: %w", err)
		}
		fmt.Printf("Written: %s\n", filepath.Join(cacheDir, "platform.sh"))

		// Profile cache
		profilePath, err := profile.FindProfile()
		if err != nil {
			return fmt.Errorf("finding profile: %w", err)
		}

		if profilePath == "" {
			// No profile — clear stale profile cache if it exists
			os.Remove(filepath.Join(cacheDir, "profile.sh"))
			fmt.Println("No profile found — loader will use all-modules default")
			return nil
		}

		p, err := profile.LoadProfile(profilePath)
		if err != nil {
			return fmt.Errorf("loading profile %s: %w", profilePath, err)
		}

		if err := profile.GenerateProfileCache(dataDir, profilePath, p); err != nil {
			return fmt.Errorf("generating profile cache: %w", err)
		}
		fmt.Printf("Written: %s\n", filepath.Join(cacheDir, "profile.sh"))

		return nil
	},
}

var cacheClearCmd = &cobra.Command{
	Use:   "clear",
	Short: "Clear all cached state",
	RunE: func(cmd *cobra.Command, args []string) error {
		dataDir := profile.FindDataDir()
		if err := profile.ClearCache(dataDir); err != nil {
			return fmt.Errorf("clearing cache: %w", err)
		}
		fmt.Printf("Cleared: %s/cache/\n", dataDir)
		return nil
	},
}

func init() {
	cacheCmd.AddCommand(cacheRebuildCmd)
	cacheCmd.AddCommand(cacheClearCmd)
	rootCmd.AddCommand(cacheCmd)
}
```

Key behaviors:
- Uses `RunE` (not `Run`) for proper error propagation
- When no profile found: clears stale profile cache, prints message, exits 0
- Always regenerates platform cache (even without profile)

- [ ] **Step 2: Verify build**

```bash
cd ~/code/sshpub/dotfiles-cli && go build -o /dev/null .
```

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add cmd/cache.go
git commit -m "feat(cmd): implement cache rebuild and clear commands

cache rebuild writes platform.sh + profile.sh. Falls back gracefully
when no profile exists. cache clear removes entire cache directory.

Part of #25"
```

---

## Task 7: `cmd/profile.go` — Real implementation

**Files:**
- Rewrite: `~/code/sshpub/dotfiles-cli/cmd/profile.go`

Depends on: Tasks 1 + 3 (profile loading, cache generation)

- [ ] **Step 1: Rewrite profile.go**

Replace `cmd/profile.go`:

```go
package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/sshpub/dotfiles-cli/pkg/profile"
	"github.com/spf13/cobra"
)

var profileCmd = &cobra.Command{
	Use:   "profile",
	Short: "Profile management",
}

var profileShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Display current profile",
	RunE: func(cmd *cobra.Command, args []string) error {
		profilePath, err := profile.FindProfile()
		if err != nil {
			return err
		}
		if profilePath == "" {
			fmt.Println("No profile found — using all-modules default")
			return nil
		}

		p, err := profile.LoadProfile(profilePath)
		if err != nil {
			return fmt.Errorf("loading profile: %w", err)
		}

		fmt.Printf("Profile: %s\n", profilePath)

		dotfilesDir, err := profile.FindDotfilesDir(p)
		if err == nil {
			fmt.Printf("Dotfiles: %s\n", dotfilesDir)
		}

		fmt.Println()

		// Role
		if len(p.Role) > 0 {
			fmt.Printf("Role: %s\n", strings.Join(p.Role, ", "))
		}

		// Modules
		enabled := p.EnabledModules()
		if len(enabled) > 0 {
			fmt.Printf("Modules (%d enabled):\n", len(enabled))
			fmt.Printf("  %s\n", strings.Join(enabled, ", "))
		}

		disabled := p.DisabledSections()
		if len(disabled) > 0 {
			fmt.Printf("Disabled sections: %s\n", strings.Join(disabled, ", "))
		}

		// Modes
		if len(p.Modes) > 0 {
			fmt.Println("Modes:")
			for name, mode := range p.Modes {
				modeType := mode.Type
				if modeType == "" {
					modeType = "include"
				}
				triggers := strings.Join(mode.EnvTriggers, ", ")
				fmt.Printf("  %s (%s)", name, modeType)
				if triggers != "" {
					fmt.Printf(": triggers %s", triggers)
				}
				if len(mode.IncludeModules) > 0 {
					fmt.Printf(" → loads %s", strings.Join(mode.IncludeModules, ", "))
				}
				if len(mode.NeverLoad) > 0 {
					fmt.Printf(" → skips %s", strings.Join(mode.NeverLoad, ", "))
				}
				fmt.Println()
			}
		}

		// Git
		if p.Git != nil && (p.Git.Name != "" || p.Git.Email != "") {
			fmt.Printf("Git: %s <%s>\n", p.Git.Name, p.Git.Email)
		}

		return nil
	},
}

var profileEditCmd = &cobra.Command{
	Use:   "edit",
	Short: "Open profile in $EDITOR",
	RunE: func(cmd *cobra.Command, args []string) error {
		profilePath, err := profile.FindProfile()
		if err != nil {
			return err
		}
		if profilePath == "" {
			return fmt.Errorf("no profile found — create one with: dotfiles setup")
		}

		editor := findEditor()
		if editor == "" {
			return fmt.Errorf("no editor found: set $EDITOR or $VISUAL")
		}

		// Open editor
		c := exec.Command(editor, profilePath)
		c.Stdin = os.Stdin
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		if err := c.Run(); err != nil {
			return fmt.Errorf("editor exited with error: %w", err)
		}

		// Auto-rebuild cache after edit
		fmt.Println("Rebuilding cache...")
		return cacheRebuildCmd.RunE(cacheRebuildCmd, nil)
	},
}

var profileWizardCmd = &cobra.Command{
	Use:   "wizard",
	Short: "Interactive profile wizard",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Not implemented — use `dotfiles setup`")
	},
}

var profileExportCmd = &cobra.Command{
	Use:   "export",
	Short: "Export profile (redacted) to stdout",
	RunE: func(cmd *cobra.Command, args []string) error {
		profilePath, err := profile.FindProfile()
		if err != nil {
			return err
		}
		if profilePath == "" {
			return fmt.Errorf("no profile found")
		}

		p, err := profile.LoadProfile(profilePath)
		if err != nil {
			return err
		}

		// Redact git identity
		if p.Git != nil {
			if p.Git.Name != "" {
				p.Git.Name = "Your Name"
			}
			if p.Git.Email != "" {
				p.Git.Email = "you@example.com"
			}
		}

		data, err := json.MarshalIndent(p, "", "  ")
		if err != nil {
			return err
		}
		fmt.Println(string(data))
		return nil
	},
}

// findEditor returns the first available editor from the fallback chain.
func findEditor() string {
	for _, env := range []string{"EDITOR", "VISUAL"} {
		if e := os.Getenv(env); e != "" {
			return e
		}
	}
	for _, name := range []string{"vim", "vi", "nano"} {
		if path, err := exec.LookPath(name); err == nil {
			return path
		}
	}
	return ""
}

func init() {
	profileCmd.AddCommand(profileShowCmd)
	profileCmd.AddCommand(profileEditCmd)
	profileCmd.AddCommand(profileWizardCmd)
	profileCmd.AddCommand(profileExportCmd)
	rootCmd.AddCommand(profileCmd)
}
```

Key behaviors:
- `profile edit` auto-runs `cache rebuild` after the editor exits
- `profile wizard` is a stub pointing to `dotfiles setup` (per spec)
- `profile export` redacts git name/email with placeholders
- Editor fallback chain: `$EDITOR` > `$VISUAL` > `vim` > `vi` > `nano`

- [ ] **Step 2: Verify build**

```bash
cd ~/code/sshpub/dotfiles-cli && go build -o /dev/null .
```

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add cmd/profile.go
git commit -m "feat(cmd): implement profile show, edit, export commands

profile show displays formatted summary. profile edit opens \$EDITOR
then auto-rebuilds cache. profile export redacts git identity.
profile wizard stubs to 'dotfiles setup'.

Part of #25"
```

---

## Task 8: `cmd/mode.go` — Replace minimal.go

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/cmd/mode.go`
- Delete: `~/code/sshpub/dotfiles-cli/cmd/minimal.go`

Depends on: Tasks 1 + 3 (profile loading, cache generation)

- [ ] **Step 1: Delete minimal.go, create mode.go**

Delete `cmd/minimal.go`. Create `cmd/mode.go`:

```go
package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/sshpub/dotfiles-cli/pkg/profile"
	"github.com/spf13/cobra"
)

var modeFlag string

var modeCmd = &cobra.Command{
	Use:   "mode",
	Short: "Mode management (minimal, server, etc.)",
}

var modeShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show mode configuration",
	RunE: func(cmd *cobra.Command, args []string) error {
		p, _, err := loadProfileOrDefault()
		if err != nil {
			return err
		}

		modeName := modeFlag

		if p.Modes == nil || p.Modes[modeName] == nil {
			if modeName == "minimal" {
				fmt.Println("Mode: minimal (hardcoded default)")
				fmt.Println("Triggers: CLAUDE_CODE, CODEX, GEMINI_CLI, OPENCODE, GROK_CLI, CI, GITHUB_ACTIONS, GITLAB_CI")
				fmt.Println("Loads modules: (none — platform + PATH + exports only)")
				return nil
			}
			return fmt.Errorf("mode %q not found in profile", modeName)
		}

		mode := p.Modes[modeName]
		modeType := mode.Type
		if modeType == "" {
			modeType = "include"
		}

		fmt.Printf("Mode: %s (type: %s)\n", modeName, modeType)
		if len(mode.EnvTriggers) > 0 {
			fmt.Printf("Triggers: %s\n", strings.Join(mode.EnvTriggers, ", "))
		}
		if len(mode.IncludeModules) > 0 {
			fmt.Printf("Loads modules: %s\n", strings.Join(mode.IncludeModules, ", "))
		}
		if len(mode.NeverLoad) > 0 {
			fmt.Printf("Never loads: %s\n", strings.Join(mode.NeverLoad, ", "))
		}

		return nil
	},
}

var modeTestCmd = &cobra.Command{
	Use:   "test",
	Short: "Spawn a shell in the named mode",
	RunE: func(cmd *cobra.Command, args []string) error {
		modeName := modeFlag
		fmt.Printf("Spawning shell with DOTFILES_MODE=%s ...\n", modeName)

		c := exec.Command("bash", "-l")
		c.Env = append(os.Environ(), fmt.Sprintf("DOTFILES_MODE=%s", modeName))
		c.Stdin = os.Stdin
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		return c.Run()
	},
}

var modeAddTriggerCmd = &cobra.Command{
	Use:   "add-trigger VAR",
	Short: "Add an env trigger to a mode",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		trigger := args[0]
		return mutateMode(modeFlag, func(mode *profile.Mode) {
			// Don't add duplicates
			for _, t := range mode.EnvTriggers {
				if t == trigger {
					return
				}
			}
			mode.EnvTriggers = append(mode.EnvTriggers, trigger)
		})
	},
}

var modeIncludeCmd = &cobra.Command{
	Use:   "include MODULE",
	Short: "Add module to mode's include list",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		mod := args[0]
		return mutateMode(modeFlag, func(mode *profile.Mode) {
			for _, m := range mode.IncludeModules {
				if m == mod {
					return
				}
			}
			mode.IncludeModules = append(mode.IncludeModules, mod)
		})
	},
}

var modeExcludeCmd = &cobra.Command{
	Use:   "exclude MODULE",
	Short: "Exclude module from mode",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		mod := args[0]
		return mutateMode(modeFlag, func(mode *profile.Mode) {
			modeType := mode.Type
			if modeType == "" {
				modeType = "include"
			}

			if modeType == "include" {
				// Remove from include list
				filtered := mode.IncludeModules[:0]
				for _, m := range mode.IncludeModules {
					if m != mod {
						filtered = append(filtered, m)
					}
				}
				mode.IncludeModules = filtered
			} else {
				// Add to never_load (no duplicates)
				for _, m := range mode.NeverLoad {
					if m == mod {
						return
					}
				}
				mode.NeverLoad = append(mode.NeverLoad, mod)
			}
		})
	},
}

// loadProfileOrDefault loads the profile and returns it with its path.
// Returns a zero Profile if none found.
func loadProfileOrDefault() (*profile.Profile, string, error) {
	profilePath, err := profile.FindProfile()
	if err != nil {
		return nil, "", err
	}
	if profilePath == "" {
		return &profile.Profile{}, "", nil
	}
	p, err := profile.LoadProfile(profilePath)
	if err != nil {
		return nil, "", err
	}
	return p, profilePath, nil
}

// mutateMode loads profile, applies a mutation to the named mode, saves, and rebuilds cache.
func mutateMode(modeName string, fn func(*profile.Mode)) error {
	profilePath, err := profile.FindProfile()
	if err != nil {
		return err
	}
	if profilePath == "" {
		return fmt.Errorf("no profile found — create one with: dotfiles setup")
	}

	p, err := profile.LoadProfile(profilePath)
	if err != nil {
		return err
	}

	if p.Modes == nil {
		p.Modes = make(map[string]*profile.Mode)
	}
	if p.Modes[modeName] == nil {
		p.Modes[modeName] = &profile.Mode{Type: "include"}
	}

	fn(p.Modes[modeName])

	if err := profile.SaveProfile(profilePath, p); err != nil {
		return fmt.Errorf("saving profile: %w", err)
	}

	fmt.Printf("Updated mode %q in %s\n", modeName, profilePath)

	// Rebuild cache
	dataDir := profile.FindDataDir()
	if err := profile.GenerateProfileCache(dataDir, profilePath, p); err != nil {
		return fmt.Errorf("rebuilding cache: %w", err)
	}
	fmt.Println("Cache rebuilt")

	return nil
}

func init() {
	// Add --mode flag to all subcommands
	for _, cmd := range []*cobra.Command{modeShowCmd, modeTestCmd, modeAddTriggerCmd, modeIncludeCmd, modeExcludeCmd} {
		cmd.Flags().StringVar(&modeFlag, "mode", "minimal", "mode name")
	}
	modeCmd.AddCommand(modeShowCmd)
	modeCmd.AddCommand(modeTestCmd)
	modeCmd.AddCommand(modeAddTriggerCmd)
	modeCmd.AddCommand(modeIncludeCmd)
	modeCmd.AddCommand(modeExcludeCmd)
	rootCmd.AddCommand(modeCmd)
}
```

Key behaviors:
- `--mode` flag on all subcommands, defaults to `"minimal"`
- `mode show` falls back to hardcoded defaults when no profile exists (matches `_dotfiles_default_profile` in loader.sh)
- `mode test` spawns `bash -l` with `DOTFILES_MODE` set (matches `dotfiles_test_mode` shell function)
- All mutation commands: load → modify → save → cache rebuild
- `mode exclude` behavior differs by mode type: include-type removes from include list, exclude-type adds to never_load
- Duplicate prevention on all add operations

- [ ] **Step 2: Verify build**

```bash
cd ~/code/sshpub/dotfiles-cli && go build -o /dev/null .
```

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git rm cmd/minimal.go
git add cmd/mode.go
git commit -m "feat(cmd): add mode commands, replacing minimal.go

Generic mode system with --mode flag (defaults to minimal).
show, test, add-trigger, include, exclude. All mutations auto-save
profile and rebuild cache.

Part of #25"
```

---

## Task 9: `cmd/doctor.go` — Real implementation

**Files:**
- Rewrite: `~/code/sshpub/dotfiles-cli/cmd/doctor.go`

Depends on: Tasks 1-4 (profile, platform, cache, module packages)

- [ ] **Step 1: Rewrite doctor.go**

Replace `cmd/doctor.go`:

```go
package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/sshpub/dotfiles-cli/pkg/module"
	"github.com/sshpub/dotfiles-cli/pkg/profile"
	"github.com/spf13/cobra"
)

type checkResult struct {
	status  string // "pass", "warn", "fail"
	message string
	fix     string
}

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Health check for symlinks, modules, profile, and dependencies",
	RunE: func(cmd *cobra.Command, args []string) error {
		var results []checkResult

		// Check 1: Profile found
		profilePath, err := profile.FindProfile()
		if err != nil {
			results = append(results, checkResult{"fail", "Error searching for profile", ""})
		} else if profilePath == "" {
			results = append(results, checkResult{"warn", "No profile found — using all-modules default", "dotfiles setup"})
		} else {
			results = append(results, checkResult{"pass", fmt.Sprintf("Profile found: %s", profilePath), ""})
		}

		// Check 2: Profile valid JSON
		var p *profile.Profile
		if profilePath != "" {
			p, err = profile.LoadProfile(profilePath)
			if err != nil {
				results = append(results, checkResult{"fail", fmt.Sprintf("Profile invalid: %s", err), ""})
			} else {
				results = append(results, checkResult{"pass", "Profile valid JSON", ""})
			}
		}

		// Check 3: Dotfiles directory exists
		var dotfilesDir string
		if p != nil {
			dotfilesDir, err = profile.FindDotfilesDir(p)
		} else {
			dotfilesDir = os.Getenv("DOTFILES_DIR")
			if dotfilesDir == "" {
				err = fmt.Errorf("not set")
			}
		}
		if err != nil || dotfilesDir == "" {
			results = append(results, checkResult{"fail", "Dotfiles directory not found", "Set $DOTFILES_DIR or dotfiles_dir in profile"})
		} else if info, statErr := os.Stat(dotfilesDir); statErr != nil || !info.IsDir() {
			results = append(results, checkResult{"fail", fmt.Sprintf("Dotfiles directory missing: %s", dotfilesDir), ""})
		} else {
			results = append(results, checkResult{"pass", fmt.Sprintf("Dotfiles directory: %s", dotfilesDir), ""})
		}

		// Check 4: Modules exist and valid
		if dotfilesDir != "" {
			enabled := []string{}
			if p != nil {
				enabled = p.EnabledModules()
			}

			modules, discoverErr := module.DiscoverModules(dotfilesDir)
			if discoverErr != nil {
				results = append(results, checkResult{"warn", fmt.Sprintf("Cannot read modules: %s", discoverErr), ""})
			} else {
				// Build lookup of discovered modules
				discovered := make(map[string]module.Module)
				for _, m := range modules {
					discovered[m.Name] = m
				}

				if len(enabled) == 0 && p != nil {
					results = append(results, checkResult{"pass", fmt.Sprintf("%d modules discovered (no profile filter)", len(modules)), ""})
				} else if len(enabled) > 0 {
					allExist := true
					for _, name := range enabled {
						if _, ok := discovered[name]; !ok {
							results = append(results, checkResult{"fail", fmt.Sprintf("Module %s: enabled but directory missing", name), ""})
							allExist = false
						}
					}
					if allExist {
						results = append(results, checkResult{"pass", fmt.Sprintf("%d modules enabled, all directories exist", len(enabled)), ""})
					}
				}

				// Check 4b: Module dependencies satisfied
				if len(enabled) > 0 {
					enabledSet := make(map[string]bool)
					for _, name := range enabled {
						enabledSet[name] = true
					}
					for _, name := range enabled {
						m, ok := discovered[name]
						if !ok {
							continue
						}
						for _, dep := range m.Dependencies {
							if !enabledSet[dep] {
								results = append(results, checkResult{
									"fail",
									fmt.Sprintf("Module %s: missing dependency %q", name, dep),
									fmt.Sprintf("dotfiles module enable %s", dep),
								})
							}
						}
					}
				}

				// Check module.json validity
				for _, m := range modules {
					errs := module.ValidateModule(&m)
					if len(errs) > 0 {
						results = append(results, checkResult{
							"warn",
							fmt.Sprintf("Module %s: %s", m.Name, strings.Join(errs, "; ")),
							"",
						})
					}
				}
			}
		}

		// Check 5: Platform cache exists and matches
		dataDir := profile.FindDataDir()
		platformCache := filepath.Join(dataDir, "cache", "platform.sh")
		if _, statErr := os.Stat(platformCache); statErr != nil {
			results = append(results, checkResult{"warn", "Platform cache missing", "dotfiles cache rebuild"})
		} else {
			results = append(results, checkResult{"pass", "Platform cache current", ""})
		}

		// Check 6: Profile cache freshness
		if profilePath != "" {
			profileCache := filepath.Join(dataDir, "cache", "profile.sh")
			profileInfo, profileStatErr := os.Stat(profilePath)
			cacheInfo, cacheStatErr := os.Stat(profileCache)
			if cacheStatErr != nil {
				results = append(results, checkResult{"warn", "Profile cache missing", "dotfiles cache rebuild"})
			} else if profileInfo.ModTime().After(cacheInfo.ModTime()) {
				results = append(results, checkResult{"warn", "Profile cache stale (profile modified after cache)", "dotfiles cache rebuild"})
			} else if profileStatErr == nil {
				results = append(results, checkResult{"pass", "Profile cache current", ""})
			}
		}

		// Check 7: Symlinks intact
		if dotfilesDir != "" {
			modules, _ := module.DiscoverModules(dotfilesDir)
			brokenLinks := 0
			for _, m := range modules {
				for _, target := range m.Symlinks {
					expanded := os.ExpandEnv(target)
					if _, err := os.Stat(expanded); err != nil {
						brokenLinks++
					}
				}
			}
			if brokenLinks > 0 {
				results = append(results, checkResult{"warn", fmt.Sprintf("%d broken symlinks", brokenLinks), "dotfiles module sync"})
			} else {
				results = append(results, checkResult{"pass", "No broken symlinks", ""})
			}
		}

		// Check 8: Binary architecture
		detected := profile.DetectPlatform()
		binaryArch := runtime.GOARCH
		if binaryArch == detected.Arch {
			results = append(results, checkResult{"pass", fmt.Sprintf("Binary matches platform (%s/%s)", detected.OS, detected.Arch), ""})
		} else {
			results = append(results, checkResult{"warn", fmt.Sprintf("Binary arch %s != detected %s", binaryArch, detected.Arch), ""})
		}

		// Print results
		fmt.Println()
		pass, warn, fail := 0, 0, 0
		for _, r := range results {
			var icon string
			switch r.status {
			case "pass":
				icon = "✓"
				pass++
			case "warn":
				icon = "⚠"
				warn++
			case "fail":
				icon = "✗"
				fail++
			}
			fmt.Printf("  %s %s\n", icon, r.message)
			if r.fix != "" {
				fmt.Printf("    → Fix: %s\n", r.fix)
			}
		}
		fmt.Printf("\n%d passed, %d warnings, %d failures\n", pass, warn, fail)

		if fail > 0 {
			os.Exit(1)
		}
		return nil
	},
}

func init() {
	rootCmd.AddCommand(doctorCmd)
}
```

Key behaviors:
- 8 health checks per spec
- Exit code 0 if no failures (warnings OK), exit code 1 if any failures
- Fix hints point to real CLI commands
- Symlink check expands env vars in targets (e.g. `$HOME/.vimrc`)
- Module dependency check verifies all deps are in the enabled set

- [ ] **Step 2: Verify build**

```bash
cd ~/code/sshpub/dotfiles-cli && go build -o /dev/null .
```

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add cmd/doctor.go
git commit -m "feat(cmd): implement doctor with 8 health checks and fix hints

Checks profile, dotfiles dir, modules, dependencies, caches, symlinks,
and binary arch. Reports pass/warn/fail with actionable fix hints.
Exit 1 on failures.

Part of #25"
```

---

## Task 10: Integration test + push

Depends on: All previous tasks

- [ ] **Step 1: Run all tests**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./...
```

All tests must pass.

- [ ] **Step 2: Build and smoke test**

```bash
cd ~/code/sshpub/dotfiles-cli
go build -o ./dotfiles .
./dotfiles platform
./dotfiles cache rebuild
./dotfiles cache clear
./dotfiles profile show
./dotfiles mode show
./dotfiles mode show --mode minimal
./dotfiles doctor
./dotfiles version
rm ./dotfiles
```

Verify each command produces reasonable output (not "not implemented").

- [ ] **Step 3: Verify no remaining "not implemented" stubs**

```bash
cd ~/code/sshpub/dotfiles-cli && grep -rn "not implemented" cmd/ pkg/
```

Expected: Only `profile wizard` should print "Not implemented — use `dotfiles setup`".

- [ ] **Step 4: Push branch**

```bash
cd ~/code/sshpub/dotfiles-cli
git push -u origin feat/25-cli-commands
```

- [ ] **Step 5: Wait for CI**

```bash
gh run watch --repo sshpub/dotfiles-cli
```

Expected: CI passes (test + build succeed).

---

## Task Dependency Graph

```
Task 1 (pkg/profile)  ──┬──→ Task 5 (cmd/platform)
Task 2 (platform.go)  ──┤
Task 3 (cache.go)     ──┼──→ Task 6 (cmd/cache)
                         ├──→ Task 7 (cmd/profile)
                         ├──→ Task 8 (cmd/mode)
Task 4 (pkg/module)   ──┼──→ Task 9 (cmd/doctor)
                         │
                         └──→ Task 10 (integration + push)
```

**Parallel opportunities:**
- Tasks 1+2+3 are in the same package but independent files — can be one combined task or sequential
- Task 4 is fully independent of Tasks 1-3
- Tasks 5, 6, 7, 8 can run in parallel once Tasks 1-3 are done
- Task 9 depends on all packages
- Task 10 is final gate
