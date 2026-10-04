if (-not $ProfileTools.yazi) { return }

# yazi needs file(1) for mime-type detection; the docs recommend the one bundled with Git for Windows.
if (-not $env:YAZI_FILE_ONE -and $ProfileTools.file) {
    $env:YAZI_FILE_ONE = $ProfileTools.file
}

function Invoke-Yazi {
    <#
    .SYNOPSIS
        Run yazi and change to its last directory on quit.
    .DESCRIPTION
        Wraps yazi with --cwd-file so the shell follows you out of it. Quit with q to cd into
        the directory yazi ended in, or Q to quit without changing directory. Extra arguments
        are passed through to yazi. Based on the shell wrapper in the yazi docs.
    .NOTES
        Requires: yazi, and file.exe from Git for Windows (sets YAZI_FILE_ONE when found)
        Aliases: y
    #>
    $tmp = (New-TemporaryFile).FullName
    try {
        yazi.exe @args --cwd-file="$tmp"
        $cwd = Get-Content -Path $tmp -Encoding UTF8
        if ($cwd -and $cwd -ne $PWD.Path -and (Test-Path -LiteralPath $cwd -PathType Container)) {
            Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp -ErrorAction Ignore
    }
}

Set-Alias -Name y -Value Invoke-Yazi
