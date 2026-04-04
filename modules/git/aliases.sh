#!/usr/bin/env bash
# modules/git/aliases.sh — Git shell aliases

dotfiles_section "git.shortcuts" && {
    alias g="git"
    alias gs="git status"
    alias ga="git add"
    alias gc="git commit"
    alias gcm="git commit -m"
    alias gp="git push"
    alias gl="git pull"
    alias gd="git diff"
    alias gb="git branch"
    alias gco="git checkout"
    alias gst="git stash"
    alias gsp="git stash pop"
}

dotfiles_section "git.log" && {
    alias glog="git log --oneline --graph --decorate"
    alias glast="git log -1 HEAD --stat"
    alias gll="git log --pretty=format:'%C(yellow)%h %Cblue%ad %Creset%s%Cgreen [%cn] %Cred%d' --decorate --date=short"
}

dotfiles_section "git.branch" && {
    alias gba="git branch -a"
    alias gbd="git branch -d"
    alias gbD="git branch -D"
    alias gsw="git switch"
    alias gsc="git switch -c"
    alias gm="git merge"
    alias grb="git rebase"
}
