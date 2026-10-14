if (-not $ProfileTools.micro) { return }

# Read settings and bindings from the repo's .config\micro, unless MICRO_CONFIG_HOME is already set.
# micro also keeps its buffer history and plugins there (git ignores them).
if (-not $env:MICRO_CONFIG_HOME) {
    $microConfig = Get-ProfileToolConfig 'micro'
    if ($microConfig) { $env:MICRO_CONFIG_HOME = $microConfig }
    Remove-Variable microConfig
}
