if (-not $ProfileTools.lazygit) { return }

# Settings come from the repo's .config\lazygit\config.yml, plus delta.yml (delta as the diff
# renderer) when delta is installed. LG_CONFIG_FILE takes a comma-separated list of files, later
# ones overriding earlier ones. Skipped when LG_CONFIG_FILE is already set.
if (-not $env:LG_CONFIG_FILE) {
    $lazygitFiles = @(
        Get-ProfileToolConfig 'lazygit\config.yml'
        if ($ProfileTools.delta) { Get-ProfileToolConfig 'lazygit\delta.yml' }
    ) | Where-Object { $_ }
    if ($lazygitFiles) { $env:LG_CONFIG_FILE = $lazygitFiles -join ',' }
    Remove-Variable lazygitFiles
}
