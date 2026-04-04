#!/usr/bin/env bash
# modules/cloud/aliases.sh — Cloud CLI aliases

dotfiles_section "cloud.aws" && {
    if command -v aws &>/dev/null; then
        alias awsp='aws_profile'
        alias awsr='aws_region'
        alias awsi='aws sts get-caller-identity'
    fi
}

dotfiles_section "cloud.gcp" && {
    if command -v gcloud &>/dev/null; then
        alias gci='gcloud info'
        alias gcl='gcloud config list'
        alias gcp='gcloud config set project'
        alias gcr='gcloud config set compute/region'
    fi
}

dotfiles_section "cloud.azure" && {
    if command -v az &>/dev/null; then
        alias azi='az account show'
        alias azl='az account list --output table'
        alias azs='az account set --subscription'
    fi
}
