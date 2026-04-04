#!/usr/bin/env bash
# modules/modern-tools/aliases.sh — Modern CLI tool aliases

dotfiles_section "modern-tools.listing" && {
    if command -v eza &>/dev/null; then
        alias ls="eza --icons --group-directories-first"
        alias l="eza -l --icons --group-directories-first"
        alias la="eza -la --icons --group-directories-first"
        alias ll="eza -la --icons --group-directories-first"
        alias lsd="eza -lD --icons --group-directories-first"
        alias lt="eza -l --sort=modified --icons --group-directories-first"
        alias lS="eza -l --sort=size --icons --group-directories-first"
        alias tree="eza --tree --icons --group-directories-first"
    elif command -v exa &>/dev/null; then
        alias ls="exa --icons"
        alias l="exa -l --icons"
        alias la="exa -la --icons"
        alias ll="exa -la --icons"
        alias lsd="exa -lD --icons"
        alias lt="exa -l --sort=modified --icons"
        alias lS="exa -l --sort=size --icons"
        alias tree="exa --tree --icons"
    fi
}

dotfiles_section "modern-tools.cat" && {
    if command -v bat &>/dev/null; then
        alias cat="bat"
        alias catp="bat --plain"
    elif command -v batcat &>/dev/null; then
        # Debian/Ubuntu package name
        alias cat="batcat"
        alias bat="batcat"
        alias catp="batcat --plain"
    fi
}

dotfiles_section "modern-tools.search" && {
    if command -v rg &>/dev/null; then
        alias rg='rg --smart-case'
    fi
    if command -v fd &>/dev/null; then
        alias fd='fd --hidden --follow'
    elif command -v fdfind &>/dev/null; then
        # Debian/Ubuntu package name
        alias fd='fdfind --hidden --follow'
    fi
}

dotfiles_section "modern-tools.cd" && {
    if command -v zoxide &>/dev/null; then
        eval "$(zoxide init bash)"
        alias zi='zoxide query -i'
    fi
}
