# Entry point for the personal PowerShell profile. Dot-sourced from $PROFILE.
# Sources config.ps1, tools.ps1, then every profile.d\*.ps1 in name order (rc.d style).

foreach ($bootstrapFile in 'config.ps1', 'tools.ps1') {
    $bootstrapPath = Join-Path $PSScriptRoot $bootstrapFile
    if (Test-Path $bootstrapPath) { . $bootstrapPath }
}

foreach ($bootstrapFile in Get-ChildItem -Path (Join-Path $PSScriptRoot 'profile.d') -Filter '*.ps1' -File | Sort-Object Name) {
    try {
        . $bootstrapFile.FullName
    }
    catch {
        Write-Warning "Failed to load $($bootstrapFile.Name): $_"
    }
}

Remove-Variable bootstrapFile, bootstrapPath -ErrorAction Ignore
