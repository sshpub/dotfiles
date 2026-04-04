#!/usr/bin/env bash
# modules/containers/functions.sh — Container functions

dotfiles_section "containers.docker" && {
    # Clean up stopped containers, dangling images, and unused volumes
    docker_cleanup() {
        docker rm $(docker ps -a -q -f status=exited) 2>/dev/null
        docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null
        docker volume rm $(docker volume ls -qf dangling=true) 2>/dev/null
        echo "Docker cleanup complete"
    }

    # Docker Hub login
    docker_login_hub() {
        local username="${1}"
        [[ -z "$username" ]] && read -rp "Docker Hub username: " username
        [[ -z "$username" ]] && { echo "Username required"; return 1; }
        docker login -u "$username"
    }

    # GitHub Container Registry login
    docker_login_ghcr() {
        local username="${1}"
        [[ -z "$username" ]] && read -rp "GitHub username: " username
        [[ -z "$username" ]] && { echo "Username required"; return 1; }
        docker login ghcr.io -u "$username"
    }
}
