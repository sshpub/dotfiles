#!/usr/bin/env bash

dotfiles_section "terraform.core" && {
    if command -v terraform &>/dev/null; then
        alias tf="terraform"
        alias tfi="terraform init"
        alias tfp="terraform plan"
        alias tfa="terraform apply"
        alias tfd="terraform destroy"
        alias tfv="terraform validate"
        alias tff="terraform fmt"
        alias tfs="terraform state"
    elif command -v tofu &>/dev/null; then
        alias tf="tofu"
        alias tfi="tofu init"
        alias tfp="tofu plan"
        alias tfa="tofu apply"
        alias tfd="tofu destroy"
        alias tfv="tofu validate"
        alias tff="tofu fmt"
        alias tfs="tofu state"
    fi
}
