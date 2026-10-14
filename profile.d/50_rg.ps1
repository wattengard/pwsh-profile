if (-not $ProfileTools.rg) { return }

# Smart case, hidden files, no .git and colors come from the repo's .config\ripgrep\ripgreprc,
# unless RIPGREP_CONFIG_PATH is already set.
if (-not $env:RIPGREP_CONFIG_PATH) {
    $rgConfig = Get-ProfileToolConfig 'ripgrep\ripgreprc'
    if ($rgConfig) { $env:RIPGREP_CONFIG_PATH = $rgConfig }
    Remove-Variable rgConfig
}

# The folder that holds every profile (C:\Users), derived from the home folder so no path is
# hard-coded. $null when the home folder has no parent to speak of.
$script:RgUsersRoot = Split-Path $env:USERPROFILE -Parent

function script:Test-RgUsersPath {
    # True when $Path is inside the users folder (C:\Users and everything below it).
    param([string]$Path)
    if (-not $script:RgUsersRoot) { return $false }
    try { $full = [IO.Path]::GetFullPath($Path, (Get-Location).ProviderPath) } catch { return $false }
    $root = $script:RgUsersRoot.TrimEnd('\') + '\'
    ($full.TrimEnd('\') + '\').StartsWith($root, [StringComparison]::OrdinalIgnoreCase)
}

function script:Test-RgSearchBlocked {
    # True when a search would read files under the users folder. Explicit paths among the
    # arguments decide; with none, the current folder does.
    param([string[]]$Arguments)
    if ($env:PROFILE_RG_ALLOW_USERS -eq '1') { return $false }
    $targets = @($Arguments | Where-Object { $_ -and -not $_.StartsWith('-') -and (Test-Path -LiteralPath $_) })
    if (-not $targets) { $targets = @('.') }
    [bool]($targets | Where-Object { Test-RgUsersPath $_ })
}

function Invoke-Rg {
    <#
    .SYNOPSIS
        ripgrep that refuses to search inside the users folder.
    .DESCRIPTION
        Searching C:\Users reads every file, and for OneDrive-synced folders (Documents, Desktop
        and the like) that makes OneDrive download all of them. This wrapper declines when the
        search target (a path argument, or the current folder when there is none) is under the
        users folder. Searching piped input is always allowed. Set PROFILE_RG_ALLOW_USERS to 1
        to turn the check off, or call rg.exe directly for a one-off. Other arguments and piped
        input are passed through to rg.
    .NOTES
        Requires: rg
        Aliases: rg
    #>
    if (-not $MyInvocation.ExpectingInput -and (Test-RgSearchBlocked $args)) {
        Write-Warning "Not searching under ${script:RgUsersRoot}: it would make OneDrive download its files. Set PROFILE_RG_ALLOW_USERS=1 to allow it."
        $global:LASTEXITCODE = 2
        return
    }
    if ($MyInvocation.ExpectingInput) { $input | & $ProfileTools.rg @args }
    else { & $ProfileTools.rg @args }
}

Remove-Alias rg -Force -ErrorAction Ignore
Set-Alias -Name rg -Value Invoke-Rg

if (-not $ProfileTools.fzf) { return }

function Search-FileContent {
    <#
    .SYNOPSIS
        Live grep: search file contents with ripgrep, narrowing as you type in fzf.
    .DESCRIPTION
        Every keystroke re-runs ripgrep over the current folder (so ripgrep's own regex syntax
        applies, and .gitignore and .config\ripgrep\ripgreprc are honored), with a preview of the
        match in bat when bat is installed. Enter opens the match in micro at that line when micro
        is installed; otherwise it returns the file and line as an object. Like rg, it declines
        to run under the users folder (see Invoke-Rg).
    .PARAMETER Query
        Pattern to start with. Without one the list starts empty.
    .NOTES
        Requires: rg, fzf
        Aliases: rgf
    #>
    param([string]$Query = '')

    if (Test-RgSearchBlocked @()) {
        Write-Warning "Not searching under ${script:RgUsersRoot}: it would make OneDrive download its files. Set PROFILE_RG_ALLOW_USERS=1 to allow it."
        return
    }

    # fzf runs the reload command through cmd.exe; "|| cd ." keeps a no-match exit code 1 from
    # being treated as a failure that blanks the list.
    $search = 'rg --column --line-number --no-heading --color=always --'
    $fzfArgs = @(
        '--ansi', '--disabled', '--height=80%', '--layout=reverse', '--no-multi', '--info=inline-right'
        '--delimiter=:', '--with-nth=1,2,4..'
        '--prompt=grep> ', "--query=$Query"
        "--bind=change:reload:$search {q} || cd ."
    )
    if ($Query) { $fzfArgs += "--bind=start:reload:$search {q} || cd ." }
    if ($ProfileTools.bat) {
        $fzfArgs += '--preview=bat --color=always --style=numbers --highlight-line {2} -- {1}'
        $fzfArgs += '--preview-window=right,55%,+{2}+3/3'
    }

    # With no initial query there is nothing to list, and an empty pipe keeps fzf from falling
    # back to FZF_DEFAULT_COMMAND (the file list).
    $selected = @() | & $ProfileTools.fzf @fzfArgs
    if ($LASTEXITCODE -ne 0 -or -not $selected) { return }

    $parts = ($selected | Select-Object -First 1) -split ':', 4
    $match = [pscustomobject]@{ Path = $parts[0]; Line = [int]$parts[1]; Column = [int]$parts[2] }
    if ($ProfileTools.micro) { & $ProfileTools.micro $match.Path "+$($match.Line):$($match.Column)" }
    else { $match }
}

Set-Alias -Name rgf -Value Search-FileContent
