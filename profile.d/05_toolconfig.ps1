# Repo-local tool configs live in .config\<tool>\ next to bootstrap.ps1. Fragments point each
# tool at its file or folder with an environment variable, using this helper.

$global:ProfileConfigDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.config'

function Get-ProfileToolConfig {
    <#
    .SYNOPSIS
        Full path of a repo-local tool config file or folder, or $null if it does not exist.
    .PARAMETER Path
        Path under .config, e.g. 'bat\config' or 'eza'.
    .NOTES
        Used by the 50_* fragments, which only point a tool at the path when this returns one.
    #>
    param([Parameter(Mandatory)][string]$Path)
    $full = Join-Path $global:ProfileConfigDir $Path
    if (Test-Path -LiteralPath $full) { $full }
}
