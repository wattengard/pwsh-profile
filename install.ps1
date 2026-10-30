#Requires -Version 7
<#
.SYNOPSIS
    Replaces the contents of $PROFILE with a single line that dot-sources bootstrap.ps1 from this repo.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'

$bootstrap = Join-Path $PSScriptRoot 'bootstrap.ps1'
if (-not (Test-Path $bootstrap)) {
    throw "bootstrap.ps1 not found at $bootstrap"
}

$profilePath = $PROFILE
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Keep a backup of any existing, non-empty profile before wiping it.
if ((Test-Path $profilePath) -and (Get-Item $profilePath).Length -gt 0) {
    $backup = "$profilePath.bak"
    if ($PSCmdlet.ShouldProcess($profilePath, "Back up to $backup")) {
        Copy-Item $profilePath $backup -Force
        Write-Host "Backed up existing profile to $backup"
    }
}

# $PROFILE may be shared between machines (OneDrive), so the line has to cope with the repo being
# absent on this one: warn and carry on with a plain shell instead of failing on every start.
$quoted = "'$($bootstrap -replace "'", "''")'"
$content = "if (Test-Path -LiteralPath $quoted) { . $quoted } else { Write-Warning ('pwsh-profile is not installed on this machine, expected at ' + $quoted + '. Clone the repo there and run install.ps1.') }"
if ($PSCmdlet.ShouldProcess($profilePath, 'Overwrite with bootstrap pointer')) {
    Set-Content -Path $profilePath -Value $content -Encoding utf8NoBOM
    Write-Host "Profile $profilePath now points to $bootstrap"
}
