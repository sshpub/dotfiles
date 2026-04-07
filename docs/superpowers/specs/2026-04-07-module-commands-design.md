# CLI Module Management Commands — Design Spec

**Issue:** #24
**Date:** 2026-04-07
**Scope:** Local module lifecycle (10 commands). Registry commands (add, search, update) deferred to #30/#31. TUI browser deferred to #30.

## Commands

| Command | Description |
|---------|-------------|
| `module list` | Table: name, enabled/disabled, description |
| `module info <name>` | Full module details |
| `module enable <name>` | Add to profile, rebuild cache |
| `module disable <name>` | Remove from profile, rebuild cache |
| `module install <name>` | Install module's packages for current platform |
| `module install --all` | Install all enabled modules' packages |
| `module validate [name]` | Validate module.json + section guards |
| `module create <name>` | Scaffold new module from template |
| `module override <section>` | Extract section code to overrides/ |
| `module reset <section>` | Remove override, restore default |

## Architecture

Business logic in packages, cmd/ wires Cobra commands.

### `pkg/module` — extended

New functions added to the existing package:

- **`Enable(profilePath string, moduleName string, dotfilesDir string) error`** — verify module dir exists, set `modules[name] = true` in profile, save, rebuild cache
- **`Disable(profilePath string, moduleName string) error`** — set `modules[name] = false` in profile, save, rebuild cache
- **`ExtractSection(mod *Module, section string) (code string, sourceFile string, err error)`** — parse shell files for `dotfiles_section "X" && {` blocks, return the code body and source filename. Section format: `module.section` (e.g. `git.shortcuts`)
- **`ResetOverride(repoOverrideDir string, localOverrideDir string, section string) []string`** — delete override files from both repo and local dirs, return removed paths
- **`Scaffold(dotfilesDir string, name string) (string, error)`** — create module dir, module.json, aliases.sh with guard template, CLAUDE.md. Returns the created directory path.
- **`ValidateSectionGuards(mod *Module) []string`** — scan shell files in load_order, compare declared sections in module.json against actual `dotfiles_section` calls. Report mismatches.

### `pkg/installer` — new (replaces doc.go)

Handles package installation for any module.

- **`ResolveRecipes(platformOS string, platformPkgManager string, recipes map[string]*InstallRecipes) (manager string, packages []string, err error)`** — look up install recipes for detected platform, handle `inherit` field. Takes primitives to avoid import cycles with pkg/module.
- **`Install(manager string, packages []string, dryRun bool) error`** — execute or print package manager command. Prepends `sudo` for apt/dnf/pacman/zypper/yum if not root. Groups all packages into a single command.
- **`InstallRecipes`** — standalone struct mirroring module.InstallRecipes fields. Cmd layer converts between them.

### `cmd/module.go` — rewrite

All 13 existing subcommand stubs replaced. Registry commands (`add`, `search`, `update`) and `browse` remain as stubs with "not implemented — see dotfiles module add/search/update" messages.

## Command Behaviors

### `module list`

```
Modules (18 discovered, 15 enabled):

  NAME            STATUS     DESCRIPTION
  git             enabled    Git aliases, functions, and configuration
  modern-tools    enabled    eza, bat, ripgrep, fd, zoxide with fallbacks
  vim             disabled   Vim configuration and plugins
  ...
```

Discovers all modules via `DiscoverModules`. Cross-references with profile's `EnabledModules()`. No profile = all enabled (matches loader behavior). Sorted alphabetically.

### `module info <name>`

```
Module: git (1.0.0)
  Git aliases, functions, and configuration
  Author: Anton Swartz
  Status: enabled

Sections:
  git.shortcuts  Common git command shortcuts (g, gs, ga, gc, gp, etc.)
  git.log        Visual log and history aliases
  git.branch     Branch management aliases

Shell: aliases.sh, functions.sh

Install (linux/apt):
  git, git-lfs

Symlinks:
  config/.gitconfig    → ~/.gitconfig
  config/.gitignore    → ~/.gitignore
  config/.gitattributes → ~/.gitattributes
```

Error if module not found in discovered modules.

### `module enable <name>`

1. Verify module directory exists (`modules/<name>/module.json`)
2. Load profile (error if no profile — "create one with: dotfiles setup")
3. Set `modules[name] = true` in profile
4. Save profile
5. Rebuild cache
6. Print confirmation

### `module disable <name>`

Same as enable but sets `modules[name] = false`. No error if module doesn't exist on disk (may have been removed).

### `module install <name>` / `--all`

1. Load module, detect platform
2. `ResolveRecipes` — find recipes for current platform, follow `inherit` if needed
3. If no recipes found, print "no install recipes for <platform>" and exit 0
4. Default: execute package manager command
5. `--dry-run`: print the command instead
6. `--all`: iterate all enabled modules, skip those without recipes

Sudo handling: if `os.Getuid() != 0` and manager is apt/dnf/pacman/zypper/yum, prepend `sudo`.

### `module validate [name]`

Two validation layers:

1. **Schema validation** — existing `ValidateModule`: name pattern, version semver, required fields, valid platforms, valid dependency names
2. **Section guard validation** — new `ValidateSectionGuards`: for each section declared in module.json, verify a `dotfiles_section "<section>"` call exists in the shell files. For each guard found in shell files, verify it's declared in module.json.

No args: validate all discovered modules. Reports per-module: pass (green check) or list of errors.

### `module create <name>`

Creates:
```
modules/<name>/
  module.json       # name, version "0.1.0", description "", empty sections/shell
  aliases.sh        # dotfiles_section "<name>.main" && { ... }
  CLAUDE.md         # # Module: <name>
```

Error if directory already exists.

### `module override <section>`

Section format: `git.shortcuts` → module=`git`, section=`git.shortcuts`.

1. Find the module by parsing section name prefix
2. Scan shell files (from `shell.load_order`) for `dotfiles_section "<section>" && {`
3. Extract the code block between the `{` and the matching `}`
4. Write to `overrides/<section>.sh` with header: `# Override: <section> (extracted from modules/<module>/<file>)`
5. The override file includes its own `dotfiles_section` guard wrapping the extracted code

Flags:
- `--local`: write to `~/.dotfiles/local/<section>.sh` instead
- `--disable`: skip extraction, just add section to profile's disable list

### `module reset <section>`

1. Delete `overrides/<section>.sh` if it exists
2. Delete `~/.dotfiles/local/<section>.sh` if it exists
3. Remove section from profile's disable list if present
4. Rebuild cache

## Section Extraction Algorithm

Shell files use this pattern:
```bash
dotfiles_section "git.shortcuts" && {
    alias g="git"
    alias gs="git status"
    # ... more code
}
```

Extraction:
1. Read shell file line by line
2. Match `dotfiles_section "<section>" && {`
3. Track brace depth (start at 1 after the opening `{`)
4. Collect lines until brace depth returns to 0
5. Return collected lines (excluding the guard line and closing `}`)

Edge case: nested `{` in code (if/for/while blocks) — handled by brace depth tracking.

## Testing

- `pkg/module`: test Enable/Disable (profile mutation round-trip), ExtractSection (known shell content), Scaffold (verify created files), ValidateSectionGuards (matching/mismatched sections)
- `pkg/installer`: test ResolveRecipes (inherit chain, missing platform), Install dry-run mode (verify printed command format)
- Existing tests must continue to pass
