# pwsh-profile

Personal PowerShell 7 profile, organized rc.d style.

## Install

```powershell
pwsh -File .\install.ps1
```

This backs up any existing `$PROFILE` to `$PROFILE.bak`, then overwrites it with a single line that dot-sources `bootstrap.ps1` from this repo. Use `-WhatIf` to preview.

## Layout

| Path | Purpose |
| --- | --- |
| `install.ps1` | Points `$PROFILE` at `bootstrap.ps1` |
| `bootstrap.ps1` | Dot-sources `config.ps1`, `tools.ps1`, then every `profile.d\*.ps1` in name order |
| `config.ps1` | Default environment variables that toggle features |
| `tools.ps1` | Detects optional external tools (e.g. `eza`) and records their paths |
| `profile.d/` | Profile fragments, loaded in order (`00_prompt.ps1`, ...) |

## Configuration

`config.ps1` sets defaults as environment variables. A variable already set in the environment wins, so you can override per session (`$env:PROMPT_GIT_MESSAGE = '0'`).

| Variable | Default | Purpose |
| --- | --- | --- |
| `PROMPT_GIT_MESSAGE` | `1` | Show the current commit subject after the git branch (`0` to disable) |
| `PROMPT_GIT_MESSAGE_WIDTH` | `40` | Max characters of the subject before it is cut with `…` |

## Optional tools

`tools.ps1` lists the external programs the profile can use and looks each one up on PATH once at startup. The result is `$ProfileTools`, a hashtable of tool name to full path, with `$null` for a missing tool. Fragments gate anything that depends on a tool:

```powershell
if ($ProfileTools.eza) {
    # aliases and functions that use eza
}
```

To support a new tool, add its name to the list in `tools.ps1`.

## Adding a fragment

Drop a `NN_name.ps1` file in `profile.d/`. Lower numbers load first. A fragment that throws produces a warning and the rest still load.

## Current fragments

- `00_prompt.ps1`: two-line prompt modeled on [pure](https://github.com/sindresorhus/pure). Path on the first line, `❯` on the second, red when the last command failed. Shows the git branch and in-progress state (rebase, merge, ...) plus the current commit subject, read straight from `.git` without spawning git on the hot path (reflog, then loose object, then a cached `git log` for packed commits).
- `50_bat.ps1`: `cat` and `type` run bat (`Invoke-Bat`) with line numbers, git change marks, a filename header, no pager and the Catppuccin Mocha theme. Use `Get-Content` when you need objects or `-Raw`/`-Tail`.
- `50_eza.ps1`: `dir` runs eza with a compact long listing (`Invoke-Eza`).
- `50_winget.ps1`: `wgs <query>` searches winget, picks a package in fzf, and installs it (`Search-WingetPackage`). Ctrl-P previews the highlighted package on demand. Needs winget and fzf.
- `50_yazi.ps1`: `y` runs yazi (`Invoke-Yazi`) and changes to its last directory on quit (`q`; `Q` quits without changing). Adapted from the shell wrapper in the yazi docs.
