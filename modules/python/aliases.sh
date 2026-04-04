#!/usr/bin/env bash

dotfiles_section "python.core" && {
    alias py="python3"
    alias pip="pip3"
}

dotfiles_section "python.venv" && {
    alias venv="python3 -m venv"
    alias activate="source venv/bin/activate 2>/dev/null || source .venv/bin/activate"
}
