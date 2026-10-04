# CLAUDE.md

A highly opinionated PowerShell 7 profile for Windows, rc.d style. See [README.md](README.md) for layout and usage.

## Working rules

- **Never commit unless explicitly asked.** Make the change, describe it, and wait for the user to say to commit. The same goes for pushing and anything else outward-facing (creating or editing remote repos, releases, issues, pull requests). Approval for one commit does not carry over to the next.
- **Ask before installing software or changing global settings.** That covers `winget install`, `git config --global`, the registry, machine or user PATH, and anything else outside this repo and the session's scratch space. Say what and why, and wait for a yes. Repo-local changes are fine.
- **This repo is public.** Never commit secrets, tokens, personal data, usernames or machine-specific absolute paths. Use `$PSScriptRoot`, `$env:USERPROFILE`, `$env:ProgramFiles` and the like.
- **Commit identity.** Commits use the author email set in this repo's local git config, which must be a GitHub noreply address. Do not change it, do not override it per commit, and never use a personal email.
- Commit messages follow [Conventional Commits](#commits) and end with the attribution trailer the session provides.
- **Review this file after each commit.** After a commit (other than one that only touches CLAUDE.md), reread this file against what the work just changed or taught: statements that are now stale, a new convention, a lesson learned the hard way, a rule that turned out wrong. If something is new or needs adjusting, tell the user and propose the change, or make it as an uncommitted edit. Do not commit it without being asked, and do not change this file silently. If nothing needs changing, there is nothing to report.

## Structure

- `install.ps1` points `$PROFILE` at `bootstrap.ps1`. It backs up the old profile and overwrites it. Supports `-WhatIf`.
- `bootstrap.ps1` dot-sources `config.ps1`, then `tools.ps1`, then every `profile.d\*.ps1` in name order. Keep it generic; put behavior in fragments.
- `config.ps1` holds feature toggles as environment variables with defaults. A value the user set wins; a default it applied earlier is refreshed when the profile is reloaded (it tracks what it applied in `$global:ProfileConfigApplied`). Add new toggles there and document them in the README table.
- `tools.ps1` is the registry of optional external tools. It detects them into `$ProfileTools` (name -> path or `$null`).
- `profile.d/NN_name.ps1` are the fragments. The numeric prefix controls load order.
- `profile.d/80_audit.ps1` provides `Invoke-ProfileAudit` (`audit`), which reads the registry to report missing tools and install hints.

## Conventions

- Windows and PowerShell 7+ only (ternary, `$PSStyle`, winget, Git for Windows paths are all fine to assume).
- Fragments are plain `.ps1` files that are dot-sourced, not modules. They share the profile's scope, so define functions (e.g. `prompt`) at the top level.
- Scope: private helpers use `script:` scope, shared state uses an explicit `$global:` (as `$ProfileTools` does), and a fragment removes its own temporary variables (`Remove-Variable`) so nothing stray leaks into the session.
- Fragments must not throw on load; bootstrap warns and continues, but a clean load is the goal.
- **Fragments must be safe to load twice.** `. $PROFILE` re-runs everything in the same session, so anything that registers a hook or chains onto existing state must not stack on itself. Capture the original once (see the location-changed hook in `50_zoxide.ps1`).
- **Startup cost matters.** Every fragment runs on each shell start. Avoid process spawns and `Get-Command` at load (a command it cannot find costs about 85 ms), prefer direct file checks, and time a fragment with `Measure-Command { . .\profile.d\<file> }` before adding it. Tool detection is about 40 ms for the whole registry, so stay in that league.
- **Glyphs.** Terminal text (the prompt, fzf lists) may use Nerd Font glyphs. The terminal tab title uses the UI font, so it must stick to plain Unicode (`✓ ✎ ✕ ↑ ↓`).
- No oh-my-posh or starship; the prompt is hand-written.
- Files are UTF-8.

## Prompt

`profile.d/00_prompt.ps1` owns the prompt and the terminal tab title, so both share the git info it has already read.

- **Never wrap or replace `prompt` from another fragment or a tool's init script.** The wrapper's first statement overwrites `$?`, which the prompt reads first to color the caret red after a failed command. zoxide's default PowerShell hook does exactly this, which is why it is loaded with `--hook none`. Use `LocationChangedAction` or similar instead.
- **The prompt must stay fast.** It must never spawn a process on the hot path. Read files directly, and where a process is unavoidable, cache the result (keyed on something that changes rarely, such as the HEAD SHA) so it runs once, not per prompt.
  - **The one exception, which proves the rule:** the git working tree state (staged, modified, untracked, conflicts, ahead/behind) cannot be read from files, so the prompt runs a single `git status --porcelain=v2 --branch` per prompt. It is held to strict limits: it is time-capped (`PROMPT_GIT_STATE_TIMEOUT_MS`, default 150 ms; a run that outlives the cap is left running and collected on the next prompt, so the prompt never blocks longer), cached per repo while the index and HEAD are unchanged and the result is under two seconds old, and can be switched off with `PROMPT_GIT_STATE=0`. Measured here: about 35 ms for small repos and under 70 ms at 60k files. Do not add any other process to the prompt path.
- **Right-aligned commit subject.** It is positioned with a cursor-column escape, so only the subject is measured. It keeps the last column free so terminals do not wrap, leaves a 2-column gap from the left part, shrinks to fit, is left out when under 12 columns would fit, and falls back to inline when the terminal width cannot be read.
- **Tab title.** Set on every prompt (programs like yazi leave their own behind): the prompt's path outside a repo, `repo (branch state)` inside one.

## Optional tools

Any alias, function or other behavior that depends on an external tool must be guarded with `if ($ProfileTools.<tool>)` so the profile degrades cleanly when the tool is not installed. A fragment that needs several tools guards on all of them (`$ProfileTools.git -and $ProfileTools.fzf`).

Register a tool by adding a spec to `$ProfileToolSpecs` in `tools.ps1`:

| Field | Meaning |
| --- | --- |
| `Name` | Key in `$ProfileTools`; also the command looked up on PATH as `<name>.exe` or `<name>.cmd` |
| `Description` | What the tool does |
| `Url` | Project page |
| `Winget` | winget package id, used for the install hint |
| `Hint` | (optional) install hint to show instead of the winget one |
| `Path` | (optional) look here instead of on PATH, for tools bundled with something else or shipped with another extension (`.bat`, `.com`) |

Detection scans PATH for those two extensions, first match wins like the shell. There is deliberately no `Get-Command` fallback: it takes about 85 ms for each tool it cannot find, so a tool with an unusual extension is reported missing until its spec has a `Path`. The audit reads these specs, so keep them accurate.

**Checklist for a new tool integration:**

1. Add the spec to `tools.ps1`.
2. Write `profile.d/50_<tool>.ps1` following the layout below, with the guard.
3. Add a row to the README "Tools used" table, any toggle to the README config table, and any key binding to the README "Key bindings" table.
4. Test with the tool present and with it missing (see Testing).

## Feature fragments

Every feature (a single alias or a larger function) gets its own file `profile.d/NN_slug.ps1`, where `slug` is a short lowercase name using underscores (e.g. `50_eza.ps1`).

**Numbering.** The prefix sets load order and groups by kind. Fragments in the same group share a number and load alphabetically within it, so independent features do not need unique numbers.

| Range | Use | Example |
| --- | --- | --- |
| `00-09` | Core shell setup | `00_prompt.ps1` |
| `10-49` | Environment and shell behavior (PSReadLine, env vars, completions) | `10_psreadline.ps1` |
| `50` | External tool integrations, one file per tool | `50_bat`, `50_eza`, `50_fzf`, `50_git`, `50_winget`, `50_yazi`, `50_zoxide` |
| `80` | Personal functions with no external dependency | `80_audit.ps1` |
| `90-99` | Late overrides, machine-local tweaks | |

**File layout.** In this order:

1. A guard that exits the fragment early if a required tool is missing: `if (-not $ProfileTools.<tool>) { return }`. Fragments are dot-sourced, so `return` only ends that file.
2. Tool-specific environment variables (e.g. `EZA_CONFIG_DIR`), right after the guard.
3. The function, named `Verb-Subject` with an approved verb (`Get-Verb`). Wrappers around an external program use `Invoke-`, e.g. `Invoke-Eza`. It passes `@args` through so callers can add flags. A comment-based help block sits inside the function so `Get-Help` works: `.SYNOPSIS`, `.DESCRIPTION`, and `.NOTES` with `Requires:` and `Aliases:` (or `Key:`) lines.
4. If an alias shadows a built-in, remove the built-in first: `Remove-Alias <name> -Force -ErrorAction Ignore`. The exception is a tool whose own init script replaces the alias with `Set-Alias -Force` (zoxide's `cd`).
5. `Set-Alias -Name <short> -Value <Verb-Subject>` to give the function its short name.

A tool with several aliases keeps them all in one file: group all the functions first, then all the `Remove-Alias` / `Set-Alias` lines at the bottom.

Aliases cannot carry arguments in PowerShell, which is why even a one-liner gets a function and the alias points at it.

**Key-binding fragments.** Anything that has to put text on the command line (the Ctrl+R history picker, the Ctrl+G branch picker) is a PSReadLine key handler, not a typed command: a command runs after Enter, when the line is already gone, so only a handler can edit it. The pattern is a `Verb-Subject` function that returns the text, plus `Set-PSReadLineKeyHandler` that calls it, runs `InvokePrompt()` to redraw after fzf, and inserts the result without running it. Pick a chord that is unbound by default (check with `Get-PSReadLineKeyHandler -Bound`). When fzf rows need a hidden field, prefix each row with an index and a tab and use `--delimiter '\t' --with-nth`, and return only the ASCII index so non-ASCII and multi-line text come back intact.

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

Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, imperative mood, lowercase summary, no trailing period. Common types: `feat`, `fix`, `docs`, `refactor`, `perf`, `chore`. Scope is optional, e.g. `feat(prompt): show git branch`. Mark breaking changes with `!` or a `BREAKING CHANGE:` footer.

Keep commits focused. When one file holds changes that belong in two commits, interactive `git add -p` is not available here: build the first commit's version of the file (for example from `git show HEAD:<file>` plus only that change), commit it, then restore the full version and commit again, and check the working files match the intended end state.

## Testing

Prefer one-shot, non-nesting runs: `pwsh -NoProfile -Command ". .\bootstrap.ps1; <what to check>"`. Do not start nested `pwsh` sessions. In the user's own shell, open a new session or run `. .\bootstrap.ps1`.

- **Stale PATH.** A long-running session (including the Claude Code shell) does not see tools installed after it started, so detection reports them missing. Refresh PATH from the registry first:
  `$env:Path = [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')`
- **Present and missing.** Check the happy path, then simulate a missing tool (remove its directory from `$env:Path`, or blank its `$ProfileTools` entry) and confirm the fragment is skipped and the profile still loads.
- **Load twice.** Dot-source a fragment more than once and confirm nothing stacks or breaks (hooks, aliases, state).
- **Isolate side effects.** Point tools at scratch locations so tests never touch the user's real data (for example `_ZO_DATA_DIR` for zoxide's database), and remove throwaway repos and folders afterwards. zoxide excludes TEMP, so test directories it should learn go elsewhere, and a repo path that is long enough leaves no room for the right-aligned commit subject, so use short paths for prompt layout tests.
- **Interactive tools** (fzf, yazi and the like) cannot be driven from here. Stub the native executable with a function or a wrapper that adds `--filter` to test the surrounding logic, and tell the user plainly which parts were not exercised.
- **PSReadLine and key bindings.** Fragments that call PSReadLine options (predictions, colors) throw when the console is redirected, so they start with `if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return }`. That also means they do nothing in this shell: test them by removing the guard in a copy, proxying `Set-PSReadLineOption` to catch binding errors, and keeping the logic in testable functions (e.g. `Select-HistoryWithFzf -History ...`). Key presses cannot be simulated, so say what the user still has to try by hand.
- **Prompt changes.** Time the prompt (`Measure-Command`) cold and cached, and confirm the only process it spawns is the capped `git status`. Test state in a throwaway repo (untracked, modified, staged, ahead/behind, a merge conflict), plus the toggle and the timeout path (`PROMPT_GIT_STATE_TIMEOUT_MS=1`). For layout, override `Get-PromptWidth` (a `script:` function) for a deterministic width and render the line through a small model of the terminal. When capturing prompt output through a tool, glyphs arrive as `?`, so map the icons to labels to tell them apart.
- Use `pwsh -NoProfile` to rule out profile problems when something looks off.
