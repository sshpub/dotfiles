#!/usr/bin/env bash
# modules/cloud/functions.sh — Cloud helper functions

dotfiles_section "cloud.aws" && {
    # Switch AWS profile
    aws_profile() {
        if [[ -z "$1" ]]; then
            echo "Available AWS profiles:"
            aws configure list-profiles 2>/dev/null | while read -r p; do
                if [[ "$AWS_PROFILE" == "$p" ]]; then
                    echo "* $p (current)"
                else
                    echo "  $p"
                fi
            done
            return 0
        fi
        export AWS_PROFILE="$1"
        echo "Switched to AWS profile: $1"
    }

    # Switch AWS region
    aws_region() {
        if [[ -z "$1" ]]; then
            echo "Current: ${AWS_REGION:-<not set>}"
            echo "Usage: aws_region <region>"
            return 0
        fi
        export AWS_REGION="$1"
        export AWS_DEFAULT_REGION="$1"
        echo "Switched to AWS region: $1"
    }

    # ECR login
    docker_login_ecr() {
        local region="${1:-${AWS_REGION:-us-east-1}}"
        local account_id
        account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        [[ -z "$account_id" ]] && { echo "Could not detect AWS account ID"; return 1; }
        local registry="${account_id}.dkr.ecr.${region}.amazonaws.com"
        aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry"
    }
}

dotfiles_section "cloud.gcp" && {
    # GCR login
    docker_login_gcr() {
        command -v gcloud &>/dev/null || { echo "gcloud not installed"; return 1; }
        gcloud auth configure-docker
    }
}
