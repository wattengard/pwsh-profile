# CLAUDE.md

A highly opinionated PowerShell 7 profile for Windows, rc.d style. See [README.md](README.md) for layout and usage.

## Working rules

- **Never commit unless explicitly asked.** Make the change, describe it, and wait for the user to say to commit. The same goes for pushing and anything else outward-facing (creating or editing remote repos, releases, issues, pull requests). Approval for one commit does not carry over to the next.
- **This repo is public.** Never commit secrets, tokens, personal data, usernames or machine-specific absolute paths. Use `$PSScriptRoot`, `$env:USERPROFILE`, `$env:ProgramFiles` and the like.
- **Commit identity.** Commits use the author email set in this repo's local git config, which must be a GitHub noreply address. Do not change it, do not override it per commit, and never use a personal email.
- Commit messages follow [Conventional Commits](#commits) and end with the attribution trailer the session provides.

## Structure

- `install.ps1` points `$PROFILE` at `bootstrap.ps1`. It backs up the old profile and overwrites it. Supports `-WhatIf`.
- `bootstrap.ps1` dot-sources `config.ps1`, then `tools.ps1`, then every `profile.d\*.ps1` in name order. Keep it generic; put behavior in fragments.
- `config.ps1` holds feature toggles as environment variables with defaults (existing env values win). Add new toggles there and document them in the README table.
- `tools.ps1` is the registry of optional external tools. It detects them into `$ProfileTools` (name -> path or `$null`).
- `profile.d/NN_name.ps1` are the fragments. The numeric prefix controls load order.
- `profile.d/80_audit.ps1` provides `Invoke-ProfileAudit` (`audit`), which reads the registry to report missing tools and install hints.

## Conventions

- Windows and PowerShell 7+ only (ternary, `$PSStyle`, winget, Git for Windows paths are all fine to assume).
- Fragments are plain `.ps1` files that are dot-sourced, not modules. They share the profile's scope, so define functions (e.g. `prompt`) at the top level.
- Scope: private helpers use `script:` scope, shared state uses an explicit `$global:` (as `$ProfileTools` does), and a fragment removes its own temporary variables (`Remove-Variable`) so nothing stray leaks into the session.
- Fragments must not throw on load; bootstrap warns and continues, but a clean load is the goal.
- No oh-my-posh or starship; the prompt is hand-written.
- **The prompt must stay fast.** It must never spawn a process on the hot path. Read files directly, and where a process is unavoidable, cache the result (keyed on something that changes rarely, such as the HEAD SHA) so it runs once, not per prompt.
  - **The one exception, which proves the rule:** the git working tree state (staged, modified, untracked, conflicts, ahead/behind) cannot be read from files, so the prompt runs a single `git status --porcelain=v2 --branch` per prompt. It is held to strict limits: it is time-capped (`PROMPT_GIT_STATE_TIMEOUT_MS`, default 150 ms; a run that outlives the cap is left running and collected on the next prompt, so the prompt never blocks longer), cached per repo while the index and HEAD are unchanged and the result is under two seconds old, and can be switched off with `PROMPT_GIT_STATE=0`. Measured here: about 35 ms for small repos and under 70 ms at 60k files. Do not add any other process to the prompt path.
- Files are UTF-8.

## Optional tools

Any alias, function or other behavior that depends on an external tool must be guarded with `if ($ProfileTools.<tool>)` so the profile degrades cleanly when the tool is not installed.

Register a tool by adding a spec to `$ProfileToolSpecs` in `tools.ps1`:

| Field | Meaning |
| --- | --- |
| `Name` | Key in `$ProfileTools`; also the command looked up on PATH |
| `Description` | What the tool does |
| `Url` | Project page |
| `Winget` | winget package id, used for the install hint |
| `Hint` | (optional) install hint to show instead of the winget one |
| `Path` | (optional) look here instead of on PATH, for tools bundled with something else |

The audit reads these specs, so keep them accurate.

**Checklist for a new tool integration:**

1. Add the spec to `tools.ps1`.
2. Write `profile.d/50_<tool>.ps1` following the layout below, with the guard.
3. Add a row to the README "Tools used" table, and any toggle to the README config table.
4. Test with the tool present and with it missing (see Testing).

## Feature fragments

Every feature (a single alias or a larger function) gets its own file `profile.d/NN_slug.ps1`, where `slug` is a short lowercase name using underscores (e.g. `50_eza.ps1`).

**Numbering.** The prefix sets load order and groups by kind. Fragments in the same group share a number and load alphabetically within it, so independent features do not need unique numbers.

| Range | Use | Example |
| --- | --- | --- |
| `00-09` | Core shell setup | `00_prompt.ps1` |
| `10-49` | Environment and shell behavior (PSReadLine, env vars, completions) | |
| `50` | External tool integrations, one file per tool | `50_bat`, `50_eza`, `50_winget`, `50_yazi` |
| `80` | Personal functions with no external dependency | `80_audit.ps1` |
| `90-99` | Late overrides, machine-local tweaks | |

**File layout.** In this order:

1. A guard that exits the fragment early if a required tool is missing: `if (-not $ProfileTools.<tool>) { return }`. Fragments are dot-sourced, so `return` only ends that file.
2. Tool-specific environment variables (e.g. `EZA_CONFIG_DIR`), right after the guard.
3. The function, named `Verb-Subject` with an approved verb (`Get-Verb`). Wrappers around an external program use `Invoke-`, e.g. `Invoke-Eza`. It passes `@args` through so callers can add flags. A comment-based help block sits inside the function so `Get-Help` works: `.SYNOPSIS`, `.DESCRIPTION`, and `.NOTES` with `Requires:` and `Aliases:` lines.
4. If an alias shadows a built-in, remove the built-in first: `Remove-Alias <name> -Force -ErrorAction Ignore`.
5. `Set-Alias -Name <short> -Value <Verb-Subject>` to give the function its short name.

A tool with several aliases keeps them all in one file: group all the functions first, then all the `Remove-Alias` / `Set-Alias` lines at the bottom.

Aliases cannot carry arguments in PowerShell, which is why even a one-liner gets a function and the alias points at it.

```powershell
# profile.d/50_eza.ps1
if (-not $ProfileTools.eza) { return }

$env:EZA_CONFIG_DIR = Join-Path $env:USERPROFILE '.config\eza'

function Invoke-Eza {
    <#
    .SYNOPSIS
        eza as a compact long listing with icons.
    .DESCRIPTION
        Long format including hidden files, without user, time or permissions columns,
        with hyperlinks and unquoted names. Extra arguments are passed through to eza.
    .NOTES
        Requires: eza
        Aliases: dir
    #>
    eza -l --icons --no-user --no-time --no-permissions -a --hyperlink --no-quotes @args
}

Remove-Alias dir -Force -ErrorAction Ignore
Set-Alias -Name dir -Value Invoke-Eza
```

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, imperative mood, lowercase summary, no trailing period. Common types: `feat`, `fix`, `docs`, `refactor`, `chore`. Scope is optional, e.g. `feat(prompt): show git branch`. Mark breaking changes with `!` or a `BREAKING CHANGE:` footer.

## Testing

Prefer one-shot, non-nesting runs: `pwsh -NoProfile -Command ". .\bootstrap.ps1; <what to check>"`. Do not start nested `pwsh` sessions. In the user's own shell, open a new session or run `. .\bootstrap.ps1`.

- **Stale PATH.** A long-running session (including the Claude Code shell) does not see tools installed after it started, so detection reports them missing. Refresh PATH from the registry first:
  `$env:Path = [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')`
- **Present and missing.** Check the happy path, then simulate a missing tool (remove its directory from `$env:Path`, or blank its `$ProfileTools` entry) and confirm the fragment is skipped and the profile still loads.
- **Interactive tools** (fzf, yazi and the like) cannot be driven from here. Stub the native executable with a function of the same name to test the surrounding logic, and tell the user plainly which parts were not exercised.
- **Prompt changes.** Time the prompt (`Measure-Command`) cold and cached, and confirm the only process it spawns is the capped `git status`. Test state in a throwaway repo (untracked, modified, staged, ahead/behind, a merge conflict), plus the toggle and the timeout path (`PROMPT_GIT_STATE_TIMEOUT_MS=1`). When capturing prompt output through a tool, glyphs arrive as `?`, so map the icons to labels to tell them apart.
- Use `pwsh -NoProfile` to rule out profile problems when something looks off.
