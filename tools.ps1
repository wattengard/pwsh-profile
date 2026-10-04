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
#   Name         key in $ProfileTools; also the command looked up on PATH (<name>.exe or <name>.cmd)
#   Description  what the tool does
#   Url          project page
#   Winget       winget package id, used to build the install hint
#   Hint         install hint to show instead of the winget one (for tools winget cannot install)
#   Path         look here instead of on PATH (for tools bundled with something else, or shipped
#                with an extension other than .exe/.cmd)

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
        Name        = 'git'
        Description = 'version control; the prompt runs git status for working tree state'
        Url         = 'https://git-scm.com'
        Winget      = 'Git.Git'
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
    [ordered]@{
        Name        = 'zoxide'
        Description = 'smarter cd that learns your most used directories'
        Url         = 'https://github.com/ajeetdsouza/zoxide'
        Winget      = 'ajeetdsouza.zoxide'
    }
)

# Lookup checks for "<name>.exe" and "<name>.cmd" in each PATH folder in order (first match
# wins, like the shell). That covers real binaries and npm/scoop-style shims in a few ms, and the
# cost is the same whether or not a tool is installed. There is deliberately no Get-Command
# fallback: it takes about 85 ms for each tool it cannot find, and probing every PATHEXT
# extension per folder is slower still. A tool shipped with another extension (.bat, .com) is
# reported missing; give its spec a Path to point at it directly.
$toolDirs = $env:Path -split ';' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ } | Select-Object -Unique
$toolExts = '.exe', '.cmd'

$global:ProfileTools = @{}
foreach ($spec in $global:ProfileToolSpecs) {
    $found = $null
    if ($spec.Path) {
        if ([IO.File]::Exists($spec.Path)) { $found = $spec.Path }
    }
    else {
        :search foreach ($dir in $toolDirs) {
            foreach ($ext in $toolExts) {
                $candidate = [IO.Path]::Combine($dir, $spec.Name + $ext)
                if ([IO.File]::Exists($candidate)) { $found = $candidate; break search }
            }
        }
    }
    $global:ProfileTools[$spec.Name] = $found
}

Remove-Variable spec, found, dir, ext, candidate, toolDirs, toolExts -ErrorAction Ignore
