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
| `config.ps1` | Every setting with its default, type and allowed values; also applies your local overrides |
| `config.local.ps1` | Your own overrides. Not in the repo (git ignores it), so `git pull` never touches it. Copy `config.local.ps1.example` to start |
| `tools.ps1` | Registry of optional external tools (e.g. `eza`); detects them and records their paths |
| `profile.d/` | Profile fragments, loaded in order (`00_prompt.ps1`, ...) |

## Configuration

Settings are environment variables with defaults, defined in `config.ps1`. Do not edit that file to change your own settings, because pulling updates would overwrite them. Put overrides in `config.local.ps1` instead:

```powershell
Copy-Item config.local.ps1.example config.local.ps1
```

Keep only the lines you want, one per setting, in the form `$env:NAME = 'value'`:

```powershell
$env:PROFILE_ICONS = 'plain'
$env:PROMPT_GIT_MESSAGE_WIDTH = '100'
```

`config.local.ps1` is applied on every load, so editing or removing a line and reloading the profile (`. $PROFILE`) takes effect, and a new default from a `git pull` reaches everything you have not overridden. Precedence, highest first: `config.local.ps1`, then a value in the environment when the shell started, then the default. A value typed into a running session (`$env:PROMPT_GIT_MESSAGE = '0'`) wins until you reload. A broken `config.local.ps1` produces a warning and the defaults still apply.

| Variable | Default | Purpose |
| --- | --- | --- |
| `PROMPT_GIT_MESSAGE` | `1` | Show the current commit subject, right-aligned on the first prompt line (`0` to disable) |
| `PROMPT_GIT_MESSAGE_WIDTH` | `72` | Max characters of the subject before it is cut with `…`. It is also cut to fit next to the path and branch, and left out when fewer than 12 characters would fit |
| `PROMPT_GIT_STATE` | `1` | Show working tree state after the branch: staged, modified, untracked, conflicts, ahead/behind (`0` to disable) |
| `PROMPT_GIT_STATE_TIMEOUT_MS` | `150` | How long the prompt waits for `git status` before showing the last known state |
| `PROFILE_ICONS` | `nerd` | Icon style: `nerd` uses Nerd Font glyphs in the prompt, `dir` (eza) and the `Ctrl+G` branch picker; `plain` uses ASCII and standard arrows, for terminals whose font is not a Nerd Font. It applies immediately; only the `cdi` preview reads it at load. yazi draws its own icons and is not affected |
| `PROMPT_TAB_TITLE` | `1` | Set the terminal tab title: the prompt's path outside a git repo, `repo (branch state)` inside one, e.g. `pwsh-profile (main ↑1 ✎ ?)` (`0` to disable). State uses plain Unicode (`✕` conflicts, `↑n`/`↓n` ahead/behind, `✓` staged, `✎` modified, `?` untracked) and follows `PROMPT_GIT_STATE` |

The branch, in-progress operation and commit subject are read straight from `.git` without spawning git. The working tree state is the exception that proves the rule: it needs one `git status` per prompt, so it is time-capped, cached, and can be turned off.

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

## Key bindings

Set up in `profile.d/10_psreadline.ps1` (PSReadLine), `profile.d/50_fzf.ps1` and `profile.d/50_git.ps1`:

| Key | Action |
| --- | --- |
| `Up` / `Down` | Search history for the text already typed |
| `Tab` | Navigable completion menu |
| `Ctrl+R` | Search history with fzf (needs fzf); `Ctrl+R` again inside fzf toggles between recency and match order. The chosen command is placed on the command line, not run |
| `Ctrl+G` | Pick a git branch with fzf (needs git and fzf) and put `git switch ...` on the command line, without running it. Local branches show a desktop icon, remote ones a globe; `Ctrl+P` toggles a log preview. A remote branch with no local copy gives `git switch --track origin/<name>`. Remote branches are as of your last fetch |

Predictions from history show inline as gray text (`Right Arrow` accepts). Lines that look like they contain secrets (password, token, API key, ...) are kept out of the history file. The PSReadLine part only applies in an interactive console.

## Adding a fragment

Drop a `NN_name.ps1` file in `profile.d/`. Lower numbers load first. A fragment that throws produces a warning and the rest still load.

## Tools used

Every tool is optional. A fragment that depends on one is skipped when it is not installed (see [Optional tools](#optional-tools)).

| Tool | What it does | Used for |
| --- | --- | --- |
| [eza](https://github.com/eza-community/eza) | A modern replacement for `ls` with icons and git awareness | `dir` |
| [bat](https://github.com/sharkdp/bat) | A `cat` clone with syntax highlighting and git integration | `cat`, `type` |
| [yazi](https://github.com/sxyazi/yazi) | A fast terminal file manager | `y`, which changes to yazi's last directory on quit |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | A smarter `cd` that learns the directories you use most | Replaces `cd` (`cd proj` jumps to the best match; real paths, `cd -` and `cd ..` work as usual) and adds `cdi` to pick from a list with fzf. Home and temp folders are never learned |
| [fzf](https://github.com/junegunn/fzf) | A command-line fuzzy finder | `Ctrl+R` history search, and picking a package in `wgs` |
| [winget](https://github.com/microsoft/winget-cli) | The Windows package manager | `wgs <query>` searches and installs |
| [Git for Windows](https://gitforwindows.org) | Git and a bundled Unix toolset | `git status` for the prompt's working tree state, and its `file.exe` gives yazi mime-type detection |
| [Nerd Fonts](https://www.nerdfonts.com) | Fonts patched with icon glyphs | Prompt branch icon and the icons in eza |
| [Catppuccin](https://catppuccin.com) | A pastel color theme | Mocha theme for bat |
| [pure](https://github.com/sindresorhus/pure) | A minimal two-line zsh prompt | Inspiration for the prompt in `00_prompt.ps1` |

## License

[MIT](LICENSE)
