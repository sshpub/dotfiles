#!/usr/bin/env bash
# .bashrc — Shim that sources .bash_profile
# Ensures the same environment in login and non-login interactive shells.

if [[ -f "${HOME}/.bash_profile" ]]; then
    . "${HOME}/.bash_profile"
fi
