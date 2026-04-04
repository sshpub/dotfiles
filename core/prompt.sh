#!/usr/bin/env bash
# core/prompt.sh — Prompt configuration
# Supports Oh My Posh, Starship, or a clean fallback prompt.

# --- Oh My Posh ---
if command -v oh-my-posh &>/dev/null && [[ "$DOTFILES_USE_STARSHIP" != "true" ]]; then
    OMP_THEME=""
    if [[ -f "$HOME/.config/ohmyposh/atomic.omp.json" ]]; then
        OMP_THEME="$HOME/.config/ohmyposh/atomic.omp.json"
    elif [[ -n "$HOMEBREW_PREFIX" ]] && [[ -f "$HOMEBREW_PREFIX/opt/oh-my-posh/themes/atomic.omp.json" ]]; then
        OMP_THEME="$HOMEBREW_PREFIX/opt/oh-my-posh/themes/atomic.omp.json"
    else
        OMP_THEME="atomic"
    fi
    eval "$(oh-my-posh init bash --config "$OMP_THEME")"
    return 0 2>/dev/null || true

# --- Starship ---
elif command -v starship &>/dev/null && [[ "$DOTFILES_USE_STARSHIP" == "true" ]]; then
    eval "$(starship init bash)"
    return 0 2>/dev/null || true
fi

# --- Fallback prompt ---
# Clean prompt with git status, color-coded user/host/path

_dotfiles_prompt_git() {
    local s='' branchName=''

    # Check if in a git repo
    git rev-parse --is-inside-work-tree &>/dev/null || return

    # Don't run checks inside .git dir
    if [[ "$(git rev-parse --is-inside-git-dir 2>/dev/null)" == 'false' ]]; then
        git update-index --really-refresh -q &>/dev/null
        # Uncommitted changes
        ! git diff --quiet --ignore-submodules --cached && s+='+'
        # Unstaged changes
        ! git diff-files --quiet --ignore-submodules -- && s+='!'
        # Untracked files
        [[ -n "$(git ls-files --others --exclude-standard)" ]] && s+='?'
        # Stashed files
        git rev-parse --verify refs/stash &>/dev/null && s+='$'
    fi

    branchName="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || \
        git rev-parse --short HEAD 2>/dev/null || \
        echo '(unknown)')"

    [[ -n "$s" ]] && s=" [${s}]"
    echo -e "${1}${branchName}${2}${s}"
}

# Colors via tput (with ANSI fallback)
if tput setaf 1 &>/dev/null; then
    tput sgr0
    bold=$(tput bold)
    reset=$(tput sgr0)
    green=$(tput setaf 64)
    orange=$(tput setaf 166)
    red=$(tput setaf 124)
    violet=$(tput setaf 61)
    white=$(tput setaf 15)
    yellow=$(tput setaf 136)
    blue=$(tput setaf 33)
else
    bold=''
    reset="\e[0m"
    green="\e[1;32m"
    orange="\e[1;33m"
    red="\e[1;31m"
    violet="\e[1;35m"
    white="\e[1;37m"
    yellow="\e[1;33m"
    blue="\e[1;34m"
fi

# Root = red, normal = orange
if [[ "${USER}" == "root" ]]; then
    userStyle="${red}"
else
    userStyle="${orange}"
fi

# SSH = bold red hostname
if [[ "${SSH_TTY}" ]]; then
    hostStyle="${bold}${red}"
else
    hostStyle="${yellow}"
fi

PS1="\[\033]0;\W\007\]"
PS1+="\[${bold}\]\n"
PS1+="\[${userStyle}\]\u"
PS1+="\[${white}\] at "
PS1+="\[${hostStyle}\]\h"
PS1+="\[${white}\] in "
PS1+="\[${green}\]\w"
PS1+="\$(_dotfiles_prompt_git \"\[${white}\] on \[${violet}\]\" \"\[${blue}\]\")"
PS1+="\n"
PS1+="\[${white}\]\$ \[${reset}\]"
export PS1

PS2="\[${yellow}\]→ \[${reset}\]"
export PS2
