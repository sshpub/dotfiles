#!/usr/bin/env bash
# core/aliases.sh — Essential aliases loaded for all interactive sessions
# Module-specific aliases (git, docker, k8s, etc.) belong in their modules.

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"
alias -- -="cd -"

# Listing — detect eza/exa or fall back to ls with color
if command -v eza &>/dev/null; then
    alias ls="eza --icons --group-directories-first"
    alias l="eza -l --icons --group-directories-first"
    alias la="eza -la --icons --group-directories-first"
    alias ll="eza -la --icons --group-directories-first"
elif command -v exa &>/dev/null; then
    alias ls="exa --icons"
    alias l="exa -l --icons"
    alias la="exa -la --icons"
    alias ll="exa -la --icons"
else
    if ls --color > /dev/null 2>&1; then
        colorflag="--color"
    else
        colorflag="-G"
    fi
    alias ls="command ls ${colorflag}"
    alias l="ls -lF ${colorflag}"
    alias la="ls -laF ${colorflag}"
    alias ll="ls -alF ${colorflag}"
    unset colorflag
fi

# Shell
alias reload="exec ${SHELL} -l"
alias path='echo -e ${PATH//:/\\n}'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Better defaults
alias mkdir='mkdir -pv'
alias df="df -h"
alias du="du -h"

# Enable aliases to be sudo'ed
alias sudo='sudo '

# Colorized grep fallback (only if ripgrep not available)
if ! command -v rg &>/dev/null; then
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi
