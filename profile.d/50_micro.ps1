if (-not $ProfileTools.micro) { return }

# Read settings and bindings from the repo's .config\micro, unless MICRO_CONFIG_HOME is already set.
# micro also keeps its buffer history and plugins there (git ignores them).
if (-not $env:MICRO_CONFIG_HOME) {
    $microConfig = Get-ProfileToolConfig 'micro'
    if ($microConfig) { $env:MICRO_CONFIG_HOME = $microConfig }
    Remove-Variable microConfig
}

# Make micro the editor for git commit messages and other tools that read EDITOR, unless it is
# already set (audit warns when it points elsewhere). The bare name, not the full path, because
# some tools split EDITOR on spaces.
if (-not $env:EDITOR) { $env:EDITOR = 'micro' }
