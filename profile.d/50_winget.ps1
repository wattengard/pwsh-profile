if (-not ($ProfileTools.winget -and $ProfileTools.fzf)) { return }

function Search-WingetPackage {
    <#
    .SYNOPSIS
        Search winget interactively and install the selected package.
    .DESCRIPTION
        Runs "winget search" for the query, lists the results in fzf, and installs the
        chosen package by exact Id. Enter installs, Esc cancels. Ctrl-P shows "winget show"
        for the highlighted package on demand (it is a network call, so it never runs on
        its own). The query may be several words without quotes.
    .EXAMPLE
        wgs bat
    .NOTES
        Requires: winget, fzf
        Aliases: wgs
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Query
    )

    $previousEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    try {
        $output = winget search ($Query -join ' ') --accept-source-agreements
    }
    finally {
        [Console]::OutputEncoding = $previousEncoding
    }

    # Output is a fixed-width table. Skip anything before the header, find where the Id column starts.
    $output = [string[]]@($output)
    $headerIndex = [array]::FindIndex($output, [Predicate[string]] { $args[0] -match '^Name\s+Id\s' })
    if ($headerIndex -lt 0) {
        Write-Warning "No packages found for '$($Query -join ' ')'."
        return
    }
    $header = $output[$headerIndex]
    $idStart = [regex]::Match($header, '\sId\s').Index + 1

    # Prefix each row with its Id and a tab; fzf hides that field (--with-nth) and uses it for preview and selection.
    $rows = $output[$headerIndex..($output.Count - 1)] | ForEach-Object {
        if ($_.Length -le $idStart) { return }
        $id = ($_.Substring($idStart) -split '\s+', 2)[0]
        "$id`t$_"
    }

    $selection = $rows | fzf --reverse --header-lines=2 --delimiter '\t' --with-nth '2..' `
        --preview-window 'hidden,right,60%,wrap' `
        --bind 'ctrl-p:preview(winget show --id {1} --exact)'
    if ($LASTEXITCODE -ne 0 -or -not $selection) { return }

    $id = ($selection -split "`t", 2)[0]
    winget install --id $id --exact
}

Set-Alias -Name wgs -Value Search-WingetPackage
