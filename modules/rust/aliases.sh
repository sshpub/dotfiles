#!/usr/bin/env bash

dotfiles_section "rust.cargo" && {
    if command -v cargo &>/dev/null; then
        alias cb="cargo build"
        alias cr="cargo run"
        alias ct="cargo test"
        alias cc="cargo check"
        alias cf="cargo fmt"
        alias cl="cargo clippy"
    fi
}
