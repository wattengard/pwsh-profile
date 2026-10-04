# Optional external tools, dot-sourced by bootstrap.ps1 before profile.d.
# Each tool is looked up once on PATH. Fragments gate their aliases and functions on the result:
#
#   if ($ProfileTools.eza) { ... }        # $ProfileTools.eza is the full path, or $null if missing

$toolNames = @(
    'bat'
    'eza'
    'fzf'
    'winget'
    'yazi'
)

$global:ProfileTools = @{}
foreach ($name in $toolNames) {
    $global:ProfileTools[$name] = Get-Command $name -CommandType Application -ErrorAction Ignore |
        Select-Object -First 1 -ExpandProperty Source
}

Remove-Variable toolNames, name
