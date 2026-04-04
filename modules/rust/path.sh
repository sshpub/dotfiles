#!/usr/bin/env bash

dotfiles_section "rust.cargo" && {
    add_to_path "${HOME}/.cargo/bin"
}
