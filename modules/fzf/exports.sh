#!/usr/bin/env bash

dotfiles_section "fzf.core" && {
    if command -v fzf &>/dev/null; then
        export FZF_DEFAULT_OPTS='
            --height 40%
            --layout=reverse
            --border
            --inline-info
            --color=dark
            --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f
            --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7
        '

        # Use fd or ripgrep for better performance
        if command -v fd &>/dev/null; then
            export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
            export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        elif command -v fdfind &>/dev/null; then
            export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
            export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        elif command -v rg &>/dev/null; then
            export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
            export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        fi
    fi
}

dotfiles_section "fzf.keybindings" && {
    # Source fzf keybindings and completion if available
    if [[ -f "${HOMEBREW_PREFIX:-}/opt/fzf/shell/key-bindings.bash" ]]; then
        . "${HOMEBREW_PREFIX}/opt/fzf/shell/key-bindings.bash"
        . "${HOMEBREW_PREFIX}/opt/fzf/shell/completion.bash"
    elif [[ -f "/usr/share/doc/fzf/examples/key-bindings.bash" ]]; then
        . "/usr/share/doc/fzf/examples/key-bindings.bash"
        [[ -f "/usr/share/bash-completion/completions/fzf" ]] && . "/usr/share/bash-completion/completions/fzf"
    fi
}
