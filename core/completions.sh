#!/usr/bin/env bash
# core/completions.sh — Base completion setup
# Module-specific completions belong in their modules.

# Source system bash-completion if available
# Platform-aware: Homebrew on macOS, system paths on Linux

if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
    # Homebrew bash-completion@2
    . "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
elif [[ -r "/usr/share/bash-completion/bash_completion" ]]; then
    # Linux system bash-completion
    . "/usr/share/bash-completion/bash_completion"
elif [[ -r "/etc/bash_completion" ]]; then
    # Older Linux systems
    . "/etc/bash_completion"
fi

# SSH hostname completion from ~/.ssh/config
if [[ -r "$HOME/.ssh/config" ]]; then
    _dotfiles_ssh_hosts() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local hosts
        hosts=$(awk '/^Host / && !/\*/ {print $2}' "$HOME/.ssh/config")
        COMPREPLY=($(compgen -W "$hosts" -- "$cur"))
    }
    complete -F _dotfiles_ssh_hosts ssh scp sftp
fi
