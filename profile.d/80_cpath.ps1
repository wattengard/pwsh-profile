function Copy-PathToClipboard {
    <#
    .SYNOPSIS
        Copies the full path of a file or folder to the clipboard.
    .DESCRIPTION
        Resolves each argument (wildcards allowed) to its full path and copies it. Several
        matches are copied one per line. The path is also written to the output so you can
        see what was copied. The item must exist.
    .NOTES
        Aliases: cpath
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Path
    )
    $found = @(Resolve-Path -Path $Path -ErrorAction Stop | ForEach-Object { $_.ProviderPath })
    Set-Clipboard -Value ($found -join "`n")
    $found
}

Set-Alias -Name cpath -Value Copy-PathToClipboard
