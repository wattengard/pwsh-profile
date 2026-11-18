if (-not $ProfileTools.bat) { return }

# Style, paging and theme come from the repo's .config\bat\config, unless BAT_CONFIG_PATH is already set.
if (-not $env:BAT_CONFIG_PATH) {
    $batConfig = Get-ProfileToolConfig 'bat\config'
    if ($batConfig) { $env:BAT_CONFIG_PATH = $batConfig }
    Remove-Variable batConfig
}

function Invoke-Bat {
    <#
    .SYNOPSIS
        bat as a drop-in cat/type with line numbers and git change marks.
    .DESCRIPTION
        Prints files with syntax highlighting, line numbers, git change marks and a filename
        header, in the Catppuccin Mocha theme, without borders or a pager (set in
        .config\bat\config). Piped input and extra arguments are passed through to bat.
    .NOTES
        Requires: bat
        Aliases: cat, type
    #>
    if ($MyInvocation.ExpectingInput) {
        $input | bat @args
    }
    else {
        bat @args
    }
}

function Copy-FileToClipboard {
    <#
    .SYNOPSIS
        Copy the text of one or more files to the clipboard, keeping the encoding.
    .DESCRIPTION
        Reads the files through bat without decorations, so the clipboard gets plain text. bat
        only converts UTF-16 files to UTF-8 when it colors the output, so it runs with colors on
        and the color codes are stripped afterwards (literal color codes in a file go too). The
        console output encoding is set to UTF-8 while the output is decoded and restored after.
    .NOTES
        Requires: bat
        Aliases: clipcat
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Path
    )
    $previousEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $text = & $ProfileTools.bat --style=plain --color=always --paging=never --decorations=always @Path
    }
    finally {
        [Console]::OutputEncoding = $previousEncoding
    }
    if ($LASTEXITCODE -ne 0) { return }
    Set-Clipboard -Value (($text -join [Environment]::NewLine) -replace '\e\[[0-9;]*m')
}

Remove-Alias cat -Force -ErrorAction Ignore
Remove-Alias type -Force -ErrorAction Ignore
Set-Alias -Name cat -Value Invoke-Bat
Set-Alias -Name type -Value Invoke-Bat
Set-Alias -Name clipcat -Value Copy-FileToClipboard
