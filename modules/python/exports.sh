#!/usr/bin/env bash

dotfiles_section "python.core" && {
    export PYTHONIOENCODING='UTF-8'
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONUNBUFFERED=1
}
