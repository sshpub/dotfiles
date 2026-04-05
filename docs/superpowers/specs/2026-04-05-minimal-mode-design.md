# Minimal Mode Design — Issue #20

**Date:** 2026-04-05
**Author:** Anton Swartz
**Status:** Approved

## Overview

Extends the generic modes system (#19) with two mode types: `include` (early return, load only specified modules) and `exclude` (full loading chain, skip specified items). Adds `DOTFILES_MODE=none/false/off` to disable mode resolution entirely, a test helper function, and performance verification.

## Decisions

- **Mode types:** Explicit `type` field — `"include"` (early return) vs `"exclude"` (full load minus exclusions)
- **No `DOTFILES_MINIMAL` trigger:** `DOTFILES_MODE=minimal` already forces minimal mode
- **Disable modes:** `DOTFILES_MODE=none/false/off` forces full interactive shell even when triggers match
- **Test helper:** One-liner `dotfiles_test_mode()` function, CLI replaces later

---

## 1. Mode `type` Field

Added to each mode in profile JSON:

```json
"modes": {
  "minimal": {
    "type": "include",
    "env_triggers": ["CLAUDE_CODE", "CI"],
    "include_modules": ["git"]
  },
  "server": {
    "type": "exclude",
    "env_triggers": ["SSH_SESSION"],
    "never_load": ["prompt", "fzf", "tmux"]
  }
}
```

### Rules

- `"include"` — early return after core essentials (platform, loader, path, exports) + `include_modules`. Fast path. `never_load` ignored.
- `"exclude"` — full loading chain runs, but anything in `never_load` is skipped. `never_load` items can be core components (`completions`, `prompt`, `sync-check`) or module names. `include_modules` ignored.
- Default type if omitted: `"include"` (backward compat with all existing modes)

### Cache format

Adds one variable per mode:

```bash
DOTFILES_MODE_minimal_TYPE=include
DOTFILES_MODE_server_TYPE=exclude
```

---

## 2. `DOTFILES_MODE` Disable Behavior

`dotfiles_resolve_mode()` checks for explicit disable before anything else:

```bash
if [[ "${DOTFILES_MODE:-}" =~ ^(none|false|off)$ ]]; then
  DOTFILES_ACTIVE_MODE=""
  return 1
fi
```

Precedence:
1. `DOTFILES_MODE=none/false/off` → no mode, full interactive
2. `DOTFILES_MODE=<name>` → force that mode
3. Unset → normal trigger detection

---

## 3. `.bash_profile` Loading Changes

Step 2 branches on mode type:

```bash
if dotfiles_resolve_mode; then
    if dotfiles_mode_is_include; then
        dotfiles_load_mode_extras
        return 0 2>/dev/null || exit 0
    fi
    # Exclude mode: continue full load, never_load enforced below
fi
```

For `exclude` modes, the loading chain continues but checks `dotfiles_should_load` at:

- **Step 3:** `completions` is skippable (aliases and functions always load)
- **Step 6:** Each module checked against `never_load`
- **Step 9:** `prompt` is skippable
- **Step 10:** `sync-check` is skippable

### New loader helpers

```bash
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

### Modified `dotfiles_load_modules`

Wraps each module in a `dotfiles_should_load` check so `exclude` modes can skip modules by name.

---

## 4. Test Helper

One-liner in `core/loader.sh`:

```bash
dotfiles_test_mode() {
  DOTFILES_MODE="${1:-minimal}" bash -l
}
```

Usage: `dotfiles_test_mode`, `dotfiles_test_mode server`

CLI replaces this in Phase 4.

---

## 5. Performance

Include-type modes (minimal) must stay under 50ms. Verified with a timing test in the test suite. Soft assertion — warns rather than fails since CI environments vary.

---

## 6. Deliverables

| File | Action | What changes |
|------|--------|-------------|
| `profiles/schema.json` | Modify | Add `type` field to mode schema |
| `core/loader.sh` | Modify | Disable check, `dotfiles_mode_is_include()`, `dotfiles_should_load()`, `dotfiles_test_mode()`, never_load-aware `dotfiles_load_modules` |
| `.bash_profile` | Modify | Branch on mode type at step 2, wrap steps 3/9/10 with `dotfiles_should_load` |
| `setup/generate-cache.sh` | Modify | Emit `DOTFILES_MODE_{name}_TYPE` variable |
| `tests/test-profile-system.sh` | Modify | Exclude mode tests, disable tests, performance test |

## 7. Out of Scope

- CLI `dotfiles minimal test` command (Phase 4)
- Documentation / guides (Phase 6)
- `never_load` for core essentials (platform, loader, path, exports always load — they're the foundation)

## 8. Backward Compatibility

- Modes without `type` field default to `"include"` — all existing caches and profiles work unchanged
- `dotfiles_is_minimal()` still works as a thin wrapper
- Default hardcoded minimal mode in `_dotfiles_default_profile` gets `TYPE=include`
