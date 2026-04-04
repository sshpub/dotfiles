#!/usr/bin/env bash
# core/path.sh — Base PATH management
#
# Provides add_to_path() helper and sets up universal base paths.
# Module-specific paths are handled by individual modules.
#
# Expects core/platform.sh to be sourced first (HOMEBREW_PREFIX, DOTFILES_OS).

# --- Helper ---

# add_to_path — safely add a directory to PATH
#
# Usage:
#   add_to_path /some/dir            # prepend (default, highest priority)
#   add_to_path --append /some/dir   # append (lowest priority)
#
# Checks:
#   - Directory must exist
#   - Duplicate entries are skipped
add_to_path() {
  local mode="prepend"
  if [[ "$1" == "--append" ]]; then
    mode="append"
    shift
  fi

  local dir="$1"
  [[ -z "$dir" ]] && return 1

  # Directory must exist
  [[ ! -d "$dir" ]] && return 1

  # Skip if already in PATH
  case ":${PATH}:" in
    *":${dir}:"*) return 0 ;;
  esac

  # Add to PATH
  if [[ "$mode" == "append" ]]; then
    PATH="${PATH}:${dir}"
  else
    PATH="${dir}:${PATH}"
  fi
}

# --- Base PATH setup ---

# User directories (highest priority)
add_to_path "${HOME}/.local/bin"
add_to_path "${HOME}/bin"

# Homebrew (if platform.sh detected it)
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  add_to_path "${HOMEBREW_PREFIX}/bin"
  add_to_path "${HOMEBREW_PREFIX}/sbin"
fi

# Snap packages on Linux (low priority)
if [[ "${DOTFILES_OS:-}" == "linux" ]]; then
  add_to_path --append "/snap/bin"
fi

export PATH
