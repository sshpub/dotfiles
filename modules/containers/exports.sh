#!/usr/bin/env bash
# modules/containers/exports.sh — Container environment variables

dotfiles_section "containers.docker" && {
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
}
