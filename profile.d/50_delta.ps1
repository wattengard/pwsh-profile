if (-not ($ProfileTools.delta -and $ProfileTools.git)) { return }

# Add .config\git\delta to git's configuration with an include entry in GIT_CONFIG_COUNT.
# That adds to the user's own git config instead of replacing it, appends after any entries
# already in the environment, and is skipped when already present so a reload does not stack.
$deltaConfig = Get-ProfileToolConfig 'git\delta'
if ($deltaConfig) {
    $deltaConfig = $deltaConfig.Replace('\', '/')
    $deltaCount = [int]$env:GIT_CONFIG_COUNT
    $deltaPresent = $false
    for ($deltaIndex = 0; $deltaIndex -lt $deltaCount; $deltaIndex++) {
        if ([Environment]::GetEnvironmentVariable("GIT_CONFIG_VALUE_$deltaIndex") -eq $deltaConfig) { $deltaPresent = $true }
    }
    if (-not $deltaPresent) {
        [Environment]::SetEnvironmentVariable("GIT_CONFIG_KEY_$deltaCount", 'include.path')
        [Environment]::SetEnvironmentVariable("GIT_CONFIG_VALUE_$deltaCount", $deltaConfig)
        $env:GIT_CONFIG_COUNT = [string]($deltaCount + 1)
    }
}
Remove-Variable deltaConfig, deltaCount, deltaPresent, deltaIndex -ErrorAction Ignore
