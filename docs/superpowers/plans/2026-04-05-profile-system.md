# Profile System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the profile system that reads `~/.dotfiles.json` (or other locations), generates a shell cache, and drives module/mode loading.

**Architecture:** A JSON profile defines enabled modules and custom modes. A throwaway jq-based generator reads the profile and writes a shell-sourceable cache. The loader sources the cache at startup, resolves the active mode, and loads modules accordingly. Data directory and profile locations are configurable via env vars and search chains.

**Tech Stack:** Bash 4.x+ (indirect expansion), jq, JSON Schema

---

**Spec:** `docs/superpowers/specs/2026-04-05-profile-system-design.md`

**Branch:** `feat/19-profile-system` from `main`

**File Map:**

| File | Action | Responsibility |
|------|--------|---------------|
| `core/platform.sh` | Modify | Add `_dotfiles_resolve_data_dir`, derive `DOTFILES_CACHE_DIR` |
| `core/loader.sh` | Modify | All-modules default, mode resolution, mode-aware loading |
| `.bash_profile` | Modify | Use `dotfiles_resolve_mode`, use `DOTFILES_DATA_DIR` for overrides |
| `profiles/schema.json` | Create | JSON Schema for profile validation |
| `profiles/examples/work-macos.json` | Create | Example profile |
| `profiles/examples/personal-linux.json` | Create | Example profile |
| `profiles/examples/personal-wsl.json` | Create | Example profile |
| `setup/generate-cache.sh` | Create | jq-based cache generator |
| `tests/test-profile-system.sh` | Create | End-to-end test script |

---

### Task 1: Create branch and test harness

**Files:**
- Create: `tests/test-profile-system.sh`

- [ ] **Step 1: Create the feature branch**

```bash
git checkout main
git checkout -b feat/19-profile-system
```

- [ ] **Step 2: Create the test harness**

Create `tests/test-profile-system.sh` — a minimal bash test runner that sources core files in isolation and asserts variable values. This will be used by all subsequent tasks.

```bash
#!/usr/bin/env bash
# tests/test-profile-system.sh — Profile system tests
# Usage: bash tests/test-profile-system.sh

set -euo pipefail

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() {
  ((TESTS_PASSED++))
  ((TESTS_RUN++))
  echo "  PASS: $1"
}

fail() {
  ((TESTS_FAILED++))
  ((TESTS_RUN++))
  echo "  FAIL: $1 — $2"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc" "expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ " $haystack " == *" $needle "* ]]; then
    pass "$desc"
  else
    fail "$desc" "'$needle' not found in '$haystack'"
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    pass "$desc"
  else
    fail "$desc" "file not found: $path"
  fi
}

# --- Test Groups ---
# Each test group runs in a subshell to isolate state

test_data_dir_resolution() {
  echo "=== Data directory resolution ==="
  echo "(placeholder — Task 2 adds tests here)"
}

test_default_profile() {
  echo "=== Default profile (no cache, no profile) ==="
  echo "(placeholder — Task 3 adds tests here)"
}

test_mode_resolution() {
  echo "=== Mode resolution ==="
  echo "(placeholder — Task 4 adds tests here)"
}

test_bash_profile_integration() {
  echo "=== .bash_profile integration ==="
  echo "(placeholder — Task 6 adds tests here)"
}

test_generate_cache() {
  echo "=== Cache generator ==="
  echo "(placeholder — Task 8 adds tests here)"
}

# --- Run ---

test_data_dir_resolution
test_default_profile
test_mode_resolution
test_bash_profile_integration
test_generate_cache

echo ""
echo "Results: $TESTS_RUN run, $TESTS_PASSED passed, $TESTS_FAILED failed"
[[ "$TESTS_FAILED" -eq 0 ]]
```

- [ ] **Step 3: Run the test harness to verify it works**

```bash
bash tests/test-profile-system.sh
```

Expected: All placeholder groups print, 0 tests run, 0 failed, exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/test-profile-system.sh
git commit -m "test: add profile system test harness with placeholder groups"
```

---

### Task 2: Data directory resolution in `core/platform.sh`

**Files:**
- Modify: `core/platform.sh:7-9` (replace hardcoded `DOTFILES_CACHE_DIR`)
- Modify: `tests/test-profile-system.sh` (fill in `test_data_dir_resolution`)

- [ ] **Step 1: Write the failing tests**

Replace the `test_data_dir_resolution` function in `tests/test-profile-system.sh`:

```bash
test_data_dir_resolution() {
  echo "=== Data directory resolution ==="

  # Test: env var override takes priority
  (
    export DOTFILES_DATA_DIR="/tmp/dotfiles-test-data-override"
    mkdir -p "$DOTFILES_DATA_DIR"
    source "${DOTFILES_DIR}/core/platform.sh"
    assert_eq "env var override" "/tmp/dotfiles-test-data-override" "$DOTFILES_DATA_DIR"
    assert_eq "cache dir derives from data dir" "/tmp/dotfiles-test-data-override/cache" "$DOTFILES_CACHE_DIR"
    rm -rf "$DOTFILES_DATA_DIR"
  )

  # Test: falls back to ~/.dotfiles/ when it exists
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-home-$$"
    mkdir -p "${test_home}/.dotfiles"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    assert_eq "fallback to ~/.dotfiles" "${test_home}/.dotfiles" "$DOTFILES_DATA_DIR"
    rm -rf "$test_home"
  )

  # Test: creates ~/.dotfiles/ as default when nothing exists
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-home-empty-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    assert_eq "default to ~/.dotfiles when nothing exists" "${test_home}/.dotfiles" "$DOTFILES_DATA_DIR"
    rm -rf "$test_home"
  )
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash tests/test-profile-system.sh
```

Expected: FAIL — `_dotfiles_resolve_data_dir` doesn't exist yet.

- [ ] **Step 3: Implement `_dotfiles_resolve_data_dir` in `core/platform.sh`**

Replace lines 7-9 of `core/platform.sh`:

```bash
DOTFILES_CACHE_DIR="${HOME}/.dotfiles/cache"
DOTFILES_PLATFORM_CACHE="${DOTFILES_CACHE_DIR}/platform.sh"
```

With:

```bash
_dotfiles_resolve_data_dir() {
  # Env var override
  if [[ -n "${DOTFILES_DATA_DIR:-}" ]]; then
    return 0
  fi
  # Search chain: first existing directory wins
  local candidate
  for candidate in \
    "${HOME}/.dotfiles" \
    "${HOME}/.config/dotfiles" \
    "${HOME}/.local/share/dotfiles" \
  ; do
    if [[ -d "$candidate" ]]; then
      DOTFILES_DATA_DIR="$candidate"
      return 0
    fi
  done
  # Default
  DOTFILES_DATA_DIR="${HOME}/.dotfiles"
}

_dotfiles_resolve_data_dir
DOTFILES_CACHE_DIR="${DOTFILES_DATA_DIR}/cache"
DOTFILES_PLATFORM_CACHE="${DOTFILES_CACHE_DIR}/platform.sh"

export DOTFILES_DATA_DIR DOTFILES_CACHE_DIR
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash tests/test-profile-system.sh
```

Expected: All data dir tests PASS.

- [ ] **Step 5: Commit**

```bash
git add core/platform.sh tests/test-profile-system.sh
git commit -m "feat: add data directory resolution with search chain

Replaces hardcoded ~/.dotfiles/cache with configurable data dir.
Search order: \$DOTFILES_DATA_DIR > ~/.dotfiles > ~/.config/dotfiles > ~/.local/share/dotfiles.
Defaults to ~/.dotfiles when nothing exists."
```

---

### Task 3: All-modules default and mode variables in `core/loader.sh`

**Files:**
- Modify: `core/loader.sh:10-35` (replace `_dotfiles_default_profile` and cache-read section)
- Modify: `tests/test-profile-system.sh` (fill in `test_default_profile`)

- [ ] **Step 1: Write the failing tests**

Replace `test_default_profile` in `tests/test-profile-system.sh`:

```bash
test_default_profile() {
  echo "=== Default profile (no cache, no profile) ==="

  # Test: discovers all bundled modules when no cache exists
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-default-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    # Should find all modules that have module.json
    local expected_count
    expected_count=$(find "${DOTFILES_DIR}/modules" -name module.json -maxdepth 2 | wc -l)
    assert_eq "discovers all modules" "$expected_count" "${#DOTFILES_ENABLED_MODULES[@]}"

    # git should be in the list
    assert_contains "git in enabled modules" "git" "${DOTFILES_ENABLED_MODULES[*]}"

    # No disabled sections by default
    assert_eq "no disabled sections" "0" "${#DOTFILES_DISABLED_SECTIONS[@]}"

    # Default minimal mode exists
    assert_contains "minimal in mode names" "minimal" "${DOTFILES_MODE_NAMES[*]}"
    assert_contains "CLAUDE_CODE in minimal triggers" "CLAUDE_CODE" "${DOTFILES_MODE_minimal_TRIGGERS[*]}"

    rm -rf "$test_home"
  )
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash tests/test-profile-system.sh
```

Expected: FAIL — `DOTFILES_MODE_NAMES` is not set, old `_dotfiles_default_profile` doesn't discover modules.

- [ ] **Step 3: Rewrite `core/loader.sh`**

Replace the entire file with:

```bash
#!/usr/bin/env bash
# core/loader.sh — Module loading, section guards, mode resolution
#
# Fast path: source cached profile for enabled modules / disabled sections / modes
# Fallback:  sensible defaults (all bundled modules, hardcoded minimal mode)
#
# This file defines the toolkit. .bash_profile orchestrates the loading order.

# --- Bootstrap ---

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DOTFILES_MODULES_DIR="${DOTFILES_DIR}/modules"
DOTFILES_PROFILE_CACHE="${DOTFILES_CACHE_DIR}/profile.sh"

export DOTFILES_DIR DOTFILES_MODULES_DIR

# --- Profile: cache-read fast path, defaults fallback ---

_dotfiles_default_profile() {
  # Discover all bundled modules
  DOTFILES_ENABLED_MODULES=()
  local d
  for d in "${DOTFILES_MODULES_DIR}"/*/; do
    [[ -f "${d}module.json" ]] && DOTFILES_ENABLED_MODULES+=("$(basename "$d")")
  done
  DOTFILES_DISABLED_SECTIONS=()

  # Hardcoded minimal mode defaults
  DOTFILES_MODE_NAMES=(minimal)
  DOTFILES_MODE_minimal_TRIGGERS=(
    CLAUDE_CODE CODEX GEMINI_CLI OPENCODE GROK_CLI
    CI GITHUB_ACTIONS GITLAB_CI
  )
  DOTFILES_MODE_minimal_MODULES=()
  DOTFILES_MODE_minimal_NEVER_LOAD=()
}

if [[ -f "$DOTFILES_PROFILE_CACHE" ]]; then
  # shellcheck source=/dev/null
  . "$DOTFILES_PROFILE_CACHE"
else
  _dotfiles_default_profile
fi

# --- Section Guards ---

dotfiles_section() {
  local section="$1"
  [[ ! " ${DOTFILES_DISABLED_SECTIONS[*]} " =~ " ${section} " ]]
}

# --- Mode Resolution ---

dotfiles_resolve_mode() {
  # Env var override
  if [[ -n "${DOTFILES_MODE:-}" ]]; then
    DOTFILES_ACTIVE_MODE="$DOTFILES_MODE"
    return 0
  fi
  # Check each mode's triggers in order
  local mode var triggers_var
  for mode in "${DOTFILES_MODE_NAMES[@]}"; do
    triggers_var="DOTFILES_MODE_${mode}_TRIGGERS[@]"
    for var in "${!triggers_var}"; do
      if [[ -n "${!var:-}" ]]; then
        DOTFILES_ACTIVE_MODE="$mode"
        return 0
      fi
    done
  done
  DOTFILES_ACTIVE_MODE=""
  return 1
}

# Backward compat wrapper
dotfiles_is_minimal() {
  dotfiles_resolve_mode && [[ "$DOTFILES_ACTIVE_MODE" == "minimal" ]]
}

# --- Module Loading ---

load_module() {
  local name="$1"
  local module_dir="${DOTFILES_MODULES_DIR}/${name}"
  local module_cache="${DOTFILES_CACHE_DIR}/modules/${name}.sh"

  # Module must exist
  if [[ ! -d "$module_dir" ]]; then
    return 1
  fi

  # Fast path: cached module manifest with load order
  if [[ -f "$module_cache" ]]; then
    # shellcheck source=/dev/null
    . "$module_cache"
    return 0
  fi

  # Fallback: source *.sh files alphabetically
  local f
  for f in "${module_dir}"/*.sh; do
    [[ -f "$f" ]] || continue
    # shellcheck source=/dev/null
    . "$f"
  done
}

dotfiles_load_modules() {
  local mod
  for mod in "${DOTFILES_ENABLED_MODULES[@]}"; do
    load_module "$mod"
  done
}

dotfiles_load_mode_extras() {
  local modules_var="DOTFILES_MODE_${DOTFILES_ACTIVE_MODE}_MODULES[@]"
  local mod
  for mod in "${!modules_var}"; do
    load_module "$mod"
  done
}
```

Key changes from original:
- `DOTFILES_CACHE_DIR` no longer set here (comes from `platform.sh` via data dir resolution)
- `_dotfiles_default_profile` discovers all modules, sets mode variables
- New `dotfiles_resolve_mode()` with env var override + trigger checking
- `dotfiles_is_minimal()` is a thin wrapper
- New `dotfiles_load_mode_extras()` loads the active mode's modules
- Uses indirect expansion (`${!triggers_var}`) instead of `local -n` namerefs for broader bash compat

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash tests/test-profile-system.sh
```

Expected: All default profile tests PASS.

- [ ] **Step 5: Commit**

```bash
git add core/loader.sh tests/test-profile-system.sh
git commit -m "feat: all-modules default profile and mode variable structure

Loader discovers all bundled modules when no cache exists.
Replaces empty DOTFILES_ENABLED_MODULES default with auto-discovery.
Adds DOTFILES_MODE_* variable structure for generic mode system."
```

---

### Task 4: Mode resolution logic

**Files:**
- Modify: `tests/test-profile-system.sh` (fill in `test_mode_resolution`)
- (loader.sh already has the implementation from Task 3)

- [ ] **Step 1: Write the tests**

Replace `test_mode_resolution` in `tests/test-profile-system.sh`:

```bash
test_mode_resolution() {
  echo "=== Mode resolution ==="

  # Test: env var override forces mode
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-mode-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    DOTFILES_MODE="custom"
    dotfiles_resolve_mode
    assert_eq "env var forces mode" "custom" "$DOTFILES_ACTIVE_MODE"
    unset DOTFILES_MODE

    rm -rf "$test_home"
  )

  # Test: trigger detection activates mode
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-trigger-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    CLAUDE_CODE=1
    dotfiles_resolve_mode
    assert_eq "CLAUDE_CODE triggers minimal" "minimal" "$DOTFILES_ACTIVE_MODE"
    unset CLAUDE_CODE

    rm -rf "$test_home"
  )

  # Test: no triggers = no active mode
  (
    unset DOTFILES_DATA_DIR DOTFILES_MODE
    unset CLAUDE_CODE CODEX GEMINI_CLI OPENCODE GROK_CLI CI GITHUB_ACTIONS GITLAB_CI
    local test_home="/tmp/dotfiles-test-nomode-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    if dotfiles_resolve_mode; then
      fail "no mode when no triggers" "should have returned 1"
    else
      pass "no mode when no triggers"
    fi
    assert_eq "active mode is empty" "" "$DOTFILES_ACTIVE_MODE"

    rm -rf "$test_home"
  )

  # Test: first triggered mode wins (order matters)
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-order-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    # Add a second mode
    DOTFILES_MODE_NAMES=(server minimal)
    DOTFILES_MODE_server_TRIGGERS=(SSH_SESSION)
    DOTFILES_MODE_server_MODULES=(git safety)
    DOTFILES_MODE_server_NEVER_LOAD=(prompt)

    # Trigger both
    SSH_SESSION=1
    CLAUDE_CODE=1
    dotfiles_resolve_mode
    assert_eq "first mode wins" "server" "$DOTFILES_ACTIVE_MODE"
    unset SSH_SESSION CLAUDE_CODE

    rm -rf "$test_home"
  )

  # Test: dotfiles_is_minimal backward compat
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-ismin-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    CLAUDE_CODE=1
    if dotfiles_is_minimal; then
      pass "dotfiles_is_minimal returns true when minimal active"
    else
      fail "dotfiles_is_minimal returns true when minimal active" "returned false"
    fi
    unset CLAUDE_CODE

    rm -rf "$test_home"
  )
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
bash tests/test-profile-system.sh
```

Expected: All mode resolution tests PASS (implementation is already in loader.sh from Task 3).

- [ ] **Step 3: Commit**

```bash
git add tests/test-profile-system.sh
git commit -m "test: add mode resolution tests

Covers env var override, trigger detection, no-trigger fallback,
first-match ordering, and dotfiles_is_minimal backward compat."
```

---

### Task 5: Update `.bash_profile` for mode resolution and data dir

**Files:**
- Modify: `.bash_profile:38-42` (step 2 — mode check)
- Modify: `.bash_profile:67-69` (step 7 — local overrides)

- [ ] **Step 1: Update step 2 — mode check**

Replace in `.bash_profile`:

```bash
# ─── 2. Minimal Mode Check ────────────────────────────────────────────
if dotfiles_is_minimal; then
    dotfiles_load_minimal_extras
    return 0 2>/dev/null || exit 0
fi
```

With:

```bash
# ─── 2. Mode Check ───────────────────────────────────────────────────
if dotfiles_resolve_mode; then
    dotfiles_load_mode_extras
    return 0 2>/dev/null || exit 0
fi
```

- [ ] **Step 2: Update step 7 — local overrides**

Replace in `.bash_profile`:

```bash
# Local-level (untracked, per-machine)
for _f in "${HOME}"/.dotfiles/local/*.sh; do
    _dotfiles_source "$_f"
done
```

With:

```bash
# Local-level (untracked, per-machine)
for _f in "${DOTFILES_DATA_DIR}"/local/*.sh; do
    _dotfiles_source "$_f"
done
```

- [ ] **Step 3: Update step 5-6 comment to reflect modes**

Replace in `.bash_profile`:

```bash
# ─── 5–6. Module Loading ─────────────────────────────────────────────
```

With:

```bash
# ─── 5–6. Profile + Module Loading ───────────────────────────────────
```

- [ ] **Step 4: Verify the full loading chain works**

```bash
# Source in a subshell to test (no triggers set = full interactive load)
(
  unset CLAUDE_CODE CODEX GEMINI_CLI CI DOTFILES_MODE
  source .bash_profile 2>&1 && echo "OK: full load succeeded"
)
```

Expected: "OK: full load succeeded" — no errors.

- [ ] **Step 5: Commit**

```bash
git add .bash_profile
git commit -m "feat: update .bash_profile for generic mode resolution

Step 2 uses dotfiles_resolve_mode instead of dotfiles_is_minimal.
Local overrides use DOTFILES_DATA_DIR instead of hardcoded ~/.dotfiles/."
```

---

### Task 6: Integration tests for `.bash_profile`

**Files:**
- Modify: `tests/test-profile-system.sh` (fill in `test_bash_profile_integration`)

- [ ] **Step 1: Write integration tests**

Replace `test_bash_profile_integration` in `tests/test-profile-system.sh`:

```bash
test_bash_profile_integration() {
  echo "=== .bash_profile integration ==="

  # Test: full interactive load (no mode triggers)
  (
    unset CLAUDE_CODE CODEX GEMINI_CLI CI DOTFILES_MODE DOTFILES_DATA_DIR
    unset OPENCODE GROK_CLI GITHUB_ACTIONS GITLAB_CI
    local test_home="/tmp/dotfiles-test-bp-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/.bash_profile" 2>/dev/null
    # Should have loaded modules (all-modules default)
    if [[ ${#DOTFILES_ENABLED_MODULES[@]} -gt 0 ]]; then
      pass "full load enables modules"
    else
      fail "full load enables modules" "no modules enabled"
    fi
    assert_eq "no active mode" "" "${DOTFILES_ACTIVE_MODE:-}"
    rm -rf "$test_home"
  )

  # Test: mode triggers cause early return
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-bp-mode-$$"
    mkdir -p "$test_home"
    CLAUDE_CODE=1 HOME="$test_home" source "${DOTFILES_DIR}/.bash_profile" 2>/dev/null
    assert_eq "minimal mode activated" "minimal" "${DOTFILES_ACTIVE_MODE:-}"
    unset CLAUDE_CODE
    rm -rf "$test_home"
  )
}
```

- [ ] **Step 2: Run all tests**

```bash
bash tests/test-profile-system.sh
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add tests/test-profile-system.sh
git commit -m "test: add .bash_profile integration tests for mode system"
```

---

### Task 7: Profile JSON Schema

**Files:**
- Create: `profiles/schema.json`

- [ ] **Step 1: Create the JSON Schema**

Create `profiles/schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/sshpub/dotfiles/profiles/schema.json",
  "_comment": "JSON Schema for ~/.dotfiles.json — validates machine profile configuration",
  "title": "Dotfiles Profile",
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "_comment": {
      "type": "string",
      "description": "Documentation field (JSON has no comments)"
    },
    "role": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "uniqueItems": true,
      "description": "Machine roles (e.g., personal, work)"
    },
    "platform": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "_comment": { "type": "string" },
        "os": {
          "type": "string",
          "enum": ["macos", "linux"],
          "description": "Operating system (auto-detected if omitted)"
        },
        "variant": {
          "type": "string",
          "enum": ["wsl"],
          "description": "Platform variant (e.g., wsl)"
        },
        "distro": {
          "type": "string",
          "description": "Linux distribution ID (e.g., ubuntu, fedora)"
        }
      },
      "description": "Platform overrides — auto-detected if omitted"
    },
    "modules": {
      "type": "object",
      "patternProperties": {
        "^[a-z][a-z0-9-]*$": {
          "oneOf": [
            {
              "type": "boolean",
              "const": true,
              "description": "Shorthand for { shell: true, install: true }"
            },
            {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "_comment": { "type": "string" },
                "shell": {
                  "type": "boolean",
                  "description": "Source this module's shell files"
                },
                "install": {
                  "type": "boolean",
                  "description": "Run this module's install recipes"
                },
                "disable": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "pattern": "^[a-z][a-z0-9-]*\\.[a-z][a-z0-9-]*$"
                  },
                  "uniqueItems": true,
                  "description": "Sections to disable (module.section format)"
                }
              }
            }
          ]
        }
      },
      "additionalProperties": false,
      "description": "Module configuration — omit for all modules enabled"
    },
    "git": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "_comment": { "type": "string" },
        "name": {
          "type": "string",
          "description": "Git user name for this machine"
        },
        "email": {
          "type": "string",
          "format": "email",
          "description": "Git user email for this machine"
        }
      },
      "description": "Machine-level git identity"
    },
    "modes": {
      "type": "object",
      "patternProperties": {
        "^[a-z][a-z0-9-]*$": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "_comment": { "type": "string" },
            "env_triggers": {
              "type": "array",
              "items": { "type": "string" },
              "uniqueItems": true,
              "description": "Environment variable names that activate this mode"
            },
            "include_modules": {
              "type": "array",
              "items": {
                "type": "string",
                "pattern": "^[a-z][a-z0-9-]*$"
              },
              "uniqueItems": true,
              "description": "Modules to load when this mode is active"
            },
            "never_load": {
              "type": "array",
              "items": { "type": "string" },
              "uniqueItems": true,
              "description": "Core components or modules to skip (forward compat — not enforced yet)"
            }
          },
          "description": "Mode configuration"
        }
      },
      "additionalProperties": false,
      "description": "Named modes — first triggered wins. Omit for hardcoded minimal defaults."
    },
    "registries": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "url"],
        "additionalProperties": false,
        "properties": {
          "_comment": { "type": "string" },
          "name": {
            "type": "string",
            "description": "Registry identifier"
          },
          "url": {
            "type": "string",
            "description": "Registry URL (HTTPS or git SSH)"
          },
          "private": {
            "type": "boolean",
            "description": "Whether this registry requires authentication"
          }
        }
      },
      "description": "Module registries (Phase 5 — defined in schema, not processed yet)"
    }
  }
}
```

- [ ] **Step 2: Validate schema is valid JSON**

```bash
jq . profiles/schema.json > /dev/null && echo "Valid JSON"
```

Expected: "Valid JSON"

- [ ] **Step 3: Commit**

```bash
git add profiles/schema.json
git commit -m "feat: add profile JSON schema (profiles/schema.json)

Validates ~/.dotfiles.json structure: role, platform, modules (with
true shorthand), git identity, generic modes system, registries."
```

---

### Task 8: Cache generator script

**Files:**
- Create: `setup/generate-cache.sh`
- Modify: `tests/test-profile-system.sh` (fill in `test_generate_cache`)

- [ ] **Step 1: Write the failing tests**

Replace `test_generate_cache` in `tests/test-profile-system.sh`:

```bash
test_generate_cache() {
  echo "=== Cache generator ==="

  local test_home="/tmp/dotfiles-test-gen-$$"
  local test_profile="${test_home}/profile.json"
  local test_cache_dir="${test_home}/.dotfiles/cache"

  # Setup
  mkdir -p "${test_home}/.dotfiles"

  # Create a test profile
  cat > "$test_profile" <<'PROFILE'
{
  "modules": {
    "git": true,
    "kubernetes": { "shell": true, "install": true, "disable": ["kubernetes.helm"] },
    "cloud": { "shell": true, "install": false },
    "vim": { "shell": false, "install": true }
  },
  "modes": {
    "minimal": {
      "env_triggers": ["CI", "CLAUDE_CODE"],
      "include_modules": ["git"],
      "never_load": ["prompt"]
    },
    "server": {
      "env_triggers": ["SSH_SESSION"],
      "include_modules": ["git", "safety"],
      "never_load": ["prompt", "fzf"]
    }
  }
}
PROFILE

  # Test: generate cache from explicit path
  (
    DOTFILES_DATA_DIR="${test_home}/.dotfiles" \
      bash "${DOTFILES_DIR}/setup/generate-cache.sh" "$test_profile" > /dev/null

    assert_file_exists "cache file created" "${test_cache_dir}/profile.sh"

    # Source the cache and check values
    source "${test_cache_dir}/profile.sh"

    # git, kubernetes, cloud should be enabled (shell: true). vim has shell: false — excluded.
    assert_contains "git enabled" "git" "${DOTFILES_ENABLED_MODULES[*]}"
    assert_contains "kubernetes enabled" "kubernetes" "${DOTFILES_ENABLED_MODULES[*]}"
    assert_contains "cloud enabled" "cloud" "${DOTFILES_ENABLED_MODULES[*]}"
    local modules_str="${DOTFILES_ENABLED_MODULES[*]}"
    if [[ " $modules_str " != *" vim "* ]]; then
      pass "vim excluded (shell: false)"
    else
      fail "vim excluded (shell: false)" "vim was included"
    fi

    # Disabled sections
    assert_contains "kubernetes.helm disabled" "kubernetes.helm" "${DOTFILES_DISABLED_SECTIONS[*]}"

    # Modes
    assert_eq "two modes" "2" "${#DOTFILES_MODE_NAMES[@]}"
    assert_eq "first mode is minimal" "minimal" "${DOTFILES_MODE_NAMES[0]}"
    assert_eq "second mode is server" "server" "${DOTFILES_MODE_NAMES[1]}"
    assert_contains "CI in minimal triggers" "CI" "${DOTFILES_MODE_minimal_TRIGGERS[*]}"
    assert_contains "git in minimal modules" "git" "${DOTFILES_MODE_minimal_MODULES[*]}"
    assert_contains "SSH_SESSION in server triggers" "SSH_SESSION" "${DOTFILES_MODE_server_TRIGGERS[*]}"
  )

  # Test: no profile = message and no cache
  (
    local empty_home="/tmp/dotfiles-test-gen-empty-$$"
    mkdir -p "${empty_home}/.dotfiles"
    DOTFILES_DATA_DIR="${empty_home}/.dotfiles" \
      bash "${DOTFILES_DIR}/setup/generate-cache.sh" 2>/dev/null
    local exit_code=$?
    if [[ ! -f "${empty_home}/.dotfiles/cache/profile.sh" ]]; then
      pass "no cache when no profile found"
    else
      fail "no cache when no profile found" "cache was written"
    fi
    rm -rf "$empty_home"
  )

  # Cleanup
  rm -rf "$test_home"
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash tests/test-profile-system.sh
```

Expected: FAIL — `setup/generate-cache.sh` doesn't exist.

- [ ] **Step 3: Create `setup/generate-cache.sh`**

```bash
#!/usr/bin/env bash
# setup/generate-cache.sh — Generate profile cache from ~/.dotfiles.json
#
# Throwaway script — the CLI (Phase 4) replaces this.
# Requires: jq
#
# Usage:
#   ./setup/generate-cache.sh                     # auto-detect profile
#   ./setup/generate-cache.sh /path/to/profile     # explicit path
#   DOTFILES_PROFILE=/path ./setup/generate-cache.sh  # env var

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Preflight ---

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed." >&2
  echo "Install: brew install jq / apt install jq / dnf install jq" >&2
  exit 1
fi

# --- Resolve data directory ---

_resolve_data_dir() {
  if [[ -n "${DOTFILES_DATA_DIR:-}" ]]; then
    return 0
  fi
  local candidate
  for candidate in \
    "${HOME}/.dotfiles" \
    "${HOME}/.config/dotfiles" \
    "${HOME}/.local/share/dotfiles" \
  ; do
    if [[ -d "$candidate" ]]; then
      DOTFILES_DATA_DIR="$candidate"
      return 0
    fi
  done
  DOTFILES_DATA_DIR="${HOME}/.dotfiles"
}

_resolve_data_dir
CACHE_DIR="${DOTFILES_DATA_DIR}/cache"
CACHE_FILE="${CACHE_DIR}/profile.sh"

# --- Find profile ---

_find_profile() {
  # Argument takes priority
  if [[ -n "${1:-}" ]]; then
    if [[ -f "$1" ]]; then
      echo "$1"
      return 0
    else
      echo "Error: profile not found: $1" >&2
      exit 1
    fi
  fi

  # Env var
  if [[ -n "${DOTFILES_PROFILE:-}" ]] && [[ -f "$DOTFILES_PROFILE" ]]; then
    echo "$DOTFILES_PROFILE"
    return 0
  fi

  # Search chain
  local candidate
  for candidate in \
    "${HOME}/.dotfiles.json" \
    "${HOME}/.config/dotfiles/profile.json" \
    "${HOME}/.config/dotfiles.json" \
    "${HOME}/.local/dotfiles.json" \
    "${DOTFILES_DIR}/dotfiles.json" \
    "${DOTFILES_DIR}/profiles/default.json" \
  ; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

PROFILE_PATH="$(_find_profile "${1:-}")" || {
  echo "No profile found. Loader will use all-modules default." >&2
  echo "Searched: ~/.dotfiles.json, ~/.config/dotfiles/profile.json, ~/.config/dotfiles.json," >&2
  echo "  ~/.local/dotfiles.json, \$DOTFILES_DIR/dotfiles.json, \$DOTFILES_DIR/profiles/default.json" >&2
  exit 0
}

echo "Profile: ${PROFILE_PATH}"

# --- Parse and generate ---

PROFILE="$(cat "$PROFILE_PATH")"

# Build enabled modules (where shell is true or shorthand true)
ENABLED_MODULES="$(echo "$PROFILE" | jq -r '
  .modules // {} | to_entries[] |
  select(
    (.value == true) or
    (.value | type == "object" and (.shell // false) == true)
  ) | .key
')"

# Build disabled sections
DISABLED_SECTIONS="$(echo "$PROFILE" | jq -r '
  [.modules // {} | to_entries[] |
   select(.value | type == "object") |
   .value.disable // [] | .[]] | .[]
')"

# Build modes
MODE_NAMES="$(echo "$PROFILE" | jq -r '.modes // {} | keys[]')"

mkdir -p "$CACHE_DIR"

{
  echo "# Generated by dotfiles — do not edit"
  echo "# Source: ${PROFILE_PATH}"
  echo "# Generated: $(date -Iseconds)"
  echo ""
  echo "DOTFILES_PROFILE_SOURCE=\"${PROFILE_PATH}\""

  # Enabled modules
  printf "DOTFILES_ENABLED_MODULES=("
  first=true
  while IFS= read -r mod; do
    [[ -z "$mod" ]] && continue
    $first || printf " "
    printf "%s" "$mod"
    first=false
  done <<< "$ENABLED_MODULES"
  echo ")"

  # Disabled sections
  printf "DOTFILES_DISABLED_SECTIONS=("
  first=true
  while IFS= read -r sec; do
    [[ -z "$sec" ]] && continue
    $first || printf " "
    printf "%s" "$sec"
    first=false
  done <<< "$DISABLED_SECTIONS"
  echo ")"

  echo ""
  echo "# Modes — first triggered wins, checked in order"

  # Mode names array
  printf "DOTFILES_MODE_NAMES=("
  first=true
  while IFS= read -r mode; do
    [[ -z "$mode" ]] && continue
    $first || printf " "
    printf "%s" "$mode"
    first=false
  done <<< "$MODE_NAMES"
  echo ")"

  # Per-mode variables
  while IFS= read -r mode; do
    [[ -z "$mode" ]] && continue

    # Triggers
    triggers="$(echo "$PROFILE" | jq -r ".modes[\"$mode\"].env_triggers // [] | .[]")"
    printf "DOTFILES_MODE_%s_TRIGGERS=(" "$mode"
    first=true
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      $first || printf " "
      printf "%s" "$t"
      first=false
    done <<< "$triggers"
    echo ")"

    # Include modules
    mods="$(echo "$PROFILE" | jq -r ".modes[\"$mode\"].include_modules // [] | .[]")"
    printf "DOTFILES_MODE_%s_MODULES=(" "$mode"
    first=true
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      $first || printf " "
      printf "%s" "$m"
      first=false
    done <<< "$mods"
    echo ")"

    # Never load
    never="$(echo "$PROFILE" | jq -r ".modes[\"$mode\"].never_load // [] | .[]")"
    printf "DOTFILES_MODE_%s_NEVER_LOAD=(" "$mode"
    first=true
    while IFS= read -r n; do
      [[ -z "$n" ]] && continue
      $first || printf " "
      printf "%s" "$n"
      first=false
    done <<< "$never"
    echo ")"
  done <<< "$MODE_NAMES"

} > "$CACHE_FILE"

echo "Cache: ${CACHE_FILE}"
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x setup/generate-cache.sh
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bash tests/test-profile-system.sh
```

Expected: All cache generator tests PASS.

- [ ] **Step 6: Commit**

```bash
git add setup/generate-cache.sh tests/test-profile-system.sh
git commit -m "feat: add jq-based profile cache generator

Reads profile via search chain, expands shorthand, generates
shell-sourceable cache at ~/.dotfiles/cache/profile.sh.
Throwaway — CLI replaces this in Phase 4."
```

---

### Task 9: Example profiles

**Files:**
- Create: `profiles/examples/work-macos.json`
- Create: `profiles/examples/personal-linux.json`
- Create: `profiles/examples/personal-wsl.json`

- [ ] **Step 1: Create `profiles/examples/work-macos.json`**

```json
{
  "_comment": "Work MacBook — full development setup",
  "role": ["work"],
  "modules": {
    "git": true,
    "modern-tools": true,
    "containers": true,
    "kubernetes": true,
    "cloud": { "shell": true, "install": true },
    "terraform": true,
    "python": true,
    "node": true,
    "vim": true,
    "fzf": true,
    "tmux": true
  },
  "git": {
    "name": "Your Name",
    "email": "you@work.com"
  },
  "modes": {
    "minimal": {
      "env_triggers": ["CLAUDE_CODE", "CODEX", "GEMINI_CLI", "CI"],
      "include_modules": ["git"],
      "never_load": ["prompt", "completions", "sync-check"]
    }
  }
}
```

- [ ] **Step 2: Create `profiles/examples/personal-linux.json`**

```json
{
  "_comment": "Personal Linux desktop",
  "role": ["personal"],
  "modules": {
    "git": true,
    "modern-tools": true,
    "rust": true,
    "python": true,
    "vim": true,
    "fzf": true,
    "safety": true,
    "navigation": true
  },
  "git": {
    "name": "Your Name",
    "email": "you@personal.com"
  }
}
```

- [ ] **Step 3: Create `profiles/examples/personal-wsl.json`**

```json
{
  "_comment": "WSL Ubuntu — development environment",
  "role": ["personal", "work"],
  "modules": {
    "git": true,
    "modern-tools": true,
    "containers": true,
    "kubernetes": { "shell": true, "install": true, "disable": ["kubernetes.helm"] },
    "cloud": { "shell": true, "install": false },
    "python": true,
    "node": true,
    "vim": true,
    "fzf": true,
    "tmux": true,
    "safety": true,
    "system": true
  },
  "git": {
    "name": "Your Name",
    "email": "you@personal.com"
  },
  "modes": {
    "minimal": {
      "env_triggers": ["CLAUDE_CODE", "CODEX", "GEMINI_CLI", "CI", "GITHUB_ACTIONS"],
      "include_modules": ["git"],
      "never_load": ["prompt", "completions", "sync-check"]
    },
    "server": {
      "env_triggers": ["SSH_SESSION"],
      "include_modules": ["git", "safety", "system", "modern-tools"],
      "never_load": ["prompt", "fzf", "tmux"]
    }
  }
}
```

- [ ] **Step 4: Validate all examples are valid JSON**

```bash
for f in profiles/examples/*.json; do
  jq . "$f" > /dev/null && echo "OK: $f"
done
```

Expected: "OK" for all three files.

- [ ] **Step 5: Test generator against an example**

```bash
DOTFILES_DATA_DIR=/tmp/dotfiles-example-test \
  bash setup/generate-cache.sh profiles/examples/personal-wsl.json
cat /tmp/dotfiles-example-test/cache/profile.sh
rm -rf /tmp/dotfiles-example-test
```

Expected: Cache file with correct modules, disabled sections, and two modes (minimal, server).

- [ ] **Step 6: Commit**

```bash
git add profiles/examples/
git commit -m "feat: add example profiles for work-macos, personal-linux, personal-wsl

Illustrative profiles showing module selection, git identity,
and custom mode configurations."
```

---

### Task 10: Final integration test and cleanup

**Files:**
- Modify: `tests/test-profile-system.sh` (add end-to-end round-trip test)

- [ ] **Step 1: Add round-trip integration test**

Add a new test group before the `# --- Run ---` section in `tests/test-profile-system.sh`:

```bash
test_round_trip() {
  echo "=== Round-trip: profile → generate → loader ==="

  local test_home="/tmp/dotfiles-test-rt-$$"
  mkdir -p "${test_home}/.dotfiles"

  # Write a profile
  cat > "${test_home}/.dotfiles.json" <<'PROFILE'
{
  "modules": {
    "git": true,
    "modern-tools": true,
    "cloud": { "shell": true, "install": false },
    "kubernetes": { "shell": true, "install": true, "disable": ["kubernetes.helm", "kubernetes.istio"] }
  },
  "modes": {
    "ci": {
      "env_triggers": ["CI", "GITHUB_ACTIONS"],
      "include_modules": ["git"],
      "never_load": ["prompt"]
    }
  }
}
PROFILE

  # Generate cache
  HOME="$test_home" DOTFILES_DATA_DIR="${test_home}/.dotfiles" \
    bash "${DOTFILES_DIR}/setup/generate-cache.sh" > /dev/null

  assert_file_exists "cache generated" "${test_home}/.dotfiles/cache/profile.sh"

  # Load via the full chain
  (
    unset CLAUDE_CODE CODEX GEMINI_CLI CI DOTFILES_MODE
    unset OPENCODE GROK_CLI GITHUB_ACTIONS GITLAB_CI
    DOTFILES_DATA_DIR="${test_home}/.dotfiles"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    # Check modules loaded from cache
    assert_eq "4 modules enabled" "4" "${#DOTFILES_ENABLED_MODULES[@]}"
    assert_contains "git enabled" "git" "${DOTFILES_ENABLED_MODULES[*]}"
    assert_contains "cloud enabled" "cloud" "${DOTFILES_ENABLED_MODULES[*]}"

    # Check disabled sections
    assert_contains "kubernetes.helm disabled" "kubernetes.helm" "${DOTFILES_DISABLED_SECTIONS[*]}"
    assert_contains "kubernetes.istio disabled" "kubernetes.istio" "${DOTFILES_DISABLED_SECTIONS[*]}"

    # Check mode
    assert_eq "mode name is ci" "ci" "${DOTFILES_MODE_NAMES[0]}"

    # Trigger the mode
    CI=true
    dotfiles_resolve_mode
    assert_eq "CI triggers ci mode" "ci" "$DOTFILES_ACTIVE_MODE"
    unset CI
  )

  rm -rf "$test_home"
}
```

Also add `test_round_trip` to the run section:

```bash
# --- Run ---

test_data_dir_resolution
test_default_profile
test_mode_resolution
test_bash_profile_integration
test_generate_cache
test_round_trip
```

- [ ] **Step 2: Run the full test suite**

```bash
bash tests/test-profile-system.sh
```

Expected: All tests PASS, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add tests/test-profile-system.sh
git commit -m "test: add round-trip integration test (profile → cache → loader)"
```

- [ ] **Step 4: Verify everything is clean**

```bash
git status
git log --oneline feat/19-profile-system ^main
```

Expected: Clean working tree. ~9 commits on the branch.

---

## Task Dependency Graph

```
Task 1 (branch + harness)
  ↓
Task 2 (data dir resolution) ──→ Task 3 (loader rewrite) ──→ Task 4 (mode tests)
                                       ↓
                                 Task 5 (.bash_profile) ──→ Task 6 (integration tests)
                                       ↓
Task 7 (schema) ─────────────── Task 8 (generator) ──→ Task 9 (examples) ──→ Task 10 (round-trip)
```

Tasks 7 and 2-6 are independent of each other. Tasks 8-10 depend on both the generator and the loader being in place.
