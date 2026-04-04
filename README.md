# sshpub/dotfiles

Modular, cross-platform dotfiles framework. Fork it, make it yours.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/sshpub/dotfiles/main/install.sh | bash
```

## Structure

```
core/       — thin foundation: platform detection, loader, PATH, exports, prompt
modules/    — self-describing feature directories with module.json
overrides/  — repo-level overrides (tracked), loaded after modules
platform/   — macOS, Linux, WSL core differences
profiles/   — example machine profiles + JSON schema
setup/      — bootstrap and installation scripts
```

## Part of [ssh.pub](https://ssh.pub)

- **sshpub/dotfiles** — the forkable framework
- **sshpub/dotfiles-cli** — Go CLI for setup, module management, and sync
