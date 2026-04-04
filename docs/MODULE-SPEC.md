# Module Specification

A module is a self-contained directory under `modules/` with a `module.json` and optional shell files.

## Directory Structure

```
modules/{name}/
├── module.json          # Required — metadata, sections, install recipes
├── CLAUDE.md            # Optional — scoped AI context
├── aliases.sh           # Optional — aliases with section guards
├── functions.sh         # Optional — functions with section guards
├── completions.sh       # Optional — tab completion setup
├── path.sh              # Optional — PATH additions
├── exports.sh           # Optional — environment variables
└── config/              # Optional — config files to symlink
```

## module.json

### Required Fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Lowercase identifier, hyphens allowed (e.g., `modern-tools`) |
| `version` | string | Semver (e.g., `1.0.0`) |
| `description` | string | One-line description |

### Optional Fields

| Field | Type | Description |
|---|---|---|
| `author` | string | Module author |
| `platforms` | array | `["macos", "linux", "wsl"]` — omit for all platforms |
| `dependencies` | array | Module names that must load first |
| `sections` | object | Map of `{module}.{section}` to description |
| `shell.load_order` | array | Ordered list of `.sh` files to source |
| `install` | object | Per-platform package manager recipes |
| `symlinks` | object | Module paths to home directory targets |
| `hooks` | object | `post_install` and `post_enable` commands |
| `_comment` | string | Documentation (JSON has no comments) |

### Full Example (kubernetes)

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
      "snap": ["helm --classic"]
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

### Minimal Example (modern-tools)

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

## Contract Rules

### MUST

- Have a `module.json` with `name`, `version`, `description`
- Use `dotfiles_section()` guards for all shell blocks
- Use `{module}.{section}` naming for sections
- Declare all sections in `module.json`
- Be self-contained — no references to other module internals

### MUST NOT

- Modify PATH outside of `path.sh`
- Source files from other modules directly
- Write to files outside the module directory
- Contain secrets or machine-specific values
- Have side effects on load (no network calls, no prompts)

## Section Guards

All shell blocks must be wrapped in section guards:

```bash
dotfiles_section "git.shortcuts" && {
    alias g='git'
    alias gs='git status'
}
```

If a section is in `DOTFILES_DISABLED_SECTIONS` (from the user's profile), the entire block is skipped.

## Validation

Validate a module against the schema:

```bash
# Using the CLI (Phase 4+)
dotfiles module validate kubernetes

# Manual (any JSON schema validator)
# Schema at: modules/schema.json
```

## Shell File Load Order

If `shell.load_order` is specified in `module.json`, files are sourced in that order. If omitted, `*.sh` files in the module directory are sourced alphabetically.

Recommended order: `exports.sh`, `path.sh`, `aliases.sh`, `functions.sh`, `completions.sh`
