if (-not $ProfileTools.fzf) { return }

# Catppuccin Mocha for every fzf window (including wgs), unless FZF_DEFAULT_OPTS is already set.
if (-not $env:FZF_DEFAULT_OPTS) {
    $env:FZF_DEFAULT_OPTS = '--color=fg:#cdd6f4,fg+:#cdd6f4,bg+:#313244,hl:#f38ba8,hl+:#f38ba8,' +
        'info:#cba6f7,prompt:#cba6f7,pointer:#f5e0dc,marker:#b4befe,spinner:#f5e0dc,header:#f38ba8'
}

function Select-HistoryWithFzf {
    <#
    .SYNOPSIS
        Pick a command from history with fzf and return it.
    .DESCRIPTION
        Lists the PSReadLine history newest first, without duplicates, in fzf and returns the
        chosen command (or nothing if cancelled). Multi-line commands show on one line with a
        return mark but come back intact. Bound to Ctrl+R, where it replaces PSReadLine's
        built-in reverse search; Ctrl+R again inside fzf toggles between recency and match order.
    .PARAMETER Query
        Text to start the fzf search with, normally the current command line.
    .PARAMETER History
        Commands to choose from, oldest first. Defaults to the PSReadLine history.
    .NOTES
        Requires: fzf
        Key: Ctrl+R
    #>
    param(
        [string]$Query = '',
        [string[]]$History = @([Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems().CommandLine)
    )

    # Newest first, de-duplicated, blanks dropped.
    $seen = [Collections.Generic.HashSet[string]]::new()
    $commands = [Collections.Generic.List[string]]::new()
    for ($i = $History.Count - 1; $i -ge 0; $i--) {
        $command = $History[$i]
        if ($command.Trim() -and $seen.Add($command)) { $commands.Add($command) }
    }
    if (-not $commands.Count) { return }

    # fzf gets "index<TAB>one-line text" and hides the index; only the ASCII index comes back,
    # so multi-line and non-ASCII commands are returned untouched from $commands.
    $rows = for ($i = 0; $i -lt $commands.Count; $i++) {
        "$i`t" + ($commands[$i] -replace '\r?\n', ' ↵ ')
    }

    $fzfArgs = @(
        '--height=40%', '--layout=reverse', '--no-multi', '--info=inline-right'
        '--scheme=history', '--tiebreak=index'
        '--delimiter=\t', '--with-nth=2..'
        '--prompt=history> ', "--query=$Query"
        '--bind=ctrl-r:toggle-sort'
    )
    $selected = $rows | & $ProfileTools.fzf @fzfArgs
    if ($LASTEXITCODE -ne 0 -or -not $selected) { return }

    $index = [int]($selected -split "`t", 2)[0]
    $commands[$index]
}

Set-PSReadLineKeyHandler -Chord Ctrl+r -BriefDescription 'FzfHistory' `
    -Description 'Search command history with fzf' -ScriptBlock {
    $line = $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $command = Select-HistoryWithFzf -Query $line

    # fzf drew over the screen; redraw the prompt, then put the choice on the command line.
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    if ($command) {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($command)
    }
}
