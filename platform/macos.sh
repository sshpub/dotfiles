#!/usr/bin/env bash
# platform/macos.sh — macOS-specific core configuration
# Sourced only when DOTFILES_OS=macos

# Homebrew shell environment
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_ENV_HINTS=1
    export HOMEBREW_CASK_OPTS="--appdir=/Applications"
fi

# Case-insensitive globbing (for filesystem)
shopt -s nocaseglob

# Finder: cd to front Finder window
cdf() {
    cd "$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')" || return
}

# Show/hide hidden files in Finder
alias show="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# Open current directory in Finder
alias f='open -a Finder ./'

# Flush DNS cache
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"

# md5sum/sha1sum fallbacks
command -v md5sum > /dev/null || alias md5sum="md5"
command -v sha1sum > /dev/null || alias sha1sum="shasum"
