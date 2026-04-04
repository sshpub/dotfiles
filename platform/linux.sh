#!/usr/bin/env bash
# platform/linux.sh — Linux-specific core configuration
# Sourced only when DOTFILES_OS=linux and NOT WSL

# Clipboard via xclip
if command -v xclip &>/dev/null; then
    alias pbcopy="xclip -selection clipboard"
    alias pbpaste="xclip -selection clipboard -o"
fi

# Open via xdg-open
alias open="xdg-open"
