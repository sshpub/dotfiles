#!/usr/bin/env bash

dotfiles_section "node.npm" && {
    export NODE_REPL_HISTORY="$HOME/.node_history"
    export NODE_REPL_HISTORY_SIZE='32768'
    export NODE_REPL_MODE='sloppy'
}
