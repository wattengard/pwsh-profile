# pwsh-profile

A highly opinionated PowerShell 7 profile, organized rc.d style. Take what you like; it is built around one person's habits.

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
| `tools.ps1` | Registry of optional external tools (e.g. `eza`); detects them and records their paths |
| `profile.d/` | Profile fragments, loaded in order (`00_prompt.ps1`, ...) |

## Configuration

`config.ps1` sets defaults as environment variables. A variable already set in the environment wins, so you can override per session (`$env:PROMPT_GIT_MESSAGE = '0'`).

| Variable | Default | Purpose |
| --- | --- | --- |
| `PROMPT_GIT_MESSAGE` | `1` | Show the current commit subject after the git branch (`0` to disable) |
| `PROMPT_GIT_MESSAGE_WIDTH` | `40` | Max characters of the subject before it is cut with `…` |

## Optional tools

`tools.ps1` holds a registry of the external programs the profile can use: name, description, project URL and winget package id. Each one is looked up once at startup. The result is `$ProfileTools`, a hashtable of tool name to full path, with `$null` for a missing tool. Fragments gate anything that depends on a tool:

```powershell
if ($ProfileTools.eza) {
    # aliases and functions that use eza
}
```

To support a new tool, add an entry to `$ProfileToolSpecs` in `tools.ps1`.

### Audit

Run `audit` (`Invoke-ProfileAudit`) to see which tools were found. Each missing tool is listed with what it does, an install command and its project page. It reports what the current shell saw at startup, so open a new shell after installing. `audit -PassThru` also returns the results as objects.

## Adding a fragment

Drop a `NN_name.ps1` file in `profile.d/`. Lower numbers load first. A fragment that throws produces a warning and the rest still load.

## Tools used

Every tool is optional. A fragment that depends on one is skipped when it is not installed (see [Optional tools](#optional-tools)).

| Tool | What it does | Used for |
| --- | --- | --- |
| [eza](https://github.com/eza-community/eza) | A modern replacement for `ls` with icons and git awareness | `dir` |
| [bat](https://github.com/sharkdp/bat) | A `cat` clone with syntax highlighting and git integration | `cat`, `type` |
| [yazi](https://github.com/sxyazi/yazi) | A fast terminal file manager | `y`, which changes to yazi's last directory on quit |
| [fzf](https://github.com/junegunn/fzf) | A command-line fuzzy finder | Picking a package in `wgs` |
| [winget](https://github.com/microsoft/winget-cli) | The Windows package manager | `wgs <query>` searches and installs |
| [Git for Windows](https://gitforwindows.org) | Git and a bundled Unix toolset | Its `file.exe` gives yazi mime-type detection |
| [Nerd Fonts](https://www.nerdfonts.com) | Fonts patched with icon glyphs | Prompt branch icon and the icons in eza |
| [Catppuccin](https://catppuccin.com) | A pastel color theme | Mocha theme for bat |
| [pure](https://github.com/sindresorhus/pure) | A minimal two-line zsh prompt | Inspiration for the prompt in `00_prompt.ps1` |

## License

[MIT](LICENSE)
