#!/usr/bin/env bash
# core/loader.sh — Module loading, section guards, minimal mode
#
# Fast path: source cached profile for enabled modules / disabled sections
# Fallback:  sensible defaults (no modules, default minimal triggers)
#
# This file defines the toolkit. .bash_profile orchestrates the loading order.

# --- Bootstrap ---

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DOTFILES_MODULES_DIR="${DOTFILES_DIR}/modules"
DOTFILES_CACHE_DIR="${HOME}/.dotfiles/cache"
DOTFILES_PROFILE_CACHE="${DOTFILES_CACHE_DIR}/profile.sh"

export DOTFILES_DIR DOTFILES_MODULES_DIR DOTFILES_CACHE_DIR

# --- Profile: cache-read fast path, defaults fallback ---

_dotfiles_default_profile() {
  DOTFILES_ENABLED_MODULES=()
  DOTFILES_DISABLED_SECTIONS=()
  DOTFILES_MINIMAL_TRIGGERS=(
    CLAUDE_CODE CODEX GEMINI_CLI OPENCODE GROK_CLI
    CI GITHUB_ACTIONS GITLAB_CI
  )
  DOTFILES_MINIMAL_MODULES=()
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

# --- Minimal Mode ---

dotfiles_is_minimal() {
  [[ "$DOTFILES_MINIMAL" == "true" ]] && return 0
  local var
  for var in "${DOTFILES_MINIMAL_TRIGGERS[@]}"; do
    [[ -n "${!var}" ]] && return 0
  done
  return 1
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

dotfiles_load_minimal_extras() {
  local mod
  for mod in "${DOTFILES_MINIMAL_MODULES[@]}"; do
    load_module "$mod"
  done
}
