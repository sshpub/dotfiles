#!/usr/bin/env bash
# core/functions.sh — Essential functions loaded for all interactive sessions
# Module-specific functions belong in their modules.

# Create directory and cd into it
mkd() {
    mkdir -p "$@" && cd "$_"
}

# Extract any archive format
extract() {
    if [[ ! -f "$1" ]]; then
        echo "extract: '$1' is not a valid file" >&2
        return 1
    fi
    case "$1" in
        *.tar.bz2) tar xjf "$1" ;;
        *.tar.gz)  tar xzf "$1" ;;
        *.tar.xz)  tar xJf "$1" ;;
        *.bz2)     bunzip2 "$1" ;;
        *.rar)     unrar x "$1" ;;
        *.gz)      gunzip "$1" ;;
        *.tar)     tar xf "$1" ;;
        *.tbz2)    tar xjf "$1" ;;
        *.tgz)     tar xzf "$1" ;;
        *.zip)     unzip "$1" ;;
        *.Z)       uncompress "$1" ;;
        *.7z)      7z x "$1" ;;
        *.zst)     unzstd "$1" ;;
        *)         echo "extract: unknown format '$1'" >&2; return 1 ;;
    esac
}

# Start HTTP server from current directory
server() {
    local port="${1:-8000}"
    python3 -m http.server "$port"
}

# Timestamped backup of a file or directory
backup() {
    if [[ ! -e "$1" ]]; then
        echo "backup: '$1' does not exist" >&2
        return 1
    fi
    cp -a "$1" "${1}.backup.$(date +%Y%m%d_%H%M%S)"
}

# File/directory size
fs() {
    if du -b /dev/null > /dev/null 2>&1; then
        local arg=-sbh
    else
        local arg=-sh
    fi
    if [[ -n "$*" ]]; then
        du $arg -- "$@"
    else
        du $arg .[^.]* ./*
    fi
}

# Syntax-highlight JSON (jq or python fallback)
json() {
    if [[ -t 0 ]]; then
        if command -v jq &>/dev/null; then
            jq '.' "$@"
        else
            python3 -m json.tool "$@"
        fi
    else
        if command -v jq &>/dev/null; then
            jq '.'
        else
            python3 -m json.tool
        fi
    fi
}

# Gzip compression ratio
gz() {
    local origsize=$(wc -c < "$1")
    local gzipsize=$(gzip -c "$1" | wc -c)
    local ratio=$(echo "$gzipsize * 100 / $origsize" | bc -l)
    printf "orig: %d bytes\n" "$origsize"
    printf "gzip: %d bytes (%2.2f%%)\n" "$gzipsize" "$ratio"
}

# Create data URL from file
dataurl() {
    local mimeType=$(file -b --mime-type "$1")
    if [[ $mimeType == text/* ]]; then
        mimeType="${mimeType};charset=utf-8"
    fi
    echo "data:${mimeType};base64,$(base64 -w 0 < "$1" 2>/dev/null || openssl base64 -in "$1" | tr -d '\n')"
}

# Create .tar.gz archive
targz() {
    if [[ $# -eq 0 ]] || [[ ! -e "$1" ]]; then
        echo "Usage: targz <file_or_directory>" >&2
        return 1
    fi
    local tmpFile="${@%/}.tar"
    tar -cvf "${tmpFile}" --exclude=".DS_Store" "$@" || return 1
    local cmd="gzip"
    command -v pigz &>/dev/null && cmd="pigz"
    echo "Compressing with ${cmd}..."
    "${cmd}" -v "${tmpFile}" || return 1
    [[ -f "${tmpFile}" ]] && rm "${tmpFile}"
}

# Use git's colored diff when available
if command -v git &>/dev/null; then
    diff() { git diff --no-index --color-words "$@"; }
fi
