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

Remove-Alias cat -Force -ErrorAction Ignore
Remove-Alias type -Force -ErrorAction Ignore
Set-Alias -Name cat -Value Invoke-Bat
Set-Alias -Name type -Value Invoke-Bat
