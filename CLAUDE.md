# CLAUDE.md

Personal PowerShell 7 profile, rc.d style. See [README.md](README.md) for layout.

## Structure

- `install.ps1` points `$PROFILE` at `bootstrap.ps1`. It backs up the old profile and overwrites it. Supports `-WhatIf`.
- `bootstrap.ps1` dot-sources `config.ps1`, then every `profile.d\*.ps1` in name order. Keep it generic; put behavior in fragments.
- `config.ps1` holds feature toggles as environment variables with defaults (existing env values win). Add new toggles there and document them in the README table.
- `tools.ps1` detects optional external tools into `$ProfileTools` (name -> path or `$null`). Any alias, function or other behavior that depends on an external tool must be guarded with `if ($ProfileTools.<tool>)` so the profile degrades cleanly when it is not installed. Register new tools by adding a spec (Name, Description, Url, Winget id, optional Hint/Path) to `$ProfileToolSpecs` in `tools.ps1`; `Invoke-ProfileAudit` (`profile.d/80_audit.ps1`) reads that registry to report missing tools and install hints, so keep the specs accurate.
- `profile.d/NN_name.ps1` are the fragments. Numeric prefix controls load order.

## Conventions

- Target PowerShell 7+ only (ternary, `$PSStyle`, etc. are fine).
- Fragments are plain `.ps1` files that are dot-sourced, not modules. They share the profile's scope, so define functions (e.g. `prompt`) at the top level and avoid leaking stray variables.
- Fragments must not throw on load; bootstrap warns and continues, but a clean load is the goal.
- No oh-my-posh or starship; the prompt is hand-written.
- Files are UTF-8; keep the repo free of machine-specific absolute paths (use `$PSScriptRoot`).

## Feature fragments

Every feature (a single alias or a larger function) gets its own file `profile.d/NN_slug.ps1`, where `slug` is a short lowercase name using underscores (e.g. `50_eza.ps1`).

**Numbering.** The prefix sets load order and groups by kind. Fragments in the same group share a number and load alphabetically within it, so independent features do not need unique numbers.

| Range | Use |
| --- | --- |
| `00-09` | Core shell setup (prompt) |
| `10-49` | Environment and shell behavior (PSReadLine, env vars, completions) |
| `50` | External tool integrations, one file per tool (eza, ...) |
| `80` | Personal functions with no external dependency |
| `90-99` | Late overrides, machine-local tweaks |

**File layout.** In this order:

1. A comment-based help block describing the feature (`.SYNOPSIS`, `.DESCRIPTION`, and `.NOTES` with `Requires:` and `Aliases:` lines). It sits inside the function so `Get-Help` works.
2. A guard that exits the fragment early if a required tool is missing: `if (-not $ProfileTools.<tool>) { return }`. Fragments are dot-sourced, so `return` only ends that file.
3. The function, named `Verb-Subject` with an approved verb (`Get-Verb`). Wrappers around an external program use `Invoke-`, e.g. `Invoke-Eza`. It passes `@args` through so callers can add flags.
4. If the alias shadows a built-in, remove the built-in first: `Remove-Alias <name> -Force -ErrorAction Ignore`.
5. `Set-Alias -Name <short> -Value <Verb-Subject>` to give the function its short name.

A tool with several aliases keeps them all in one file: group all the functions first, then all the `Remove-Alias` / `Set-Alias` lines at the bottom. Tool-specific environment variables (e.g. `EZA_CONFIG_DIR`) also go in that file, right after the guard.

Aliases cannot carry arguments in PowerShell, which is why even a one-liner gets a function and the alias points at it.

```powershell
# profile.d/50_eza.ps1
if (-not $ProfileTools.eza) { return }

function Invoke-Eza {
    <#
    .SYNOPSIS
        eza with preferred defaults.
    .DESCRIPTION
        Lists directory contents with eza instead of Get-ChildItem.
    .NOTES
        Requires: eza
        Aliases: dir
    #>
    eza --group-directories-first @args
}

Remove-Alias dir -Force -ErrorAction Ignore
Set-Alias -Name dir -Value Invoke-Eza
```

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, imperative mood, lowercase summary, no trailing period. Common types: `feat`, `fix`, `docs`, `refactor`, `chore`. Scope is optional, e.g. `feat(prompt): show git branch`. Mark breaking changes with `!` or a `BREAKING CHANGE:` footer.

## Testing

Open a new `pwsh` session, or run `. .\bootstrap.ps1` in the current one. Use `pwsh -NoProfile` to rule out profile problems.
