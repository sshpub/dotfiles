#!/usr/bin/env bash
# Note: basic rm/cp/mv safety is in core/aliases.sh
# This module adds disk-awareness aliases

dotfiles_section "safety.disk" && {
    alias diskspace="df -h | grep -v tmpfs | sort -k5 -h -r"
    alias dirsize="du -sh * 2>/dev/null | sort -h -r"
    alias biggest="du -ah . 2>/dev/null | sort -rh | head -20"
}
