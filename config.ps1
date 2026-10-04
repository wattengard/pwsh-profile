# Profile configuration, dot-sourced by bootstrap.ps1 before tools.ps1 and profile.d.
#
# This file is tracked and is the single source of truth for every setting: its name, default,
# type and allowed values. Do not edit it to change your own settings, because `git pull` would
# overwrite them. Put overrides in config.local.ps1 instead (git ignores it; see
# config.local.ps1.example). That file is plain PowerShell, one `$env:NAME = 'value'` per line.
#
# Precedence, highest first:
#   1. config.local.ps1, applied on every load (including `. $PROFILE`)
#   2. a value in the environment when the shell started (e.g. set before launching pwsh)
#   3. the default below
# A value typed into a running session wins until the profile is reloaded.
#
# Settings are registered in $ProfileConfigSpecs so tools (the audit, an interactive config
# editor) can list them, validate values and show defaults. Spec fields:
#   Name         environment variable name: PROMPT_* for the prompt only, PROFILE_* for cross-cutting
#   Default      value applied when nothing else sets it (always a string)
#   Type         bool (1 or 0), int, or choice
#   Values       the allowed values, for choice
#   Min          lowest allowed value, for int
#   Group        heading to list it under
#   Description  one line on what it does

$global:ProfileConfigSpecs = @(
    [ordered]@{
        Name        = 'PROFILE_ICONS'
        Default     = 'nerd'
        Type        = 'choice'
        Values      = @('nerd', 'plain')
        Group       = 'General'
        Description = "Icon style for the prompt, eza listings and the branch picker: 'nerd' uses Nerd Font glyphs, 'plain' uses ASCII and standard arrows (pick it if your terminal font is not a Nerd Font)."
    }
    [ordered]@{
        Name        = 'PROMPT_GIT_MESSAGE'
        Default     = '1'
        Type        = 'bool'
        Group       = 'Prompt'
        Description = "Show the current commit's subject, right-aligned on the first prompt line."
    }
    [ordered]@{
        Name        = 'PROMPT_GIT_MESSAGE_WIDTH'
        Default     = '72'
        Type        = 'int'
        Min         = 12
        Group       = 'Prompt'
        Description = 'Max characters of the commit subject. It is also cut to fit beside the path and branch, and left out when fewer than 12 characters would fit.'
    }
    [ordered]@{
        Name        = 'PROMPT_GIT_STATE'
        Default     = '1'
        Type        = 'bool'
        Group       = 'Prompt'
        Description = 'Show working tree state after the branch (staged, modified, untracked, conflicts, ahead/behind). Runs one time-capped git status per prompt.'
    }
    [ordered]@{
        Name        = 'PROMPT_GIT_STATE_TIMEOUT_MS'
        Default     = '150'
        Type        = 'int'
        Min         = 1
        Group       = 'Prompt'
        Description = 'How long the prompt waits for git status, in milliseconds, before showing the last known state and letting git finish in the background.'
    }
    [ordered]@{
        Name        = 'PROMPT_TAB_TITLE'
        Default     = '1'
        Type        = 'bool'
        Group       = 'Prompt'
        Description = 'Set the terminal tab title on every prompt: the prompt''s path outside a git repo, "repo (branch state)" inside one. The state part follows PROMPT_GIT_STATE.'
    }
)

# $ProfileConfigApplied records the values this file applied itself (defaults, and values that
# config.local.ps1 set). On a reload those are cleared and worked out again, so a changed default
# or an edited or removed line in config.local.ps1 takes effect, while a value you typed into the
# session yourself differs from what was recorded and is left alone.
if (-not $global:ProfileConfigApplied) { $global:ProfileConfigApplied = @{} }
$configNames = $global:ProfileConfigSpecs.Name

foreach ($configName in $configNames) {
    $configApplied = $global:ProfileConfigApplied[$configName]
    if ($null -ne $configApplied -and [Environment]::GetEnvironmentVariable($configName) -eq $configApplied) {
        [Environment]::SetEnvironmentVariable($configName, $null, 'Process')
    }
    $global:ProfileConfigApplied.Remove($configName)
}

# Local overrides. Anything the file changes counts as applied by us, so it is refreshed on reload.
$configBefore = @{}
foreach ($configName in $configNames) { $configBefore[$configName] = [Environment]::GetEnvironmentVariable($configName) }

$configLocal = Join-Path $PSScriptRoot 'config.local.ps1'
if (Test-Path -LiteralPath $configLocal) {
    try { . $configLocal }
    catch { Write-Warning "Failed to load config.local.ps1: $_" }
}

foreach ($configName in $configNames) {
    $configNow = [Environment]::GetEnvironmentVariable($configName)
    if ($configNow -and $configNow -ne $configBefore[$configName]) { $global:ProfileConfigApplied[$configName] = $configNow }
}

# Defaults for whatever is still unset.
foreach ($spec in $global:ProfileConfigSpecs) {
    if (-not [Environment]::GetEnvironmentVariable($spec.Name)) {
        [Environment]::SetEnvironmentVariable($spec.Name, $spec.Default, 'Process')
        $global:ProfileConfigApplied[$spec.Name] = $spec.Default
    }
}

Remove-Variable configNames, configName, configApplied, configBefore, configLocal, configNow, spec -ErrorAction Ignore
