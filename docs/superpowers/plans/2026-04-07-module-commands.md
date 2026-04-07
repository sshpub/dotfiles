# Module Management Commands Implementation Plan — Issue #24

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 10 local module lifecycle commands for `sshpub/dotfiles-cli`: list, info, enable, disable, install, validate, create, override, reset.

**Architecture:** Extend `pkg/module` with enable/disable/scaffold/override/validate functions. Create `pkg/installer` for platform-aware package installation. Rewrite `cmd/module.go` to wire Cobra commands to package functions. Registry commands remain as stubs (deferred to #30).

**Tech Stack:** Go 1.25, Cobra, encoding/json, os/exec, runtime

---

**Spec:** `docs/superpowers/specs/2026-04-07-module-commands-design.md` (in sshpub/dotfiles repo)

**Working directory:** `~/code/sshpub/dotfiles-cli/`

**Branch:** `feat/24-module-commands` (from main)

**File Map:**

| File | Action | Purpose |
|------|--------|---------|
| `pkg/installer/installer.go` | Create (replace doc.go) | ResolveRecipes, Install |
| `pkg/installer/installer_test.go` | Create | Installer tests |
| `pkg/module/enable.go` | Create | Enable, Disable profile mutations |
| `pkg/module/enable_test.go` | Create | Enable/Disable tests |
| `pkg/module/section.go` | Create | ExtractSection, ResetOverride |
| `pkg/module/section_test.go` | Create | Section extraction tests |
| `pkg/module/scaffold.go` | Create | Scaffold new module |
| `pkg/module/scaffold_test.go` | Create | Scaffold tests |
| `pkg/module/validate.go` | Create | ValidateSectionGuards |
| `pkg/module/validate_test.go` | Create | Section guard validation tests |
| `pkg/installer/doc.go` | Delete | Replaced by installer.go |
| `cmd/module.go` | Rewrite | Wire all 10 commands to package functions |

---

## Task 1: `pkg/installer` — Platform-aware package installation

**Files:**
- Delete: `~/code/sshpub/dotfiles-cli/pkg/installer/doc.go`
- Create: `~/code/sshpub/dotfiles-cli/pkg/installer/installer.go`
- Create: `~/code/sshpub/dotfiles-cli/pkg/installer/installer_test.go`

Independent of all other tasks.

- [ ] **Step 1: Delete doc.go, create installer.go**

Delete `pkg/installer/doc.go`. Create `pkg/installer/installer.go`:

```go
package installer

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// InstallRecipes mirrors module.InstallRecipes for decoupling.
type InstallRecipes struct {
	Brew    []string
	Apt     []string
	Dnf     []string
	Pacman  []string
	Snap    []string
	Zypper  []string
	Inherit string
}

// ResolveRecipes determines the package manager and package list for the
// current platform. It follows the inherit chain if the current platform
// has no direct recipes.
//
// platformOS is "macos", "linux", or "wsl".
// platformPkgManager is "brew", "apt", "dnf", "pacman", "zypper", "yum", or "".
// recipes maps platform name ("macos", "linux", "wsl") to InstallRecipes.
func ResolveRecipes(platformOS, platformPkgManager string, recipes map[string]*InstallRecipes) (manager string, packages []string, err error) {
	if recipes == nil {
		return "", nil, nil
	}

	// Determine which platform key to look up
	platformKey := platformOS
	if platformOS == "wsl" {
		// WSL is treated as linux unless it has its own entry
		if _, ok := recipes["wsl"]; !ok {
			platformKey = "linux"
		}
	}

	r := recipes[platformKey]
	if r == nil {
		return "", nil, nil
	}

	// Follow inherit chain (max depth 3 to prevent loops)
	for i := 0; i < 3 && r.Inherit != ""; i++ {
		inherited := recipes[r.Inherit]
		if inherited == nil {
			break
		}
		r = inherited
	}

	// Match platform package manager to recipe field
	switch platformPkgManager {
	case "brew":
		return "brew", r.Brew, nil
	case "apt":
		return "apt", r.Apt, nil
	case "dnf":
		return "dnf", r.Dnf, nil
	case "pacman":
		return "pacman", r.Pacman, nil
	case "zypper":
		return "zypper", r.Zypper, nil
	case "yum":
		// yum uses dnf recipes as fallback
		if len(r.Dnf) > 0 {
			return "yum", r.Dnf, nil
		}
		return "", nil, nil
	default:
		return "", nil, nil
	}
}

// installCommand is a package-level var for testability.
var installCommand = func(name string, args ...string) *exec.Cmd {
	return exec.Command(name, args...)
}

// Install runs the package manager to install the given packages.
// If dryRun is true, prints the command instead of executing it.
func Install(manager string, packages []string, dryRun bool) error {
	if len(packages) == 0 {
		return nil
	}

	var args []string
	needsSudo := false

	switch manager {
	case "brew":
		args = append([]string{"install"}, packages...)
	case "apt":
		args = append([]string{"install", "-y"}, packages...)
		needsSudo = true
	case "dnf", "yum":
		args = append([]string{"install", "-y"}, packages...)
		needsSudo = true
	case "pacman":
		args = append([]string{"-S", "--noconfirm"}, packages...)
		needsSudo = true
	case "zypper":
		args = append([]string{"install", "-y"}, packages...)
		needsSudo = true
	default:
		return fmt.Errorf("unsupported package manager: %s", manager)
	}

	// Prepend sudo if needed and not root
	cmdName := manager
	if needsSudo && os.Getuid() != 0 {
		args = append([]string{cmdName}, args...)
		cmdName = "sudo"
	}

	if dryRun {
		fmt.Printf("  %s %s\n", cmdName, strings.Join(args, " "))
		return nil
	}

	fmt.Printf("Running: %s %s\n", cmdName, strings.Join(args, " "))
	cmd := installCommand(cmdName, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
```

- [ ] **Step 2: Create installer_test.go**

Create `pkg/installer/installer_test.go`:

```go
package installer

import (
	"bytes"
	"io"
	"os"
	"testing"
)

func TestResolveRecipes_LinuxApt(t *testing.T) {
	recipes := map[string]*InstallRecipes{
		"linux": {Apt: []string{"git", "git-lfs"}},
	}
	mgr, pkgs, err := ResolveRecipes("linux", "apt", recipes)
	if err != nil {
		t.Fatalf("error: %v", err)
	}
	if mgr != "apt" {
		t.Errorf("manager = %q, want apt", mgr)
	}
	if len(pkgs) != 2 || pkgs[0] != "git" {
		t.Errorf("packages = %v, want [git git-lfs]", pkgs)
	}
}

func TestResolveRecipes_MacosBrew(t *testing.T) {
	recipes := map[string]*InstallRecipes{
		"macos": {Brew: []string{"ripgrep", "fd"}},
	}
	mgr, pkgs, err := ResolveRecipes("macos", "brew", recipes)
	if err != nil {
		t.Fatalf("error: %v", err)
	}
	if mgr != "brew" || len(pkgs) != 2 {
		t.Errorf("got %q %v, want brew [ripgrep fd]", mgr, pkgs)
	}
}

func TestResolveRecipes_Inherit(t *testing.T) {
	recipes := map[string]*InstallRecipes{
		"linux": {Apt: []string{"git"}},
		"wsl":   {Inherit: "linux"},
	}
	mgr, pkgs, err := ResolveRecipes("wsl", "apt", recipes)
	if err != nil {
		t.Fatalf("error: %v", err)
	}
	if mgr != "apt" || len(pkgs) != 1 || pkgs[0] != "git" {
		t.Errorf("got %q %v, want apt [git]", mgr, pkgs)
	}
}

func TestResolveRecipes_WSLFallbackToLinux(t *testing.T) {
	recipes := map[string]*InstallRecipes{
		"linux": {Apt: []string{"curl"}},
	}
	// WSL with no "wsl" key falls back to "linux"
	mgr, pkgs, err := ResolveRecipes("wsl", "apt", recipes)
	if err != nil {
		t.Fatalf("error: %v", err)
	}
	if mgr != "apt" || len(pkgs) != 1 {
		t.Errorf("got %q %v, want apt [curl]", mgr, pkgs)
	}
}

func TestResolveRecipes_NilRecipes(t *testing.T) {
	mgr, pkgs, err := ResolveRecipes("linux", "apt", nil)
	if err != nil {
		t.Fatalf("error: %v", err)
	}
	if mgr != "" || pkgs != nil {
		t.Errorf("got %q %v, want empty", mgr, pkgs)
	}
}

func TestResolveRecipes_NoPlatform(t *testing.T) {
	recipes := map[string]*InstallRecipes{
		"macos": {Brew: []string{"git"}},
	}
	mgr, pkgs, err := ResolveRecipes("linux", "apt", recipes)
	if err != nil {
		t.Fatalf("error: %v", err)
	}
	if mgr != "" || pkgs != nil {
		t.Errorf("got %q %v, want empty", mgr, pkgs)
	}
}

func TestResolveRecipes_YumFallbackToDnf(t *testing.T) {
	recipes := map[string]*InstallRecipes{
		"linux": {Dnf: []string{"git"}},
	}
	mgr, pkgs, err := ResolveRecipes("linux", "yum", recipes)
	if err != nil {
		t.Fatalf("error: %v", err)
	}
	if mgr != "yum" || len(pkgs) != 1 {
		t.Errorf("got %q %v, want yum [git]", mgr, pkgs)
	}
}

func TestInstall_DryRun(t *testing.T) {
	// Capture stdout
	old := os.Stdout
	r, w, _ := os.Pipe()
	os.Stdout = w

	err := Install("brew", []string{"git", "git-lfs"}, true)

	w.Close()
	os.Stdout = old
	var buf bytes.Buffer
	io.Copy(&buf, r)

	if err != nil {
		t.Fatalf("error: %v", err)
	}
	output := buf.String()
	if output != "  brew install git git-lfs\n" {
		t.Errorf("output = %q, want \"  brew install git git-lfs\\n\"", output)
	}
}

func TestInstall_EmptyPackages(t *testing.T) {
	err := Install("brew", nil, false)
	if err != nil {
		t.Errorf("Install with empty packages should be no-op, got: %v", err)
	}
}

func TestInstall_UnsupportedManager(t *testing.T) {
	err := Install("nix", []string{"git"}, false)
	if err == nil {
		t.Error("expected error for unsupported manager")
	}
}
```

- [ ] **Step 3: Verify tests pass**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./pkg/installer/...
```

- [ ] **Step 4: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git rm pkg/installer/doc.go
git add pkg/installer/installer.go pkg/installer/installer_test.go
git commit -m "feat(installer): add platform-aware package installation

ResolveRecipes follows inherit chain, matches platform package manager.
Install executes or dry-runs package manager commands with sudo detection.

Part of #24"
```

---

## Task 2: `pkg/module` — Enable and Disable

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/pkg/module/enable.go`
- Create: `~/code/sshpub/dotfiles-cli/pkg/module/enable_test.go`

Independent of Task 1.

- [ ] **Step 1: Create enable.go**

Create `pkg/module/enable.go`:

```go
package module

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Enable sets a module to enabled (true) in the profile's modules map,
// saves the profile, and returns the updated profile bytes.
// Verifies the module directory exists under dotfilesDir.
func Enable(profilePath string, moduleName string, dotfilesDir string) error {
	// Verify module exists on disk
	modDir := filepath.Join(dotfilesDir, "modules", moduleName)
	jsonPath := filepath.Join(modDir, "module.json")
	if _, err := os.Stat(jsonPath); err != nil {
		return fmt.Errorf("module %q not found at %s", moduleName, modDir)
	}

	return mutateProfile(profilePath, func(data map[string]interface{}) {
		modules, ok := data["modules"].(map[string]interface{})
		if !ok {
			modules = make(map[string]interface{})
			data["modules"] = modules
		}
		modules[moduleName] = true
	})
}

// Disable sets a module to disabled (false) in the profile's modules map
// and saves the profile. Does not require the module directory to exist.
func Disable(profilePath string, moduleName string) error {
	return mutateProfile(profilePath, func(data map[string]interface{}) {
		modules, ok := data["modules"].(map[string]interface{})
		if !ok {
			modules = make(map[string]interface{})
			data["modules"] = modules
		}
		modules[moduleName] = false
	})
}

// DisableSection adds a section to the module's disable list in the profile.
func DisableSection(profilePath string, moduleName string, section string) error {
	return mutateProfile(profilePath, func(data map[string]interface{}) {
		modules, ok := data["modules"].(map[string]interface{})
		if !ok {
			modules = make(map[string]interface{})
			data["modules"] = modules
		}

		// Get or create the module object
		modRaw, exists := modules[moduleName]
		var modObj map[string]interface{}

		switch v := modRaw.(type) {
		case map[string]interface{}:
			modObj = v
		case bool:
			modObj = map[string]interface{}{"shell": v}
		default:
			if !exists {
				modObj = map[string]interface{}{"shell": true}
			} else {
				modObj = map[string]interface{}{}
			}
		}

		// Get or create disable list
		disableRaw, _ := modObj["disable"].([]interface{})
		for _, d := range disableRaw {
			if s, ok := d.(string); ok && s == section {
				return // already disabled
			}
		}
		modObj["disable"] = append(disableRaw, section)
		modules[moduleName] = modObj
	})
}

// EnableSection removes a section from the module's disable list in the profile.
func EnableSection(profilePath string, moduleName string, section string) error {
	return mutateProfile(profilePath, func(data map[string]interface{}) {
		modules, ok := data["modules"].(map[string]interface{})
		if !ok {
			return
		}
		modObj, ok := modules[moduleName].(map[string]interface{})
		if !ok {
			return
		}
		disableRaw, ok := modObj["disable"].([]interface{})
		if !ok {
			return
		}
		filtered := make([]interface{}, 0, len(disableRaw))
		for _, d := range disableRaw {
			if s, ok := d.(string); ok && s == section {
				continue
			}
			filtered = append(filtered, d)
		}
		if len(filtered) == 0 {
			delete(modObj, "disable")
		} else {
			modObj["disable"] = filtered
		}
	})
}

// mutateProfile reads a profile JSON, applies a mutation, and writes it back.
// Preserves all fields including unknown ones (no struct round-trip).
func mutateProfile(profilePath string, fn func(data map[string]interface{})) error {
	raw, err := os.ReadFile(profilePath)
	if err != nil {
		return err
	}

	var data map[string]interface{}
	if err := json.Unmarshal(raw, &data); err != nil {
		return err
	}

	fn(data)

	out, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}
	out = append(out, '\n')
	return os.WriteFile(profilePath, out, 0644)
}
```

Key design: `mutateProfile` works with `map[string]interface{}` (not the Profile struct) to preserve unknown fields in the JSON. This avoids data loss from round-tripping through a struct that may not cover all fields.

- [ ] **Step 2: Create enable_test.go**

Create `pkg/module/enable_test.go`:

```go
package module

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func writeTestProfile(t *testing.T, dir string, content string) string {
	t.Helper()
	path := filepath.Join(dir, "profile.json")
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("writing test profile: %v", err)
	}
	return path
}

func readProfileModules(t *testing.T, path string) map[string]interface{} {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("reading profile: %v", err)
	}
	var data map[string]interface{}
	if err := json.Unmarshal(raw, &data); err != nil {
		t.Fatalf("parsing profile: %v", err)
	}
	modules, _ := data["modules"].(map[string]interface{})
	return modules
}

func TestEnable_NewModule(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"modules": {"git": true}}`)

	// Create module directory
	modDir := filepath.Join(dir, "modules", "vim")
	os.MkdirAll(modDir, 0755)
	os.WriteFile(filepath.Join(modDir, "module.json"), []byte(`{"name":"vim","version":"1.0.0","description":"test"}`), 0644)

	err := Enable(profilePath, "vim", dir)
	if err != nil {
		t.Fatalf("Enable() error: %v", err)
	}

	modules := readProfileModules(t, profilePath)
	if modules["vim"] != true {
		t.Errorf("vim = %v, want true", modules["vim"])
	}
	// Existing module preserved
	if modules["git"] != true {
		t.Errorf("git = %v, want true (preserved)", modules["git"])
	}
}

func TestEnable_ModuleNotFound(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"modules": {}}`)

	err := Enable(profilePath, "nonexistent", dir)
	if err == nil {
		t.Error("Enable() expected error for missing module")
	}
}

func TestDisable(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"modules": {"git": true, "vim": true}}`)

	err := Disable(profilePath, "vim")
	if err != nil {
		t.Fatalf("Disable() error: %v", err)
	}

	modules := readProfileModules(t, profilePath)
	if modules["vim"] != false {
		t.Errorf("vim = %v, want false", modules["vim"])
	}
	if modules["git"] != true {
		t.Errorf("git = %v, want true (preserved)", modules["git"])
	}
}

func TestDisable_NoModulesMap(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"role": ["personal"]}`)

	err := Disable(profilePath, "vim")
	if err != nil {
		t.Fatalf("Disable() error: %v", err)
	}

	modules := readProfileModules(t, profilePath)
	if modules["vim"] != false {
		t.Errorf("vim = %v, want false", modules["vim"])
	}
}

func TestDisableSection(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"modules": {"git": true}}`)

	err := DisableSection(profilePath, "git", "git.log")
	if err != nil {
		t.Fatalf("DisableSection() error: %v", err)
	}

	modules := readProfileModules(t, profilePath)
	gitObj, ok := modules["git"].(map[string]interface{})
	if !ok {
		t.Fatalf("git should be object, got %T", modules["git"])
	}
	disableRaw, _ := gitObj["disable"].([]interface{})
	if len(disableRaw) != 1 || disableRaw[0] != "git.log" {
		t.Errorf("disable = %v, want [git.log]", disableRaw)
	}
	// shell should be preserved as true
	if gitObj["shell"] != true {
		t.Errorf("shell = %v, want true", gitObj["shell"])
	}
}

func TestDisableSection_NoDuplicate(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"modules": {"git": {"shell": true, "disable": ["git.log"]}}}`)

	err := DisableSection(profilePath, "git", "git.log")
	if err != nil {
		t.Fatalf("DisableSection() error: %v", err)
	}

	modules := readProfileModules(t, profilePath)
	gitObj := modules["git"].(map[string]interface{})
	disableRaw := gitObj["disable"].([]interface{})
	if len(disableRaw) != 1 {
		t.Errorf("disable = %v, should not duplicate", disableRaw)
	}
}

func TestEnableSection(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"modules": {"git": {"shell": true, "disable": ["git.log", "git.branch"]}}}`)

	err := EnableSection(profilePath, "git", "git.log")
	if err != nil {
		t.Fatalf("EnableSection() error: %v", err)
	}

	modules := readProfileModules(t, profilePath)
	gitObj := modules["git"].(map[string]interface{})
	disableRaw := gitObj["disable"].([]interface{})
	if len(disableRaw) != 1 || disableRaw[0] != "git.branch" {
		t.Errorf("disable = %v, want [git.branch]", disableRaw)
	}
}

func TestEnableSection_RemovesEmptyDisableKey(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"modules": {"git": {"shell": true, "disable": ["git.log"]}}}`)

	err := EnableSection(profilePath, "git", "git.log")
	if err != nil {
		t.Fatalf("EnableSection() error: %v", err)
	}

	modules := readProfileModules(t, profilePath)
	gitObj := modules["git"].(map[string]interface{})
	if _, exists := gitObj["disable"]; exists {
		t.Error("disable key should be removed when empty")
	}
}

func TestMutateProfile_PreservesUnknownFields(t *testing.T) {
	dir := t.TempDir()
	profilePath := writeTestProfile(t, dir, `{"_comment": "keep me", "custom_field": 42, "modules": {}}`)

	err := Disable(profilePath, "vim")
	if err != nil {
		t.Fatalf("error: %v", err)
	}

	raw, _ := os.ReadFile(profilePath)
	var data map[string]interface{}
	json.Unmarshal(raw, &data)

	if data["_comment"] != "keep me" {
		t.Error("_comment field lost")
	}
	if data["custom_field"] != float64(42) {
		t.Error("custom_field lost")
	}
}
```

- [ ] **Step 3: Verify tests pass**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./pkg/module/...
```

- [ ] **Step 4: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add pkg/module/enable.go pkg/module/enable_test.go
git commit -m "feat(module): add Enable, Disable, DisableSection, EnableSection

Profile mutation via raw JSON map to preserve unknown fields.
Enable verifies module directory exists. Disable is unconditional.
Section disable/enable manages per-module disable lists.

Part of #24"
```

---

## Task 3: `pkg/module` — Section extraction

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/pkg/module/section.go`
- Create: `~/code/sshpub/dotfiles-cli/pkg/module/section_test.go`

Independent of Tasks 1-2.

- [ ] **Step 1: Create section.go**

Create `pkg/module/section.go`:

```go
package module

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ExtractSection finds a section guard block in a module's shell files
// and returns the code body (without the guard line and closing brace).
//
// Section format: "module.section" (e.g. "git.shortcuts").
// Scans files listed in shell.load_order, or all .sh files if no load_order.
func ExtractSection(mod *Module, section string) (code string, sourceFile string, err error) {
	files := shellFiles(mod)
	if len(files) == 0 {
		return "", "", fmt.Errorf("module %q has no shell files", mod.Name)
	}

	guard := fmt.Sprintf(`dotfiles_section "%s"`, section)

	for _, file := range files {
		path := filepath.Join(mod.Dir, file)
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}

		lines := strings.Split(string(data), "\n")
		body, found := extractGuardBlock(lines, guard)
		if found {
			return body, file, nil
		}
	}

	return "", "", fmt.Errorf("section %q not found in module %q shell files", section, mod.Name)
}

// extractGuardBlock finds a `dotfiles_section "X" && {` line and extracts
// the code body, tracking brace depth for nested blocks.
func extractGuardBlock(lines []string, guard string) (string, bool) {
	inBlock := false
	depth := 0
	var body []string

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if !inBlock {
			// Look for the guard line
			if strings.Contains(trimmed, guard) && strings.HasSuffix(trimmed, "{") {
				inBlock = true
				depth = 1
				continue
			}
			continue
		}

		// Count braces
		for _, ch := range line {
			switch ch {
			case '{':
				depth++
			case '}':
				depth--
			}
		}

		if depth <= 0 {
			// Closing brace of the guard block
			return strings.Join(body, "\n"), true
		}

		body = append(body, line)
	}

	return "", false
}

// WriteOverride writes extracted section code to an override file.
// The file includes a section guard so it integrates with the loader.
func WriteOverride(overrideDir string, section string, code string, sourceModule string, sourceFile string) error {
	if err := os.MkdirAll(overrideDir, 0755); err != nil {
		return err
	}

	fileName := section + ".sh"
	path := filepath.Join(overrideDir, fileName)

	var b strings.Builder
	fmt.Fprintf(&b, "#!/usr/bin/env bash\n")
	fmt.Fprintf(&b, "# Override: %s (extracted from modules/%s/%s)\n", section, sourceModule, sourceFile)
	fmt.Fprintf(&b, "# Edit this file to customize. Remove to restore module default.\n\n")
	fmt.Fprintf(&b, "dotfiles_section \"%s\" && {\n", section)
	b.WriteString(code)
	b.WriteString("\n}\n")

	return os.WriteFile(path, []byte(b.String()), 0644)
}

// ResetOverride removes override files for a section from both repo and local dirs.
func ResetOverride(repoOverrideDir string, localOverrideDir string, section string) (removed []string) {
	fileName := section + ".sh"

	for _, dir := range []string{repoOverrideDir, localOverrideDir} {
		if dir == "" {
			continue
		}
		path := filepath.Join(dir, fileName)
		if _, err := os.Stat(path); err == nil {
			os.Remove(path)
			removed = append(removed, path)
		}
	}

	return removed
}

// shellFiles returns the list of .sh files for a module.
// Uses shell.load_order if defined, otherwise discovers all .sh files.
func shellFiles(mod *Module) []string {
	if mod.Shell != nil && len(mod.Shell.LoadOrder) > 0 {
		return mod.Shell.LoadOrder
	}

	entries, err := os.ReadDir(mod.Dir)
	if err != nil {
		return nil
	}

	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sh") {
			files = append(files, e.Name())
		}
	}
	return files
}
```

- [ ] **Step 2: Create section_test.go**

Create `pkg/module/section_test.go`:

```go
package module

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const testShellContent = `#!/usr/bin/env bash
# test module

dotfiles_section "test.aliases" && {
    alias foo="bar"
    alias baz="qux"
}

dotfiles_section "test.functions" && {
    myfunc() {
        if [[ -n "$1" ]]; then
            echo "$1"
        fi
    }
}
`

func setupTestModule(t *testing.T) *Module {
	t.Helper()
	dir := t.TempDir()
	modDir := filepath.Join(dir, "modules", "test")
	os.MkdirAll(modDir, 0755)
	os.WriteFile(filepath.Join(modDir, "aliases.sh"), []byte(testShellContent), 0644)
	os.WriteFile(filepath.Join(modDir, "module.json"), []byte(`{
		"name": "test", "version": "1.0.0", "description": "test",
		"sections": {"test.aliases": "Aliases", "test.functions": "Functions"},
		"shell": {"load_order": ["aliases.sh"]}
	}`), 0644)
	return &Module{
		Name: "test",
		Dir:  modDir,
		Shell: &ShellConfig{LoadOrder: []string{"aliases.sh"}},
		Sections: map[string]string{
			"test.aliases":   "Aliases",
			"test.functions": "Functions",
		},
	}
}

func TestExtractSection_Simple(t *testing.T) {
	mod := setupTestModule(t)
	code, file, err := ExtractSection(mod, "test.aliases")
	if err != nil {
		t.Fatalf("ExtractSection() error: %v", err)
	}
	if file != "aliases.sh" {
		t.Errorf("sourceFile = %q, want aliases.sh", file)
	}
	if !strings.Contains(code, `alias foo="bar"`) {
		t.Errorf("code missing foo alias:\n%s", code)
	}
	if !strings.Contains(code, `alias baz="qux"`) {
		t.Errorf("code missing baz alias:\n%s", code)
	}
}

func TestExtractSection_NestedBraces(t *testing.T) {
	mod := setupTestModule(t)
	code, _, err := ExtractSection(mod, "test.functions")
	if err != nil {
		t.Fatalf("ExtractSection() error: %v", err)
	}
	if !strings.Contains(code, "myfunc()") {
		t.Errorf("code missing function:\n%s", code)
	}
	if !strings.Contains(code, `echo "$1"`) {
		t.Errorf("code missing echo:\n%s", code)
	}
}

func TestExtractSection_NotFound(t *testing.T) {
	mod := setupTestModule(t)
	_, _, err := ExtractSection(mod, "test.nonexistent")
	if err == nil {
		t.Error("expected error for missing section")
	}
}

func TestWriteOverride(t *testing.T) {
	dir := t.TempDir()
	overrideDir := filepath.Join(dir, "overrides")

	code := "    alias foo=\"custom\""
	err := WriteOverride(overrideDir, "test.aliases", code, "test", "aliases.sh")
	if err != nil {
		t.Fatalf("WriteOverride() error: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(overrideDir, "test.aliases.sh"))
	if err != nil {
		t.Fatalf("reading override: %v", err)
	}
	content := string(data)

	if !strings.Contains(content, "# Override: test.aliases") {
		t.Error("missing override header")
	}
	if !strings.Contains(content, `dotfiles_section "test.aliases" && {`) {
		t.Error("missing section guard")
	}
	if !strings.Contains(content, `alias foo="custom"`) {
		t.Error("missing code body")
	}
}

func TestResetOverride(t *testing.T) {
	dir := t.TempDir()
	repoDir := filepath.Join(dir, "overrides")
	localDir := filepath.Join(dir, "local")
	os.MkdirAll(repoDir, 0755)
	os.MkdirAll(localDir, 0755)

	os.WriteFile(filepath.Join(repoDir, "test.aliases.sh"), []byte("test"), 0644)
	os.WriteFile(filepath.Join(localDir, "test.aliases.sh"), []byte("test"), 0644)

	removed := ResetOverride(repoDir, localDir, "test.aliases")
	if len(removed) != 2 {
		t.Errorf("removed %d files, want 2", len(removed))
	}

	if _, err := os.Stat(filepath.Join(repoDir, "test.aliases.sh")); !os.IsNotExist(err) {
		t.Error("repo override should be removed")
	}
	if _, err := os.Stat(filepath.Join(localDir, "test.aliases.sh")); !os.IsNotExist(err) {
		t.Error("local override should be removed")
	}
}

func TestResetOverride_NoneExist(t *testing.T) {
	dir := t.TempDir()
	removed := ResetOverride(filepath.Join(dir, "overrides"), filepath.Join(dir, "local"), "test.aliases")
	if len(removed) != 0 {
		t.Errorf("removed %d files, want 0", len(removed))
	}
}
```

- [ ] **Step 3: Verify tests pass**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./pkg/module/...
```

- [ ] **Step 4: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add pkg/module/section.go pkg/module/section_test.go
git commit -m "feat(module): add section extraction, override write, and reset

ExtractSection parses dotfiles_section guards with brace depth tracking.
WriteOverride creates override files with section guard wrapper.
ResetOverride removes override files from repo and local dirs.

Part of #24"
```

---

## Task 4: `pkg/module` — Scaffold and ValidateSectionGuards

**Files:**
- Create: `~/code/sshpub/dotfiles-cli/pkg/module/scaffold.go`
- Create: `~/code/sshpub/dotfiles-cli/pkg/module/scaffold_test.go`
- Create: `~/code/sshpub/dotfiles-cli/pkg/module/validate.go`
- Create: `~/code/sshpub/dotfiles-cli/pkg/module/validate_test.go`

Independent of Tasks 1-3.

- [ ] **Step 1: Create scaffold.go**

Create `pkg/module/scaffold.go`:

```go
package module

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Scaffold creates a new module directory with template files.
func Scaffold(dotfilesDir string, name string) (string, error) {
	if !namePattern.MatchString(name) {
		return "", fmt.Errorf("invalid module name %q: must match ^[a-z][a-z0-9-]*$", name)
	}

	modDir := filepath.Join(dotfilesDir, "modules", name)
	if _, err := os.Stat(modDir); err == nil {
		return "", fmt.Errorf("module directory already exists: %s", modDir)
	}

	if err := os.MkdirAll(modDir, 0755); err != nil {
		return "", err
	}

	// module.json
	mod := Module{
		Name:        name,
		Version:     "0.1.0",
		Description: "",
		Sections:    map[string]string{name + ".main": "Main section"},
		Shell:       &ShellConfig{LoadOrder: []string{"aliases.sh"}},
	}
	jsonData, err := json.MarshalIndent(mod, "", "  ")
	if err != nil {
		return "", err
	}
	jsonData = append(jsonData, '\n')
	if err := os.WriteFile(filepath.Join(modDir, "module.json"), jsonData, 0644); err != nil {
		return "", err
	}

	// aliases.sh
	shellContent := fmt.Sprintf(`#!/usr/bin/env bash
# modules/%s/aliases.sh

dotfiles_section "%s.main" && {
    # Add your aliases and functions here
    :
}
`, name, name)
	if err := os.WriteFile(filepath.Join(modDir, "aliases.sh"), []byte(shellContent), 0644); err != nil {
		return "", err
	}

	// CLAUDE.md
	claudeContent := fmt.Sprintf("# Module: %s\n\nDescribe this module for AI assistants.\n", name)
	if err := os.WriteFile(filepath.Join(modDir, "CLAUDE.md"), []byte(claudeContent), 0644); err != nil {
		return "", err
	}

	return modDir, nil
}
```

- [ ] **Step 2: Create scaffold_test.go**

Create `pkg/module/scaffold_test.go`:

```go
package module

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestScaffold(t *testing.T) {
	dir := t.TempDir()
	modDir, err := Scaffold(dir, "my-tool")
	if err != nil {
		t.Fatalf("Scaffold() error: %v", err)
	}

	// module.json exists and is valid
	mod, err := LoadModule(filepath.Join(modDir, "module.json"))
	if err != nil {
		t.Fatalf("LoadModule() error: %v", err)
	}
	if mod.Name != "my-tool" {
		t.Errorf("name = %q, want my-tool", mod.Name)
	}
	if mod.Version != "0.1.0" {
		t.Errorf("version = %q, want 0.1.0", mod.Version)
	}
	if mod.Sections["my-tool.main"] != "Main section" {
		t.Error("missing my-tool.main section")
	}

	// aliases.sh exists with section guard
	data, err := os.ReadFile(filepath.Join(modDir, "aliases.sh"))
	if err != nil {
		t.Fatalf("reading aliases.sh: %v", err)
	}
	if !strings.Contains(string(data), `dotfiles_section "my-tool.main"`) {
		t.Error("aliases.sh missing section guard")
	}

	// CLAUDE.md exists
	if _, err := os.Stat(filepath.Join(modDir, "CLAUDE.md")); err != nil {
		t.Error("CLAUDE.md not created")
	}
}

func TestScaffold_AlreadyExists(t *testing.T) {
	dir := t.TempDir()
	os.MkdirAll(filepath.Join(dir, "modules", "existing"), 0755)

	_, err := Scaffold(dir, "existing")
	if err == nil {
		t.Error("expected error for existing directory")
	}
}

func TestScaffold_InvalidName(t *testing.T) {
	dir := t.TempDir()
	_, err := Scaffold(dir, "Bad_Name")
	if err == nil {
		t.Error("expected error for invalid name")
	}
}
```

- [ ] **Step 3: Create validate.go**

Create `pkg/module/validate.go`:

```go
package module

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var sectionGuardRe = regexp.MustCompile(`dotfiles_section\s+"([^"]+)"`)

// ValidateSectionGuards compares declared sections in module.json against
// actual dotfiles_section calls in the shell files.
// Returns a list of warnings (nil if clean).
func ValidateSectionGuards(mod *Module) []string {
	var warnings []string

	// Collect all guards found in shell files
	foundGuards := make(map[string]bool)
	files := shellFiles(mod)

	for _, file := range files {
		path := filepath.Join(mod.Dir, file)
		data, err := os.ReadFile(path)
		if err != nil {
			warnings = append(warnings, fmt.Sprintf("cannot read %s: %v", file, err))
			continue
		}

		matches := sectionGuardRe.FindAllStringSubmatch(string(data), -1)
		for _, match := range matches {
			foundGuards[match[1]] = true
		}
	}

	// Check declared sections have guards
	for section := range mod.Sections {
		if !foundGuards[section] {
			warnings = append(warnings, fmt.Sprintf("section %q declared in module.json but no guard found in shell files", section))
		}
	}

	// Check guards have declarations
	for guard := range foundGuards {
		// Only check guards that match this module's namespace
		if !strings.HasPrefix(guard, mod.Name+".") {
			continue
		}
		if _, declared := mod.Sections[guard]; !declared {
			warnings = append(warnings, fmt.Sprintf("guard %q found in shell files but not declared in module.json sections", guard))
		}
	}

	return warnings
}
```

- [ ] **Step 4: Create validate_test.go**

Create `pkg/module/validate_test.go`:

```go
package module

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestValidateSectionGuards_AllMatch(t *testing.T) {
	dir := t.TempDir()
	modDir := filepath.Join(dir, "modules", "test")
	os.MkdirAll(modDir, 0755)

	os.WriteFile(filepath.Join(modDir, "aliases.sh"), []byte(`
dotfiles_section "test.main" && {
    alias foo="bar"
}
`), 0644)

	mod := &Module{
		Name:     "test",
		Dir:      modDir,
		Sections: map[string]string{"test.main": "Main"},
		Shell:    &ShellConfig{LoadOrder: []string{"aliases.sh"}},
	}

	warnings := ValidateSectionGuards(mod)
	if len(warnings) != 0 {
		t.Errorf("expected no warnings, got: %v", warnings)
	}
}

func TestValidateSectionGuards_MissingGuard(t *testing.T) {
	dir := t.TempDir()
	modDir := filepath.Join(dir, "modules", "test")
	os.MkdirAll(modDir, 0755)

	os.WriteFile(filepath.Join(modDir, "aliases.sh"), []byte(`
dotfiles_section "test.main" && {
    alias foo="bar"
}
`), 0644)

	mod := &Module{
		Name: "test",
		Dir:  modDir,
		Sections: map[string]string{
			"test.main":    "Main",
			"test.missing": "This has no guard",
		},
		Shell: &ShellConfig{LoadOrder: []string{"aliases.sh"}},
	}

	warnings := ValidateSectionGuards(mod)
	found := false
	for _, w := range warnings {
		if strings.Contains(w, "test.missing") && strings.Contains(w, "no guard found") {
			found = true
		}
	}
	if !found {
		t.Errorf("expected warning about test.missing, got: %v", warnings)
	}
}

func TestValidateSectionGuards_UndeclaredGuard(t *testing.T) {
	dir := t.TempDir()
	modDir := filepath.Join(dir, "modules", "test")
	os.MkdirAll(modDir, 0755)

	os.WriteFile(filepath.Join(modDir, "aliases.sh"), []byte(`
dotfiles_section "test.main" && {
    alias foo="bar"
}
dotfiles_section "test.extra" && {
    alias baz="qux"
}
`), 0644)

	mod := &Module{
		Name:     "test",
		Dir:      modDir,
		Sections: map[string]string{"test.main": "Main"},
		Shell:    &ShellConfig{LoadOrder: []string{"aliases.sh"}},
	}

	warnings := ValidateSectionGuards(mod)
	found := false
	for _, w := range warnings {
		if strings.Contains(w, "test.extra") && strings.Contains(w, "not declared") {
			found = true
		}
	}
	if !found {
		t.Errorf("expected warning about test.extra, got: %v", warnings)
	}
}
```

- [ ] **Step 5: Verify tests pass**

```bash
cd ~/code/sshpub/dotfiles-cli && go test ./pkg/module/...
```

- [ ] **Step 6: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add pkg/module/scaffold.go pkg/module/scaffold_test.go pkg/module/validate.go pkg/module/validate_test.go
git commit -m "feat(module): add scaffold and section guard validation

Scaffold creates module.json + aliases.sh + CLAUDE.md template.
ValidateSectionGuards cross-checks declared sections against guards
found in shell files.

Part of #24"
```

---

## Task 5: `cmd/module.go` — Rewrite with all 10 commands

**Files:**
- Rewrite: `~/code/sshpub/dotfiles-cli/cmd/module.go`

Depends on: Tasks 1-4

- [ ] **Step 1: Rewrite module.go**

Replace `cmd/module.go`:

```go
package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/sshpub/dotfiles-cli/pkg/installer"
	"github.com/sshpub/dotfiles-cli/pkg/module"
	"github.com/sshpub/dotfiles-cli/pkg/profile"
	"github.com/spf13/cobra"
)

var moduleCmd = &cobra.Command{
	Use:   "module",
	Short: "Module management",
	Long:  "List, enable, disable, install, and manage dotfiles modules.",
}

// --- list ---

var moduleListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all modules with enabled/disabled status",
	RunE: func(cmd *cobra.Command, args []string) error {
		p, _, dotfilesDir, err := loadContext()
		if err != nil {
			return err
		}

		modules, err := module.DiscoverModules(dotfilesDir)
		if err != nil {
			return err
		}

		enabledSet := make(map[string]bool)
		noProfile := false
		if p != nil {
			for _, name := range p.EnabledModules() {
				enabledSet[name] = true
			}
		} else {
			noProfile = true
		}

		sort.Slice(modules, func(i, j int) bool {
			return modules[i].Name < modules[j].Name
		})

		enabledCount := 0
		for _, m := range modules {
			if noProfile || enabledSet[m.Name] {
				enabledCount++
			}
		}

		fmt.Printf("Modules (%d discovered, %d enabled):\n\n", len(modules), enabledCount)
		fmt.Printf("  %-20s %-10s %s\n", "NAME", "STATUS", "DESCRIPTION")

		for _, m := range modules {
			status := "disabled"
			if noProfile || enabledSet[m.Name] {
				status = "enabled"
			}
			fmt.Printf("  %-20s %-10s %s\n", m.Name, status, m.Description)
		}
		return nil
	},
}

// --- info ---

var moduleInfoCmd = &cobra.Command{
	Use:   "info [name]",
	Short: "Show module details, sections, and install recipes",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		p, _, dotfilesDir, err := loadContext()
		if err != nil {
			return err
		}

		mod, err := findModule(dotfilesDir, args[0])
		if err != nil {
			return err
		}

		fmt.Printf("Module: %s (%s)\n", mod.Name, mod.Version)
		fmt.Printf("  %s\n", mod.Description)
		if mod.Author != "" {
			fmt.Printf("  Author: %s\n", mod.Author)
		}

		// Status from profile
		status := "enabled"
		if p != nil {
			enabled := p.EnabledModules()
			found := false
			for _, name := range enabled {
				if name == mod.Name {
					found = true
					break
				}
			}
			if !found {
				status = "disabled"
			}
		}
		fmt.Printf("  Status: %s\n", status)
		fmt.Println()

		// Sections
		if len(mod.Sections) > 0 {
			fmt.Println("Sections:")
			for name, desc := range mod.Sections {
				fmt.Printf("  %-30s %s\n", name, desc)
			}
			fmt.Println()
		}

		// Shell files
		if mod.Shell != nil && len(mod.Shell.LoadOrder) > 0 {
			fmt.Printf("Shell: %s\n", strings.Join(mod.Shell.LoadOrder, ", "))
		}

		// Dependencies
		if len(mod.Dependencies) > 0 {
			fmt.Printf("Dependencies: %s\n", strings.Join(mod.Dependencies, ", "))
		}

		// Platforms
		if len(mod.Platforms) > 0 {
			fmt.Printf("Platforms: %s\n", strings.Join(mod.Platforms, ", "))
		}

		// Install recipes
		if len(mod.Install) > 0 {
			fmt.Println("\nInstall recipes:")
			for platform, recipes := range mod.Install {
				if recipes.Inherit != "" {
					fmt.Printf("  %s: (inherits %s)\n", platform, recipes.Inherit)
				} else {
					parts := []string{}
					if len(recipes.Brew) > 0 {
						parts = append(parts, "brew: "+strings.Join(recipes.Brew, ", "))
					}
					if len(recipes.Apt) > 0 {
						parts = append(parts, "apt: "+strings.Join(recipes.Apt, ", "))
					}
					if len(recipes.Dnf) > 0 {
						parts = append(parts, "dnf: "+strings.Join(recipes.Dnf, ", "))
					}
					if len(recipes.Pacman) > 0 {
						parts = append(parts, "pacman: "+strings.Join(recipes.Pacman, ", "))
					}
					fmt.Printf("  %s: %s\n", platform, strings.Join(parts, " | "))
				}
			}
		}

		// Symlinks
		if len(mod.Symlinks) > 0 {
			fmt.Println("\nSymlinks:")
			for src, dst := range mod.Symlinks {
				fmt.Printf("  %-30s → %s\n", src, dst)
			}
		}

		return nil
	},
}

// --- enable / disable ---

var moduleEnableCmd = &cobra.Command{
	Use:   "enable [name]",
	Short: "Enable a module in the profile",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		profilePath, dotfilesDir, err := requireProfile()
		if err != nil {
			return err
		}

		if err := module.Enable(profilePath, args[0], dotfilesDir); err != nil {
			return err
		}

		rebuildCache(profilePath)
		fmt.Printf("Enabled module %q\n", args[0])
		return nil
	},
}

var moduleDisableCmd = &cobra.Command{
	Use:   "disable [name]",
	Short: "Disable a module in the profile",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		profilePath, _, err := requireProfile()
		if err != nil {
			return err
		}

		if err := module.Disable(profilePath, args[0]); err != nil {
			return err
		}

		rebuildCache(profilePath)
		fmt.Printf("Disabled module %q\n", args[0])
		return nil
	},
}

// --- install ---

var moduleInstallCmd = &cobra.Command{
	Use:   "install [name]",
	Short: "Install a module's packages",
	RunE: func(cmd *cobra.Command, args []string) error {
		p, _, dotfilesDir, err := loadContext()
		if err != nil {
			return err
		}

		dryRun, _ := cmd.Flags().GetBool("dry-run")
		all, _ := cmd.Flags().GetBool("all")

		info := profile.DetectPlatform()

		// Determine OS key for recipes
		platformOS := info.OS
		if info.WSL {
			platformOS = "wsl"
		}

		var targets []module.Module
		if all {
			modules, discErr := module.DiscoverModules(dotfilesDir)
			if discErr != nil {
				return discErr
			}
			// Filter to enabled modules
			enabledSet := make(map[string]bool)
			if p != nil {
				for _, name := range p.EnabledModules() {
					enabledSet[name] = true
				}
			}
			for _, m := range modules {
				if p == nil || enabledSet[m.Name] {
					targets = append(targets, m)
				}
			}
		} else {
			if len(args) == 0 {
				return fmt.Errorf("specify a module name or use --all")
			}
			mod, findErr := findModule(dotfilesDir, args[0])
			if findErr != nil {
				return findErr
			}
			targets = []module.Module{*mod}
		}

		for _, mod := range targets {
			recipes := convertRecipes(mod.Install)
			mgr, pkgs, resolveErr := installer.ResolveRecipes(platformOS, info.PkgManager, recipes)
			if resolveErr != nil {
				return resolveErr
			}
			if mgr == "" || len(pkgs) == 0 {
				if !all {
					fmt.Printf("No install recipes for %s on %s/%s\n", mod.Name, platformOS, info.PkgManager)
				}
				continue
			}

			fmt.Printf("\n%s:\n", mod.Name)
			if err := installer.Install(mgr, pkgs, dryRun); err != nil {
				return fmt.Errorf("installing %s: %w", mod.Name, err)
			}
		}

		return nil
	},
}

// --- validate ---

var moduleValidateCmd = &cobra.Command{
	Use:   "validate [name]",
	Short: "Validate module.json and section guards",
	RunE: func(cmd *cobra.Command, args []string) error {
		_, _, dotfilesDir, err := loadContext()
		if err != nil {
			return err
		}

		var targets []module.Module
		if len(args) > 0 {
			mod, findErr := findModule(dotfilesDir, args[0])
			if findErr != nil {
				return findErr
			}
			targets = []module.Module{*mod}
		} else {
			modules, discErr := module.DiscoverModules(dotfilesDir)
			if discErr != nil {
				return discErr
			}
			targets = modules
		}

		hasErrors := false
		for _, mod := range targets {
			schemaErrs := module.ValidateModule(&mod)
			guardWarns := module.ValidateSectionGuards(&mod)
			allIssues := append(schemaErrs, guardWarns...)

			if len(allIssues) == 0 {
				fmt.Printf("  ✓ %s\n", mod.Name)
			} else {
				hasErrors = true
				fmt.Printf("  ✗ %s\n", mod.Name)
				for _, issue := range allIssues {
					fmt.Printf("    - %s\n", issue)
				}
			}
		}

		if hasErrors {
			os.Exit(1)
		}
		return nil
	},
}

// --- create ---

var moduleCreateCmd = &cobra.Command{
	Use:   "create [name]",
	Short: "Scaffold a new module from template",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		_, _, dotfilesDir, err := loadContext()
		if err != nil {
			return err
		}

		modDir, err := module.Scaffold(dotfilesDir, args[0])
		if err != nil {
			return err
		}

		fmt.Printf("Created module at %s\n", modDir)
		fmt.Println("Files:")
		fmt.Println("  module.json   — edit name, description, sections, install recipes")
		fmt.Println("  aliases.sh    — add your shell aliases and functions")
		fmt.Println("  CLAUDE.md     — describe the module for AI assistants")
		return nil
	},
}

// --- override ---

var moduleOverrideCmd = &cobra.Command{
	Use:   "override [section]",
	Short: "Clone a section to overrides",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		profilePath, dotfilesDir, err := requireProfile()
		if err != nil {
			return err
		}

		section := args[0]
		local, _ := cmd.Flags().GetBool("local")
		disable, _ := cmd.Flags().GetBool("disable")

		// Parse module name from section (e.g. "git.shortcuts" → "git")
		moduleName := strings.SplitN(section, ".", 2)[0]

		if disable {
			if err := module.DisableSection(profilePath, moduleName, section); err != nil {
				return err
			}
			rebuildCache(profilePath)
			fmt.Printf("Disabled section %q\n", section)
			return nil
		}

		// Find module and extract section
		mod, findErr := findModule(dotfilesDir, moduleName)
		if findErr != nil {
			return findErr
		}

		code, sourceFile, extractErr := module.ExtractSection(mod, section)
		if extractErr != nil {
			return extractErr
		}

		// Determine override directory
		overrideDir := filepath.Join(dotfilesDir, "overrides")
		if local {
			overrideDir = filepath.Join(profile.FindDataDir(), "local")
		}

		if err := module.WriteOverride(overrideDir, section, code, moduleName, sourceFile); err != nil {
			return err
		}

		fmt.Printf("Override written: %s/%s.sh\n", overrideDir, section)
		fmt.Println("Edit this file to customize. Delete to restore module default.")
		return nil
	},
}

// --- reset ---

var moduleResetCmd = &cobra.Command{
	Use:   "reset [section]",
	Short: "Remove override, restore module default",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		profilePath, dotfilesDir, err := requireProfile()
		if err != nil {
			return err
		}

		section := args[0]
		moduleName := strings.SplitN(section, ".", 2)[0]

		repoDir := filepath.Join(dotfilesDir, "overrides")
		localDir := filepath.Join(profile.FindDataDir(), "local")

		removed := module.ResetOverride(repoDir, localDir, section)

		// Also remove from disable list
		if err := module.EnableSection(profilePath, moduleName, section); err != nil {
			return err
		}

		rebuildCache(profilePath)

		if len(removed) > 0 {
			for _, path := range removed {
				fmt.Printf("Removed: %s\n", path)
			}
		}
		fmt.Printf("Section %q restored to module default\n", section)
		return nil
	},
}

// --- stubs for registry commands (deferred to #30) ---

var moduleBrowseCmd = &cobra.Command{
	Use:   "browse",
	Short: "Interactive TUI module browser",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Not implemented — see issue #30 (registry)")
	},
}

var moduleAddCmd = &cobra.Command{
	Use:   "add [registry/name]",
	Short: "Install a module from a registry",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Not implemented — see issue #30 (registry)")
	},
}

var moduleUpdateCmd = &cobra.Command{
	Use:   "update [name]",
	Short: "Update module(s) from registry",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Not implemented — see issue #30 (registry)")
	},
}

var moduleSearchCmd = &cobra.Command{
	Use:   "search [query]",
	Short: "Search all registries for modules",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Not implemented — see issue #30 (registry)")
	},
}

// --- helpers ---

// loadContext loads profile and resolves dotfiles dir. Returns nil profile if none found.
func loadContext() (*profile.Profile, string, string, error) {
	profilePath, err := profile.FindProfile()
	if err != nil {
		return nil, "", "", err
	}

	var p *profile.Profile
	if profilePath != "" {
		p, err = profile.LoadProfile(profilePath)
		if err != nil {
			return nil, "", "", fmt.Errorf("loading profile: %w", err)
		}
	}

	dotfilesDir, err := profile.FindDotfilesDir(p)
	if err != nil {
		return nil, "", "", err
	}

	return p, profilePath, dotfilesDir, nil
}

// requireProfile loads profile and dotfiles dir, erroring if no profile found.
func requireProfile() (profilePath string, dotfilesDir string, err error) {
	p, pp, dd, err := loadContext()
	if err != nil {
		return "", "", err
	}
	if pp == "" {
		return "", "", fmt.Errorf("no profile found — create one with: dotfiles setup")
	}
	_ = p
	return pp, dd, nil
}

// findModule discovers all modules and returns the one matching name.
func findModule(dotfilesDir string, name string) (*module.Module, error) {
	modules, err := module.DiscoverModules(dotfilesDir)
	if err != nil {
		return nil, err
	}
	for _, m := range modules {
		if m.Name == name {
			return &m, nil
		}
	}
	return nil, fmt.Errorf("module %q not found in %s/modules/", name, dotfilesDir)
}

// rebuildCache rebuilds the profile cache silently.
func rebuildCache(profilePath string) {
	p, err := profile.LoadProfile(profilePath)
	if err != nil {
		return
	}
	dataDir := profile.FindDataDir()
	profile.GenerateProfileCache(dataDir, profilePath, p)
}

// convertRecipes converts module.InstallRecipes to installer.InstallRecipes.
func convertRecipes(modRecipes map[string]*module.InstallRecipes) map[string]*installer.InstallRecipes {
	if modRecipes == nil {
		return nil
	}
	result := make(map[string]*installer.InstallRecipes, len(modRecipes))
	for platform, r := range modRecipes {
		result[platform] = &installer.InstallRecipes{
			Brew:    r.Brew,
			Apt:     r.Apt,
			Dnf:     r.Dnf,
			Pacman:  r.Pacman,
			Snap:    r.Snap,
			Zypper:  r.Zypper,
			Inherit: r.Inherit,
		}
	}
	return result
}

func init() {
	moduleInstallCmd.Flags().Bool("all", false, "Install all enabled modules' packages")
	moduleInstallCmd.Flags().Bool("dry-run", false, "Print commands instead of executing")
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

- [ ] **Step 2: Verify build**

```bash
cd ~/code/sshpub/dotfiles-cli && go build -o /dev/null .
```

- [ ] **Step 3: Commit**

```bash
cd ~/code/sshpub/dotfiles-cli
git add cmd/module.go
git commit -m "feat(cmd): implement 10 module management commands

list, info, enable, disable, install (with --dry-run), validate,
create, override (--local/--disable), reset. Registry commands
(browse, add, update, search) remain as stubs for #30.

Part of #24"
```

---

## Task 6: Integration test + push

Depends on: All previous tasks.

- [ ] **Step 1: Run all tests**

```bash
cd ~/code/sshpub/dotfiles-cli && go test -count=1 ./...
```

All tests must pass.

- [ ] **Step 2: Build and smoke test**

```bash
cd ~/code/sshpub/dotfiles-cli
go build -o ./dotfiles .
DOTFILES_DIR=~/code/sshpub/dotfiles ./dotfiles module list
DOTFILES_DIR=~/code/sshpub/dotfiles ./dotfiles module info git
DOTFILES_DIR=~/code/sshpub/dotfiles ./dotfiles module validate git
DOTFILES_DIR=~/code/sshpub/dotfiles ./dotfiles module install git --dry-run
rm ./dotfiles
```

Verify each command produces real output.

- [ ] **Step 3: Verify no remaining stubs in #24 commands**

```bash
cd ~/code/sshpub/dotfiles-cli && grep -n "not implemented" cmd/module.go
```

Expected: No matches. Registry stubs use "Not implemented — see issue #30 (registry)".

- [ ] **Step 4: Push branch**

```bash
cd ~/code/sshpub/dotfiles-cli
git push -u origin feat/24-module-commands
```

- [ ] **Step 5: Wait for CI**

```bash
gh run watch --repo sshpub/dotfiles-cli
```

Expected: CI passes.

---

## Task Dependency Graph

```
Task 1 (pkg/installer)  ──┐
Task 2 (enable/disable) ──┼──→ Task 5 (cmd/module.go) ──→ Task 6 (integration + push)
Task 3 (section.go)     ──┤
Task 4 (scaffold+validate)┘
```

**Parallel opportunities:**
- Tasks 1, 2, 3, 4 are fully independent — all can run in parallel
- Task 5 depends on all four packages being done
- Task 6 is the final gate
