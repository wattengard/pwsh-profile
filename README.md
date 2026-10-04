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
| `bootstrap.ps1` | Dot-sources every `profile.d\*.ps1` in name order |
| `profile.d/` | Profile fragments, loaded in order (`00_prompt.ps1`, ...) |

## Adding a fragment

Drop a `NN_name.ps1` file in `profile.d/`. Lower numbers load first. A fragment that throws produces a warning and the rest still load.

## Current fragments

- `00_prompt.ps1`: two-line prompt modeled on [pure](https://github.com/sindresorhus/pure). Path on the first line, `❯` on the second, red when the last command failed.
