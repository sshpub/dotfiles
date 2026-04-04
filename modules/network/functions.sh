#!/usr/bin/env bash

dotfiles_section "network.ip" && {
    # Test internet connectivity
    testnet() {
        echo "Testing connectivity..."
        ping -c 1 8.8.8.8 &>/dev/null && echo "Internet: reachable" || echo "Internet: unreachable"
        ping -c 1 google.com &>/dev/null && echo "DNS: working" || echo "DNS: failed"
    }

    # Quick port check
    port() {
        [[ -z "$1" ]] && { echo "Usage: port <number>"; return 1; }
        if is_macos; then
            lsof -i ":$1"
        else
            ss -tlnp | grep ":$1"
        fi
    }
}

dotfiles_section "network.http" && {
    # Show SSL certificate names for a domain
    getcertnames() {
        [[ -z "$1" ]] && { echo "Usage: getcertnames <domain>"; return 1; }
        echo "Testing $1..."
        local tmp
        tmp=$(echo -e "GET / HTTP/1.0\nEOT" | openssl s_client -connect "$1:443" -servername "$1" 2>&1)
        if [[ "$tmp" == *"-----BEGIN CERTIFICATE-----"* ]]; then
            echo "$tmp" | openssl x509 -text -certopt "no_aux,no_header,no_issuer,no_pubkey,no_serial,no_sigdump,no_signame,no_validity,no_version" | grep -A1 "Subject Alternative Name:" | tail -1 | tr ',' '\n' | sed 's/DNS://g; s/ //g'
        else
            echo "Certificate not found"
            return 1
        fi
    }

    # DNS dig shortcut
    digga() {
        dig +nocmd "$1" any +multiline +noall +answer
    }
}
