if (-not $ProfileTools.bat) { return }

function Invoke-Bat {
    <#
    .SYNOPSIS
        bat as a drop-in cat/type with line numbers and git change marks.
    .DESCRIPTION
        Prints files with syntax highlighting, line numbers, git change marks and a filename
        header, in the Catppuccin Mocha theme, without borders or a pager. Piped input and extra arguments are passed through
        to bat.
    .NOTES
        Requires: bat
        Aliases: cat, type
    #>
    $batArgs = '--style=numbers,changes,header', '--paging=never', '--theme=Catppuccin Mocha'
    if ($MyInvocation.ExpectingInput) {
        $input | bat @batArgs @args
    }
    else {
        bat @batArgs @args
    }
}

Remove-Alias cat -Force -ErrorAction Ignore
Remove-Alias type -Force -ErrorAction Ignore
Set-Alias -Name cat -Value Invoke-Bat
Set-Alias -Name type -Value Invoke-Bat
