#!/usr/bin/env bash
# modules/kubernetes/completions.sh — Kubernetes tab completion

dotfiles_section "kubernetes.core" && {
    if command -v kubectl &>/dev/null; then
        eval "$(kubectl completion bash 2>/dev/null)"
        complete -F __start_kubectl k 2>/dev/null
    fi
}

dotfiles_section "kubernetes.helm" && {
    if command -v helm &>/dev/null; then
        eval "$(helm completion bash 2>/dev/null)"
    fi
}
