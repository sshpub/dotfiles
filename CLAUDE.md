# CLAUDE.md — sshpub/dotfiles

Modular, cross-platform dotfiles framework. Part of the ssh.pub ecosystem.

## Project Status

Active development tracked via GitHub Issues on `sshpub/dotfiles` (37 issues, 6 milestones).
Full design spec: `docs/superpowers/specs/2026-04-04-dotfiles-overhaul-design.md`

## Branch Rules

- **main is locked** — all changes via PRs only
- Feature branches: `feat/{issue-number}-short-description`
- PR body must reference issue: `Closes #N`

## Architecture

- **core/** — thin foundation: platform detection, loader, PATH, exports, essential aliases/functions, prompt, completions, sync-check
- **modules/** — self-describing feature directories with `module.json`, section guards, per-module CLAUDE.md
- **overrides/** — repo-level overrides (tracked), loaded after modules
- **platform/** — macOS, Linux, WSL core differences
- **profiles/** — example machine profiles + JSON schema for `~/.dotfiles.json`
- **setup/** — bootstrap and installation scripts

## Key Principles

1. **Modules are self-contained** — add a directory, everything is in one place
2. **Section guards** — all module shell blocks use `dotfiles_section()` guards
3. **JSON for config** — never YAML. Use `_comment` fields for documentation
4. **Minimal mode** — AI tools and CI get platform + PATH + exports only (<50ms)
5. **Three-layer overrides** — module defaults → repo overrides → local overrides (~/.dotfiles/local/)
6. **Shell startup < 200ms** interactive, < 50ms minimal

## Working with Issues

```bash
# See what's next
gh issue list --repo sshpub/dotfiles --state open --milestone "Phase 1: Scaffold & Core"

# Check sub-issue progress
gh api repos/sshpub/dotfiles/issues/11/sub_issues --jq '.[] | "#\(.number) [\(.state)] \(.title)"'
```

## Reference Repo

Original dotfiles at `~/code/dotfiles/` (necrogami/dotfiles) — read-only reference for extracting shell configs during module creation. Do not modify.
