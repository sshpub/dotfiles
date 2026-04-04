#!/usr/bin/env bash

dotfiles_section "network.ip" && {
    alias myip="dig +short myip.opendns.com @resolver1.opendns.com"
    alias ipinfo="curl -s ipinfo.io"
    alias weather="curl -s wttr.in | head -n 17"
}
