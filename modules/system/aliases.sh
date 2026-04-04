#!/usr/bin/env bash

dotfiles_section "system.info" && {
    alias week='date +%V'
    alias now='date +"%T"'
    alias nowdate='date +"%Y-%m-%d"'
}

dotfiles_section "system.processes" && {
    if command -v htop &>/dev/null; then
        alias top="htop"
    fi
    alias free="free -h"
}
