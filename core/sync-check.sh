#!/usr/bin/env bash
# core/sync-check.sh — Git sync notification (cache-read only)
#
# Reads cached sync state and shows a one-liner if behind upstream.
# Never hits the network on shell startup — cache is updated externally
# by `dotfiles sync check` (background cron/timer or manual).

DOTFILES_SYNC_CACHE="${DOTFILES_CACHE_DIR:-$HOME/.dotfiles/cache}/sync-state"

_dotfiles_sync_check() {
    # Silent if no cache exists
    [[ -f "$DOTFILES_SYNC_CACHE" ]] || return 0

    local behind=""
    local branch=""

    # Cache format (one key=value per line):
    #   behind=3
    #   branch=origin/main
    #   checked=2026-04-04T12:00:00
    while IFS='=' read -r key value; do
        case "$key" in
            behind) behind="$value" ;;
            branch) branch="$value" ;;
        esac
    done < "$DOTFILES_SYNC_CACHE"

    # Only notify if behind
    if [[ -n "$behind" ]] && [[ "$behind" -gt 0 ]] 2>/dev/null; then
        echo "dotfiles: ${behind} commit(s) behind ${branch:-upstream} (run 'dotfiles update')"
    fi
}

_dotfiles_sync_check
