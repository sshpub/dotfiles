#!/usr/bin/env bash

dotfiles_section "node.npm" && {
    alias ni="npm install"
    alias ns="npm start"
    alias nt="npm test"
    alias nr="npm run"
    alias nb="npm run build"
    alias nd="npm run dev"
}
