if (-not ($ProfileTools.git -and $ProfileTools.fzf)) { return }

# Picked per call from PROFILE_ICONS: Nerd Font glyphs, or letters when 'plain'.
$script:GitBranchIcons = @{
    nerd  = @{ Local = [string][char]0xF108; Remote = [string][char]0xF0AC }  # nf-fa-desktop, nf-fa-globe
    plain = @{ Local = 'L'; Remote = 'R' }
}

function Select-GitBranch {
    <#
    .SYNOPSIS
        Pick a local or remote branch with fzf and return the git switch command for it.
    .DESCRIPTION
        Lists every local branch and every remote-tracking branch, newest commit first, with a
        desktop icon for local and a globe for remote (the letters L and R when PROFILE_ICONS
        is 'plain'). Returns the command text and does not run
        it: "git switch <branch>" for a local branch (or a remote one that already has a local
        twin), and "git switch --track <remote>/<branch>" for a remote branch with no local copy.
        Bound to Ctrl+G, which puts the command on the command line for you to review and run.
        Remote branches are as of the last fetch. Ctrl+P toggles a log preview inside fzf.
    .NOTES
        Requires: git, fzf
        Key: Ctrl+G
    #>
    $format = '%(refname)%09%(HEAD)%09%(refname:short)%09%(committerdate:relative)%09%(contents:subject)'
    $refs = @(git for-each-ref --sort=-committerdate "--format=$format" refs/heads refs/remotes 2>$null)
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Not a git repository.'; return }

    $entries = foreach ($line in $refs) {
        $f = $line -split "`t", 5
        if ($f[0].EndsWith('/HEAD')) { continue }   # origin/HEAD is a pointer, not a branch
        $isLocal = $f[0].StartsWith('refs/heads/')
        $short = $f[2]
        $remote = $isLocal ? $null : $short.Substring(0, $short.IndexOf('/'))
        [pscustomobject]@{
            Ref     = $f[0]
            Local   = $isLocal
            Remote  = $remote
            Name    = $isLocal ? $short : $short.Substring($remote.Length + 1)
            Short   = $short
            Current = $f[1] -eq '*'
            Date    = $f[3]
            Subject = $f[4]
        }
    }
    if (-not $entries) { Write-Warning 'No branches found.'; return }

    $localNames = [Collections.Generic.HashSet[string]]::new([string[]]@($entries | Where-Object Local | ForEach-Object Name))
    $nameWidth = [Math]::Min(40, ($entries | ForEach-Object { $_.Short.Length } | Measure-Object -Maximum).Maximum)
    $fg = $PSStyle.Foreground
    $plain = $env:PROFILE_ICONS -eq 'plain'
    $icons = $plain ? $script:GitBranchIcons.plain : $script:GitBranchIcons.nerd

    # Local first, then remote; each group keeps the newest-first order from for-each-ref.
    $ordered = @($entries | Where-Object Local) + @($entries | Where-Object { -not $_.Local })
    $rows = for ($i = 0; $i -lt $ordered.Count; $i++) {
        $e = $ordered[$i]
        $icon = $e.Local ? "$($fg.Green)$($icons.Local)" : "$($fg.Blue)$($icons.Remote)"
        $name = $e.Short.PadRight($nameWidth)
        $mark = $e.Current ? "$($fg.Green)*$($PSStyle.Reset)" : ' '
        "$i`t$($e.Ref)`t$icon$($PSStyle.Reset) $mark $name  $($fg.BrightBlack)$($e.Date.PadRight(14))  $($e.Subject)$($PSStyle.Reset)"
    }

    $fzfArgs = @(
        '--ansi', '--height=50%', '--layout=reverse', '--no-multi', '--info=inline-right'
        '--tiebreak=index'
        '--delimiter=\t', '--with-nth=3..'
        $plain ? '--prompt=switch (L local, R remote)> ' : '--prompt=switch> '
        '--preview=git log --oneline --graph --decorate -n 20 --color=always {2}'
        '--preview-window=right,50%'
        '--bind=ctrl-p:toggle-preview'
    )
    $selected = $rows | & $ProfileTools.fzf @fzfArgs
    if ($LASTEXITCODE -ne 0 -or -not $selected) { return }

    $e = $ordered[[int]($selected -split "`t", 2)[0]]
    $target = ($e.Local -or $localNames.Contains($e.Name)) ? $e.Name : "--track $($e.Short)"
    if ($target -notmatch '^[\w./@+\- ]+$') { $target = "'" + ($target -replace "'", "''") + "'" }
    "git switch $target"
}

# Ctrl+G: pick a branch and put "git switch ..." on the command line, without running it. This
# has to be a key handler (not a typed command) because only a handler can edit the line being
# typed; a command runs after Enter, when the line is already gone.
Set-PSReadLineKeyHandler -Chord Ctrl+g -BriefDescription 'FzfGitSwitch' `
    -Description 'Pick a git branch with fzf and prepare the git switch command' -ScriptBlock {
    $command = Select-GitBranch

    # fzf drew over the screen; redraw the prompt, then put the command on the line.
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    if ($command) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($command) }
}
