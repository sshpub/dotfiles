#!/usr/bin/env bash
# .bash_profile — Main entry point for the dotfiles framework
#
# Loading order:
#   1. Core essentials (always)
#   2. Minimal mode check → early exit for AI/CI
#   3. Core interactive
#   4. Platform layer
#   5. Profile cache → enabled modules / disabled sections
#   6. Module loading
#   7. Overrides (repo-level, then local)
#   8. Private config (~/.extra, ~/.local)
#   9. Prompt
#  10. Sync check

# --- Resolve DOTFILES_DIR (symlink-aware) ---
_dotfiles_resolve_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ "$source" != /* ]] && source="$dir/$source"
    done
    echo "$(cd -P "$(dirname "$source")" && pwd)"
}
export DOTFILES_DIR="$(_dotfiles_resolve_dir)"
unset -f _dotfiles_resolve_dir

# Helper: source a file if it exists
_dotfiles_source() { [[ -f "$1" ]] && . "$1"; }

# ─── 1. Core Essentials (always loaded) ───────────────────────────────
. "${DOTFILES_DIR}/core/platform.sh"
. "${DOTFILES_DIR}/core/loader.sh"
. "${DOTFILES_DIR}/core/path.sh"
. "${DOTFILES_DIR}/core/exports.sh"

# ─── 2. Mode Check ───────────────────────────────────────────────────
if dotfiles_resolve_mode; then
    dotfiles_load_mode_extras
    return 0 2>/dev/null || exit 0
fi

# ─── 3. Core Interactive ──────────────────────────────────────────────
. "${DOTFILES_DIR}/core/aliases.sh"
. "${DOTFILES_DIR}/core/functions.sh"
. "${DOTFILES_DIR}/core/completions.sh"

# ─── 4. Platform Layer ────────────────────────────────────────────────
if is_wsl; then
    _dotfiles_source "${DOTFILES_DIR}/platform/wsl.sh"
elif is_macos; then
    _dotfiles_source "${DOTFILES_DIR}/platform/macos.sh"
elif is_linux; then
    _dotfiles_source "${DOTFILES_DIR}/platform/linux.sh"
fi

# ─── 5–6. Profile + Module Loading ───────────────────────────────────
dotfiles_load_modules

# ─── 7. Overrides ────────────────────────────────────────────────────
# Repo-level (tracked)
for _f in "${DOTFILES_DIR}"/overrides/*.sh; do
    _dotfiles_source "$_f"
done
# Local-level (untracked, per-machine)
for _f in "${DOTFILES_DATA_DIR}"/local/*.sh; do
    _dotfiles_source "$_f"
done
unset _f

# ─── 8. Private Config ───────────────────────────────────────────────
_dotfiles_source "${HOME}/.extra"

# ─── 9. Prompt ───────────────────────────────────────────────────────
. "${DOTFILES_DIR}/core/prompt.sh"

# ─── 10. Sync Check ──────────────────────────────────────────────────
_dotfiles_source "${DOTFILES_DIR}/core/sync-check.sh"

unset -f _dotfiles_source
