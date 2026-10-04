# Optional external tools, dot-sourced by bootstrap.ps1 before profile.d.
#
# $ProfileToolSpecs is the registry: one entry per tool. Each tool is looked up once at startup
# and the result goes into $ProfileTools, which fragments use to gate their aliases and functions:
#
#   if ($ProfileTools.eza) { ... }        # the full path, or $null if missing
#
# The audit command (profile.d\80_audit.ps1) reads the same registry to report what is missing.
#
# Spec fields:
#   Name         key in $ProfileTools; also the command looked up on PATH
#   Description  what the tool does
#   Url          project page
#   Winget       winget package id, used to build the install hint
#   Hint         install hint to show instead of the winget one (for tools winget cannot install)
#   Path         look here instead of on PATH (for tools that are bundled with something else)

$global:ProfileToolSpecs = @(
    [ordered]@{
        Name        = 'bat'
        Description = 'cat clone with syntax highlighting and git integration'
        Url         = 'https://github.com/sharkdp/bat'
        Winget      = 'sharkdp.bat'
    }
    [ordered]@{
        Name        = 'eza'
        Description = 'modern replacement for ls with icons and git awareness'
        Url         = 'https://github.com/eza-community/eza'
        Winget      = 'eza-community.eza'
    }
    [ordered]@{
        Name        = 'file'
        Description = 'file(1) mime-type detection, needed by yazi (the copy bundled with Git for Windows)'
        Url         = 'https://gitforwindows.org'
        Winget      = 'Git.Git'
        Path        = Join-Path $env:ProgramFiles 'Git\usr\bin\file.exe'
    }
    [ordered]@{
        Name        = 'fzf'
        Description = 'command-line fuzzy finder'
        Url         = 'https://github.com/junegunn/fzf'
        Winget      = 'junegunn.fzf'
    }
    [ordered]@{
        Name        = 'winget'
        Description = 'Windows package manager'
        Url         = 'https://github.com/microsoft/winget-cli'
        Hint        = "'App Installer' from the Microsoft Store"
    }
    [ordered]@{
        Name        = 'yazi'
        Description = 'fast terminal file manager'
        Url         = 'https://github.com/sxyazi/yazi'
        Winget      = 'sxyazi.yazi'
    }
)

$global:ProfileTools = @{}
foreach ($spec in $global:ProfileToolSpecs) {
    $global:ProfileTools[$spec.Name] = if ($spec.Path) {
        (Test-Path -LiteralPath $spec.Path) ? $spec.Path : $null
    }
    else {
        Get-Command $spec.Name -CommandType Application -ErrorAction Ignore |
            Select-Object -First 1 -ExpandProperty Source
    }
}

Remove-Variable spec
