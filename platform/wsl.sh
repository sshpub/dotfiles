#!/usr/bin/env bash
# platform/wsl.sh — WSL-specific core configuration
# Sourced only when DOTFILES_WSL=true

# Clipboard via Windows executables
alias pbcopy="clip.exe"
alias pbpaste="powershell.exe -command 'Get-Clipboard'"

# Open via Windows Explorer
alias open="explorer.exe"

# Windows home directory
if [[ -d "/mnt/c/Users/${USER}" ]]; then
    export WIN_HOME="/mnt/c/Users/${USER}"
fi

# Strip Windows paths from PATH unless opted in
# Windows PATH entries slow down command resolution significantly
if [[ "$DOTFILES_NO_WIN_PATH" != "false" ]]; then
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/mnt/c' | paste -sd ':' -)
fi
