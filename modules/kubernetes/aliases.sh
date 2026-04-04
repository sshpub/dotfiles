#!/usr/bin/env bash
# modules/kubernetes/aliases.sh — Kubernetes aliases

dotfiles_section "kubernetes.core" && {
    if command -v kubectl &>/dev/null; then
        alias k="kubectl"
        alias kgp="kubectl get pods"
        alias kgs="kubectl get services"
        alias kgd="kubectl get deployments"
        alias kgn="kubectl get nodes"
        alias kaf="kubectl apply -f"
        alias kdel="kubectl delete"
        alias klog="kubectl logs -f"
        alias kexec="kubectl exec -it"
        alias kdesc="kubectl describe"
    fi
}

dotfiles_section "kubernetes.helm" && {
    if command -v helm &>/dev/null; then
        alias h="helm"
        alias hi="helm install"
        alias hu="helm upgrade"
        alias hl="helm list"
        alias hs="helm search repo"
        alias hr="helm repo"
    fi
}

dotfiles_section "kubernetes.ctx" && {
    if command -v kubectx &>/dev/null; then
        alias kctx="kubectx"
        alias kns="kubens"
    elif command -v kubectl &>/dev/null; then
        alias kctx="kubectl config use-context"
        alias kns="kubectl config set-context --current --namespace"
    fi
}
