# CLAUDE.md

Personal PowerShell 7 profile, rc.d style. See [README.md](README.md) for layout.

## Structure

- `install.ps1` points `$PROFILE` at `bootstrap.ps1`. It backs up the old profile and overwrites it. Supports `-WhatIf`.
- `bootstrap.ps1` dot-sources every `profile.d\*.ps1` in name order. Keep it generic; put behavior in fragments.
- `profile.d/NN_name.ps1` are the fragments. Numeric prefix controls load order.

## Conventions

- Target PowerShell 7+ only (ternary, `$PSStyle`, etc. are fine).
- Fragments are plain `.ps1` files that are dot-sourced, not modules. They share the profile's scope, so define functions (e.g. `prompt`) at the top level and avoid leaking stray variables.
- Fragments must not throw on load; bootstrap warns and continues, but a clean load is the goal.
- No oh-my-posh or starship; the prompt is hand-written.
- Files are UTF-8; keep the repo free of machine-specific absolute paths (use `$PSScriptRoot`).

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, imperative mood, lowercase summary, no trailing period. Common types: `feat`, `fix`, `docs`, `refactor`, `chore`. Scope is optional, e.g. `feat(prompt): show git branch`. Mark breaking changes with `!` or a `BREAKING CHANGE:` footer.

## Testing

Open a new `pwsh` session, or run `. .\bootstrap.ps1` in the current one. Use `pwsh -NoProfile` to rule out profile problems.
