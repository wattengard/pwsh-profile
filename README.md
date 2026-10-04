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
| `bootstrap.ps1` | Dot-sources `config.ps1`, then every `profile.d\*.ps1` in name order |
| `config.ps1` | Default environment variables that toggle features |
| `profile.d/` | Profile fragments, loaded in order (`00_prompt.ps1`, ...) |

## Configuration

`config.ps1` sets defaults as environment variables. A variable already set in the environment wins, so you can override per session (`$env:PROMPT_GIT_MESSAGE = '0'`).

| Variable | Default | Purpose |
| --- | --- | --- |
| `PROMPT_GIT_MESSAGE` | `1` | Show the current commit subject after the git branch (`0` to disable) |
| `PROMPT_GIT_MESSAGE_WIDTH` | `40` | Max characters of the subject before it is cut with `…` |

## Adding a fragment

Drop a `NN_name.ps1` file in `profile.d/`. Lower numbers load first. A fragment that throws produces a warning and the rest still load.

## Current fragments

- `00_prompt.ps1`: two-line prompt modeled on [pure](https://github.com/sindresorhus/pure). Path on the first line, `❯` on the second, red when the last command failed. Shows the git branch and in-progress state (rebase, merge, ...) plus the current commit subject, read straight from `.git` without spawning git on the hot path (reflog, then loose object, then a cached `git log` for packed commits).
