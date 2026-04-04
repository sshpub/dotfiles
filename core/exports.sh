#!/usr/bin/env bash
# core/exports.sh — Sane default environment variables
#
# Only universally useful settings live here.
# Module-specific exports belong in their respective modules.

# Editor — prefer nvim > vim > vi
if command -v nvim &>/dev/null; then
    export EDITOR='nvim'
    export VISUAL='nvim'
elif command -v vim &>/dev/null; then
    export EDITOR='vim'
    export VISUAL='vim'
else
    export EDITOR='vi'
    export VISUAL='vi'
fi

# Terminal
export TERM='xterm-256color'

# Locale
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# Bash history
export HISTSIZE='32768'
export HISTFILESIZE="${HISTSIZE}"
export HISTCONTROL='ignoreboth:erasedups'
export HISTIGNORE='ls:bg:fg:history:clear'
export HISTTIMEFORMAT='%F %T '

# Less / man with color support
export LESS='-F -g -i -M -R -S -w -X -z-4'
export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;36m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;33m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'
export LESS_TERMCAP_ue=$'\E[0m'
export MANPAGER='less -X'

# GPG TTY for signing commits
if tty -s 2>/dev/null; then
    export GPG_TTY
    GPG_TTY=$(tty)
fi

# XDG base directories (set defaults, don't mkdir)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
