#!/usr/bin/env bash
# modules/containers/aliases.sh — Container aliases

dotfiles_section "containers.docker" && {
    if command -v docker &>/dev/null; then
        alias d="docker"
        alias dps="docker ps"
        alias dpsa="docker ps -a"
        alias di="docker images"
        alias dex="docker exec -it"
        alias dlog="docker logs -f"
        alias dstop="docker stop"
        alias drm="docker rm"
        alias drmi="docker rmi"
        alias dprune="docker system prune -a"
    fi
}

dotfiles_section "containers.compose" && {
    if command -v docker &>/dev/null; then
        alias dc="docker compose"
        alias dcup="docker compose up -d"
        alias dcdown="docker compose down"
        alias dclogs="docker compose logs -f"
        alias dcps="docker compose ps"
        alias dcrestart="docker compose restart"
    fi
}
