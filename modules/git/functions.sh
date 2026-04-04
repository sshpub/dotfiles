#!/usr/bin/env bash
# modules/git/functions.sh — Git helper functions

dotfiles_section "git.shortcuts" && {
    # Current branch name
    git_current_branch() {
        git symbolic-ref --short HEAD 2>/dev/null
    }

    # Main branch name (detects main vs master)
    git_main_branch() {
        git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5 || echo "main"
    }
}
