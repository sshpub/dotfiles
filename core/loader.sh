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
  # Explicit disable
  if [[ "${DOTFILES_MODE:-}" =~ ^(none|false|off)$ ]]; then
    DOTFILES_ACTIVE_MODE=""
    return 1
  fi
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
    dotfiles_should_load "$mod" && load_module "$mod"
  done
}

dotfiles_load_mode_extras() {
  local modules_var="DOTFILES_MODE_${DOTFILES_ACTIVE_MODE}_MODULES[@]"
  local mod
  for mod in "${!modules_var}"; do
    load_module "$mod"
  done
}
