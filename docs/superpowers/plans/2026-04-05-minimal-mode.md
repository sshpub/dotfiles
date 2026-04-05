# Minimal Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the modes system with include/exclude types, DOTFILES_MODE disable, selective loading via `never_load`, and a test helper function.

**Architecture:** Modes gain a `type` field (`include` = early return, `exclude` = full load minus exclusions). The loader gets helper functions (`dotfiles_mode_is_include`, `dotfiles_should_load`) and `.bash_profile` wraps skippable steps. The cache generator emits the new TYPE variable.

**Tech Stack:** Bash 4.x+ (indirect expansion), jq, JSON Schema

---

**Spec:** `docs/superpowers/specs/2026-04-05-minimal-mode-design.md`

**Branch:** `feat/20-minimal-mode` from `main`

**File Map:**

| File | Action | Responsibility |
|------|--------|---------------|
| `core/loader.sh` | Modify | Add disable check, `dotfiles_mode_is_include()`, `dotfiles_should_load()`, `dotfiles_test_mode()`, never_load-aware `dotfiles_load_modules` |
| `.bash_profile` | Modify | Branch on mode type at step 2, wrap steps 3/9/10 with `dotfiles_should_load` |
| `profiles/schema.json` | Modify | Add `type` field to mode schema |
| `setup/generate-cache.sh` | Modify | Emit `DOTFILES_MODE_{name}_TYPE` variable |
| `tests/test-profile-system.sh` | Modify | Add mode disable, exclude mode, selective loading, and performance tests |

---

### Task 1: Create branch and add mode disable tests

**Files:**
- Modify: `tests/test-profile-system.sh`

- [ ] **Step 1: Create the feature branch**

```bash
git checkout main
git checkout -b feat/20-minimal-mode
```

- [ ] **Step 2: Add mode disable tests**

Add a new test group before `# --- Run ---` in `tests/test-profile-system.sh`:

```bash
test_mode_disable() {
  echo "=== Mode disable (DOTFILES_MODE=none/false/off) ==="

  # Test: DOTFILES_MODE=none disables mode even when trigger is set
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-disable-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    CLAUDE_CODE=1
    DOTFILES_MODE=none
    if dotfiles_resolve_mode; then
      fail "DOTFILES_MODE=none disables" "should have returned 1"
    else
      pass "DOTFILES_MODE=none disables"
    fi
    assert_eq "active mode empty with none" "" "$DOTFILES_ACTIVE_MODE"
    unset CLAUDE_CODE DOTFILES_MODE
    rm -rf "$test_home"
  )

  # Test: DOTFILES_MODE=false disables
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-disable-false-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    CLAUDE_CODE=1
    DOTFILES_MODE=false
    if dotfiles_resolve_mode; then
      fail "DOTFILES_MODE=false disables" "should have returned 1"
    else
      pass "DOTFILES_MODE=false disables"
    fi
    unset CLAUDE_CODE DOTFILES_MODE
    rm -rf "$test_home"
  )

  # Test: DOTFILES_MODE=off disables
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-disable-off-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    CLAUDE_CODE=1
    DOTFILES_MODE=off
    if dotfiles_resolve_mode; then
      fail "DOTFILES_MODE=off disables" "should have returned 1"
    else
      pass "DOTFILES_MODE=off disables"
    fi
    unset CLAUDE_CODE DOTFILES_MODE
    rm -rf "$test_home"
  )
}
```

Also add `test_mode_disable` to the run section:

```bash
test_data_dir_resolution
test_default_profile
test_mode_resolution
test_mode_disable
test_bash_profile_integration
test_generate_cache
test_round_trip
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bash tests/test-profile-system.sh
```

Expected: 3 FAILs — `DOTFILES_MODE=none` doesn't disable yet (it gets treated as a mode name).

- [ ] **Step 4: Implement disable check in `core/loader.sh`**

Add at the top of `dotfiles_resolve_mode()`, before the existing env var override check:

```bash
dotfiles_resolve_mode() {
  # Explicit disable
  if [[ "${DOTFILES_MODE:-}" =~ ^(none|false|off)$ ]]; then
    DOTFILES_ACTIVE_MODE=""
    return 1
  fi
  # Env var override
  if [[ -n "${DOTFILES_MODE:-}" ]]; then
```

(The rest of the function stays the same.)

- [ ] **Step 5: Run tests to verify they pass**

```bash
bash tests/test-profile-system.sh
```

Expected: All tests PASS including 3 new disable tests.

- [ ] **Step 6: Commit**

```bash
git add core/loader.sh tests/test-profile-system.sh
git commit -m "feat: add DOTFILES_MODE=none/false/off to disable mode resolution

Allows forcing full interactive shell even when mode triggers match.
Useful for debugging in CI or AI tool environments."
```

---

### Task 2: Add `dotfiles_mode_is_include` and `dotfiles_should_load` helpers

**Files:**
- Modify: `core/loader.sh`
- Modify: `tests/test-profile-system.sh`

- [ ] **Step 1: Add tests for mode type helpers**

Add a new test group before `# --- Run ---` in `tests/test-profile-system.sh`:

```bash
test_mode_types() {
  echo "=== Mode types (include/exclude) ==="

  # Test: default type is include
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-type-default-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    CLAUDE_CODE=1
    dotfiles_resolve_mode
    if dotfiles_mode_is_include; then
      pass "default mode type is include"
    else
      fail "default mode type is include" "returned false"
    fi
    unset CLAUDE_CODE
    rm -rf "$test_home"
  )

  # Test: explicit include type
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-type-include-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    DOTFILES_MODE_NAMES=(testmode)
    DOTFILES_MODE_testmode_TRIGGERS=(TEST_TRIGGER)
    DOTFILES_MODE_testmode_TYPE=include
    DOTFILES_MODE_testmode_MODULES=()
    DOTFILES_MODE_testmode_NEVER_LOAD=()

    TEST_TRIGGER=1
    dotfiles_resolve_mode
    if dotfiles_mode_is_include; then
      pass "explicit include type"
    else
      fail "explicit include type" "returned false"
    fi
    unset TEST_TRIGGER
    rm -rf "$test_home"
  )

  # Test: exclude type
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-type-exclude-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    DOTFILES_MODE_NAMES=(servermode)
    DOTFILES_MODE_servermode_TRIGGERS=(SSH_TEST)
    DOTFILES_MODE_servermode_TYPE=exclude
    DOTFILES_MODE_servermode_MODULES=()
    DOTFILES_MODE_servermode_NEVER_LOAD=(prompt fzf)

    SSH_TEST=1
    dotfiles_resolve_mode
    if dotfiles_mode_is_include; then
      fail "exclude type not include" "returned true"
    else
      pass "exclude type not include"
    fi
    unset SSH_TEST
    rm -rf "$test_home"
  )

  # Test: dotfiles_should_load returns 0 when no mode active
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-shouldload-nomode-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    DOTFILES_ACTIVE_MODE=""
    if dotfiles_should_load prompt; then
      pass "should_load true when no mode"
    else
      fail "should_load true when no mode" "returned false"
    fi
    rm -rf "$test_home"
  )

  # Test: dotfiles_should_load skips items in never_load for exclude mode
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-shouldload-exclude-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    DOTFILES_MODE_NAMES=(servermode)
    DOTFILES_MODE_servermode_TRIGGERS=(SSH_TEST)
    DOTFILES_MODE_servermode_TYPE=exclude
    DOTFILES_MODE_servermode_MODULES=()
    DOTFILES_MODE_servermode_NEVER_LOAD=(prompt fzf)

    SSH_TEST=1
    dotfiles_resolve_mode
    if dotfiles_should_load prompt; then
      fail "should_load blocks prompt in exclude mode" "returned true"
    else
      pass "should_load blocks prompt in exclude mode"
    fi
    if dotfiles_should_load git; then
      pass "should_load allows git in exclude mode"
    else
      fail "should_load allows git in exclude mode" "returned false"
    fi
    unset SSH_TEST
    rm -rf "$test_home"
  )

  # Test: dotfiles_should_load allows everything in include mode
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-shouldload-include-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    CLAUDE_CODE=1
    dotfiles_resolve_mode
    if dotfiles_should_load prompt; then
      pass "should_load allows prompt in include mode"
    else
      fail "should_load allows prompt in include mode" "returned false"
    fi
    unset CLAUDE_CODE
    rm -rf "$test_home"
  )
}
```

Also add `test_mode_types` to the run section, after `test_mode_disable`:

```bash
test_mode_disable
test_mode_types
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash tests/test-profile-system.sh
```

Expected: FAILs — `dotfiles_mode_is_include` and `dotfiles_should_load` don't exist yet.

- [ ] **Step 3: Implement helpers in `core/loader.sh`**

Add after the `dotfiles_is_minimal()` function:

```bash
# --- Mode Type Helpers ---

dotfiles_mode_is_include() {
  local type_var="DOTFILES_MODE_${DOTFILES_ACTIVE_MODE}_TYPE"
  [[ "${!type_var:-include}" == "include" ]]
}

dotfiles_should_load() {
  [[ -z "$DOTFILES_ACTIVE_MODE" ]] && return 0
  dotfiles_mode_is_include && return 0
  local never_var="DOTFILES_MODE_${DOTFILES_ACTIVE_MODE}_NEVER_LOAD[@]"
  local item
  for item in "${!never_var}"; do
    [[ "$item" == "$1" ]] && return 1
  done
  return 0
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash tests/test-profile-system.sh
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add core/loader.sh tests/test-profile-system.sh
git commit -m "feat: add dotfiles_mode_is_include and dotfiles_should_load helpers

Include modes do early return (fast path). Exclude modes run the full
loading chain but skip items in never_load. Default type is include
for backward compat."
```

---

### Task 3: Update `.bash_profile` for selective loading

**Files:**
- Modify: `.bash_profile`
- Modify: `core/loader.sh` (wrap `dotfiles_load_modules` with never_load check)
- Modify: `tests/test-profile-system.sh`

- [ ] **Step 1: Add exclude mode integration test**

Add a new test group before `# --- Run ---` in `tests/test-profile-system.sh`:

```bash
test_exclude_mode_integration() {
  echo "=== Exclude mode integration ==="

  # Test: exclude mode loads modules but skips never_load items
  (
    set +eu +o pipefail
    unset DOTFILES_DATA_DIR CLAUDE_CODE CODEX GEMINI_CLI CI
    unset OPENCODE GROK_CLI GITHUB_ACTIONS GITLAB_CI
    local test_home="/tmp/dotfiles-test-exclude-int-$$"
    mkdir -p "$test_home"

    # Set up an exclude mode via env vars (no cache needed — we set vars directly)
    DOTFILES_MODE_NAMES=(testexclude)
    DOTFILES_MODE_testexclude_TRIGGERS=(TEST_EXCLUDE)
    DOTFILES_MODE_testexclude_TYPE=exclude
    DOTFILES_MODE_testexclude_MODULES=()
    DOTFILES_MODE_testexclude_NEVER_LOAD=(prompt sync-check)

    TEST_EXCLUDE=1 HOME="$test_home" source "${DOTFILES_DIR}/.bash_profile" 2>/dev/null
    set -eu -o pipefail

    assert_eq "exclude mode activated" "testexclude" "${DOTFILES_ACTIVE_MODE:-}"

    # Modules should have loaded (all-modules default, full chain)
    if [[ ${#DOTFILES_ENABLED_MODULES[@]} -gt 0 ]]; then
      pass "exclude mode loads modules"
    else
      fail "exclude mode loads modules" "no modules loaded"
    fi

    unset TEST_EXCLUDE
    rm -rf "$test_home"
  )
}
```

Add `test_exclude_mode_integration` to the run section, after `test_bash_profile_integration`.

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash tests/test-profile-system.sh
```

Expected: FAIL — `.bash_profile` still does early return for all modes.

- [ ] **Step 3: Update `.bash_profile` step 2**

Replace in `.bash_profile`:

```bash
# ─── 2. Mode Check ───────────────────────────────────────────────────
if dotfiles_resolve_mode; then
    dotfiles_load_mode_extras
    return 0 2>/dev/null || exit 0
fi
```

With:

```bash
# ─── 2. Mode Check ───────────────────────────────────────────────────
if dotfiles_resolve_mode; then
    if dotfiles_mode_is_include; then
        dotfiles_load_mode_extras
        return 0 2>/dev/null || exit 0
    fi
    # Exclude mode: continue full load, never_load enforced below
fi
```

- [ ] **Step 4: Update `.bash_profile` steps 3, 9, 10 with `dotfiles_should_load`**

Replace step 3:

```bash
# ─── 3. Core Interactive ──────────────────────────────────────────────
. "${DOTFILES_DIR}/core/aliases.sh"
. "${DOTFILES_DIR}/core/functions.sh"
. "${DOTFILES_DIR}/core/completions.sh"
```

With:

```bash
# ─── 3. Core Interactive ──────────────────────────────────────────────
. "${DOTFILES_DIR}/core/aliases.sh"
. "${DOTFILES_DIR}/core/functions.sh"
dotfiles_should_load completions && . "${DOTFILES_DIR}/core/completions.sh"
```

Replace step 9:

```bash
# ─── 9. Prompt ───────────────────────────────────────────────────────
. "${DOTFILES_DIR}/core/prompt.sh"
```

With:

```bash
# ─── 9. Prompt ───────────────────────────────────────────────────────
dotfiles_should_load prompt && . "${DOTFILES_DIR}/core/prompt.sh"
```

Replace step 10:

```bash
# ─── 10. Sync Check ──────────────────────────────────────────────────
_dotfiles_source "${DOTFILES_DIR}/core/sync-check.sh"
```

With:

```bash
# ─── 10. Sync Check ──────────────────────────────────────────────────
dotfiles_should_load sync-check && _dotfiles_source "${DOTFILES_DIR}/core/sync-check.sh"
```

- [ ] **Step 5: Update `dotfiles_load_modules` in `core/loader.sh`**

Replace:

```bash
dotfiles_load_modules() {
  local mod
  for mod in "${DOTFILES_ENABLED_MODULES[@]}"; do
    load_module "$mod"
  done
}
```

With:

```bash
dotfiles_load_modules() {
  local mod
  for mod in "${DOTFILES_ENABLED_MODULES[@]}"; do
    dotfiles_should_load "$mod" && load_module "$mod"
  done
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bash tests/test-profile-system.sh
```

Expected: All tests PASS including exclude mode integration.

- [ ] **Step 7: Commit**

```bash
git add .bash_profile core/loader.sh tests/test-profile-system.sh
git commit -m "feat: implement selective loading for exclude-type modes

Include modes do early return (unchanged). Exclude modes run the full
loading chain but skip items in never_load. Completions, prompt, and
sync-check are individually skippable. Module loading checks never_load."
```

---

### Task 4: Update schema and cache generator

**Files:**
- Modify: `profiles/schema.json`
- Modify: `setup/generate-cache.sh`
- Modify: `tests/test-profile-system.sh`

- [ ] **Step 1: Add cache generator test for type field**

Add a new test group before `# --- Run ---` in `tests/test-profile-system.sh`:

```bash
test_generate_cache_types() {
  echo "=== Cache generator with mode types ==="

  local test_home="/tmp/dotfiles-test-gen-types-$$"
  local test_profile="${test_home}/profile.json"

  mkdir -p "${test_home}/.dotfiles"

  cat > "$test_profile" <<'PROFILE'
{
  "modules": { "git": true },
  "modes": {
    "minimal": {
      "type": "include",
      "env_triggers": ["CI"],
      "include_modules": ["git"],
      "never_load": []
    },
    "server": {
      "type": "exclude",
      "env_triggers": ["SSH_SESSION"],
      "include_modules": [],
      "never_load": ["prompt", "fzf"]
    }
  }
}
PROFILE

  (
    DOTFILES_DATA_DIR="${test_home}/.dotfiles" \
      bash "${DOTFILES_DIR}/setup/generate-cache.sh" "$test_profile" > /dev/null

    source "${test_home}/.dotfiles/cache/profile.sh"

    assert_eq "minimal type is include" "include" "${DOTFILES_MODE_minimal_TYPE}"
    assert_eq "server type is exclude" "exclude" "${DOTFILES_MODE_server_TYPE}"
  )

  rm -rf "$test_home"
}
```

Add `test_generate_cache_types` to the run section, after `test_generate_cache`.

- [ ] **Step 2: Run tests to verify they fail**

```bash
bash tests/test-profile-system.sh
```

Expected: FAIL — `DOTFILES_MODE_minimal_TYPE` is not set (generator doesn't emit it yet).

- [ ] **Step 3: Update `setup/generate-cache.sh` to emit TYPE**

In the per-mode variables loop, add the type emission after the mode name loop begins. Find this line in the file:

```bash
    [[ -z "$mode" ]] && continue

    # Triggers
```

Add before `# Triggers`:

```bash
    # Type (defaults to include)
    mode_type="$(echo "$PROFILE" | jq -r ".modes[\"$mode\"].type // \"include\"")"
    printf "DOTFILES_MODE_%s_TYPE=%s\n" "$mode" "$mode_type"

```

- [ ] **Step 4: Update `profiles/schema.json`**

Add the `type` field to the mode object properties. In the mode's `patternProperties` object, add after `"_comment"`:

```json
"type": {
  "type": "string",
  "enum": ["include", "exclude"],
  "description": "Mode type — include (early return, load only include_modules) or exclude (full load, skip never_load). Defaults to include."
},
```

- [ ] **Step 5: Validate schema is still valid JSON**

```bash
jq . profiles/schema.json > /dev/null && echo "Valid JSON"
```

Expected: "Valid JSON"

- [ ] **Step 6: Run tests to verify they pass**

```bash
bash tests/test-profile-system.sh
```

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add profiles/schema.json setup/generate-cache.sh tests/test-profile-system.sh
git commit -m "feat: add mode type field to schema and cache generator

Schema accepts type: include|exclude on modes. Generator emits
DOTFILES_MODE_{name}_TYPE variable. Defaults to include."
```

---

### Task 5: Test helper and default profile update

**Files:**
- Modify: `core/loader.sh`

- [ ] **Step 1: Add `dotfiles_test_mode` function**

Add at the end of `core/loader.sh`, after `dotfiles_load_mode_extras`:

```bash
# --- Test Helper ---

dotfiles_test_mode() {
  DOTFILES_MODE="${1:-minimal}" bash -l
}
```

- [ ] **Step 2: Add TYPE to default profile**

In `_dotfiles_default_profile()` in `core/loader.sh`, add after `DOTFILES_MODE_NAMES=(minimal)`:

```bash
  DOTFILES_MODE_minimal_TYPE=include
```

- [ ] **Step 3: Verify test helper works**

```bash
DOTFILES_MODE=minimal bash -lc 'echo "mode=$DOTFILES_ACTIVE_MODE"; exit'
```

Expected: `mode=minimal`

- [ ] **Step 4: Run full test suite**

```bash
bash tests/test-profile-system.sh
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add core/loader.sh
git commit -m "feat: add dotfiles_test_mode helper and TYPE to default profile

dotfiles_test_mode spawns a login shell in the given mode.
Default minimal mode explicitly sets TYPE=include."
```

---

### Task 6: Performance measurement and final verification

**Files:**
- Modify: `tests/test-profile-system.sh`

- [ ] **Step 1: Add performance test**

Add a new test group before `# --- Run ---` in `tests/test-profile-system.sh`:

```bash
test_performance() {
  echo "=== Performance ==="

  # Test: minimal mode startup under 50ms (soft assertion)
  (
    local start elapsed
    start=$(date +%s%N)
    DOTFILES_MODE=minimal bash -lc 'exit' 2>/dev/null
    elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
    if [[ $elapsed -lt 50 ]]; then
      pass "minimal mode under 50ms (${elapsed}ms)"
    elif [[ $elapsed -lt 100 ]]; then
      pass "minimal mode under 100ms (${elapsed}ms) — soft pass, close to target"
    else
      fail "minimal mode under 50ms" "took ${elapsed}ms"
    fi
  )
}
```

Add `test_performance` to the run section, at the end before `test_round_trip`.

- [ ] **Step 2: Run full test suite**

```bash
bash tests/test-profile-system.sh
```

Expected: All tests PASS. Performance test reports timing.

- [ ] **Step 3: Commit**

```bash
git add tests/test-profile-system.sh
git commit -m "test: add minimal mode performance measurement

Soft assertion — passes under 100ms with note, fails over 100ms."
```

- [ ] **Step 4: Run full test suite one final time and verify clean state**

```bash
bash tests/test-profile-system.sh
git status
git log --oneline feat/20-minimal-mode ^main
```

Expected: All tests PASS, clean working tree, ~6 commits on the branch.

---

## Task Dependency Graph

```
Task 1 (branch + disable) → Task 2 (type helpers) → Task 3 (.bash_profile + selective loading)
                                                         ↓
                              Task 4 (schema + generator) → Task 5 (test helper + defaults) → Task 6 (performance)
```

Tasks are sequential — each builds on the previous.
