#!/usr/bin/env bash

dotfiles_section "security.ssh" && {
    # Generate SSH key
    ssh_keygen() {
        local email="$1" key_type="${2:-ed25519}"
        [[ -z "$email" ]] && { echo "Usage: ssh_keygen <email> [key_type]"; return 1; }
        local key_file="$HOME/.ssh/id_${key_type}"
        ssh-keygen -t "$key_type" -C "$email" -f "$key_file"
    }

    # Add SSH key to agent
    ssh_add() {
        [[ -z "$SSH_AUTH_SOCK" ]] && eval "$(ssh-agent -s)"
        if [[ -n "$1" ]]; then
            ssh-add "$1"
        else
            local keys=($(find ~/.ssh -type f -name 'id_*' ! -name '*.pub' 2>/dev/null))
            [[ ${#keys[@]} -eq 0 ]] && { echo "No SSH keys found"; return 1; }
            ssh-add "${keys[0]}"
        fi
    }

    # Copy SSH public key to clipboard
    ssh_copy() {
        local key="${1:-$(find ~/.ssh -name 'id_*.pub' 2>/dev/null | head -1)}"
        [[ ! -f "$key" ]] && { echo "No public key found"; return 1; }
        if command -v pbcopy &>/dev/null; then
            cat "$key" | pbcopy
        elif command -v xclip &>/dev/null; then
            cat "$key" | xclip -selection clipboard
        elif command -v clip.exe &>/dev/null; then
            cat "$key" | clip.exe
        else
            cat "$key"
            return 0
        fi
        echo "Public key copied to clipboard: $key"
    }

    # List SSH keys
    ssh_list() {
        echo "SSH Keys:"
        for key in ~/.ssh/id_*.pub; do
            [[ -f "$key" ]] || continue
            ssh-keygen -lf "$key" 2>/dev/null
        done
        echo ""
        echo "Loaded in agent:"
        ssh-add -l 2>/dev/null || echo "  (none)"
    }

    # Check SSH permissions
    ssh_check() {
        local issues=0
        [[ -d "$HOME/.ssh" ]] || { echo "~/.ssh doesn't exist"; return 0; }
        local perms
        perms=$(stat -c '%a' "$HOME/.ssh" 2>/dev/null || stat -f '%A' "$HOME/.ssh")
        [[ "$perms" != "700" ]] && { echo "~/.ssh: $perms (should be 700)"; issues=$((issues+1)); }
        for key in ~/.ssh/id_*; do
            [[ -f "$key" && ! "$key" =~ \.pub$ ]] || continue
            perms=$(stat -c '%a' "$key" 2>/dev/null || stat -f '%A' "$key")
            [[ "$perms" != "600" ]] && { echo "$(basename $key): $perms (should be 600)"; issues=$((issues+1)); }
        done
        [[ $issues -eq 0 ]] && echo "All SSH permissions OK" || echo "$issues issue(s) found"
    }

    # Fix SSH permissions
    ssh_fix() {
        [[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh"
        for key in ~/.ssh/id_*; do
            [[ -f "$key" && ! "$key" =~ \.pub$ ]] && chmod 600 "$key"
            [[ -f "$key" && "$key" =~ \.pub$ ]] && chmod 644 "$key"
        done
        [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
        [[ -f "$HOME/.ssh/authorized_keys" ]] && chmod 600 "$HOME/.ssh/authorized_keys"
        echo "SSH permissions fixed"
    }

    # Password generator
    genpass() {
        local length="${1:-16}"
        if command -v openssl &>/dev/null; then
            openssl rand -base64 "$length" | tr -d '\n' | head -c "$length"
        else
            < /dev/urandom tr -dc A-Za-z0-9 | head -c"$length"
        fi
        echo
    }
}

dotfiles_section "security.gpg" && {
    # List GPG keys
    gpg_list() {
        command -v gpg &>/dev/null || { echo "GPG not installed"; return 1; }
        gpg --list-secret-keys --keyid-format=long
    }

    # Export GPG public key
    gpg_export() {
        [[ -z "$1" ]] && { echo "Usage: gpg_export <email>"; return 1; }
        gpg --armor --export "$1"
    }

    # Configure git to use GPG key
    gpg_git() {
        [[ -z "$1" ]] && { echo "Usage: gpg_git <email>"; return 1; }
        local key_id
        key_id=$(gpg --list-secret-keys --keyid-format=long "$1" 2>/dev/null | grep sec | awk '{print $2}' | cut -d'/' -f2)
        [[ -z "$key_id" ]] && { echo "No GPG key found for $1"; return 1; }
        git config --global user.signingkey "$key_id"
        git config --global commit.gpgsign true
        echo "Git configured to sign with key: $key_id"
    }
}
