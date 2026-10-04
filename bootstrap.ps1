# Entry point for the personal PowerShell profile. Dot-sourced from $PROFILE.
# Sources every profile.d\*.ps1 in name order (rc.d style).

foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'profile.d') -Filter '*.ps1' -File | Sort-Object Name) {
    try {
        . $file.FullName
    }
    catch {
        Write-Warning "Failed to load $($file.Name): $_"
    }
}
